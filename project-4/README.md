# Project 4

This folder contains the fourth game in the `Service Suspended` series: the resource management episode.

The playable Godot project is:

- [service-suspended-episode-4](/project-4/service-suspended-episode-4)

Prebuilt exports can be placed here:

- [builds](/CSC-486/project-4/builds)

## Requirements

- Godot Engine `4.6`
- A desktop environment capable of running the Godot editor/game window

This project uses the Godot 4 project format and is configured with:

- `config/name="Service Suspended Episode 4"`
- `config/features=PackedStringArray("4.6", "GL Compatibility")`

## How To Run

### Option 1: Run A Prebuilt Build

If you do not want to open Godot, use the exported game builds in:

- [builds/windows](/CSC-486/project-4/builds/windows)
- [builds/macos](/CSC-486/project-4/builds/macos)
- [builds/linux](/CSC-486/project-4/builds/linux)

Use the build that matches your operating system.

### Option 2: Run From The Godot Editor

1. Open Godot `4.6`.
2. Click `Import`.
3. Select [project.godot](/CSC-486/project-4/service-suspended-episode-4/project.godot).
4. Open the imported project.
5. Press `F5` or click `Run Project`.

Godot will launch the configured main scene automatically.

### Option 3: Run From The Command Line

From the repo root:

```bash
cd project-4/service-suspended-episode-4
godot --path .
```

If your system uses a different executable name, replace `godot` with the correct Godot 4 binary.

## Project Structure

- [builds](/CSC-486/project-4/builds): exported runnable builds for supported platforms
- [service-suspended-episode-4](/CSC-486/project-4/service-suspended-episode-4): main Godot project
- [Assets](/CSC-486/project-4/UI/Assets): supporting art and source assets
- [story](/CSC-486/project-4/story): story and writing-related materials
- [project4_demo](/CSC-486/project-4/project4_demo): older demo/prototype materials

## Controls

- `WASD`: move
- `E`: interact
- `Space`: attack
- `Esc`: pause, close menus, close puzzle UIs
- Mouse: click inventory items and interact with bonfire to burn items

## Notes

- The game starts from the configured project main scene, so you should run the project itself rather than opening individual environment scenes first.
- If a working export already exists in [builds](/CSC-486/project-4/builds), players can launch that directly without opening Godot.
- If Godot shows missing imports on first open, let it finish reimporting project assets before running.
