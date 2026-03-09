# Key/Lock System Design

## Overview
Keys are collectible pickups placed in dungeon sections. Doors and chests can be marked as locked via an export variable. Locked items show a lock icon instead of the press-E prompt. The player clicks the key icon in the UI to enter key-cursor mode, then clicks a locked item to unlock it, consuming one key.

## Asset Pipeline

### Key.aseprite (single file, tagged frames)
- **pickup idle** tag → export as spritesheet `assets/sprites/pickups/key/key_pickup_float.png`
- **inventory icon** tag → export as `assets/sprites/pickups/key/key_icon.png`
- **cursor** tag → export as `assets/ui/cursor/key_cursor.png`
- **spawn marker** → first frame exported as `assets/sprites/pickups/key/key_spawn_marker.png` (16x32 like ticket marker)

### Lock-Icon.aseprite (tagged frames: locked, opening, unlocked)
- Export each tag as separate PNGs or a combined spritesheet
- Destination: `assets/sprites/ui/lock/lock_locked.png`, `lock_opening.png` (if multi-frame), `lock_unlocked.png`
- Or combined spritesheet: `assets/sprites/ui/lock/lock_spritesheet.png`

## Key Pickup (follows ticket pickup pattern)

### Scene: `scenes/pickups/key_pickup.tscn`
- Root: Area2D (collision_layer = 4 pickups, collision_mask = 1 player)
- AnimatedSprite2D — idle float animation, position offset (0, -8), outline_glow shader
- CollisionShape2D — RectangleShape2D ~12x12
- Exported collision_size/collision_offset like trap_spikes

### Script: `scenes/pickups/key_pickup.gd`
- On body_entered (CharacterBody2D only): call GameState.collect_key()
- Tween scale-up + fade, then queue_free()
- Glow pulse tween on shader glow_alpha (same as ticket)

### Tilemap Integration
- Add key marker to `item_spawn_markers.tres` as source 0, next available atlas coord
- Register in `tile_entities.gd`: `{ "source": 0, "marker": Vector2i(1, 0), "scene": preload("res://scenes/pickups/key_pickup.tscn"), "size": Vector2i(1, 1), "layer": "items" }`
- Painted in Items TileMapLayer in editor

## GameState Additions

```gdscript
var keys_collected: int = 0
signal key_collected(current: int)

func collect_key() -> void:
    keys_collected += 1
    key_collected.emit(keys_collected)

func use_key() -> bool:
    if keys_collected > 0:
        keys_collected -= 1
        key_collected.emit(keys_collected)
        return true
    return false
```

## Lock Prompt

### Scene: `scenes/ui/lock_prompt.tscn`
- AnimatedSprite2D (like press_e_prompt)
- z_index = 20, z_as_relative = false
- visible = false by default
- Animations: "locked" (idle locked icon), "opening" (unlock transition), "unlocked" (open lock icon, brief)

### Usage
- Instanced as child of Area2D in door/chest scenes (alongside PressEPrompt)
- When locked: lock_prompt visible, press_e_prompt hidden
- When unlocked: lock_prompt plays "opening", then hides; press_e_prompt becomes visible

## Door/Chest Lock Integration

### door.gd changes
```gdscript
@export var locked: bool = false

@onready var _lock_prompt: AnimatedSprite2D = $Area2D/LockPrompt

func _ready() -> void:
    # ... existing setup ...
    if locked:
        _lock_prompt.visible = true
        _lock_prompt.play("locked")

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("interact") and _player_nearby:
        if locked:
            return  # can't interact when locked
        # ... existing open/close logic ...

func unlock() -> void:
    locked = false
    _lock_prompt.play("opening")
    await _lock_prompt.animation_finished
    _lock_prompt.visible = false
    _prompt.visible = true  # show press-E
```

### chest.gd — same pattern as door.gd

### Scene changes
- Add LockPrompt instance to door .tscn and chest .tscn files (sibling of PressEPrompt under Area2D)

## Key Cursor + Click-to-Unlock Flow

### UI Key Button
- `$UILayer/KeyButton` — TextureButton in floor scenes
- Shows key icon, visible only when GameState.keys_collected > 0
- Clicking toggles key cursor mode

### floor.gd cursor mode additions
- New state: `_key_mode: bool`
- Key cursor textures: key_cursor.png (idle), key_cursor_click.png (clicking) — or reuse single texture
- In key mode:
  - Cursor swaps to key texture
  - Mouse click raycasts / checks for locked interactable Area2D under cursor
  - If locked item found: call GameState.use_key(), call item.unlock(), exit key mode
  - If miss or Escape pressed: exit key mode, restore normal cursor

### Click detection
- In key mode, on mouse click: use physics point query at mouse world position
- Check if any Area2D hit belongs to a door/chest with `locked == true`
- Call `unlock()` on that node's parent (the door/chest root)

## Signal Flow
```
Key pickup collected → GameState.collect_key() → key_collected signal → UILayer updates KeyButton visibility
KeyButton clicked → floor.gd enters key mode → cursor changes
Click on locked item → GameState.use_key() → door/chest.unlock() → lock_prompt animation → press_e_prompt shown
                     → key_collected signal → UILayer updates KeyButton (hide if 0 keys)
Escape / click miss → exit key mode → cursor restores
```
