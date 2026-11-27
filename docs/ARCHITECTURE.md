# AggieWare architecture

The collection has two integration paths. Canvas, Campus Crossing, Schedule Builder, Stay Focused, and Logic Gates use `MicrogameBase`. Luna's Variable Not in Scope, Swipe Card, Stay Awake, and Microscope retain their native PR #16 scripts and scenes; an external adapter supplies the collection-facing contract. Both paths work with the week flow and debug launcher without requiring a common visual style or identical difficulty timings.

## Ownership and entry points

| Component | Responsibility |
| --- | --- |
| `MicrogameBase` | Framework-game introduction, countdown, feedback, result completion, independent pause/retry |
| `NativeMicrogameSession` | Wrap an unchanged authored game; bridge signals, intro state, host timing and cleanup |
| `game_flow.gd` | Day/round order, score, lives, menus and bike transitions |
| `WeekPlan`, `StageDefinition`, `MicrogameDefinition` | Inspector-editable collection configuration |
| `MicrogameCatalog`, `microgame_launcher.gd` | Select the integration path and launch isolated difficulty/speed tests |
| `InputActions`, `GameState`, `SettingsStore`, `Accessibility` | Shared bindings, pause, saved options and hosted active-round speed |
| `MicrogameUI`, `InstructionPrompt`, `ResultCue`, `game_hud.gd` | Framework presentation and bare TIME display |
| Luna's `PixelText`, `MicrogameOverlay`, `WalkInIntro` | Preserved native typography, centered messages and building-entry animations |
| `pixel_backdrop.gd`, `CardDrag` | Framework environments and transformed drag/drop geometry |
| `scripts/crossing/`, `addons/aggie_crossing/` | Crossing simulation and native Godot level authoring |

F5 enters the week flow. F6 on `scenes/debug/microgame_launcher.tscn` opens the catalog. F6 on a framework microgame enters the shared independent lifecycle. F6 on one of Luna's four native scenes runs that original scene, including its local pause menu, without the external adapter. F6 on an authored crossing level creates the Crossing adapter automatically.

## Preservation boundary

The preserved source is PR #16 commit `5412665`, whose parent is final PR #14 commit `6c86ced`. The four game scripts and scenes, their UIDs, `PixelText`, `MicrogameOverlay`, `WalkInIntro`, Swipe/Awake art and imports, and the two art generators are copied without rewriting the implementations. Existing AggiePixel glyphs remain unchanged; the collection's font generator additionally provides missing syntax and interface symbols.

| Native game | Active seconds: Easy / Normal / Hard | Native introduction | Rules and presentation retained |
| --- | --- | --- | --- |
| Variable Not in Scope | 9 / 7 / 5.5 | 0 | Monospace code, panel layout, case-sensitive decoys, hard-mode shuffle; wrong choice ends the round |
| Swipe Card | 9 / 8 / 7 | 3.2 | Latest Peet's exterior and 16 x 30 walker, centered dimmed title, wallet/reader and real-time swipe speed |
| Stay Awake | 8 / 7 / 6 | 3.2 | Building entrance, lecture hall, animated projector/professor, student states and clickable Z sprites |
| Microscope | 10 / 9 / 8 | 0 | Procedural eyepiece, reference specimen, minimap, target lock and panning |

Scope's lowercase/uppercase distinction is intentional and uses a case-sensitive monospace font. It must not be converted to the caps-only pixel font. A wrong choice is a failure, not a retry popup. The native duration arrays must not be replaced with the framework's 9 / 8 / 7 defaults as an integration shortcut.

## Framework lifecycle

For the five framework games, `_ready()` builds the world, creates shared presentations, and adds a pause menu only for independent play. `_start_round()` resets common and game-specific state. The default introduction lasts 3.2 seconds and is click-skippable. `_begin_play()` starts accessibility timing and allows interaction.

Each active frame reduces the clock, emits `time_changed(left, total)`, and calls `_update_game(delta)` with at most the remaining duration. Timeout is evaluated afterward. `can_interact()` rejects input during introduction, pause, expiration and completion.

`_finish_round(success, message)` guards completion, restores the previous game speed, invokes cleanup, presents the centered result and emits `round_completed(success)`. After the 1.4-second result interval it emits `result_finished()` once. Incorrect actions that allow another attempt use `show_feedback()` without completing the round.

| Child hook | Purpose |
| --- | --- |
| `get_round_seconds()` | Default active duration |
| `_build_ui()` | Create the world and controls once |
| `_reset_game()` | Reset rules, objects and transient interaction |
| `_update_game(delta)` | Advance active simulation |
| `_on_timeout()` | Select the timeout result |
| `_show_result(success, message)` | Cancel drags/tweens and disable controls |
| `_update_intro_progress(elapsed, duration)` | Optional establishing scene or meter visibility |
| `_on_pause_changed(paused)` | Cancel transient interaction when paused |

Framework game scripts keep `_ready`, `_process`, `_start_round` and `_finish_round` inherited. The external native adapter is a separate integration boundary, not a template requiring changes to Luna's game scripts.

## Native host adapter

The catalog factory creates `scripts/core/native_microgame_session.gd` for the four native scene paths. It recognizes the original native contract (`round_completed`, `time_changed`, `get_round_seconds()`, `difficulty` and `show_internal_timer`) without requiring `MicrogameBase` inheritance. The wrapper instantiates the original scene and passes difficulty before it enters the tree. It exposes the host's completion, time and result-finished interface while leaving the native game responsible for its rules, countdown and presentation. It must not also tick a second gameplay clock or call the framework's visual builder over the native scene.

Swipe and Awake retain their own 3.2-second `WalkInIntro`. Scope and Microscope begin immediately. The host's prompt toggle can skip an existing native introduction, but must not invent an additional prompt. The native timer stays in its authored position and the host HUD stays hidden. This prevents a top-left host timer from covering Scope/Microscope's persistent titles.

