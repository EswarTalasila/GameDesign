# Project 3: Service Suspended Episode 3

This folder contains the third game in the `Service Suspended` series: the escape room episode.

The playable Godot project is:

- [service-suspended-episode-3](/Users/znboston/Learning/csc486/CSC-486/project-3/service-suspended-episode-3)

Prebuilt exports can be placed here:

- [builds](/Users/znboston/Learning/csc486/CSC-486/project-3/builds)

The puzzle reference sheet is here:

- [Escape_Room_Puzzle_Cheatsheet.pdf](/Users/znboston/Learning/csc486/CSC-486/project-3/Escape_Room_Puzzle_Cheatsheet.pdf)

## Requirements

- Godot Engine `4.6`
- A desktop environment capable of running the Godot editor/game window

This project uses the Godot 4 project format and is configured with:

- `config/name="Service Suspended Episode 3"`
- `config/features=PackedStringArray("4.6", "GL Compatibility")`

## How To Run

### Option 1: Run A Prebuilt Build

If you do not want to open Godot, use the exported game builds in:

- [builds/windows](/Users/znboston/Learning/csc486/CSC-486/project-3/builds/windows)
- [builds/macos](/Users/znboston/Learning/csc486/CSC-486/project-3/builds/macos)
- [builds/linux](/Users/znboston/Learning/csc486/CSC-486/project-3/builds/linux)

Use the build that matches your operating system.

### Option 2: Run From The Godot Editor

1. Open Godot `4.6`.
2. Click `Import`.
3. Select [project.godot](/Users/znboston/Learning/csc486/CSC-486/project-3/service-suspended-episode-3/project.godot).
4. Open the imported project.
5. Press `F5` or click `Run Project`.

Godot will launch the configured main scene automatically.

### Option 3: Run From The Command Line

From the repo root:

```bash
cd project-3/service-suspended-episode-3
godot --path .
```

If your system uses a different executable name, replace `godot` with the correct Godot 4 binary.

## Project Structure

- [builds](/Users/znboston/Learning/csc486/CSC-486/project-3/builds): exported runnable builds for supported platforms
- [service-suspended-episode-3](/Users/znboston/Learning/csc486/CSC-486/project-3/service-suspended-episode-3): main Godot project
- [Assets](/Users/znboston/Learning/csc486/CSC-486/project-3/Assets): supporting art and source assets
- [story](/Users/znboston/Learning/csc486/CSC-486/project-3/story): story and writing-related materials
- [project3_demo](/Users/znboston/Learning/csc486/CSC-486/project-3/project3_demo): older demo/prototype materials
- [Escape_Room_Puzzle_Cheatsheet.pdf](/Users/znboston/Learning/csc486/CSC-486/project-3/Escape_Room_Puzzle_Cheatsheet.pdf): quick puzzle aid

## Controls

- `WASD`: move
- `E`: interact
- `Space`: attack
- `Esc`: pause, close menus, close puzzle UIs
- `Tab`: open the lore journal after collecting documents
- Mouse: click inventory items and interact with puzzle UI elements

## Notes

- The game starts from the configured project main scene, so you should run the project itself rather than opening individual room scenes first.
- If a working export already exists in [builds](/Users/znboston/Learning/csc486/CSC-486/project-3/builds), players can launch that directly without opening Godot.
- If Godot shows missing imports on first open, let it finish reimporting project assets before running.
- The cheat sheet is included for help if you get stuck on the escape room puzzles.

## Team Members

- Eswar Talasila
- Zachary Boston
- Mokshagna Kadiyala
- Nishil Rally
