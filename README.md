# AggieWare

An ECS 179 collection of short games about student life at UC Davis. Nine microgames are available through the week flow and debug launcher. The original five use the shared microgame framework; Luna's four retain their PR #16 implementations and connect through an external host adapter. Game UI, custom editor tools, code comments, and current documentation use English.

## Open and play

Use **Godot 4.7.2-stable**, standard edition, with the GL Compatibility renderer. Import `project.godot` and press **F5**. The viewport is 1280 × 720.

The default week preserves six rounds across five days:

| Day | Rounds | Difficulty |
| --- | --- | --- |
| Monday | Canvas Upload → Campus Crossing | Easy, Easy |
| Tuesday | Schedule Builder | Easy |
| Wednesday | Stay Focused | Normal |
| Thursday | Logic Gates | Normal |
| Friday | Canvas Final Upload | Hard |

Each successful round earns 100 points; failure costs one of three lives and retries that round after the bike transition. Day clear follows the last round of a day. Game over offers a fresh attempt at that day. Score, lives, and day sequencing remain host state. Each game retains its own gameplay presentation.

All nine scenes also support independent **F6** play:

| Microgame | Launcher ID | Scene |
| --- | --- | --- |
| Canvas Upload | `canvas` | `scenes/microgames/canvas.tscn` |
| Campus Crossing | `crossing` | `scenes/microgames/crossing.tscn` |
| Schedule Builder | `schedule` | `scenes/microgames/schedule_builder.tscn` |
| Stay Focused | `focus` | `scenes/microgames/stay_focused.tscn` |
| Logic Gates | `gates` | `scenes/microgames/gates.tscn` |
| Variable Not in Scope | `scope` | `scenes/microgames/variable_scope.tscn` |
| Swipe Card | `swipe` | `scenes/microgames/swipe_card.tscn` |
| Stay Awake | `awake` | `scenes/microgames/stay_awake.tscn` |
| Microscope | `microscope` | `scenes/microgames/microscope.tscn` |

The four additional games are available in the launcher and as configurable week-plan entries. They do not replace the original week. The five framework games support shared pause and **R** retry in F6. Luna's four scenes retain their native F6 behavior and local pause menu; the host adapter is used only when launched through the collection or debug launcher. Their native scenes do not acquire the framework's R-retry or timer-assist lifecycle. Use the launcher to test hosted settings, or F8 and F6 to restart a native scene.

## Presentation and preserved implementations

Canvas, Campus Crossing, Schedule Builder, Stay Focused, and Logic Gates use `MicrogameBase`: a 3.2-second click-skippable introduction, 9 / 8 / 7 seconds of active play, and 1.4 seconds of centered result feedback. Their shared presentation uses AggiePixel text, nearest-neighbor pixel worlds, a top-left TIME label and small game-specific meters.

Luna's four games are preserved from **PR #16, commit `5412665`**, which includes the final **PR #14 commit `6c86ced`**. Their scripts, scenes, presentation helpers, and Swipe/Awake artwork remain unchanged. The integration adapter handles host signals and timing without replacing their visuals or game rules.

| Game | Easy / Normal / Hard active seconds | Native intro | Preserved presentation and rules |
| --- | --- | --- | --- |
| Variable Not in Scope | 9 / 7 / 5.5 | None | Monospace code, panels, case-sensitive decoys; a wrong choice fails |
| Swipe Card | 9 / 8 / 7 | 3.2 seconds, click to skip | Redrawn Peet's entrance, larger walking student, centered dimmed title, wallet and reader; rejected swipes can retry |
| Stay Awake | 8 / 7 / 6 | 3.2 seconds, click to skip | Building entrance, lecture hall, animated projector, professor, student and Z sprites |
| Microscope | 10 / 9 / 8 | None | Original procedural eyepiece, reference specimen, minimap, panning and focus rules |

Hosted Luna games retain their own timers and result/status presentation. The collection does not place another prompt, timer or result banner over them. It waits for the result interval before advancing. Native F6 scenes remain independent of that navigation. The AggiePixel font retains its original existing glyphs; the generator adds missing syntax and interface symbols used elsewhere in the collection.

These are deliberate preservation choices, so the producer-format defaults are not universal claims about all nine games. See [Format and Preservation Guide](docs/FORMAT_STANDARD.md) for the boundaries and review procedure.

## Controls and saved settings

| Action | Default | Use |
| --- | --- | --- |
| `game_up`, `game_down` | Up / W, Down / S | Movement and selection |
| `game_left`, `game_right` | Left / A, Right / D | Movement |
| `game_confirm` | Enter / Space | Confirm and skip bike transition |
| `game_type` | Space / Enter | Primary game interaction |
| `game_mash` | Space / Enter | Repeated interaction |
| `game_pause` | Escape | Pause / resume |
| `game_retry` | R | Restart an independent framework game |

Canvas, Gates, and Swipe Card use dragging; Schedule, Variable Scope, and Stay Awake use clicks. Focus uses horizontal movement or the mouse. Crossing and Microscope use directional movement.

