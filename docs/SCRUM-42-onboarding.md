# SCRUM-42: Monday onboarding

Monday's existing Canvas Upload and Campus Crossing rounds opt into teaching through
`MicrogameDefinition.tutorial_enabled`. Other days, standalone scenes, the launcher,
and preserved native microgames keep their existing presentation and rules.

## Player experience

- Monday's introductions wait for **I'M READY** (mouse or focused-button keyboard
  activation). Reading and background clicks consume no round time and cannot
  activate gameplay. Pause still works.
- Canvas shows a bottom hint for dragging FILE.ZIP; a successful drop changes it
  to the submit instruction. Wrong files still use existing retryable feedback.
- Crossing explains movement using current input bindings, the flag goal, and
  the countdown. The hint remains visible during the teaching round.
- First failed tutorial round per week shows the actual remaining lives after
  the existing result presentation. Continue retries the same round, or shows
  game over at zero. The flow remains the sole owner of score and life changes.
- A new week resets the life explanation. Retrying a day retains that explanation
  history. Each tutorial round/retry waits for readiness again.

This is a deliberate Monday-only exception to the standard 3.2-second intro and
minimal in-play text. No timers, movement difficulty, art, or later-day mechanics
are changed. There is no forced failure and no extra practice life.

## Preview

Run the project, choose Start Week, then Monday. Wait on the introduction to
confirm the timer does not run; choose I'M READY, drag FILE.ZIP and submit. In
Crossing, test the movement prompt with default or remapped keys. Let a round time
out to see the life lesson and use Continue to retry.

## Validation (Godot 4.7.2)

- `tools/test_onboarding.gd`: 21 checks, zero failures (real mouse drag/button
  events, keyboard readiness, waiting, pause, timer, life loss, duplicate signals,
  retries, new-week reset, later-day intro, and remapped movement).
- `tools/test_collection.gd`: 248 checks, zero failures.
- `tools/test_input_routes.gd`: 28 checks, zero failures.
- `tools/test_presentation.gd`: 1,027 checks, zero failures.
- `tools/check_microgames.gd`: MICROGAME_CHECK_OK.
- `tools/smoke_accessibility.gd`: ACCESSIBILITY_SMOKE_OK.
- Editor import passes on retry of the repository-documented headless texture
  race. Actual rendered ready, drag, movement, and life-lesson screens inspected.
- Both Web build scripts include the new onboarding suite. No Web export or
  human novice playtest was performed for this change.

Existing regression tests acknowledge the new life-lesson screen before asserting
ordinary transitions; dedicated onboarding checks verify the screen itself.
