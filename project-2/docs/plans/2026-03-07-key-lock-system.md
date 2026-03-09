# Key/Lock System Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add collectible keys, lockable doors/chests, and a click-to-unlock cursor flow to the dungeon.

**Architecture:** Keys are walk-over pickups (same pattern as tickets). Doors/chests get an `@export var locked` toggle. A lock icon replaces the press-E prompt when locked. Players click a key UI button to enter key-cursor mode, then click a locked item to unlock it (consuming one key). GameState tracks key count.

**Tech Stack:** Godot 4.6, GDScript, existing tile_entities marker system, outline_glow shader.

**Prerequisite — Asset Export (manual, done by user):**
The user must export from Aseprite before implementation begins:
- `Key.aseprite` → export tagged frames:
  - Pickup idle tag → horizontal spritesheet to `service-suspended-episode-2/assets/sprites/pickups/key/key_pickup_float.png`
  - First frame of idle → single image to `service-suspended-episode-2/assets/sprites/pickups/key/key_spawn_marker.png` (16x32 marker tile)
  - Inventory icon tag → single image to `service-suspended-episode-2/assets/ui/key_icon.png`
  - Cursor tag → single image to `service-suspended-episode-2/assets/ui/cursor/key_cursor.png`
- `Lock-Icon.aseprite` → export tagged frames:
  - "locked" tag → individual PNGs to `service-suspended-episode-2/assets/sprites/ui/lock/lock_locked_N.png` (N = frame number, or single PNG if 1 frame)
  - "opening" tag → individual PNGs to `service-suspended-episode-2/assets/sprites/ui/lock/lock_opening_N.png`
  - "unlocked" tag → individual PNGs to `service-suspended-episode-2/assets/sprites/ui/lock/lock_unlocked_N.png`

After export, the user tells Claude the frame counts and dimensions for each tag.

---

### Task 1: GameState — Add Key Tracking

**Files:**
- Modify: `service-suspended-episode-2/scripts/game_state.gd`

**Step 1: Add key state and signals**

Add after the `signal player_died` line (line 8):

```gdscript
signal key_collected(current: int)
```

Add after `var dungeon_seed: int = 0` (line 15):

```gdscript
var keys_collected: int = 0
```

**Step 2: Add collect_key and use_key functions**

Add after the `collect_ticket()` function (after line 60):

```gdscript
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

**Step 3: Reset keys in reset() and on_player_death flow**

In `reset()` (line 73), add `keys_collected = 0` after `tickets_collected = 0`.

**Step 4: Verify** — Run the game, confirm no errors on startup. GameState autoload loads cleanly.

**Step 5: Commit** — `feat: add key tracking to GameState`

---

### Task 2: Key Pickup Scene and Script

**Files:**
- Create: `service-suspended-episode-2/scenes/pickups/key_pickup.gd`
- Create: `service-suspended-episode-2/scenes/pickups/key_pickup.tscn`

**Depends on:** Task 1 (GameState.collect_key exists), asset export complete (key_pickup_float.png available)

**Step 1: Write key_pickup.gd**

Follow ticket_pickup.gd pattern exactly. File: `scenes/pickups/key_pickup.gd`

```gdscript
extends Area2D

@export var collision_size := Vector2(12, 12)
@export var collision_offset := Vector2(0, 0)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _col: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	_col.shape = _col.shape.duplicate()
	(_col.shape as RectangleShape2D).size = collision_size
	_col.position = collision_offset
	collision_layer = 4
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	_start_glow_pulse()

func _start_glow_pulse() -> void:
	var mat = sprite.material as ShaderMaterial
	if not mat or not mat.get_shader_parameter("glow_enabled"):
		return
	var tween = create_tween().set_loops()
	tween.tween_property(mat, "shader_parameter/glow_alpha", 0.3, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(mat, "shader_parameter/glow_alpha", 0.7, 0.8).set_trans(Tween.TRANS_SINE)

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		set_deferred("monitoring", false)
		GameState.collect_key()
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.15)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.15)
		tween.tween_callback(queue_free)
