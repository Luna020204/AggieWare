# Aggie Crossing

Campus Crossing is part of the Godot 4.7.2 AggieWare collection, with **native Godot editor tools** for building levels. Roads run horizontally; the student travels from the bottom toward the top. Everything supplied with this project is in English.

## Open and edit

1. Import `project.godot` in **Godot 4.7.2-stable**.
2. Open `scenes/crossing/campus_intro.tscn` and switch to **2D**.
3. Select a road or object in the viewport or Scene tree. The **Campus Tools** dock opens beside the editor, and the **Inspector** shows the selected node's properties.
4. Drag objects in the 2D viewport. They snap to a 40-pixel grid. Road lanes move between rows and always span the map.
5. **Ctrl+S** saves the normal `.tscn` scene. **Ctrl+Z** uses Godot's normal undo history.
6. **F6** plays the current crossing level with the common microgame prompt, timer, and pause menu. **F5** plays the full AggieWare collection. Stop the game with Godot's stop button or **F8** to continue editing.

The plugin is enabled in `project.godot`. If the dock is missing, check **Project > Project Settings > Plugins > Aggie Crossing Level Tools**, then select a crossing node. You can also show **Campus Tools** from **Editor > Editor Docks**.

The built-in Godot interface follows your editor language setting. The project, custom dock, game UI, comments, and examples use English. Godot can be launched with `--language en` to use its English interface.

## Build a small level

Click **New level** in Campus Tools, or open `scenes/crossing/blank_template.tscn` and use **Scene > Save Scene As**.

- Set **Row** and **Column** in the dock. These fields are **1-based**; JSON coordinates are **0-based**.
- Click **+ Road lane** to create a horizontal road at that row. Add adjacent rows to make a wider road with multiple traffic directions.
- Click **Paint grass row** or **Paint path row** to change the ground under that row. To remove a road, delete its lane node from the Scene tree; painting ground does not remove a lane.
- Add **Planter**, **Bench**, or **Barrier** objects. They block the player, not traffic.
- Add **Item** objects for pickups. Select an item and edit **Item Type** and **Properties** in the Inspector.
- Move the **Start** and **Goal** markers. There must be exactly one of each.
- Click **Validate**, then **F6** to try the current level.

Levels use a fixed **21 × 15 grid** with **40-pixel cells**. Keep authored objects as direct children of `CampusLevel`. Native `Position` and the dock's move command control placement; these grid objects do not use rotation or scaling. Players can move in all four directions by default while working toward the goal at the top. **Allow Horizontal** is enabled on the level root and in the supplied examples. Disable it only for a deliberately vertical-only level; in that mode, start and goal must share a column and the vertical route must stay free of obstacles.

## Author traffic in the Inspector

Select a `CrossingRoadLane` node:

| Property | Meaning |
| --- | --- |
| Direction | Right means left-to-right; Left means right-to-left. |
| Default Speed | Baseline speed in pixels per second: bicycles use 1x and scooters use 1.5x when their override is zero. |
| Cycle Seconds | How often the complete event schedule repeats. |
| Events | An array of `CrossingVehicleEvent` resources. Each entry is one vehicle. |

Use **+ Bicycle** and **+ Scooter** in the Inspector or dock to add events. Drag the diamonds in the Inspector's **Traffic Schedule** to change spawn times. Click a diamond, then **Inspect selected vehicle resource**, or expand the native **Events** array to edit its resources directly.

Each event exposes **Vehicle Type**, **Spawn Time**, and **Speed Override**. With **Speed Override = 0**, bicycles use the lane's **Default Speed**, and scooters use **1.5 times** that speed. For example, a default speed of **120** gives bicycles **120 px/s** and scooters **180 px/s**. A nonzero override must be **30–600** and is the exact speed in pixels per second, without a multiplier. Keep scooter overrides above bicycle overrides when you want that speed difference. Spawn time must be nonnegative and less than the lane's cycle length.

For example, a five-second cycle with events at `0.0` and `2.5` seconds generates vehicles at `0.0, 2.5, 5.0, 7.5, ...`. Vehicles enter from the appropriate map edge. The vehicle icons in the editor are schedule previews, not initial world positions. Overlapping events are allowed intentionally; adjust their times if you want more spacing.

The viewport preview and timeline update as properties change. To give duplicated lanes independent schedules, use **Make Unique** on their event resources if you duplicate nodes with Godot's standard duplicate command.

## Play controls

| Key | Action |
| --- | --- |
| W / Up | Walk toward the goal |
| S / Down | Retreat |
| A / Left, D / Right | Move left / right (enabled by default) |
| Escape | Pause or resume |
| R | Restart an independent F6 playtest |

The round starts automatically after the CROSS prompt. Reaching the goal before the timer expires wins. A traffic collision ends the run unless a shield is available. Each restart restores the level's initial variables and pickups. Traffic follows the authored schedule without additional random spawning. In the collection, the host manages retries, score, and lives; R is reserved for independent playtests. All movement and pause bindings come from the shared InputActions API.