A native completion signal reserves score/lives once. The wrapper restores hosted speed and waits for the result interval before emitting `result_finished`; it does not add another result banner. Native child processing continues so `MicrogameOverlay` can fade and Awake's projector can animate. The native game's own ended flag blocks further gameplay.

For hosted play, the original scene's local pause-menu instance is removed from the runtime instance and the host supplies one pause menu. The source `.tscn` remains untouched. The wrapper cancels a held Swipe card on pause so the mouse release and real-time swipe timestamps cannot span the paused interval. Replacing a hosted round creates a fresh native scene rather than changing the difficulty of an existing wallet.

Native F6 is deliberately different: the original scene owns its clock, result/status display and local pause menu. It does not receive wrapper navigation, the framework's R-retry lifecycle, or hosted timer assistance. Use the launcher to test those integration features.

## Host and registry contracts

The catalog is the shared creation boundary for both week flow and launcher. Hosts configure difficulty, playback speed, prompt visibility and result wait before adding the returned game. Duration overrides apply to framework games. For a native game, a nonzero WeekPlan override produces a warning and the authored duration remains in force. The collection-facing signals are `time_changed(left, total)`, `round_completed(success)` and `result_finished()`. The host protocol also exposes `get_seconds_left()`, `get_round_duration()`, `get_round_seconds()`, `get_intro_seconds()`, `skip_intro()`, `can_interact()`, `is_playing()`, `is_round_finished()` and `uses_native_hud()`. The host HUD reads these APIs rather than native fields. Native presentation metadata remains authored in the native game; implementation-specific `_intro_left` and overlay fade reads are isolated inside `NativeMicrogameSession`.

The WeekPlan holds the days in order. StageDefinition chooses a game index from its own pool using the win count and previous scene path. Ordered days advance on wins. Pool days exclude every entry that points to the last scene when an alternative exists. The host selects once before the bike preview and mounts that same index on arrival. Day wins are independent of the index. SettingsStore saves the highest unlocked day alongside the player's options.

The host sets the minimum difficulty tier and playback speed using day and win progress. Game-specific difficulty floors still apply. Accessibility owns the gameplay clock and restores it for results. On the first active clock tick after each intro, AudioManager applies that same progress to the looping 8 Bit Aggie track. Timer assist scales both clocks. The music player changes playback speed and pitch together. Returning to the title restores 1× playback.

The flow reserves `RESULT` synchronously before changing score or lives. Run tokens protect time, outcome, result-finished and bike callbacks from obsolete rounds. The launcher uses the same guards. Replacement detaches nodes immediately and defers destruction, preventing stale controls from processing on a newer screen.

## Shared systems and art

Framework presentation follows the producer-format defaults: AggiePixel, proportional dark shadows, pixel worlds, temporary introductions/results and an unboxed TIME display. `MicrogameUI.build_header()` supplies intro metadata and a timer; its legacy title/instruction nodes are hidden. Framework worlds render to 256 x 144 surfaces enlarged to 1280 x 720 with nearest filtering, while input Controls remain in gameplay coordinates.

The native games are explicitly outside that restyling. Swipe and Awake use Luna's 5x nearest sprite artwork and helpers; Scope and Microscope retain their earlier layouts and fonts. Their helpers are retained separately rather than replaced by `MicrogameUI`.

`CardDrag` converts mouse positions to the card parent's coordinates. Drop geometry works with transformed parents and targets. Canvas and Gates cancel drags on pause/completion; uploaded files follow moving targets. Swipe keeps its own gesture implementation.

`InputActions` preserves nonempty project bindings and creates defaults for missing actions. `GameState` owns pause and validated settings. Pause input runs after UI capture so Escape can cancel rebinding without resuming play. `SettingsStore` saves options and bindings to `user://settings.cfg`; script tests isolate player settings.

For hosted play, `Accessibility` applies launcher speed divided by timer assistance after the actual introduction ends. It restores the previous speed on completion or detachment. Ownership guards prevent stale cleanup from resetting a newer round's speed. A native rejection popup retains `MicrogameOverlay`'s own game-time fade; the wrapper does not rewrite the helper to impose a different feedback clock.

## Native crossing authoring

Levels remain `.tscn` scenes rooted at `CrossingCampusLevel`. Roads and objects are native child nodes. Each lane's `CrossingVehicleEvent` resources specify type, spawn time and speed override. Default scooters move at 1.5 times the bicycle lane speed; nonzero overrides are exact speeds. Use Make Unique for independent duplicated schedules.

`pixel_campus_renderer.gd` fills the 1280 x 720 playfield. Road/object positions map from the original 840 x 600 coordinates while sprites keep fixed pixel proportions. `campus_canvas.configure_runtime_view()` selects this runtime-only path; the editor retains its original grid and annotations.

Each attempt copies authored data into the simulation. Initial variables and pickups reset without modifying the authored scene. `game_hooks.gd` exposes item handlers, vehicle registration, variables and signals. The editor dock, timeline, undo/redo, validation and JSON interchange remain native Godot features. See [Crossing Level Guide](CROSSING_LEVEL_GUIDE.md).

## Verification and history

Tests must distinguish the two paths: framework lifecycle/presentation checks, native gameplay and preservation checks, and hosted adapter integration checks. Captures should show the preserved native presentation as well as framework scenes. See [Validation](VALIDATION.md) for actual revision evidence; no test counts or platform-validation claims are implied here.

The original README, technical record and vertical-slice checkpoint remain under `docs/` as historical records. Current instructions belong in the root README and current guides. The original Downloads checkout is not the publishing workspace. Integration changes do not imply measured performance improvements or validated release-platform behavior.
