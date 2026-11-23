#!/usr/bin/env bash
# Build and validate locally or in CI; --publish explicitly opts in to itch.io.
# GODOT selects the Godot 4.7.2 executable. SKIP_TESTS=1 bypasses regression tests.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
PUBLISH=0
if [[ "${1:-}" == "--publish" ]]; then PUBLISH=1; fi
mkdir -p build/logs

run_godot() {
  local name="$1" marker="$2" status=0
  shift 2
  echo "Running $name"
  "$GODOT" "$@" >"build/logs/$name.log" 2>&1 || status=$?
  # Godot 4.7's dummy renderer can emit this lone, nonfatal import race.
  # https://github.com/godotengine/godot/issues/124139
  if [[ "$name" == import ]] && (( status == 0 )); then
    local import_errors
    import_errors="$(grep -E '^[[:space:]]*(SCRIPT ERROR|ERROR|Parse Error):' "build/logs/$name.log" || true)"
    if [[ "$import_errors" == 'ERROR: Parameter "t" is null.' ]]; then
      mv "build/logs/$name.log" build/logs/import-first.log
      echo 'Retrying import after Godot headless texture race'
      "$GODOT" "$@" >"build/logs/$name.log" 2>&1 || status=$?
    fi
  fi
  if (( status != 0 )) || grep -Eq '^[[:space:]]*(SCRIPT ERROR|ERROR|Parse Error):' "build/logs/$name.log"; then
    cat "build/logs/$name.log"
    echo "Godot check failed: $name (exit $status)."
    exit 1
  fi
  if [[ -n "$marker" ]] && ! grep -Eq "$marker" "build/logs/$name.log"; then
    cat "build/logs/$name.log"
    echo "Godot check failed: $name did not report success."
    exit 1
  fi
}

run_godot version '^4\.7\.2\.' --headless --version
run_godot import '' --headless --path . --import
if [[ "${SKIP_TESTS:-0}" != "1" ]]; then
  for test in test_onboarding smoke_flow test_collection test_input_routes test_presentation check_microgames smoke_variable_scope smoke_new_microgames smoke_accessibility; do
    run_godot "$test" '^[A-Z_]+_OK[[:space:]]*$' --headless --path . --script "res://tools/$test.gd"
  done
  run_godot crossing_framework 'RESULT: [0-9]+ checks, 0 failures' --headless --path . --script res://tests/crossing/test_framework.gd
  run_godot crossing_editor 'NATIVE EDITOR RESULT: [0-9]+ checks, 0 failures' --headless --editor --path . scenes/crossing/campus_intro.tscn -- --test-native-editor
fi

# Remove old files so a failed export can never pass by finding a stale build.
rm -rf -- build/web
mkdir -p build/web
run_godot export '' --headless --path . --export-release Web build/web/index.html
for file in index.html index.pck index.wasm index.js; do
  if [[ ! -s "build/web/$file" ]]; then echo "Export is missing $file."; exit 1; fi
done
COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo local)"
printf '%s\n' "$COMMIT" > build/web/BUILD_COMMIT.txt
rm -f -- build/aggieware-web.zip
if command -v zip >/dev/null; then
  (cd build/web && zip -qr ../aggieware-web.zip .)
else
  python3 -c "import shutil; shutil.make_archive('build/aggieware-web', 'zip', 'build/web')"
fi
echo "Created build/aggieware-web.zip"
if (( PUBLISH == 1 )); then
  : "${BUTLER_API_KEY:?Publishing requires BUTLER_API_KEY}"
  : "${ITCH_TARGET:?Publishing requires ITCH_TARGET}"
  butler push build/web "$ITCH_TARGET" --userversion "$COMMIT"
fi
