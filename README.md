# AggieWare

A collection of short games about a week in the life of a UC Davis student, built for ECS 179. Campus Crossing is integrated into the same day sequence, timer, score, lives, pause menu, and retry flow as the original games. All game UI, custom editor tools, code comments, and project documentation are in English.

## Open and play

Use **Godot 4.7.2-stable**, standard edition, with the GL Compatibility renderer. Import `project.godot` and press **F5** to run the collection. The project uses a 1280 × 720 viewport.

Select a day, complete its rounds, and continue through the week. A successful round earns 100 points. A failed round costs one of three lives and retries that round after the bike transition. Losing all lives offers a fresh attempt at the current day. A short instruction prompt appears before each round; the timer starts after it disappears. Pausing freezes the game, transition, and result delay.

The default week has six rounds across five days:

| Day | Rounds, in order | Difficulty |
| --- | --- | --- |
| Monday | Canvas Upload → Campus Crossing | 0, 0 |
| Tuesday | Schedule Builder | 0 |
| Wednesday | Stay Focused | 1 |
| Thursday | Logic Gates | 1 |
| Friday | Canvas Final Upload | 2 |

Open any of these five microgame scenes and press **F6** to test it independently:

| Microgame | Scene |
| --- | --- |
| Canvas Upload | `scenes/microgames/canvas.tscn` |
| Campus Crossing | `scenes/microgames/crossing.tscn` |
| Schedule Builder | `scenes/microgames/schedule_builder.tscn` |
| Stay Focused | `scenes/microgames/stay_focused.tscn` |
| Logic Gates | `scenes/microgames/gates.tscn` |

Independent microgames receive their own timer, pause menu, and retry control. You can also play `scenes/core/bike_transition.tscn` or `scenes/core/game_flow.tscn` with F6. Stop play with F8 to return to editing.

## Controls

| Shared action | Default binding | Use |
| --- | --- | --- |
| `game_up`, `game_down` | Up / W, Down / S | Movement and menu selection |
| `game_left`, `game_right` | Left / A, Right / D | Movement |
| `game_confirm` | Enter / Space | Menu confirmation and skipping the bike transition |
| `game_type` | Space / Enter | A microgame's primary interaction |
| `game_mash` | Space / Enter | Repeated interaction |
| `game_pause` | Escape | Pause / resume |
| `game_retry` | R | Restart an independent F6 microgame |

Canvas and Logic Gates also use mouse dragging; Schedule Builder uses clickable class buttons. Stay Focused uses horizontal movement. Campus Crossing supports all four directions by default; dodge horizontal bicycle and scooter traffic and reach the flag at the top.

Change bindings in **Project > Project Settings > Input Map**. `InputActions` fills missing or empty actions at startup and preserves existing nonempty bindings. The runtime APIs are `is_pressed`, `is_just_pressed`, `get_strength`, `movement_vector`, `get_action_events`, `replace_action_events`, `reset_action`, and `action_label`. Runtime remapping is not saved to disk.

`GameState` owns pause state and the `music_enabled` / `sfx_enabled` settings. Settings are session-only and are **not persisted**. Future audio playback can read these values or subscribe to `setting_changed`; the current collection has no soundtrack or sound-effect playback system.

## Edit the week in Godot

Open `scenes/core/game_flow.tscn`, select **GameFlow**, and expand **Week Plan** in the Inspector. Its assigned resource is `scenes/core/default_week.tres`.

- A `WeekPlan` contains an ordered **Stages** array.
- Each `StageDefinition` has a **Title** and an ordered **Games** array.
- Each `MicrogameDefinition` sets **Id**, **Title**, **Prompt**, **Scene Path**, **Difficulty**, and optional **Round Seconds Override**. Zero uses the game's normal duration.

Reorder the arrays to reorder days or rounds. To add a round, extend a day's **Games** array, create a new `MicrogameDefinition`, and assign a microgame `.tscn` path. Save the resource. The flow automatically updates day/round progress, runs a bike transition between rounds, and shows day clear only after every round in that day succeeds. No game-specific branches in `game_flow.gd` are required.

Resources are shared by default. Use **Make Unique** before changing a duplicated resource when the copy should have independent settings. Keep at least one round per day and use scenes whose root script extends `MicrogameBase`.

## Author crossing levels

The level-authoring interface is part of the **Godot editor**. Open `scenes/crossing/campus_intro.tscn` in 2D to edit the example, or save a copy of `scenes/crossing/blank_template.tscn` for a new level. The enabled **Aggie Crossing Level Tools** plugin provides the **Campus Tools** dock and the lane's **Traffic Schedule** Inspector.

Place road lanes, obstacles, pickups, Start, and Goal as native scene nodes. Set a lane's **Direction**, **Default Speed**, **Cycle Seconds**, and **Events**. Each vehicle event controls its type, spawn time, and speed override. With a zero override, bicycles use the lane speed and scooters use **1.5×** that speed. A nonzero override is an exact speed, so choose scooter overrides above bicycle overrides when keeping that relationship. Vehicles travel horizontally; the player can move in four directions while working toward the top.

Use **Validate** and then F6 to play the authored scene through the same shared microgame lifecycle. F6 does not add the level to the week automatically.

To use a new layout in the collection:

1. Save the authored level under `scenes/crossing/`.
2. Open `scenes/microgames/crossing.tscn` and use **Save Scene As** to make a wrapper for that layout.
3. Select the wrapper's root and set **Level Scene** to the authored level.
4. Assign that wrapper's scene path to a `MicrogameDefinition` in the week plan.
5. Set its difficulty and optional duration override, save, and test with F5.