Open **Escape → Controls** to rebind movement, confirm, type, mash, and standalone retry. Click a binding and press its replacement; Escape cancels capture while keeping the game paused. Conflicting bindings show a warning. **Reset keys** restores defaults. **Hold instead of mash** repeats the shared mash action every 0.12 game seconds while held.

**Timer assist** offers Off, +25%, and +50% real time by slowing active game time in the framework or hosted adapter. Introductions and terminal results remain outside assisted play. Luna's unwrapped F6 scenes keep their authored timing. **Result symbols and low-time warning** controls the shared framework's optional cues; Luna's own result visuals are preserved.

`SettingsStore` saves bindings and options to `user://settings.cfg` and restores them on launch. Script-based tests use isolated settings paths. `InputActions` preserves nonempty project bindings; default bindings can also be edited in Godot's Input Map. Music and sound-effect preferences are stored for future audio playback.

## Debug launcher

Open `scenes/debug/microgame_launcher.tscn` and press F6. Select a game and difficulty, choose 0.5×–2× test speed, then launch. Clearing the **Prompt** checkbox skips an existing introduction for quick tests; Scope and Microscope already have no native introduction. Timer assist combines with test speed only during active play. **STOP** returns early; normal completion returns after the result interval without adding a second result banner.

```sh
godot --path . res://scenes/debug/microgame_launcher.tscn -- --microgame=swipe --difficulty=2 --speed=1.5
```

`scripts/core/microgame_catalog.gd` lists all nine games and their host metadata. Its factory accepts the common host protocol or wraps a native game in `NativeMicrogameSession`. The catalog supplies launcher availability; the WeekPlan separately controls the main game's order.

## Edit the week

Open `scenes/core/game_flow.tscn`, select **GameFlow**, and expand **Week Plan**. Its resource is `scenes/core/default_week.tres`.

- `WeekPlan.Stages` contains ordered day resources.
- Each `StageDefinition` has a **Title** and an ordered **Games** array.
- Each `MicrogameDefinition` sets **Id**, **Title**, **Prompt**, **Scene Path**, **Difficulty**, and **Round Seconds Override**. Zero uses the game's normal duration. A nonzero override applies to framework games; preserved native games retain their authored duration and issue a warning instead.

To add a round, extend a day's Games array, create a `MicrogameDefinition`, and assign a microgame scene path. Reorder the arrays to change the sequence. Save the resource and test with F5. Use **Make Unique** before changing duplicated resources independently. Keep at least one round per day. The flow automatically transitions between rounds and waits for all rounds before day clear.

## Author crossing levels

Open `scenes/crossing/campus_intro.tscn` in Godot's 2D editor, or save a copy of `scenes/crossing/blank_template.tscn`. The enabled **Aggie Crossing Level Tools** plugin provides the **Campus Tools** dock and lane **Traffic Schedule** Inspector.

Place native road, obstacle, pickup, Start, and Goal nodes. A lane exposes **Direction**, **Default Speed**, **Cycle Seconds**, and **Events**. Each vehicle event sets its type, spawn time, and optional speed override. With a zero override, bicycles use the lane speed and scooters use **1.5×** that speed. Nonzero overrides are exact speeds. Vehicles move horizontally; the student can move in four directions toward the goal at the top.

Play fills the screen with the authored campus, using pixel student, bicycle, scooter, pickup, and obstacle sprites, crosswalks, trees, flowers, and library-side scenery. TIME, crossing progress, and inventory remain small unboxed indicators; pause and independent retry use the shared controls. The full-screen runtime mapping preserves fixed sprite proportions and leaves the native editor grid, object placement, and simulation geometry unchanged.

Use **Validate**, then F6 to play the authored layout. To include it in the collection:

1. Save the layout under `scenes/crossing/`.
2. Save a copy of `scenes/microgames/crossing.tscn` as its playable wrapper.
3. Set the wrapper root's **Level Scene** to the authored layout.
4. Assign that wrapper's path to a week-plan game definition.
5. Set difficulty or a duration override, save, and test F5.

Initial Variables and item Properties remain available to extensions. `scripts/crossing/game_hooks.gd` supplies variables, signals, item handlers, and vehicle registration; `extensions/crossing/coffee_pickup.gd` demonstrates a custom pickup. See the [Crossing Level Guide](docs/CROSSING_LEVEL_GUIDE.md) for full authoring and interchange instructions.

## Add a microgame

For a new framework game, create a full-rect `Control` scene with a script extending `MicrogameBase`. This section applies to framework games, not to the preserved Luna source files.

| Hook / API | Responsibility |
| --- | --- |
| `get_round_seconds()` | Difficulty-specific active duration; normally 9 / 8 / 7 |
| `_build_ui()` | Build the pixel world and interactive objects once |
| `_reset_game()` | Restore a fresh attempt |
| `_update_game(delta)` | Advance active gameplay |
| `_on_timeout()` | Choose the outcome at the deadline |
| `_show_result(success, message)` | Cancel drags/tweens and disable controls; presentation belongs to the base |
| `_finish_round(success, message)` | Finish once and start shared result feedback |
| `show_feedback(message, color)` | Temporary central feedback for an incorrect or intermediate action |
| `can_interact()` | Gate input during introduction, pause, expiry, or completion |
| `_update_intro_progress(elapsed, duration)` | Optional establishing-scene animation or meter visibility |
| `_on_pause_changed(paused)` | Cancel transient interaction when needed |