```

**Step 2: Build key_pickup.tscn**

This scene mirrors ticket_pickup.tscn structure. The exact frame count and dimensions depend on the exported spritesheet — the user must provide these after export. The structure:

- Root: `Area2D` named `KeyPickup`, script = `key_pickup.gd`
- Child: `AnimatedSprite2D` — position `(0, -8)`, `texture_filter = 0` (nearest), ShaderMaterial with `outline_glow.gdshader` (glow_enabled=true, glow_color=white, glow_alpha=0.6, outline_width=1.0). SpriteFrames with "float" animation from key_pickup_float.png spritesheet (AtlasTexture regions, 16px wide per frame, looped, speed ~10.0)
- Child: `CollisionShape2D` — RectangleShape2D size 12x12

**Note:** The .tscn file construction requires knowing the frame count and sprite dimensions from the exported PNG. Claude should read the imported PNG dimensions at build time to compute AtlasTexture regions.

**Step 3: Verify** — Place a key_pickup instance in a test section, run the game, walk over it, confirm it plays the glow/collect animation and GameState.keys_collected increments.

**Step 4: Commit** — `feat: add key pickup scene and script`

---

### Task 3: Register Key Pickup in Tile Entities

**Files:**
- Modify: `service-suspended-episode-2/assets/tilesets/dungeon/item_spawn_markers.tres`
- Modify: `service-suspended-episode-2/scenes/floors/shared/tile_entities.gd`

**Depends on:** Task 2, asset export (key_spawn_marker.png available)

**Step 1: Add key marker tile to item_spawn_markers.tres**

The current tileset has source 0 = ticket marker (16x32, one tile at 0:0). We need to add the key marker as a second tile in the same atlas source OR as a new source.

Option A (same atlas — preferred if key_spawn_marker.png is also 16x32): Add the key marker PNG as a new atlas source (source 1) in the .tres file. This keeps sources independent.

Add to item_spawn_markers.tres:
```
[ext_resource type="Texture2D" path="res://assets/sprites/pickups/key/key_spawn_marker.png" id="2_key"]

[sub_resource type="TileSetAtlasSource" id="2"]
texture = ExtResource("2_key")
texture_region_size = Vector2i(16, 32)
0:0/0 = 0

# Add under [resource]:
sources/1 = SubResource("2")
```

**Step 2: Register in tile_entities.gd**

Add after the ticket pickup entry (line 28):

```gdscript
# Key pickups (scanned from Items layer — source 1 in item_spawn_markers.tres)
{ "source": 1, "marker": Vector2i(0, 0), "scene": preload("res://scenes/pickups/key_pickup.tscn"), "size": Vector2i(1, 1), "layer": "items" },
```

**Step 3: Verify** — Paint a key marker tile in a section's Items layer in the Godot editor, run the game, confirm the key pickup spawns at the painted location.

**Step 4: Commit** — `feat: register key pickup in tile entities system`

---

### Task 4: Lock Prompt Scene

**Files:**
- Create: `service-suspended-episode-2/scenes/ui/lock_prompt.tscn`

**Depends on:** Asset export (lock PNGs available)

**Step 1: Build lock_prompt.tscn**

Follows press_e_prompt.tscn pattern. Root: `AnimatedSprite2D` named `LockPrompt`.

Properties:
- `z_index = 20`, `z_as_relative = false`
- `texture_filter = 1` (linear)
- `visible = false`

SpriteFrames with 3 animations:
- `"locked"` — locked tag frames, looped, speed 4.0
- `"opening"` — opening tag frames, NOT looped, speed 8.0
- `"unlocked"` — unlocked tag frames, NOT looped, speed 8.0

Autoplay = `"locked"`.

**Note:** Exact frame setup depends on exported PNGs. Each animation uses ExtResource PNGs (individual frames, like press_e_prompt uses press_e1-8.png).

**Step 2: Verify** — Instance the scene in the editor, preview animations in the SpriteFrames panel.

**Step 3: Commit** — `feat: add lock prompt scene`

---

### Task 5: Door Lock Integration

**Files:**
- Modify: `service-suspended-episode-2/scenes/doors/door.gd`
- Modify: `service-suspended-episode-2/scenes/doors/door_wood.tscn`
- Modify: `service-suspended-episode-2/scenes/doors/door_cell.tscn`
- Modify: `service-suspended-episode-2/scenes/doors/door_framed_wood.tscn`
- Modify: `service-suspended-episode-2/scenes/doors/door_framed_cell.tscn`

**Depends on:** Task 4 (lock_prompt.tscn exists)

**Step 1: Update door.gd**

Add export and onready vars:

```gdscript
@export var locked: bool = false