Crossing's default round durations are 14, 12, and 10 seconds for difficulties 0, 1, and 2. The authored traffic schedule remains deterministic. The native level's **Initial Variables** and item **Properties** remain available to extensions. `scripts/crossing/game_hooks.gd` provides variable signals, custom item handlers, and vehicle registration; `extensions/crossing/coffee_pickup.gd` is an example.

See [Crossing Level Guide](docs/CROSSING_LEVEL_GUIDE.md) for step-by-step road and obstacle placement, vehicle timing, JSON interchange, and extension APIs. [Architecture and Refactor Notes](docs/ARCHITECTURE.md) describes the shared components and corrected behavior.

## Add another microgame

Create a full-rect `Control` scene under `scenes/microgames/`, attach a script extending `MicrogameBase`, and implement the relevant hooks:

| Hook / API | Responsibility |
| --- | --- |
| `get_round_seconds()` | Return the default duration for the current difficulty. |
| `_build_ui()` | Build the game's controls once. Honor `show_internal_timer`. |
| `_reset_game()` | Reset gameplay, visuals, and transient objects for a fresh round. |
| `_update_game(delta)` | Advance gameplay while the round is active. |
| `_on_timeout()` | Choose the timeout result; the default is failure. |
| `_show_result(success, message)` | Present the final result without routing scenes. |
| `_finish_round(success, message)` | Report an outcome exactly once. |
| `can_interact()` | Check pause, prompt, remaining time, and completion before handling input. |
| `get_seconds_left()`, `is_round_finished()` | Read common runtime status. |

The base owns `_ready`, `_process`, `_start_round`, `_finish_round`, the prompt, countdown, and standalone retry/pause. Do not override those lifecycle methods. Use `_seconds_left` for the current time, `_round_seconds` for the configured duration, and `difficulty` for game-specific tuning. The base bounds the final update to the remaining time, then calls `_on_timeout` only if the game has not finished.

Use the shared input actions instead of raw key codes. Gate button, drag, and other event handlers with `can_interact()`. `scripts/ui/microgame_ui.gd` supplies the common palette, headers, labels, panels, and status text. `scripts/core/card_drag.gd` supplies shared dragging and drop geometry. Keep each game's rules in its own script.

Before adding a game to the tree, the host sets `managed_by_flow`, `show_internal_timer`, `difficulty`, `prompt`, and `duration_override`. It listens to `round_completed(success)` and `time_changed(seconds_left, round_seconds)`. The host owns navigation, score, and lives; a microgame should not change scenes or create a second hosted pause menu. Independent F6 play automatically adds its own pause menu and result retry hint.

Finally, add a `MicrogameDefinition` to the week plan and test both its F6 scene and the F5 collection path.

## Project layout

| Location | Purpose |
| --- | --- |
| `scenes/core/default_week.tres` | Editable collection order and per-round settings |
| `scenes/core/` | Main flow and bike transition scenes |
| `scenes/microgames/` | Playable microgame wrappers |
| `scenes/crossing/` | Native crossing level-authoring scenes |
| `scenes/ui/` | Shared HUD and pause menu scenes |
| `scripts/core/` | Lifecycle, resource types, flow, input, shared state, dragging |
| `scripts/microgames/` | Individual game rules and crossing adapter |
| `scripts/ui/` | Shared presentation, HUD, pause settings |
| `scripts/crossing/` | Crossing simulation, drawing, validation, hooks, timeline |
| `addons/aggie_crossing/` | Godot editor dock, Inspector, nodes, and resources |
| `levels/crossing/` | JSON interchange examples; native scenes are the authoring source |
| `extensions/crossing/` | Example custom pickup behavior |
| `tools/` | Collection and flow regression checks |
| `tests/crossing/` | Crossing framework and native editor checks |
| `assets/art/`, `assets/audio/` | Reserved art and audio folders |
| `docs/` | Authoring guide and preserved team records |

## Verify changes

Run these commands from the project directory, replacing `godot` with your **Godot 4.7.2** executable:

```sh
godot --headless --editor --path . --import --quit
godot --headless --path . --script res://tools/smoke_flow.gd
godot --headless --path . --script res://tools/test_collection.gd
godot --headless --path . --script res://tools/test_input_routes.gd
godot --headless --path . --script res://tests/crossing/test_framework.gd
godot --headless --editor --path . scenes/crossing/campus_intro.tscn -- --test-native-editor
```

The collection suite covers the shared lifecycle, outcome handling, day/round advancement, retries, pause, input bindings, and individual game rules. The crossing suites cover validation, traffic timing, collisions, pickups, saved scene data, native editor ownership, and undo/redo. Also play F5 and the relevant F6 scenes to check appearance and interaction. See [Integration Verification](docs/VALIDATION.md) for the recorded results and their limits.

`tests/crossing/generate_samples.gd` rebuilds the supplied sample scenes and JSON. Run it only when intentionally replacing those examples.

## Team and project history

| Name | Main role | Sub-role |
| --- | --- | --- |
| Gaeun (Luna) Yu | Technical Producer | Accessibility and Usability Design |
| Zheng Zhou | Game Logic | Game Programming |
| Hongrui Zhao | User Interface and Input | TBD |
| Kyle Groves | Animation and Visuals | Music |
| Diego Beltran | Movement/Physics | Game Feel |
| Yutong Guo | Technical Artist | Player Onboarding and Tutorial Design |

The team's [original collection README](docs/AGGIEWARE_ORIGINAL_README.md) and [Hongrui's technical record](docs/individual-technical-record-hongrui.md) are preserved as historical records. The original README describes the collection before this integration; this README describes the current structure.

This integration adds no downloaded art, audio, fonts, or external libraries. Current microgame visuals use Godot controls and procedural 2D drawing. The crossing layout is a fictional campus-inspired example. Record source and license information here when adding outside assets.
