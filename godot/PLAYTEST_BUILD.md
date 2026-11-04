# NightShift — playable alpha build (Godot 4.7.2)

This is a standalone desktop build for friends. They do **not** need Godot or a copy of the source repository.

## Export from the developer's Mac

1. In GitHub Desktop, choose **Pull Origin**.
2. Open `godot/project.godot` in **Godot 4.7.2 stable**.
3. In **Editor → Manage Export Templates**, install the matching **4.7.2 stable** export templates.
4. Open **Project → Export**. Two presets are included: **macOS** and **Windows Desktop**.
5. Select **macOS**, check for validation errors, then choose **Export Project**. Save as `NightShift-macOS.zip`. Keep **Export With Debug** disabled for a release test.
6. For Windows, select **Windows Desktop** and **Export Project** as `NightShift-Windows.exe`.
7. Test the resulting app *outside the editor* on your own computer before sending it to friends. Check club loading, booking, all four DJ playlists, pause/resume, guest behavior, event choices, and saving.
8. Send the ZIP to Mac testers or the EXE to Windows testers via a file-sharing link. Large audio libraries will make the packages sizable.

**macOS security:** Without a paid Developer ID certificate and notarization, a downloaded test app may be blocked by Gatekeeper. Testers can go to **System Settings → Privacy & Security → Open Anyway** after attempting a first launch; only do this for a file they trust. Do not disable Gatekeeper globally.

**Windows security:** A fresh unsigned EXE may trigger a SmartScreen warning. Verify the origin and avoid telling testers to disable antivirus protection.

**Project location:** This Godot project lives in `godot/`, not in the root of the browser game. The browser version at playmyclub.online is separate.

**Audio:** The game reads imported audio resources using `ResourceLoader.list_directory()`, which works in the editor and exported builds. Only distribute tracks you have rights to share with testers.

**Save data:** Each tester gets a separate local `user://nightshift_club.json`. Their progress does not change the developer's save or the repository.

## Notes for future releases

- Do not commit exported executable files or large ZIP packages to the source repository.
- A notarized/signed macOS build can be prepared later for one-click installation.
- The first friend build is a **desktop alpha**, not a browser release.