@onready var _lock_prompt: AnimatedSprite2D = $Area2D/LockPrompt
```

In `_ready()`, after existing setup, add:

```gdscript
if locked:
	_lock_prompt.visible = true
	_lock_prompt.play("locked")
	_prompt.visible = false
```

In `_input()`, guard interaction when locked:

```gdscript
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _player_nearby:
		if locked:
			return
		if _open:
			_close_door()
		else:
			_open_door()
```

Add unlock function:

```gdscript
func unlock() -> void:
	locked = false
	_lock_prompt.play("opening")
	await _lock_prompt.animation_finished
	_lock_prompt.visible = false
	_prompt.visible = true
```

**Step 2: Add LockPrompt instance to all 4 door .tscn files**

In each door scene, add as a child of the Area2D node (sibling of PressEPrompt):

```
[node name="LockPrompt" parent="Area2D" instance=ExtResource("X_lock")]
position = Vector2(0, -33)  ; same position as PressEPrompt for wood/cell doors
                             ; (0, -25) for framed doors — adjust to match PressEPrompt position
```

Each .tscn needs an ext_resource for `res://scenes/ui/lock_prompt.tscn`.

**Step 3: Verify** — Set `locked = true` on a door instance in the editor, run the game, confirm lock icon shows instead of press-E, and E press does nothing.

**Step 4: Commit** — `feat: add lock support to doors`

---

### Task 6: Chest Lock Integration

**Files:**
- Modify: `service-suspended-episode-2/scenes/interactables/chest.gd`
- Modify: `service-suspended-episode-2/scenes/interactables/chest.tscn`

**Depends on:** Task 4 (lock_prompt.tscn exists)

**Step 1: Update chest.gd**

Same pattern as door.gd. Add:

```gdscript
@export var locked: bool = false

@onready var _lock_prompt: AnimatedSprite2D = $Area2D/LockPrompt
```

In `_ready()`, after existing setup:

```gdscript
if locked:
	_lock_prompt.visible = true
	_lock_prompt.play("locked")
	_prompt.visible = false
```

In `_input()`, guard interaction:

```gdscript
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _player_nearby:
		if locked:
			return
		if _open:
			_close_chest()
		else:
			_open_chest()
```

Add unlock function:

```gdscript
func unlock() -> void:
	locked = false
	_lock_prompt.play("opening")
	await _lock_prompt.animation_finished
	_lock_prompt.visible = false
	_prompt.visible = true
```

**Step 2: Add LockPrompt instance to chest.tscn**

Add ext_resource for lock_prompt.tscn, then:

```
[node name="LockPrompt" parent="Area2D" instance=ExtResource("X_lock")]
position = Vector2(0, -21)  ; same as PressEPrompt position in chest
```

**Step 3: Verify** — Set `locked = true` on a chest, run the game, confirm lock icon shows and chest can't be opened.

**Step 4: Commit** — `feat: add lock support to chests`

---

### Task 7: Key UI Button and Cursor Mode in Floor

**Files:**
- Modify: `service-suspended-episode-2/scenes/floors/shared/floor.gd`
- Modify: `service-suspended-episode-2/scenes/floors/floor_1/floor_1.tscn`
- Modify: `service-suspended-episode-2/scenes/floors/floor_2/floor_2.tscn`

**Depends on:** Tasks 1, 5, 6 (GameState key tracking, door/chest unlock() method)

**Step 1: Add KeyButton to both floor .tscn files**

In UILayer, add after PunchButton:

```
[ext_resource type="Texture2D" path="res://assets/ui/key_icon.png" id="X_key"]

[node name="KeyButton" type="TextureButton" parent="UILayer"]
visible = false
offset_left = 1017.0
offset_top = 100.0
offset_right = 1107.0
offset_bottom = 190.0
texture_normal = ExtResource("X_key")
ignore_texture_size = true
stretch_mode = 0
```

Position above PunchButton (top=100, bottom=190). Starts invisible (shown when keys > 0).

**Step 2: Add key cursor mode to floor.gd**

Add preload for key cursor texture:

```gdscript
var _key_cursor = preload("res://assets/ui/cursor/key_cursor.png")
```

