# Service Suspended - Episode 2

A pixel-art dungeon crawler built in Godot 4.6 (GL Compatibility). Episode 2 continues the story from Episode 1's interactive narrative — your mundane commute spirals into a looping nightmare when a mysterious ticket pulls you into strange dungeons beneath the train.

## Team Members

Eswar Talasila, Zachary Boston, Mokshagna Kadiyala, Nishil Rally

## Contributions

| Member | Contributions |
|--------|---------------|
| **Zachary Boston** | Asset design and creation, tileset painting, dungeon and train map design, GDScript programming, character design and animation, scene wiring and game flow, sound integration, testing |
| **Eswar Talasila** | Play testing, game narrative and dialogue script writing |
| **Mokshagna Kadiyala** | Play testing, asset design and creation, train tileset foundation |
| **Nishil Rally** | Play testing, sound sourcing and design, narrative and dialogue script writing |

## Setup

1. Install Godot 4.6 from https://godotengine.org/
2. Open the `service-suspended-episode-2/` folder as a Godot project
3. Press F5 or click the Play button to run

## Story Overview

You board a train and meet a mysterious woman in red who warns you about "him" — the Conductor. Between train rides you're pulled into looping dungeon floors where you must collect tickets, punch them to rotate sections, find golden tickets to unlock the exit, and survive enemies and traps. After escaping the dungeon you return to the train, where the story progresses toward a confrontation with the Conductor.

### Game Flow

**Main Menu → Train Section 1 → Dungeon → Train Section 2 → Conductor Hub (Ending)**

1. **Train Section 1** — Meet the Lady in Red, explore the train car, then enter the dungeon via the connector door (Press E)
2. **Dungeon** — Explore randomized dungeon floors, collect tickets, punch them to rotate sections, find keys and golden tickets, avoid traps and enemies, then escape through the exit door
3. **Train Section 2** — Return to the train post-dungeon, speak with the Lady in Red again for final advice
4. **Conductor Hub** — Cutscene confrontation with the Conductor, ending sequence

## Controls

- **WASD** — Move the character (8-directional)
- **E** — Interact (open doors, talk to NPCs, use connectors)
- **Mouse** — Custom cursor with context-sensitive states
- **Left Click** — Click UI inventory slots, punch floating tickets
- **Escape** — Cancel active mode / open pause menu

## Gameplay Systems

### Ticket Punch System
Collect ticket pickups scattered through dungeon sections. Click the ticket icon to float one out, click the punch icon to enter punch mode, then click the floating ticket to punch it. Punching a ticket triggers a burn dissolve animation and **rotates the current dungeon section** to a new variant with fresh items, enemies, and layout.

### Section Rotation
Each dungeon floor has 4 sections (A-D) with 3 variants each. Punching a ticket inside a section swaps it to the next variant. This is the core mechanic — rotating sections reveals new paths, items, and golden ticket spawns.

### Golden Tickets
6 special golden tickets are required per floor to unlock the exit door. They spawn with 75% probability in newly rotated sections. Collect all 6 to unlock the special exit and escape to the train.

### Keys & Locked Doors
Keys drop from enemies and are found in the environment. Use them to unlock doors and chests by pressing E near them or clicking the key icon then clicking the lock.

### Combat
Enemies patrol dungeon sections. The player can take up to 3 hits before dying. Heart pickups restore health. At 1 HP a heartbeat sound plays as a warning.

### Death & Respawn
- **Reload** — Free restart, resets all progress on the current floor
- **Respawn** — Costs one collected ticket, burns it with a dissolve animation, reloads the current section and respawns at the last checkpoint

## Dialogue System

Uses Dialogue Manager v3.10.1 with branching dialogue trees. NPCs have proximity-based "Press E" interaction prompts. Dialogue choices affect the narrative and provide story context about the train, the tickets, and the Conductor.

## Features

- Hand-painted dungeon tilemaps with multi-layer rendering (terrain, walls, furniture, overhead)
- Train interior scenes with hand-placed furniture, NPCs, and environmental storytelling
- 8-directional character movement with idle and walk animations
- Section variant swapping mechanic driven by ticket punching
- Branching NPC dialogue with the Lady in Red and the Conductor
- Conductor Hub cutscene with scripted character movement, dialogue, and fade-to-black ending
- Burn dissolve shader for ticket punch animations
- Custom pixel-art cursor with context-sensitive states (default, clicked, punch, key)
- Loading screen transitions between all scenes
- Checkpoint/save system per dungeon section
- Pause menu with resume, restart, and quit options
- Dual ambient audio layers (dungeon ambience, train sounds)
- Tile entity system — marker tiles painted in the editor are replaced with entity scenes at runtime

## Externally Sourced Content

