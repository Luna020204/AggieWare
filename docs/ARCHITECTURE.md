# AggieWare architecture

The collection now hosts Canvas Upload, Schedule Builder, Stay Focused, Logic Gates, and Campus Crossing through the same round contract. Common code owns the round lifecycle and collection navigation. Each game owns its rules, objects, and success conditions.

## Ownership and entry points

| Location | Responsibility |
| --- | --- |
| `scenes/core/game_flow.tscn` and `scripts/core/game_flow.gd` | Main collection, menus, days, rounds, score, lives, and transitions |
| `scenes/core/default_week.tres` | Editable order and configuration of the collection |
| `scripts/core/microgame_base.gd` | Prompt, countdown, completion, pause integration, and independent retry |
| `scripts/core/input_actions.gd` | Shared actions and configurable bindings |
| `scripts/ui/microgame_ui.gd` | Common headers, panels, labels, feedback colors, and node cleanup |
| `scripts/core/card_drag.gd` | Mouse dragging and drop geometry shared by Canvas and Gates |
| `scripts/microgames/` | Game-specific rules and the Campus Crossing adapter |
| `scripts/crossing/` | Crossing simulation, drawing, data validation, and extension hooks |
| `addons/aggie_crossing/` | Native Godot level editing tools and authored node/resource types |

F5 starts the collection. F6 on a microgame scene starts an independent round. F6 on an authored crossing level creates the same crossing adapter automatically.

## One lifecycle for every game

`MicrogameBase` extends `Control`. Its `_ready()` builds game UI, creates the prompt, adds a pause menu for independent play, and starts the round. A game implements these hooks:

| Hook | Purpose |
| --- | --- |
| `get_round_seconds()` | Default duration for the selected difficulty |
| `_build_ui()` | Create the game's controls once |
| `_reset_game()` | Restore game state and objects for a new attempt |
| `_update_game(delta)` | Advance game-specific behavior during active play |
| `_on_timeout()` | Decide the result when time expires; failure is the default |
| `_show_result(success, message)` | Freeze interactive objects and show feedback |

Games call `_finish_round(success, message)` and expose the inherited `round_completed(success)` and `time_changed(seconds_left, round_seconds)` signals. They do not duplicate `_ready()`, `_process()`, `_start_round()`, or `_finish_round()`.

The one-word prompt precedes active play. The countdown does not run during the prompt or a pause. The base passes only the remaining round time to `_update_game()`, so a long frame cannot simulate gameplay beyond the deadline. It checks timeout after that final simulation interval, allowing a result reached within the interval to stand.

Completion is idempotent: the first result marks the round ended; later calls do nothing. Input handlers use `can_interact()` to reject actions during the prompt, pause, expired clock, or finished round. A reset restores both common and game-specific state.

The host sets `managed_by_flow`, difficulty, prompt, timer visibility, and any duration override before adding the game to the tree. Hosted games use the collection HUD and let the host manage retries. Independent games have one pause menu and the shared retry action, defaulting to R. Result messages display the current retry binding. Input defaults fill missing actions without replacing existing project or player bindings.

## The collection is resource-driven

`WeekPlan.stages` is an array of `StageDefinition` resources. Each stage has a title and a `games` array of `MicrogameDefinition` resources. Each game definition contains its ID, title, prompt, scene path, difficulty, and optional duration override. An override of zero uses the game's normal duration.

Edit `scenes/core/default_week.tres` in the Inspector to reorder rounds, add a round to a day, or add a day. Make resources unique before changing copies independently. A game scene must have a `MicrogameBase` root. Invalid plans or scene types produce a configuration error instead of starting an incomplete round.

`game_flow.gd` owns the sequence. On completion it enters `RESULT` synchronously before changing score or lives and waiting for feedback. Every active scene has a run token. Result, timer, and transition callbacks from an older run are ignored, including callbacks that resume after an asynchronous delay. This prevents duplicate rewards, duplicate life loss, and stale transitions. Active scenes and menu controls are detached before deferred deletion so old controls cannot remain in a newly built screen.

## Shared presentation and dragging

