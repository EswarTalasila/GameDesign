# Service Suspended: Episode 3 — Demo

## Overview
This is a demo build of Service Suspended Episode 3, a top-down dungeon crawler / escape room game built in Godot 4.6. The player is trapped in a room and must solve puzzles to escape. This episode replaces the ticket-based loop system from Episode 2 with a clock mechanic and introduces interactive close-up puzzles.

## Requirements
- **Godot 4.6** (GL Compatibility renderer)
- Resolution: 1920x1080

## How to Run
1. Open Godot 4.6
2. Import this project (select the `project.godot` file)
3. If prompted about missing dependencies, click "Open Anyway" — the Dialogue Manager addon should auto-enable
4. Press F5 or click the Play button

## Controls
| Key | Action |
|-----|--------|
| W/A/S/D | Move (8-directional) |
| E | Interact (press E prompts) |
| SPACE | Attack |
| ESC | Pause menu |

## Demo Features

### Vision Cone System
- The player has a directional field-of-view cone that follows their facing direction
- Areas outside the cone are darkened — encourages exploration and awareness
- The cone uses a shader overlay that clears darkness in the player's line of sight

### Electrical Panel Puzzle
- Walk up to the electrical panel on the wall — a "Press E" prompt appears
- Press E to open the close-up view of the panel
- Click the closed panel door to open it and reveal the wires inside
- Press ESC to close the puzzle and return to gameplay

### Wire Cutter Pickup
- Find the wire cutter pickup in the room (animated item on the ground)
- Walk over it to collect it — the wire cutter icon appears in the inventory (bottom-right)
- Click the inventory icon to activate wire cutter mode (cursor changes)
- Click again to deactivate

### Pause Menu
- Press ESC to open the pause menu
- Resume, Restart, or Quit from the clipboard UI
- Mute toggle available

### Health System
- Health bar displayed in the top-right corner (3 HP)
- Health and inventory UI are not affected by the vision cone darkness

## Known Limitations (Demo)
- Wire cutting on the electrical panel is not yet functional (wires need to be split into individual sprites)
- Clock-based loop system is planned but not yet implemented
- Only one room is playable in this demo
- Wall collision for the vision cone (line-of-sight blocking) is a future feature

## Project Structure
- `escape_room_1.tscn` — Main gameplay scene
- `scenes/ui/` — All UI scenes (main menu, pause, health bar, inventory, panel puzzle)
- `scenes/player/` — Player character with movement, combat, and vision system
- `scenes/interactables/` — Electrical panel and other interactable objects
- `scenes/pickups/` — Wire cutter and other pickup items
- `scripts/` — Core singletons (GameState, CustomCursor, room coordinator)
- `assets/shaders/vision_cone.gdshader` — Vision cone shader
