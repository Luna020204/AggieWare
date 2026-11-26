
# Asset Import Guidelines

**SCRUM-35 — Draft for Team Review**

## 1. Folder Structure

Keep the existing `assets/art/` and `assets/audio/` folders. Organize downloaded asset packs into separate folders and use the current AggieWare project as a reference.

The following structure shows the existing art and audio folders in the project:

```text
assets/
├── art/
│   ├── PNG/
│   ├── RPG Urban Pack/
│   ├── Tiles/
│   ├── Tiny_Town/
│   └── UI_Pack_Pixel Adventure/
└── audio/
    ├── Impact_Sounds/
    ├── Interface_Sounds/
    ├── Jingles/
    └── RPG_Sounds/
```

Keep each downloaded pack in its own folder. Preserve internal files and folders needed for tilesheets or other resources. Keep the license file with the corresponding asset pack.

Team members can refer to these existing folders as examples when importing new assets.

## 2. Naming Conventions

Use clear and descriptive English names for files and folders. Underscores are recommended to separate words.

Existing AggieWare examples:

- `Tiny_Town/`
- `UI_Pack_Pixel Adventure/`
- `Impact_Sounds/`
- `Interface_Sounds/`
- `RPG_Sounds/`

Downloaded asset packs may keep their original filenames. Do not rename individual files if their names are required by the asset pack.

Avoid unclear names such as `final_final`, `copy`, and repeated file extensions.

## 3. Import Workflow

Use the team's Godot version: **4.7.2-stable, standard edition**.

1. Choose the appropriate folder under `assets/art/` or `assets/audio/`.
2. Copy the required image or audio files into the selected folder.
3. Return to Godot and wait for automatic import.
4. Select the asset in FileSystem and open the Import tab.
5. Apply the relevant settings below and click **Reimport**.
6. Preview the image or audio to check that it imported correctly.

For external assets, record the pack name, author, source link, and license in the root README's **Credits and licenses** section. Include any required attribution.

## 4. Image Settings

For ordinary 2D pixel-art sprites and UI:

- Import As: **Texture2D**
- Compress → Mode: **Lossless**
- Mipmaps → Generate: **Off**

Use **Nearest** texture filtering on the node displaying pixel art, or an appropriate shared parent. This is a display setting, not an image Import option in Godot 4.

For project-authored microgame art, use the 5× convention below. Downloaded packs may retain another whole-number scale when needed. Check transparency and appearance at the intended display size.

Different settings may be needed for non-pixel artwork or heavily downscaled images.

### Team convention for generated microgame pixel art

Following Luna's SCRUM-35 guidance (November 21, 2026; reference PRs #14, #16 and #17):

- Generate original pixel art with Python/Pillow (PIL) scripts in `tools/art/`.
- Draw on a **256×144** grid, one fifth of the **1280×720** game layout. Individual sprites use appropriately sized canvases on that same grid.
- Write PNGs to `assets/art/microgames/<game>/` and commit both the generator and its output.
- Display artwork at **5×** with `TEXTURE_FILTER_NEAREST`. Keep lossless compression and mipmaps off.
- Use the **AggiePixel** bitmap font at sizes that are multiples of **7**. Preserve explicitly documented exceptions, such as AggieMono for case-sensitive code in Variable Not in Scope.
- Keep live UI elements such as progress bars, aim indicators, and timer labels in Godot; backgrounds and sprite artwork come from the generated images.

Example: after installing Pillow, run `python3 tools/art/gen_festival_art.py` from the project root. `python3 tools/art/gen_festival_art.py --check` verifies the committed PNG pixel data without rewriting it. The SCRUM-75 scenes load these images at 5× through the shared nearest-filtered pixel canvas.

## 5. Audio Settings

Godot supports both WAV and Ogg Vorbis. Existing OGG effects do not need conversion to WAV.

- Interface sounds, gameplay effects, and one-shot jingles: **Loop off**.
- Background music: enable looping only when intended.
- For OGG, adjust **Loop**.
- For WAV, adjust **Edit → Loop Mode**.
- Click **Reimport** after changing import settings.

Preview representative sounds and check volume, unwanted silence, and repetition. For looping music, listen across the loop boundary.

## 6. Sharing and Review

Commit:

- Source images and audio
- Corresponding import metadata and settings files, where applicable
- License files and documentation
- Any intentionally changed scenes or resources

Do not commit the generated `.godot/` cache. The existing project `.gitignore` already excludes it.

Work on a feature branch, include `SCRUM-35` in the branch name or PR title, and request teammate review before merging into `main`.

## 7. Completion Checks

- Submitted assets follow the documented folder structure.
- Naming conventions are clear and consistently applied.
- Representative images and sounds have been checked.
- Import settings are saved and included in the submission.
- Sources and licenses are recorded.
- A teammate can follow these instructions to import another asset.

