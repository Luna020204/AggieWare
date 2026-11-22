# Integration and preservation verification

Review environment: **Windows, Godot 4.7.2.stable.official.ed1daf0bf**, November 21, 2026. This record covers the current integration revision that preserves Luna's PR #16 (`5412665`), including final PR #14 (`6c86ced`). The original five games use the shared framework; Luna's four use `NativeMicrogameSession` for hosted integration without replacing their implementations.

## Confirmed for this review revision

| Check | Result |
| --- | --- |
| Collection behavior, `tools/test_collection.gd` | 232 checks, 0 failures |
| Actual viewport input, `tools/test_input_routes.gd` | 28 checks, 0 failures |
| Framework presentation and native preservation, `tools/test_presentation.gd` | 914 checks, 0 failures |
| Flow smoke subset, `tools/smoke_flow.gd` | 100 checks, 0 failures |
| Native source/assets SHA-256 comparison | All manifest files match the latest reviewed native revision (see `tools/fixtures/pr16_native_sha256.json`; PR #17 `f4b2ac5` added the Microscope art) |
| Editor import, catalog contract and launcher | Passed; `MICROGAME_CHECK_OK` |
| Scope, Swipe/Awake/Microscope rules | Both native-rule smoke suites passed |
| Accessibility, key remapping and saved settings | `ACCESSIBILITY_SMOKE_OK` |
| Crossing simulation and authored scenes | 56 checks, 0 failures |
| Native Godot editor, Inspector and undo/redo | 12 checks, 0 failures |
| Graphics capture at 1280 x 720 | 36 screens rendered and visually reviewed |
| Windows build pipeline | All gates passed; actual Web export and ZIP packaging succeeded |
| Source-only copy without `.godot` cache | Clean import; all 914 presentation checks passed, including 68 native hashes |
| English source, whitespace and conflict-marker checks | Passed |

The flow smoke suite overlaps the collection suite. The native hash checks are included in the presentation suite. These counts must not be added together as independent coverage totals. Godot logs are also inspected for errors; exit code zero alone is insufficient.

The preservation manifest is `tools/fixtures/pr16_native_sha256.json`. It includes the four native game scripts, scenes and UIDs; `WalkInIntro`, `MicrogameOverlay` and `PixelText`; all Swipe/Awake PNGs and imports; and both art generators. Shared font files are intentionally outside the manifest: existing glyphs are retained while missing syntax and interface symbols are added.

## What the checks cover

The presentation tests distinguish the two integration paths. Framework games retain their shared introduction, countdown, timer and result presentation. Native games retain their own timers, fonts, layouts, game rules and result/status displays; the wrapper contains no extra `InstructionPrompt` or `ResultCue`.

| Preserved native game | Easy / Normal / Hard active seconds | Native introduction |
| --- | --- | --- |
| Variable Not in Scope | 9 / 7 / 5.5 | 0 seconds |
| Swipe Card | 9 / 8 / 7 | 3.2-second walk-in |
| Stay Awake | 8 / 7 / 6 | 3.2-second walk-in |
| Microscope | 10 / 9 / 8 | 0 seconds |

Swipe/Awake checks cover the authored walk/door/fade sequence, click skipping, unchanged sprites and native popup fade. Awake's projected game and drowsy student states remain part of the native presentation. Scope/Microscope start directly; the host does not invent an introduction for them. Scope preserves its original wrong-answer failure, case-sensitive monospace choices and panel layout. Native UI is intentionally preserved rather than normalized to the framework format.

Hosted checks exercise one pause menu, native timer visibility with the common HUD hidden, one native countdown, result hold/fade before navigation, duplicate completion rejection, stale callbacks, and engine-speed restoration. Scope's choice/code fonts and ordinary labels are compared with the raw standalone scene to detect inherited host typography. Pausing a successful Swipe result preserves the accepted card position.

Relaunch tests create fresh native instances at each difficulty. They verify current wallet contents and stale-instance teardown; they do not claim that Luna's original Swipe script supports changing difficulty and rebuilding the wallet within the same native instance. Wrapper restart detaches the prior child and ignores its later result/time signals.

Collection and input checks also cover the retained six-round week, score/life changes, framework retry, actual viewport interactions, transformed dragging, pause/resume, key remapping and custom scene instructions outside the catalog. Crossing's redundant on-screen Escape/pause text is removed while the Escape action still opens settings. Independent Crossing retains its Play Again result control. Location-name boxes have been removed from its runtime scenery and the framework backdrops; the updated captures confirm these changes.

Crossing mechanics checks cover both movement axes, default 1.5x scooter speed, exact speed overrides, traffic events/cycles, swept collisions, pickups, variables, saved scenes and native editing. Full-screen drawing remains separate from simulation and authored coordinates.

## Reproduce

From the project directory, replace `godot` with the Godot 4.7.2 executable:

```sh
godot --headless --editor --path . --import --quit
godot --headless --path . --script res://tools/test_collection.gd
godot --headless --path . --script res://tools/test_input_routes.gd
godot --headless --path . --script res://tools/test_presentation.gd
godot --headless --path . --script res://tools/smoke_flow.gd
godot --headless --path . --script res://tools/check_microgames.gd
godot --headless --path . --script res://tools/smoke_variable_scope.gd
godot --headless --path . --script res://tools/smoke_new_microgames.gd
godot --headless --path . --script res://tools/smoke_accessibility.gd
godot --headless --path . --script res://tests/crossing/test_framework.gd
godot --headless --editor --path . scenes/crossing/campus_intro.tscn -- --test-native-editor
```

For a clean-source check, create a separate copy of the exact reviewed source without `.godot`, build outputs or capture artifacts, then run import and the same checks there. Keep the original project intact. Capture with a graphics renderer:

```sh
godot --path . --script res://tools/capture_collection.gd
```

Inspect full-size images, including native F6 versus hosted presentation, at 1280 x 720. The updated [review galleries](review/format-v1/README.md) show all nine games, Crossing's menus and hosted native results/typography from the new 36-screen set.

The Windows pipeline runs the checks before export:

```powershell
./tools/build_web.ps1 -Godot "C:/path/to/Godot_v4.7.2-stable_win64_console.exe"
```

The equivalent shell entry point is `tools/build_web.sh` with `GODOT` selecting the executable. Matching Web export templates are required. Inspect `build/logs/` and the actual exported files before recording success. Publishing is a separate opt-in operation and is not part of this verification record.

The export used the official Godot 4.7.2 Web templates and produced HTML, JavaScript, PCK, WASM and supporting assets in `build/web/`, packaged as `build/aggieware-web.zip`. Documentation, test tools and review captures are excluded from the game export. Nothing was published to itch.io.

Automated tests and captures do not establish human difficulty balance, full accessibility usability, browser interaction, or macOS/Linux runtime behavior. CI rebuilds from the submitted revision independently.

## Update for PR #17 (Microscope pixel art)

PR #17 redraws Microscope with a lab walk-in. The preservation manifest now records revision `f4b2ac5` (89 files, adding the Microscope art and its generator), and `tools/test_presentation.gd` / `tools/test_collection.gd` treat Microscope as a walk-in game. When a native game is redesigned, regenerate the manifest and update `NATIVE_REVISION`, `NATIVE_FILE_COUNT` and `WALK_IN_IDS` in `tools/test_presentation.gd`.

## Update for PR #18 (Variable Not in Scope pixel art)

PR #18 redraws Variable Not in Scope on a laptop with a walk-in and the case-preserving AggieMono font. The manifest now records revision `5610ac7` (97 files, adding the Scope art, AggieMono and both generators). Scope runs the walk-in checks, and the font checks expect AggieMono instead of a SystemFont.
