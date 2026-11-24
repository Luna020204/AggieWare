# SCRUM-75: ECS 179 festival exercises

Friday now plays Position Lock (Exercise 2), Shield Break (Exercise 3), then the existing Canvas Final Upload. Each new game is also independently selectable in the debug microgame launcher. The default Friday uses Normal difficulty; all three tiers are available in the launcher.

| Game | Controls and objective | Easy / Normal / Hard |
| --- | --- | --- |
| Position Lock | Move the camera frame with the mapped movement keys (arrows or WASD by default). Keep the entire vessel inside the frame continuously for 0.65 seconds; leaving the frame resets progress. | Target motion rate: 0.65 / 0.9 / 1.15 radians per second |
| Shield Break | Move the gun left/right (arrows or A/D), align with the shield, then mash ACTION (Space or Enter). Off-target beams do no damage. | 6 / 9 / 12 hits |

Both games have 9 / 8 / 7 seconds of active play. The shared introduction does not consume the countdown; timeout loses a life through the existing host. A win produces one result and advances through the standard bike transition. Friday retains its final Canvas round. The common pause, retry, timer assistance, remapping, and hold-to-mash accessibility settings remain supported. Gameplay labels display the current mapped keys. All new artwork is drawn in code on the existing pixel canvas, with no external asset dependencies.

Run in Godot 4.7:

```sh
godot --headless --path . --script res://tools/test_festival.gd
godot --headless --path . --script res://tools/test_collection.gd
godot --headless --path . --script res://tools/check_microgames.gd
```

`test_festival.gd` covers all three tiers, intro/pause gating, loss of camera lock, reachable wins using movement actions, misaligned shots, remapped physical firing input, hold-to-mash, result gating, and retry reset. Collection and presentation checks cover timeout, one-result semantics, Friday transitions and shared overlays. Both web build scripts include the festival tests.

Manual review: select Friday or launch each game individually; confirm that the lock meter and shield/beam feedback are readable, try a missed lock/shot and a timeout, then pause/resume and retry. Human playtesting and a browser-export playthrough are still needed for final feel/balance approval.