## Include a level in the collection

Duplicate `scenes/microgames/crossing.tscn`, then set its root's **Level Scene** to your authored `.tscn`. In `scenes/core/default_week.tres`, expand a stage's **Games** and point a round's **Scene Path** to your wrapper scene. Set its **Difficulty** or **Round Seconds Override** as needed. Zero uses the default duration: 14 seconds on easy, 12 on medium, and 10 on hard. Add a separate wrapper for each distinct authored level. Make shared resources unique before editing them independently.

## Items and extension points

Two item types are implemented to demonstrate the extension surface:

| Item Type | Properties | Effect |
| --- | --- | --- |
| `token` | `{ "value": 1 }` | Adds to the runtime `tokens` variable. |
| `shield` | `{ "charges": 1 }` | Adds shield charges; each charge absorbs one collision. |

Select `CampusLevel` to edit **Initial Variables**. Add keys such as `energy`, `quest_stage`, or `weather` there. These values are copied into the runtime for every run.

`scripts/crossing/game_hooks.gd` provides a small public API:

```gdscript
hooks.register_item_handler("coffee", callable)
hooks.register_vehicle_type("cart", Vector2(30, 12), Color.ORANGE)
hooks.set_variable("quest_stage", 2)
hooks.add_variable("energy", 25)
```

Signals include `run_started(level)`, `run_finished(elapsed, variables)`, `item_collected(item)`, `vehicle_hit(vehicle)`, `variable_changed(key, value)`, and `custom_event(event_name, payload)`.

For a working example, add a normal **Node** under `CampusLevel` and attach `extensions/crossing/coffee_pickup.gd`. Place an item with **Item Type** `coffee` and **Properties** `{ "energy": 25 }`. The extension connects to the level's `runtime_ready(controller)` signal, registers its handler before the run starts, and adds energy when the pickup is collected. Unknown item types still emit `item_collected` even without a registered handler.

New vehicle types can register their collision size, color, and an optional fourth `speed_multiplier` argument (default `1.0`). This multiplier applies only when Speed Override is zero. Set a vehicle resource's **Vehicle Type** to `custom` and its **Custom Type** to the registered ID. The default renderer gives custom types a scooter-shaped placeholder. Add custom artwork in `scripts/crossing/campus_canvas.gd` when needed. Movement rules or timed effects can be implemented in an extension connected to the controller; arbitrary variables do not acquire behavior automatically.

## Files and data

| Location | Purpose |
| --- | --- |
| `scenes/crossing/campus_intro.tscn` | Ready-to-edit six-lane example used by the default crossing round |
| `scenes/crossing/blank_template.tscn` | Empty native scene with start and goal |
| `addons/aggie_crossing/` | Editor dock, Inspector timeline, native node/resource types, scene conversion |
| `scripts/crossing/simulation.gd` | Deterministic traffic scheduling, movement, collisions, pickups, win state |
| `scripts/microgames/crossing.gd` | Shared-lifecycle adapter, controls, and game feedback |
| `scripts/crossing/game_hooks.gd` | Signals, variables, item handlers, vehicle registry |
| `scripts/crossing/level_data.gd` | Versioned JSON schema, validation, safe loading/saving |
| `levels/crossing/` | JSON interchange examples; the `.tscn` scenes are the authoring source |
| `extensions/crossing/coffee_pickup.gd` | Optional custom pickup example |
| `tests/crossing/` | Framework tests, native editor integration checks, sample generator |

**Import JSON** creates a new `.tscn` scene at a location you choose. **Export JSON** writes the current scene as validated level data. The JSON schema is version `1`; it stores terrain rows, lane schedules, start/goal cells, obstacles, items, rules, initial variables, and metadata. Schema migrations belong in `level_data.gd`.

No asset downloads, external libraries, or installed fonts are required. The graphics are drawn with Godot's 2D API and can be replaced independently of the data and simulation. The sample campus layout is fictional.

## Verification

Run from the project directory, replacing `godot` with your Godot 4.7.2 executable:

```sh
godot --headless --editor --path . --import --quit
godot --headless --path . --script tests/crossing/test_framework.gd
godot --headless --editor --path . scenes/crossing/campus_intro.tscn -- --test-native-editor
```

The framework suite checks validation, safe save/load, spawn timing, collision tunneling, obstacles, pickups, custom handlers, reset behavior, typed resources, scene packing, and separation between authored and runtime data. The native editor suite checks actual editor undo/redo, owned scene-node creation, adding vehicle resources, and viewport dragging.

`tests/crossing/generate_samples.gd` rebuilds the supplied example scenes and JSON files. Run it only when intentionally resetting those examples.

Editor implementation follows Godot's [EditorPlugin API](https://docs.godotengine.org/en/4.7/classes/class_editorplugin.html), [EditorDock API](https://docs.godotengine.org/en/4.7/classes/class_editordock.html), and [EditorInspectorPlugin API](https://docs.godotengine.org/en/4.7/classes/class_editorinspectorplugin.html).
