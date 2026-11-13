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

While the core stage manager is still being assembled, individual scenes can
be tested by opening them and pressing **F6**:

- Canvas microgame: `scenes/microgames/canvas.tscn`
- Bike transition: `scenes/core/bike_transition.tscn`
- Title and stage flow: `scenes/core/game_flow.tscn`

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
