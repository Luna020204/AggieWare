# Microgame format and preservation guide

This guide distinguishes the shared framework presentation from the latest preserved Luna implementations. The reference design document is **AggieWare Microgame Format & Design Standard v1.0**, dated November 21, 2026. The explicit integration decision is to preserve Luna's PR #16 (`5412665`), including final PR #14 (`6c86ced`), rather than rewrite those games to force every format default.

## Which path applies

| Games | Implementation and review baseline |
| --- | --- |
| Canvas, Campus Crossing, Schedule Builder, Stay Focused, Logic Gates | `MicrogameBase` and shared framework presentation |
| Swipe Card, Stay Awake | Unchanged native games, 5x nearest sprites, `WalkInIntro`, `MicrogameOverlay`, `PixelText` |
| Variable Not in Scope, Microscope | Unchanged native layouts, fonts, gameplay and status presentation |

The native games are integrated by an external host adapter. Do not replace their source scripts, scene layout, visuals or mechanics merely to satisfy shared UI assumptions. The four native scripts/scenes, three native presentation helpers, Swipe/Awake art and two art generators must match the chosen upstream revision unless a separate gameplay/art change is explicitly reviewed.

## Framework defaults

These defaults apply to the five framework games and new games intentionally built on that framework.

| Stage | Presentation | Timing and input |
| --- | --- | --- |
| Intro | Gold 70 px title and white 28 px instruction under 35 characters | Default 3.2 seconds; gameplay/timer blocked; click skips and is consumed |
| Play | Pixel world, yellow 28 px TIME at top-left, small essential meters | Default 9 / 8 / 7 seconds; timer assist applies here |
| Rejected action | Orange 28 px centered feedback, symbol/words and 55% black dim | 1.4-second fade; retry remains available where allowed by the rules |
| Result | Green success or red failure, 42 px centered feedback | 1.4 seconds including fade; completion once |
| Next | Host navigation | Waits for `result_finished` |

Framework gameplay avoids permanent title/instruction/status panels; physical game objects can carry labels. Menus and settings may use panels. Crossing fills the full viewport and retains small progress/inventory indicators; pause and independent retry use the shared controls. The runtime renderer does not change native Godot map coordinates or editor layout.

Framework art renders at 256 x 144 and displays at 5x with nearest filtering. `MicrogameUI.pixel_canvas()` keeps hit areas in ordinary logical coordinates. AggiePixel uses integer scaling, font sizes divisible by 7, and a `#14121A` shadow offset by `font_size / 7`. Lowercase glyphs alias capitals, so new pixel-font puzzles must not rely on case-only distinctions.

Shared colors are Aggie Blue `#022851`, title Gold `#FFBF00`, TIME `#FFD166`, success `#73E6A8`, rejection `#FFB38A` and failure `#FF9E9E`. Use concise feedback and preserve words as well as optional symbols.

## Preserved native behavior

| Game | Easy / Normal / Hard seconds | Intro | Presentation boundary |
| --- | --- | --- | --- |
| Variable Not in Scope | 9 / 7 / 5.5 | 0 | Case-sensitive monospace code, panels, persistent instructions/status; a wrong answer fails |
| Swipe Card | 9 / 8 / 7 | 3.2 seconds | Latest Peet's artwork, larger student, centered dimmed title; native swipe meter and result pops |
| Stay Awake | 8 / 7 / 6 | 3.2 seconds | Lecture building/hall sprites, projector animation, professor/student, native pop counter and result pops |
| Microscope | 10 / 9 / 8 | 0 | Original procedural eyepiece, reference card, minimap, fonts and status labels |

Swipe/Awake walk for 0–2.2 seconds, open the door and fade title text during 2.2–2.5, and fade through black during 2.5–3.2. A click skips their native intro. Scope/Microscope do not receive an extra intro from the host. `MicrogameOverlay` owns a 1.4-second pop with a 0.4-second fade; the adapter does not substitute another banner. Its native rejection-pop clock remains game time.

Nonzero WeekPlan duration overrides are not applied to these preserved games; the flow warns and retains the original duration. The native games retain their own timer positions and sizes. Their host HUD is suppressed, avoiding duplicate timers and overlap with native titles. Scope's case-only decoys remain readable because its code/choices use the original monospace font, not AggiePixel. Existing native instruction lengths, meters and fonts are preservation exceptions, not claims of universal PDF compliance.

Native F6 runs the original scene and local pause menu. The adapter supplies host navigation, playback-speed/timer-assist ownership and pause compatibility only in the collection/launcher. Native F6 does not gain framework R retry. Use the launcher when testing integrated behavior.

## Implementing and reviewing integration

For a new framework game, extend `MicrogameBase`, set scene metadata, implement the build/reset/update hooks and gate input with `can_interact()`. Call `_finish_round()` once for a terminal outcome and use `show_feedback()` only for a retryable action. Keep inherited lifecycle methods. Add a catalog entry separately from adding a `MicrogameDefinition` to the week.

For a preserved game, add its scene to the catalog. The factory automatically selects `NativeMicrogameSession` when the scene exposes the native two-signal/duration contract instead of the full host protocol. Keep the original scene and script. The wrapper bridges native time/outcome signals, retains its presentation, suppresses duplicate host UI, removes only the hosted instance's local pause menu, and delays navigation until the result interval finishes. The native game's own ended flag blocks further gameplay while its presentation keeps processing.

Review integration against these boundaries:

- Compare preserved source and asset bytes with the selected upstream commit; document any approved deviation separately.
- Exercise native F6 and hosted launcher/WeekPlan entry independently.
- Check original difficulty timings, Scope wrong-answer failure, Swipe rejection/retry, Awake contact/timeout and Microscope confirm/focus.
- Check one pause menu, no duplicated intro/timer/result, intro click consumption, paused Swipe drag cancellation, and exactly-once host completion.
- Check stop/replacement during intro, play and result; old callbacks must not affect the new run or its speed.
- Review captures at native resolution. Structural tests do not establish text fit, art quality, or human difficulty balance.

The README lists test commands. [Validation](VALIDATION.md) records results for the actual revision; this guide does not claim a fixed number of passing tests or a successful Web export. PR review should include representative native and framework captures. Do not push changes directly to `main`.
