# SCRUM-33: player animation controller

`scenes/core/animated_character.tscn` is a reusable visual child for a character.
Its `AnimationController` owns presentation only. The game or SCRUM-29 character
owns movement, input, win/loss decisions, and difficulty. SCRUM-29 has not landed
on main yet, so this PR provides a composition interface rather than inventing
Diego's base class.

## Run the demo and tests

Use the repository-pinned **Godot 4.7.2-stable, standard (not .NET)**.
Open `tools/animation_demo.tscn` and press **F6**. Click each state and move the
slider to compare speeds. Success/fail play once and hold until reset. The demo
is independent of the project's future main scene.

From the repository root (substitute the path to your Godot executable):

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/test_player_animation_controller.gd
```

On macOS the executable is normally `/Applications/Godot.app/Contents/MacOS/Godot`.
Tests exercise real scene instantiation, playback, non-restarting state updates,
terminal outcomes, reset, difficulty bounds, invalid inputs, missing clips,
facing, independent character instances, and the demo's buttons and slider.
A nonzero exit indicates failure.

## SCRUM-29 integration

Instance `animated_character.tscn` as `Visual` under the controllable character:

```gdscript
@onready var animation = $Visual/AnimationController

func start_microgame(level: float) -> void:
    animation.reset_for_microgame(level)

func update_biking(is_moving: bool) -> void:
    animation.set_state(&"biking" if is_moving else &"idle")

func update_typing(is_mashing: bool) -> void:
    animation.set_state(&"typing" if is_mashing else &"idle")

func finish_microgame(won: bool) -> void:
    animation.set_state(&"success" if won else &"fail")
```

Call `set_facing_left(bool)` when changing direction. `set_difficulty(level)`
uses a 1-based level: `clamp(1 + .15 * (level - 1), 1, 3)`; invalid non-finite
values are ignored. It changes only sprite playback, never global game speed.
`state_changed(state)` reports accepted transitions;
`outcome_finished(state)` fires when a non-looping result clip finishes.
Repeated states do not restart. The first outcome wins until an explicit reset.
Unknown or unavailable clips return false and preserve the current state.

## Replace the placeholder art

The controller works with any assigned AnimatedSprite2D. Provide nonempty
SpriteFrames named `idle`, `biking`, `typing`, `success`, and `fail`. Loop the
first three; leave success/fail non-looping so completion signals fire. Assign
that sprite to the controller's `sprite` inspector property. When replacing the
included scene's frames in the editor, remove its `placeholder_character.gd`
script, which otherwise generates the demo frames on entering the tree.

`assets/art/player_placeholder.svg` contains original geometric placeholder art
created for this implementation, with four frames per state (96 × 96 each).
No external art, downloads, or licenses are required. It is demonstration art,
not the separate SCRUM-35 asset pipeline or SCRUM-61 effects work.
