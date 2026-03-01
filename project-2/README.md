# Service Suspended - Episode 2

A pixel-art dungeon exploration demo built in Godot 4.6 (GL Compatibility). Episode 2 continues the story of a mysterious ticket that keeps pulling you into strange, looping dungeons beneath the train station.

## Team Members
Eswar Talasila, Zachary Boston, Mokshagna Kadiyala, Nishil Rally

## Setup

1. Install Godot 4.6 from https://godotengine.org/
2. Open the `service-suspended-episode-2/` folder as a Godot project
3. Press F5 or click the Play button to run

## Controls

- **WASD** - Move the character
- **E** - Interact (open doors, use exit)
- **Mouse** - Custom cursor, click UI buttons
- **Left Click** - Punch ticket (when in punch mode)

## How to Play

1. You start in a small dungeon room with a ticket UI in the corner
2. Walk around and **collect all ticket pickups** scattered on the floor (ticket count goes up as you collect)
3. **Avoid spike traps** - they blink on and off, stepping on them kills you
4. Once all tickets are collected, an **exit door** spawns at the center of the dungeon
5. Walk to the exit door and **Press E** to escape through the loading screen
6. Use the **hole punch button** in the UI to enter punch mode, then click the **ticket button** to fly in a ticket and punch it (burn animation)

## Death and Respawn

- Dying to a trap shows the death screen with two options:
  - **Reload** - Free restart, resets your ticket count to 0
  - **Respawn** - Costs one collected ticket, plays a burn animation, then respawns you with remaining tickets preserved

## Features

- Hand-painted dungeon tilemap with wall collision
- Interactive doors using transparent sprite overlays from the tileset (Press E to open)
- Ticket pickup system with inventory count UI
- Spike traps with timed on/off blinking
- Exit door that spawns with a pop-in animation after collecting all tickets
- Death screen with reload/respawn choice (respawn burns a ticket with dissolve shader)
- Custom pixel-art cursor with context-sensitive states (default, clicked, punch open, punch closed)
- Loading screen transitions between scenes
- Burn dissolve shader for ticket punch animation

## Externally Sourced Content

N/A

## Custom-Made Assets

All art, UI, sprites, animations, tilesets, and shaders were created by the team.

## Asset Reference

### Aseprite Source Files (`assets/`)

#### Protagonist (`assets/protag/`)
| File | Description |
|------|-------------|
| `Protag_Directions.aseprite` | Master direction reference sheet |
| `protag_idle_east.aseprite` | Idle animation facing east |
| `protag_idle_north.aseprite` | Idle animation facing north |
| `protag_idle_north_east.aseprite` | Idle animation facing north-east |
| `protag_idle_north_west.aseprite` | Idle animation facing north-west |
| `protag_idle_south.aseprite` | Idle animation facing south |
| `protag_idle_south_east.aseprite` | Idle animation facing south-east |
| `protag_idle_south_west.aseprite` | Idle animation facing south-west |
| `protag_idle_west.aseprite` | Idle animation facing west |
| `protag_walk_east.aseprite` | Walk animation facing east |
| `protag_walk_north.aseprite` | Walk animation facing north |
| `protag_walk_north_east.aseprite` | Walk animation facing north-east |
| `protag_walk_north_west.aseprite` | Walk animation facing north-west |
| `protag_walk_south.aseprite` | Walk animation facing south |
| `protag_walk_south_east.aseprite` | Walk animation facing south-east |
| `protag_walk_south_west.aseprite` | Walk animation facing south-west |
| `protag_walk_west.aseprite` | Walk animation facing west |
| `protag_sprite_sheet.aseprite` | Combined sprite sheet |

