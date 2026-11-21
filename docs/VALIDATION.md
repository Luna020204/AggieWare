# Integration Verification

Verified on Windows with **Godot 4.7.2.stable.official.ed1daf0bf** on November 21, 2026. These results apply to the integrated workspace, not the unchanged source collection in Downloads.

| Check | Result |
| --- | --- |
| Editor import, resource registration, enabled authoring plugin | Passed |
| Source-only copy without the workspace's `.godot` cache | Imported successfully; collection and input suites passed |
| Collection behavior suite, `tools/test_collection.gd` | 149 checks, 0 failures |
| Flow smoke subset, `tools/smoke_flow.gd` | 100 checks, 0 failures |
| Actual viewport input, `tools/test_input_routes.gd` | 17 checks, 0 failures |
| Crossing framework, `tests/crossing/test_framework.gd` | 56 checks, 0 failures |
| Native Godot editor, `tests/crossing/native_editor_test.gd` | 12 checks, 0 failures |
| Render captures with the Compatibility renderer | 9 captures reviewed |
| Chinese-character scan of source, scenes, custom tools, tests, and documentation | No matches |

The smoke suite is a subset of the collection suite; its checks should not be added to the full suite's total. Input checks dispatch real viewport keyboard and mouse events to verify menu confirmation, mouse upload/submission, transformed card and target geometry, moving targets, standalone retry, and releasing a drag while paused.

The collection suite exercises the six-round week through game mechanics, correct and incorrect uploads/gates, registration opening and duplicate clicks, Focus interception and misses, exactly-once results, score/life changes, retry, stale callbacks, pause during results and bike transitions, and synchronized crossing simulation/countdown advancement. Crossing tests cover both movement axes, default scooter speed, explicit speeds, event times and cycle boundaries, collisions, obstacle blocking, pickup extensions, saved authoring data, typed event resources, and native editor undo/redo.

The rendered captures cover the title, day selection, all five microgames, the pause overlay, and direct F6 play of an authored crossing level at 1280 x 720. Reproduce them with `godot --path . --script res://tools/capture_collection.gd`; this command requires a graphics renderer and writes to `artifacts/collection-preview/`.

See the root README for the behavior and editor test commands. Automated outcomes and layout review do not establish human difficulty balance, frame-rate improvements, web-export compatibility, or cross-platform certification. Those remain separate playtesting and release tasks.