Add node reference:

```gdscript
@onready var key_btn: TextureButton = $UILayer/KeyButton
```

Add state var:

```gdscript
var key_mode: bool = false
```

In `_ready()`, connect signals:

```gdscript
key_btn.pressed.connect(_on_key_pressed)
GameState.key_collected.connect(_on_key_collected)
```

In `_exit_tree()`, disconnect:

```gdscript
if GameState.key_collected.is_connected(_on_key_collected):
	GameState.key_collected.disconnect(_on_key_collected)
```

**Step 3: Add key mode handlers**

```gdscript
func _on_key_pressed() -> void:
	if is_animating:
		return
	key_mode = not key_mode
	if key_mode:
		punch_mode = false  # exit punch mode if active
	cursor_sprite.texture = _key_cursor if key_mode else _cursor_default

func _on_key_collected(_current: int) -> void:
	key_btn.visible = GameState.keys_collected > 0
	if GameState.keys_collected <= 0 and key_mode:
		key_mode = false
		cursor_sprite.texture = _cursor_default
```

**Step 4: Update _input for key cursor mode**

Update the cursor texture swap logic in `_input()`:

```gdscript
if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
	if event.pressed:
		if punch_mode:
			cursor_sprite.texture = _punch_cursor_closed
		elif key_mode:
			cursor_sprite.texture = _key_cursor  # or a clicked variant
		else:
			cursor_sprite.texture = _cursor_clicked
	else:
		if punch_mode:
			cursor_sprite.texture = _punch_cursor_open
		elif key_mode:
			cursor_sprite.texture = _key_cursor
		else:
			cursor_sprite.texture = _cursor_default
```

Add Escape to cancel key mode:

```gdscript
if event.is_action_pressed("ui_cancel") and key_mode:
	key_mode = false
	cursor_sprite.texture = _cursor_default
```

**Step 5: Add click-to-unlock detection**

In `_input()`, after the punch-click block, add:

```gdscript
# Key-click on locked items
if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
	if key_mode and not is_animating:
		_try_key_unlock()
```

Add the unlock method:

```gdscript
func _try_key_unlock() -> void:
	var mouse_world = player.get_global_mouse_position()
	var space = player.get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = mouse_world
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 0xFFFFFFFF  # check all layers
	var results = space.intersect_point(query, 32)

	for result in results:
		var collider = result.collider
		if collider is Area2D:
			var parent = collider.get_parent()
			if parent.has_method("unlock") and parent.get("locked") == true:
				if GameState.use_key():
					parent.unlock()
					key_mode = false
					cursor_sprite.texture = _cursor_default
				return
```

**Step 6: Verify** — Pick up a key, confirm KeyButton appears. Click KeyButton, confirm cursor changes. Click a locked door, confirm it unlocks and key is consumed. Press Escape, confirm key mode cancels.

**Step 7: Commit** — `feat: add key UI button and click-to-unlock cursor mode`

---

### Task 8: Reset Keys on Death/Reload

**Files:**
- Modify: `service-suspended-episode-2/scenes/floors/shared/floor.gd`

**Depends on:** Task 7

**Step 1: Update key UI on floor load**

In `_ready()`, after `_update_ticket_count_display()`, add:

```gdscript
key_btn.visible = GameState.keys_collected > 0
```

**Step 2: Reset keys on death reload**

In `_on_death_reload()`, add after `GameState.tickets_collected = 0`:

```gdscript
GameState.keys_collected = 0
```

**Step 3: Verify** — Die with keys, confirm keys reset. Respawn, confirm KeyButton hidden.

**Step 4: Commit** — `feat: reset keys on death/reload`

---

## Task Dependency Graph

```
Task 1 (GameState) ─────────────────────────┐
                                             │
Asset Export (manual) ──┬── Task 2 (Key Pickup) ── Task 3 (Tile Entities)
                        │
                        └── Task 4 (Lock Prompt) ──┬── Task 5 (Door Lock)
                                                    │
                                                    └── Task 6 (Chest Lock)
                                                              │
Tasks 1,5,6 ────────────────────────────────── Task 7 (Floor UI + Cursor)
                                                              │
                                                     Task 8 (Death Reset)
```

Tasks 1 and 4 can run in parallel. Tasks 5 and 6 can run in parallel after Task 4.