### Addons
- **Dialogue Manager** v3.10.1 — Nathan Hoad (https://github.com/nathanhoad/godot_dialogue_manager)

### Tilesets
- **Dark Dungeon** tileset — Brullov (https://brullov.itch.io/dark-dungeon) — used for dungeon floor, wall, and decoration tiles
- **Pixel Art Top Down - Basic** v1.2.3 — ~~used for outdoor/subway exterior tiles~~ (cut content, unused)
- **Jungle Tileset 16x16 Pixelart** — ElvGames (https://elvgames.itch.io) — ~~used for exterior forest dungeon tiles~~ (cut content, unused)
- **Jungle Winter & Autumn Tileset** — ElvGames (https://elvgames.itch.io) — ~~used for exterior forest dungeon tiles~~ (cut content, unused)

### UI Components
- **Paper Pack** UI elements — Robin Norkum / LCSkeleton — ~~used for UI component foundations~~ (cut content, unused)

### Fonts
- **Compass 9** pixel font — used for in-game text rendering

### Sound Effects
- Sound effects sourced from **Pixabay** (https://pixabay.com/sound-effects/) and the **Freesound** community — includes door sounds, ambient tracks, pickup effects, and UI feedback sounds

## Cut Content

The following features were planned but had to be cut due to time constraints:

- **Dungeon Floor 2** — A second dungeon floor with 4 additional sections (A-D, 3 variants each), accessible after completing Floor 1. The architecture and section rotation system were built to support multiple floors, but only Floor 1 was fully painted and populated.
- **Forest Dungeon** — A second outdoor forest-themed dungeon to be played between the train and the Conductor Hub, using the jungle and outdoor tilesets. This would have added a different visual environment and gameplay feel before the final confrontation.

## Custom-Made Assets

Main menu art, UI buttons, all character sprites and animations (protagonist, Lady in Red, Conductor, enemies), train tileset and interior painting, burn dissolve shader, and game-specific sound design were created by the team.

### Aseprite Source Files (`assets/`)

#### Protagonist (`assets/protag/`)
| File | Description |
|------|-------------|
| `Protag_Directions.aseprite` | Master direction reference sheet |
| `protag_idle_*.aseprite` | Idle animations — 8 directions |
| `protag_walk_*.aseprite` | Walk animations — 8 directions |
| `protag_sprite_sheet.aseprite` | Combined sprite sheet |

#### NPCs (`assets/npc/`)
| File | Description |
|------|-------------|
| `Lady_In_Red/animations/Idle/` | Lady in Red idle animations — 8 directions (Aseprite) |
| Conductor sprites | Exported PNGs for idle and walk (south, east) — 64x64 |

#### UI Elements (`assets/UI/`)
| File | Description |
|------|-------------|
| `Briefcase UI.aseprite` | Briefcase inventory UI element |
| `cursor_hand.aseprite` | Custom mouse cursor |
| `death_screen.aseprite` | Death screen animation (10 frames) |
| `Hole Punch UI.ase` | Hole punch tool UI (4 frames) |
| `Loading_Screen.aseprite` | Loading screen transition (10 frames) |
| `numbers.aseprite` | Number digit sprites for UI counters |
| `Reload_Button.aseprite` | Reload button states |
| `Respawn_Button.aseprite` | Respawn button states |
| `text_bubble.aseprite` | Dialog text bubble variants |
| `Ticket Asset.ase` | Ticket item sprite |
| `UI_Base.aseprite` | Base UI panel background |

#### Train Level (`assets/levels/train/`)
| File | Description |
|------|-------------|
| `Train Tiles.png` | Train interior tileset (16x16) |
| `modern subway.ase` | Modern subway car layout |
| `semi modern subway.ase` | Semi-modern subway car layout |
| `components/` | Train car border, flooring, wall segment pieces |

### Tilesets

| File | Description |
|------|-------------|
| `dungeon_tileset_floor_and_stairs.png` | Floor and stair tiles |
| `dungeon_tileset_walls.png` | Wall tiles |
| `dungeon_tileset_decorations.png` | Furniture and decoration tiles |
| `dungeon_tileset_water.png` | Water and fence tiles |
| `dungeon_terrain.tres` | Combined Godot TileSet resource |
| `Train Tiles.png` | Train interior tileset |

### Shaders

| File | Description |
|------|-------------|
| `burn_dissolve.gdshader` | Perlin noise burn/dissolve effect for ticket punch animation |

### Sound Effects (`assets/sounds/`)

| File | Description |
|------|-------------|
| `train_sounds.mp3` | Train mechanical loop |
| `train_ambience.mp3` / `train_ambience_2.mp3` | Train ambient tracks |
| `dungeon_ambience.mp3` / `dungeon_ambience_2.mp3` | Dungeon ambient tracks |
| `heartbeat.mp3` | Low health warning |
| `ticket_punch.mp3` | Punch sound effect |
| `ticket_burn.mp3` | Burn dissolve sound |
| `health_pickup.mp3` | Health restore sound |
| `chest_open.wav` | Chest opening sound |
| `wooden_door_open.mp3` / `metal_door_open.mp3` | Door sounds |
| `door_unlock.mp3` | Lock opening sound |
| `golden_ticket_pickup.mp3` | Golden ticket collect sound |
| `shadow_hit.mp3` | Enemy hit sound |
| `game_over.mp3` | Death sound |
