# NightShift — Godot 4 migration

This is an **independent desktop prototype**, not a replacement for the browser game.
The existing Three.js site remains unchanged.

## Step 1 — run the prototype

1. Install Godot 4.3 or later (standard edition, GDScript).
2. Clone or pull the NightShift GitHub repository.
3. In Godot Project Manager choose **Import** and select `godot/project.godot`.
4. Open the project and press **F6** with `scenes/main.tscn` open, or **F5**.

The first scene uses simple procedural placeholders. This is intentional: we validate the
camera, orthographic projection and grid before importing the GLB asset library.

**Controls:** left-drag rotate, Shift+left-drag pan, mouse wheel zoom, R reset.

## Next milestones

- Import original GLB club models into `godot/assets/` and map the existing object catalog.
- Load the donated ABLETON GYM layout from the game's JSON save.
- Rebuild placement, rotation, collision, undo, and save/load.
- Import animated guests and implement navigation.
- Port game economy, UI, progression and DJ booking.
- Add licensed local audio tracks and Steam desktop packaging.

Do not move the web game's `assets/` directory; it is still used by the live website.
Audio files must be licensed for distribution in a commercial game.
