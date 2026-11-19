# SCRUM-52 checkpoint: playable vertical slice (due 11/17)

Checked 11/18 by Luna (Technical Producer) with Godot 4.7.2-stable.
Build checked: branch `SCRUM-52-vertical-slice`, which is PR #3
(`zeturn:codex/feature-hongrui-scrum-60-input`, `de5e44c`) plus SCRUM-58 and SCRUM-23 on top.

**Jira criterion:** "the core loop works end-to-end with 3+ microgames, timer/lives,
HUD, and the bike transition", one full day, usable as the fallback demo.

**Verdict: met on the PR #3 branch, but NOT on `main`.** Two caveats below.

## Criterion by criterion

| Criterion | Status | Evidence |
| --- | --- | --- |
| Core loop end to end | ✅ on PR #3 | `game_flow.gd`: title → day select → microgame → stage clear / life lost → bike → next microgame → game over / retry. `tools/smoke_flow.gd` → `FLOW_SMOKE_OK`. A windowed run lost a life and went through the bike screen to the next round. |
| 3+ microgames | ✅ 4 in the flow, plus 1 more | Canvas (Mon/Fri), Schedule Builder (Tue), Stay Focused (Wed), Logic Gates (Thu). Variable Not in Scope (SCRUM-23) is playable from the launcher but not in the flow. `tools/check_microgames.gd` → `MICROGAME_CHECK_OK` for all 5 × 3 difficulties. |
| Timer | ✅ | Each microgame emits `time_changed`. The HUD bar and seconds update; the round fails at 0. |
| Lives | ✅ | 3 lives, −1 per failed round, game over at 0, retry resets. Covered by the smoke test. |
| HUD | ✅ | `game_hud.gd`: time, lives, score, day N/5. |
| Bike transition | ✅ | `bike_transition.gd`: 3 s lane-switching interstitial showing "NEXT UP", lives, and score. Plays between days and after a failed round. |

## Caveats / gaps

1. **Nothing is merged.** `main` is still the empty skeleton. PR #3 (game), #2 (SCRUM-33 animation
   controller) and #1 (SCRUM-35 asset guidelines) are open with no reviews. The milestone holds
   only once PR #3 is reviewed and merged. That is the top action item.
2. **"One full day" means one microgame per day right now.** A day ends after one win.
   There is no run of 3+ microgames inside a single day, and no speed-up between rounds. The
   week as a whole chains 4 microgames. If the fallback demo should be one day with several
   microgames back to back, the flow / manager owner (SCRUM-14) needs to add a per-day playlist.
3. **No shared microgame base class or manager** (SCRUM-15 / SCRUM-14 are still "Idea").
   Microgames follow an informal contract instead (documented in `scripts/debug/microgame_catalog.gd`).
4. SCRUM-23 is not placed on a day yet. Adding it to `game_flow.gd` is the flow owner's call.
5. PR #2's animation controller is not used by the bike transition or the microgames yet.
6. Not checked: web (HTML5) export, the itch.io build, or real human playtesting. Every run
   here was scripted (headless smoke tests, plus windowed runs rendered to PNG frames).

## How to re-check

```
godot --headless --path . --script res://tools/smoke_flow.gd           # FLOW_SMOKE_OK
godot --headless --path . --script res://tools/check_microgames.gd     # MICROGAME_CHECK_OK
godot --headless --path . --script res://tools/smoke_variable_scope.gd # VARIABLE_SCOPE_SMOKE_OK
```
