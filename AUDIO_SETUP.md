# Audio manager setup (Godot 4)

The project now has a centralized `AudioManager` autoload. The audio manager is wired into the existing game flow, but this project archive did not contain music or jingle files, so playback remains silent until you assign audio assets.

## Assign audio files

1. Import your audio files into the project (for example, create `audio/music/` and `audio/sfx/`).
2. Open `resources/audio_library.tres` in the Godot Inspector.
3. Assign the imported files to these fields:
   - `Title Music`
   - `Gameplay Music`
   - `Startup Jingle`
   - `Win Jingle`
   - `Lose Jingle`
   - `Stage Clear Jingle`
   - `Game Over Jingle`
4. Set `Max Gameplay Pitch` to control how much faster the gameplay music gets by the end of the week. It defaults to `1.18` (18% faster and higher in pitch).
5. Set `Music Fade Seconds` to control music fade-ins.
6. For looping music, enable looping in the audio file's Import settings where the selected stream format supports it, then reimport.

## Current behavior

- Startup jingle plays when the game loads; title music starts at the same time.
- Gameplay music starts when the microgame's instruction/introduction screen ends and active play begins.
- Win/loss jingles play when the round result is decided.
- Stage-clear and game-over jingles play on their respective result screens.
- Music and SFX respect the existing `GameState` music/SFX settings.
- Gameplay playback speed ramps from `1.0x` toward the configured maximum across the week. It progresses both within each round and between rounds/stages.

## Important tempo note

Godot's `AudioStreamPlayer.pitch_scale` changes both playback speed and pitch. This first implementation therefore makes the music faster *and* slightly higher in pitch. If you want the tempo to increase while preserving pitch, the next step would be to use authored intensity variants or a time-stretching audio solution instead.
