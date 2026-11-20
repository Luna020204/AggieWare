#!/usr/bin/env bash
# SCRUM-59: build (and optionally publish) the AggieWare web build.
#
#   tools/build_web.sh            smoke tests -> web export -> build/aggieware-web.zip
#   tools/build_web.sh --publish  ...then push to itch.io with butler
#
# Env:
#   GODOT            Godot 4.7.2 executable (default: godot on PATH)
#   BUTLER_API_KEY   itch.io API key (publish only; never commit it)
#   ITCH_TARGET      itch.io target, e.g. user/aggieware:html5 (publish only)
#   SKIP_TESTS=1     skip the smoke-test gate (not recommended)
set -euo pipefail

cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
PUBLISH=0
if [[ "${1:-}" == "--publish" ]]; then PUBLISH=1; fi

step() { printf '\n== %s\n' "$*"; }

step "Godot version"
"$GODOT" --headless --version

step "Import project"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true

if [[ "${SKIP_TESTS:-0}" != "1" ]]; then
  for test in smoke_flow check_microgames smoke_variable_scope smoke_new_microgames; do
    step "Smoke test: $test"
    if ! out="$("$GODOT" --headless --path . --script "res://tools/$test.gd" 2>&1)"; then
      echo "$out" | tail -30
      echo "FAILED: $test"
      exit 1
    fi
    if ! echo "$out" | grep -E "_OK$"; then
      echo "$out" | tail -30
      echo "FAILED: $test printed no _OK line"
      exit 1
    fi
  done
fi

step "Export Web preset"
rm -rf build/web
mkdir -p build/web
"$GODOT" --headless --path . --export-release "Web" build/web/index.html || true
if [[ ! -f build/web/index.html || ! -f build/web/index.pck ]]; then
  echo "Export did not produce build/web/index.html + index.pck."
  echo "Are the Godot 4.7.2 export templates installed? (Editor > Manage Export Templates)"
  exit 1
fi

step "Package"
COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo local)"
echo "$COMMIT" > build/web/BUILD_COMMIT.txt
rm -f build/aggieware-web.zip
if command -v zip >/dev/null; then
  (cd build/web && zip -qr ../aggieware-web.zip .)
else
  python3 -c "import shutil; shutil.make_archive('build/aggieware-web', 'zip', 'build/web')"
fi
ls -l build/aggieware-web.zip

if [[ "$PUBLISH" == "1" ]]; then
  step "Publish to itch.io"
  : "${BUTLER_API_KEY:?set BUTLER_API_KEY to publish}"
  : "${ITCH_TARGET:?set ITCH_TARGET, e.g. user/aggieware:html5}"
  butler push build/web "$ITCH_TARGET" --userversion "$COMMIT"
fi

step "Done: build/web ($COMMIT)"