`MicrogameUI` supplies the common palette and small control builders. Instructions start below the collection HUD. Internal countdowns are hidden in hosted rounds; Schedule Builder retains its pass-time cue because opening registration is part of the game, but omits its duplicate seconds display. Status feedback resets its color between attempts.

`CardDrag` owns the active card, grab offset, motion, release, and cancellation. Mouse positions are converted into the card parent's coordinates; drop detection and centering use transforms. Canvas and Gates therefore share reliable geometry when their parent is moved or scaled. The helper reports a dropped card; each game decides whether that drop is valid.

No shared helper decides which file is correct, how a gate works, when a class opens, or whether a distraction was blocked:

- **Canvas:** correct-file upload followed by submission, decoy files, moving upload zone, and moving submit button.
- **Schedule Builder:** a 1.5-second wait, registration buttons, and shuffling unregistered classes. Duration overrides change the available round time while preserving the opening delay.
- **Stay Focused:** shield movement, thought spawning, blocked/missed counts, and success on surviving the exam.
- **Logic Gates:** gate selection, input sockets, and the special one-input NOT circuit.
- **Campus Crossing:** authored traffic, movement, obstacles, pickups, and reaching the goal through its simulation.

## Crossing keeps native Godot authoring

`scripts/microgames/crossing.gd` adapts `scripts/crossing/simulation.gd` to the common lifecycle. It supplies shared input, displays inventory and feedback, and converts simulation win/crash states into round results. It consumes the complete active round interval in bounded simulation calls, keeping traffic and the host clock aligned.

The simulation remains independent of the collection UI. It copies authored data for each attempt and owns player movement, scheduled vehicles, collision checks, pickups, and runtime state. `game_hooks.gd` exposes variables, item handlers, vehicle types, and signals for extensions. Initial variables and collected items reset on retry; the authored scene remains the source data.

Levels remain normal `.tscn` scenes rooted at `CrossingCampusLevel`. Roads and objects are native child nodes edited in the Scene tree, 2D viewport, and Inspector. Each lane's `Events` array contains `CrossingVehicleEvent` resources with vehicle type, spawn time, and speed override. Bicycle defaults use the lane speed; scooter defaults use 1.5 times that speed. A nonzero override is an exact speed. Shared event resources must be made unique when schedules should differ.

The Campus Tools dock, timeline Inspector, undo/redo, validation, and JSON interchange remain editor features. There is no separate level-editor game. To include another authored level, duplicate `scenes/microgames/crossing.tscn`, assign its `Level Scene`, and reference that wrapper in the week plan. See [CROSSING_LEVEL_GUIDE.md](CROSSING_LEVEL_GUIDE.md) for the authoring workflow and extension examples.

## Correctness fixes in this revision

- Canvas no longer restarts itself from its submit button after a result while the collection is waiting to transition. Pending drags are cancelled at completion.
- Retry cleanup detaches old cards, buttons, and thoughts immediately before deferred deletion. New attempts do not keep stale interactive objects.
- An uploaded file follows Canvas's moving drop zone.
- Canvas and Gates use consistent local/global coordinate conversion for dragging and placement.
- Releasing the mouse while paused or outside the window no longer leaves a stale card drag after resuming.
- Stay Focused uses small simulation steps so a fast thought cannot jump through the shield on a slow frame.
- Repeating movement and spawn timers preserve elapsed-time remainders. Schedule shuffling uses its own seedable random generator.
- Hosted rounds no longer draw duplicate countdowns or duplicate pause menus. Instructions no longer overlap the shared HUD.
- Collection result handling rejects repeated results and callbacks from obsolete rounds.

These changes target correctness, maintainability, and level authoring. They do not establish an FPS improvement or validate a web export.

## Verification and historical material

The collection checks live in `tools/test_collection.gd` and `tools/smoke_flow.gd`. Crossing simulation and native editor checks remain under `tests/crossing/`. Import, automated behavior checks, and visual playtests serve different purposes; consult the final verification results for the checks actually run on this revision.

The original group README is preserved as `docs/AGGIEWARE_ORIGINAL_README.md`, and `docs/individual-technical-record-hongrui.md` remains as historical project documentation. Historical documents describe their original version; current setup and editing instructions belong in the main README and crossing level guide. The supplied source archive was left untouched; integration work was completed in a separate project workspace.