#### UI Elements (`assets/UI/`)
| File | Description |
|------|-------------|
| `Briefcase UI.aseprite` | Briefcase inventory UI element |
| `cursor_hand.aseprite` | Custom mouse cursor (hand/pointer) |
| `death_screen.aseprite` | "You Died" death screen animation (10 frames) |
| `Hole Punch UI.ase` | Hole punch tool UI (open/closed states, 4 frames) |
| `Loading_Screen.aseprite` | Loading screen transition animation (10 frames) |
| `numbers.aseprite` | Number digit sprites for UI counters |
| `Reload_Button.aseprite` | Reload button (normal/hover/pressed, 3 frames) |
| `Respawn_Button.aseprite` | Respawn button (normal/hover/pressed, 3 frames) |
| `text_bubble.aseprite` | Dialog text bubble (left and right variants) |
| `Ticket Asset.ase` | Ticket item sprite |
| `UI_Base.aseprite` | Base UI panel background |

#### Train Level Components (`assets/levels/train/`)
| File | Description |
|------|-------------|
| `modern subway.ase` | Modern subway train car layout |
| `semi modern subway.ase` | Semi-modern subway train car layout |
| `components/boarder.aseprite` | Train car border/edge piece |
| `components/flooring.aseprite` | Train car floor tile |
| `components/wall_segment.aseprite` | Train car wall segment |
| `template/train_template.aseprite` | Base train car template |

### Exported PNGs in Godot Project (`service-suspended-episode-2/assets/`)

#### Protagonist Sprites (`assets/sprites/protagonist/`)
- `animations/breathing-idle/` — 8 directions (east, north, north-east, north-west, south, south-east, south-west, west), 4 frames each
- `animations/walking/` — 8 directions, 5-7 frames each
- `protagonist_frames.tres` — Godot SpriteFrames resource
- `metadata.json` — Animation metadata

#### Furniture Sprites (`assets/sprites/furniture/`)
| File | Description |
|------|-------------|
| `bench_seat.png` | Bench/seat prop |
| `table_lamp.png` | Table lamp prop |
| `wall_panel.png` | Wall panel decoration |
| `window.png` | Window sprite |

#### Dungeon Tilesets (`assets/tilesets/dungeon/`)
| File | Description |
|------|-------------|
| `dungeon_tileset_floor_and_stairs.png` | Floor and stair tiles (336x128, 21x8 grid) |
| `dungeon_tileset_walls.png` | Wall tiles (336x176, 21x11 grid) |
| `dungeon_tileset_decorations.png` | Furniture and decoration tiles (336x192, 21x12 grid) |
| `dungeon_tileset_water.png` | Water and fence tiles (336x112, 21x7 grid) |
| `dungeon_terrain.tres` | Godot TileSet resource combining all 4 spritesheets |

#### UI Elements (`assets/ui/`)
| Folder/File | Description |
|-------------|-------------|
| `cursor/frame_0.png, frame_1.png` | Custom cursor states (clicked, default) |
| `death_screen/frame_0.png – frame_9.png` | Death screen animation frames (10 frames) |
| `hole_punch/punch_0.png – punch_3.png` | Hole punch icon and cursor states (4 frames) |
| `loading_screen/frame_0.png – frame_9.png` | Loading screen animation frames (10 frames) |
| `loading_screen_sheet.png` | Loading screen combined sprite sheet |
| `reload_button/frame_0.png – frame_2.png` | Reload button states (normal/hover/pressed) |
| `respawn_button/frame_0.png – frame_2.png` | Respawn button states (normal/hover/pressed) |
| `ticket_frames/ticket_0.png – ticket_26.png` | Ticket animation sequence (27 frames: static, digits 0-9, fly-in, idle float) |
| `text_bubble_left.png, text_bubble_right.png` | Dialog bubble variants |
| `Ticket_Asset.png` | Ticket item pickup sprite |
| `UI_Base.png` | Base UI panel texture |
| `Hole_Punch_UI_Closed.png` | Hole punch closed state (legacy) |
| `Hole_Punch_UI_Opened.png` | Hole punch open state (legacy) |

### Shaders (`service-suspended-episode-2/shaders/`)
| File | Description |
|------|-------------|
| `burn_dissolve.gdshader` | Perlin noise burn/dissolve effect for ticket punch animation |
