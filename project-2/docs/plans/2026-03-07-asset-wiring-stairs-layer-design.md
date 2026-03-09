# Asset Wiring & Stairs Layer Design

## 1. Death Screen — Re-point Frames

The death_screen.tscn currently references old `frame_0.png` through `frame_9.png` (Feb 25).
New frames with updated font: `death_screen1.png` through `death_screen10.png` (Mar 7).

Update the .tscn ext_resource paths and SpriteFrames to reference the new files.
Delete old frame_*.png files after to avoid confusion.

## 2. Loading Screen — Swap Frames

The loading_screen.tscn references root-level `frame_0-9.png` (Feb 25, old font).
Updated frames live in `frames/frame_0-9.png` (Mar 7, new font).

Copy `frames/frame_0-9.png` over root-level `frame_0-9.png`. The .tscn stays unchanged
since paths remain the same.

## 3. Saving Icon — New Scene + Wiring

Assets: `assets/ui/saving_icon/saving_sheet.png` (10 frames, 128x128 each, 100ms/frame)
Individual frames in `assets/ui/saving_icon/frames/`.

Create:
- `scenes/ui/saving_icon.tscn` — AnimatedSprite2D node
- `scenes/ui/saving_icon.gd` — script

Behavior:
- 10 frames at 10fps, non-looping
- Position: bottom-right of viewport
- On animation finish: fade out over 0.3s, then queue_free()

Wiring:
- In `floor.gd::_on_checkpoint_set()`: instantiate saving_icon scene, add to UILayer, play

## 4. Stairs Layer — New TileMapLayer

Problem: Stairs on Terrain layer render behind Walls layer (tree order). Stairs have
transparent areas that need walls visible behind them, so they can't share a layer.

Solution: Add a "Stairs" TileMapLayer after Walls in scene tree for all 24 section scenes.

Properties:
- tile_set: dungeon_terrain.tres (same as all layers)
- Uses source 0 (floor_and_stairs atlas)
- y_sort_enabled: true (matches Walls)
- No z_index change needed (tree order = renders after Walls = on top)
- collision_enabled: true (stairs have collision for guiding player)

Add programmatically by editing all section .tscn files. User then repaints problematic
stair tiles from Terrain to the new Stairs layer in the Godot editor.