The base owns `_ready`, `_process`, `_start_round`, `_finish_round`, introductions, results, timer assistance, and standalone pause/retry. Keep those lifecycle methods inherited. `_seconds_left` and `_round_seconds` describe active game time. The base bounds the final update to the remaining duration.

For framework games, hosts set `managed_by_flow`, `show_internal_timer`, `game_title`, `instruction_text`, `difficulty`, `duration_override`, `playback_speed`, and `result_seconds` before adding the scene. `round_completed(success)` reserves score/lives immediately; **`result_finished()`** permits navigation only after the feedback fade. `time_changed(left, total)` updates the shared timer. Framework games never route themselves or add another hosted pause/intro/result overlay. Preserved native games instead keep their own presentation and expose their original signals through the external adapter.

Use `MicrogameUI` for new framework fonts, shadows, labels, transparent buttons, and pixel canvases. Use `CardDrag` for drag/drop geometry. To integrate an existing authored game, preserve its script and scene. The catalog factory wraps a native `Control` with `round_completed`, `time_changed`, `get_round_seconds()`, `difficulty` and `show_internal_timer` in `scripts/core/native_microgame_session.gd`; no inheritance or presentation rewrite is required. Add an entry to `MicrogameCatalog` for launcher testing, and optionally add a WeekPlan entry for F5. See [Architecture](docs/ARCHITECTURE.md).

## Verify and build

From the project directory, replace `godot` with your Godot 4.7.2 executable:

```sh
godot --headless --editor --path . --import --quit
godot --headless --path . --script res://tools/test_collection.gd
godot --headless --path . --script res://tools/test_input_routes.gd
godot --headless --path . --script res://tools/test_presentation.gd
godot --headless --path . --script res://tools/check_microgames.gd
godot --headless --path . --script res://tools/smoke_accessibility.gd
godot --headless --path . --script res://tools/smoke_variable_scope.gd
godot --headless --path . --script res://tools/smoke_new_microgames.gd
godot --headless --path . --script res://tests/crossing/test_framework.gd
godot --headless --editor --path . scenes/crossing/campus_intro.tscn -- --test-native-editor
```

`tools/smoke_flow.gd` is the smaller flow subset. `tools/capture_collection.gd` requires a graphics renderer and produces review captures. `tests/crossing/generate_samples.gd` intentionally replaces the supplied sample layouts; use it only when rebuilding those examples. Recorded results and limits belong in [Validation](docs/VALIDATION.md).

`tools/build_web.ps1` or `tools/build_web.sh` runs the checks and exports the Web preset to `build/web/`, then packages `build/aggieware-web.zip`. Godot 4.7.2 export templates are required. The GitHub workflow builds pull requests and configured release events. Local publishing requires `-Publish` / `--publish`; itch.io publishing requires the configured `BUTLER_API_KEY` secret and `ITCH_TARGET` destination. Build scripts and templates are separate from evidence that an export was successfully validated.

## Project layout and credits

| Location | Purpose |
| --- | --- |
| `scenes/core/`, `scripts/core/` | Week resources, flow, shared lifecycle, settings, input |
| `scenes/microgames/`, `scripts/microgames/` | Nine playable games |
| `scenes/debug/`, `scripts/debug/` | Catalog launcher |
| `scenes/ui/`, `scripts/ui/` | Shared presentation, pixel worlds, pause UI |
| `scenes/crossing/`, `addons/aggie_crossing/` | Native crossing levels and editor tools |
| `scripts/crossing/`, `levels/crossing/`, `extensions/crossing/` | Simulation, interchange data, extension example |
| `assets/fonts/`, `assets/art/`, `tools/art/` | AggiePixel, sprites, and their generators |
| `tools/`, `tests/crossing/` | Verification, captures, build tools |
| `docs/` | Format, authoring, architecture, validation, historical records |

| Name | Main role | Sub-role |
| --- | --- | --- |
| Gaeun (Luna) Yu | Technical Producer | Accessibility and Usability Design |
| Zheng Zhou | Game Logic | Game Programming |
| Hongrui Zhao | User Interface and Input | TBD |
| Kyle Groves | Animation and Visuals | Music |
| Diego Beltran | Movement/Physics | Game Feel |
| Yutong Guo | Technical Artist | Player Onboarding and Tutorial Design |

The [original collection README](docs/AGGIEWARE_ORIGINAL_README.md), [Hongrui's technical record](docs/individual-technical-record-hongrui.md), and [vertical-slice checkpoint](docs/SCRUM-52-vertical-slice-checkpoint.md) are preserved as historical records. This README describes the current implementation.

The checked-in generators create the AggiePixel font and Luna's Swipe Card and Stay Awake sprites. The framework environments use procedural pixel drawing. Campus Crossing layouts are fictional. Record sources and licenses when adding outside assets.
