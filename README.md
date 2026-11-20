# AggieWare

A WarioWare-style microgame gauntlet that takes you through a week in the life of a UC Davis student. Bike across campus, survive lectures and the Dining Commons, and make it to Friday's ECS 179 final boss.

ECS 179 group project.

## Godot version

**Godot 4.7.2-stable** (GL Compatibility renderer, for web export). Everyone on the team must use this exact version, or project files will keep conflicting.

## How to run

1. Install [Godot 4.7.2-stable](https://godotengine.org/download/archive/) (standard version, not .NET).
2. Clone this repository.
3. In Godot, choose **Import** and select `project.godot`.
4. Press **F5** to run.

Pressing **F5** now runs the playable week: select a day, complete each
microgame, view the stage-clear screen, and bike to the next day. Monday and
Friday use Canvas upload, Tuesday uses Schedule Builder, Wednesday uses Stay
Focused, and Thursday uses Logic Gates. The HUD tracks the round timer, lives,
score, and day progress. Losing all three lives opens the game-over screen
with a retry action. Individual scenes can also be tested by opening them and
pressing **F6**:

- Canvas microgame: `scenes/microgames/canvas.tscn`
- Schedule Builder: `scenes/microgames/schedule_builder.tscn`
- Stay Focused: `scenes/microgames/stay_focused.tscn`
- Logic Gates: `scenes/microgames/gates.tscn`
- Variable Not in Scope (SCRUM-23, Lecture Hall, mouse only): `scenes/microgames/variable_scope.tscn`.
  It isn't in the week flow yet. Play it from the test launcher (`--microgame=scope`).
  Smoke test: `godot --headless --path . --script res://tools/smoke_variable_scope.gd`
- Swipe Card (SCRUM-72, Rush Hour, mouse only): `scenes/microgames/swipe_card.tscn` (launcher id `swipe`).
- Stay Awake (SCRUM-76, Lecture Hall, mouse only): `scenes/microgames/stay_awake.tscn` (launcher id `awake`).
  Smoke test for Luna's later microgames: `godot --headless --path . --script res://tools/smoke_new_microgames.gd`
- Bike transition: `scenes/core/bike_transition.tscn`
- Title and stage flow: `scenes/core/game_flow.tscn`

Run `godot --headless --path . --script res://tools/smoke_flow.gd` to check the
week flow, microgame outcomes, stage-clear, bike-transition, life-loss, and
retry paths.

### Microgame test launcher (SCRUM-58)

A debug scene that jumps straight into any microgame at any difficulty and
speed, skipping the title and stage flow.

- **In the editor:** open `scenes/debug/microgame_launcher.tscn` and press **F6**.
- **Pick:** UP/DOWN (or click) chooses the microgame, LEFT/RIGHT (or click)
  chooses EASY / NORMAL / HARD, the **Speed** dropdown sets 0.5x–2x game speed
  (`Engine.time_scale`). ENTER/SPACE, **LAUNCH**, or double-clicking a
  microgame starts it.
- **While playing:** the shared HUD shows the real timer (lives/score are
  placeholders). Click **■ STOP** (bottom-left) to go back early. When the
  round ends, the launcher returns to the menu and shows
  `Last run: <game> · <difficulty> · <speed>x → WIN/FAIL after N s`.
  Escape still opens the pause/settings menu.
- **From the command line**, launch one microgame directly:

  ```
  godot --path . res://scenes/debug/microgame_launcher.tscn -- --microgame=gates --difficulty=2 --speed=1.5
  ```

  Ids: `canvas`, `schedule`, `focus`, `gates`, `scope`, `swipe`, `awake`.

**Instruction prompts (SCRUM-39):** before every microgame, both the week flow
and the launcher show a one-verb prompt (e.g. `SWIPE!`) with a control icon
(mouse click, mouse drag, left/right, or arrow keys) for 1 second. The
microgame is frozen (no timer, no input) until the prompt ends. Each catalog
entry sets its `"verb"` and `"icon"`. The prompt is
`scripts/ui/instruction_prompt.gd`, and the launcher's **Prompt** checkbox turns
it off for quick testing.

**Adding a microgame:** add one line to `ENTRIES` in
`scripts/core/microgame_catalog.gd`. The scene must follow the same contract
`game_flow.gd` uses: a `Control` root, `round_completed(success: bool)` and
`time_changed(seconds_left, round_seconds)` signals, a `difficulty` property
(0–2), and `get_round_seconds()`.

**Hook check:** `godot --headless --path . --script res://tools/check_microgames.gd`
runs every catalog microgame at every difficulty and reports whether
`time_changed` ticks, whether the round ends on its own with exactly one
`round_completed`, and whether `_finish_round(true/false)` emits the matching
result. It also launches each microgame through the launcher and checks it
returns to the menu. It prints `MICROGAME_CHECK_OK` on success. The forced
win/fail column checks the signal wiring only. `tools/smoke_flow.gd` is what
plays the real interactions.

Playable build: _TBD (itch.io link)_

## Controls

Microgames must use the shared actions below instead of reading raw keys:

| Action | Default bindings | Intended use |
| --- | --- | --- |
| `game_type` | Space / Enter | Type or perform the current interaction |
| `game_mash` | Space / Enter | Repeated action input |
| `game_up` / `game_down` | Arrow keys / W / S | Vertical movement |
| `game_left` / `game_right` | Arrow keys / A / D | Horizontal movement |
| `game_confirm` | Enter / Space | Confirm a prompt or menu choice |
| `game_pause` | Escape | Pause or resume the game |

The `InputActions` autoload creates missing actions and exposes a remapping
API for SCRUM-57. `GameState` owns pause state and shared settings. Add
`scenes/ui/settings_pause_menu.tscn` to a playable scene to provide the
pause/settings overlay. Each microgame should still show a one-word prompt
before it starts.

## Repository layout

| Folder | What goes here |
| --- | --- |
| `scenes/core/` | Microgame manager, stage flow, bike transition |
| `scenes/microgames/` | One subfolder per microgame |
| `scenes/ui/` | Menus, HUD, settings |
| `scripts/core/` | Base classes, game state, difficulty, input |
| `scripts/microgames/` | One subfolder per microgame |
| `scripts/ui/` | UI scripts |
| `assets/art/`, `assets/audio/` | Art and audio (record sources and licenses below) |
| `tools/` | Team tools, e.g., the microgame test launcher |

## Working on the project

- `main` must always open and run. Don't push broken work to `main`.
- Work on a branch named `feature/<your-name>-<task>` (e.g., `feature/diego-bike-physics`).
- Open a pull request into `main`. Ask at least one teammate to review it before merging.
- Put the Jira key in branch names or PR titles when you can (e.g., `SCRUM-30`).
- **One owner per scene.** Two people editing the same `.tscn` at once almost always conflicts. Coordinate before touching someone else's scene.
- Pull from `main` often, and merge working features early rather than in the last week.
- This repository is public: never commit passwords, API keys, or playtesters' personal information.

## Team

| Name | Main role | Sub-role |
| --- | --- | --- |
| Gaeun (Luna) Yu | Technical Producer | Accessibility and Usability Design |
| Zheng Zhou | Game Logic | Game Programming |
| Hongrui Zhao | User Interface and Input | TBD |
| Kyle Groves | Animation and Visuals | Music |
| Diego Beltran | Movement/Physics | Game Feel |
| Yutong Guo | Technical Artist | Player Onboarding and Tutorial Design |

## Known problems

_None yet._

## Credits and licenses

_List every outside asset here with its source and license._

## Links

- Design document: _TBD_
- Press kit: _TBD_
- Trailer: _TBD_
- Final graded commit / release: _TBD_
