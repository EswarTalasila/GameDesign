# Key Cursor Click-to-Unlock Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enable clicking locked doors/chests with the key cursor to unlock them, fix the locked chest marker bug, and add a 0.3s delay before showing the Press E prompt after unlock.

**Architecture:** Move `key_mode` state to `GameState` singleton so entities can read it. Door and chest entities detect clicks on their Area2D via `input_event` signal — only fires when the click lands on the collision shape. Floor.gd reacts to `key_mode` changes via a new signal to reset cursor texture. Remove the old floor-side `_try_key_unlock()` physics query.

**Tech Stack:** Godot 4.6, GDScript

---

### Task 1: Fix locked chest marker coordinates

**Files:**
- Modify: `service-suspended-episode-2/scenes/floors/shared/tile_entities.gd:29`

**Step 1: Fix the atlas coordinate**

Change `Vector2i(15, 3)` to `Vector2i(14, 3)` on line 29:

```gdscript
# Before:
{ "source": 2, "marker": Vector2i(15, 3), "scene": preload("res://scenes/interactables/chest.tscn"), "size": Vector2i(3, 2), "props": { "locked": true } },

# After:
{ "source": 2, "marker": Vector2i(14, 3), "scene": preload("res://scenes/interactables/chest.tscn"), "size": Vector2i(3, 2), "props": { "locked": true } },
```

**Step 2: Commit**

```
fix: correct locked chest marker atlas coords from (15,3) to (14,3)
```

---

### Task 2: Add key_mode to GameState

**Files:**
- Modify: `service-suspended-episode-2/scripts/game_state.gd`

**Step 1: Add key_mode state and signal**

After line 9 (`signal key_collected(current: int)`), add:

```gdscript
signal key_mode_changed(active: bool)
```

After line 17 (`var keys_collected: int = 0`), add:

```gdscript
var key_mode: bool = false
```

Add a setter function after `use_key()` (after line 73):

```gdscript
func set_key_mode(active: bool) -> void:
	key_mode = active
	key_mode_changed.emit(active)
```

In `reset()` (line 86), add `key_mode = false` after `keys_collected = 0`.

**Step 2: Commit**

```
feat: add key_mode state and signal to GameState
```

---

### Task 3: Update floor.gd to use GameState.key_mode

**Files:**
- Modify: `service-suspended-episode-2/scenes/floors/shared/floor.gd`

**Step 1: Remove local key_mode and wire up GameState.key_mode**

Remove `var key_mode: bool = false` from line 58.

In `_ready()` (after line 138 where `GameState.key_collected` is connected), add:

```gdscript
GameState.key_mode_changed.connect(_on_key_mode_changed)
```

In `_exit_tree()`, add disconnect:

```gdscript
if GameState.key_mode_changed.is_connected(_on_key_mode_changed):
	GameState.key_mode_changed.disconnect(_on_key_mode_changed)
```

**Step 2: Replace all `key_mode` references with `GameState.key_mode`**

In `_input()` (lines 160-196), replace every `key_mode` with `GameState.key_mode`:

```gdscript
func _input(event: InputEvent) -> void:
	if _dead:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if punch_mode:
				cursor_sprite.texture = _punch_cursor_closed
			elif GameState.key_mode:
				cursor_sprite.texture = _key_cursor_click
			else:
				cursor_sprite.texture = _cursor_clicked
		else:
			if punch_mode:
				cursor_sprite.texture = _punch_cursor_open
			elif GameState.key_mode:
				cursor_sprite.texture = _key_cursor
			else:
				cursor_sprite.texture = _cursor_default

	# Punch-click on the floating ticket
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if punch_mode and flying_ticket.visible and not is_animating:
			var click = get_viewport().get_mouse_position()
			var ticket_pos = flying_ticket.get_global_transform_with_canvas().origin
			if click.distance_to(ticket_pos) < 100:
				_punch_ticket()

	# Cancel key mode with Escape
	if event.is_action_pressed("ui_cancel") and GameState.key_mode:
		GameState.set_key_mode(false)

	# Exit door interaction
	if event.is_action_pressed("interact") and _near_exit_door and not _exit_door_data.is_empty():
		_use_exit_door()
```

Note: The key-click block (`lines 181-183` with `_try_key_unlock()`) is **removed entirely** — entities handle clicks now.

**Step 3: Update `_on_key_pressed()`**

```gdscript
func _on_key_pressed() -> void:
	if is_animating:
		return
	GameState.set_key_mode(not GameState.key_mode)
	if GameState.key_mode:
		punch_mode = false
	cursor_sprite.texture = _key_cursor if GameState.key_mode else _cursor_default
```

**Step 4: Update `_on_key_collected()`**

```gdscript
func _on_key_collected(_current: int) -> void:
	key_btn.visible = GameState.keys_collected > 0
	if GameState.keys_collected <= 0 and GameState.key_mode:
		GameState.set_key_mode(false)
```

**Step 5: Update `_on_punch_pressed()` to disable key mode**

```gdscript
func _on_punch_pressed() -> void:
	if is_animating:
		return
	punch_mode = not punch_mode
	if punch_mode:
		GameState.set_key_mode(false)
	cursor_sprite.texture = _punch_cursor_open if punch_mode else _cursor_default
```

**Step 6: Add `_on_key_mode_changed()` handler**

This resets cursor when entities disable key_mode after unlocking:

```gdscript
func _on_key_mode_changed(active: bool) -> void:
	if not active:
		cursor_sprite.texture = _cursor_default
	else:
		cursor_sprite.texture = _key_cursor
```

**Step 7: Remove `_try_key_unlock()` function entirely (lines 262-281)**

Delete the entire function — entities now handle click-to-unlock.

**Step 8: Commit**

```
refactor: move key_mode to GameState, remove floor-side _try_key_unlock
```

---

### Task 4: Add click-to-unlock to door.gd

**Files:**
- Modify: `service-suspended-episode-2/scenes/doors/door.gd`

**Step 1: Connect Area2D input_event signal in _ready()**

After `$Area2D.body_exited.connect(_on_zone_exited)` (line 17), add:

```gdscript
$Area2D.input_pickable = true
$Area2D.input_event.connect(_on_area_input)
```

**Step 2: Add the click handler**

After the `_on_zone_exited` function, add:

```gdscript
func _on_area_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not locked or not _player_nearby or not GameState.key_mode:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if GameState.use_key():
			unlock()
			GameState.set_key_mode(false)
```

**Step 3: Commit**

```
feat: add click-to-unlock on door Area2D via key cursor
```

---

### Task 5: Add click-to-unlock to chest.gd

**Files:**
- Modify: `service-suspended-episode-2/scenes/interactables/chest.gd`

**Step 1: Connect Area2D input_event signal in _ready()**

After `$Area2D.body_exited.connect(_on_zone_exited)` (line 24), add:

```gdscript
$Area2D.input_pickable = true
$Area2D.input_event.connect(_on_area_input)
```

**Step 2: Add the click handler**

After the `_on_zone_exited` function, add:

```gdscript
func _on_area_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not locked or not _player_nearby or not GameState.key_mode:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if GameState.use_key():
			unlock()
			GameState.set_key_mode(false)
```

**Step 3: Commit**

```
feat: add click-to-unlock on chest Area2D via key cursor
```

---

### Task 6: Add 0.3s delay before Press E prompt after unlock

**Files:**
- Modify: `service-suspended-episode-2/scenes/doors/door.gd:57-63`
- Modify: `service-suspended-episode-2/scenes/interactables/chest.gd:71-77`

**Step 1: Update door.gd unlock()**

```gdscript
func unlock() -> void:
	locked = false
	_lock_prompt.play("opening")
	await _lock_prompt.animation_finished
	_lock_prompt.visible = false
	await get_tree().create_timer(0.3).timeout
	if _player_nearby:
		_prompt.visible = true
```

**Step 2: Update chest.gd unlock()**

```gdscript
func unlock() -> void:
	locked = false
	_lock_prompt.play("opening")
	await _lock_prompt.animation_finished
	_lock_prompt.visible = false
	await get_tree().create_timer(0.3).timeout
	if _player_nearby:
		_prompt.visible = true
```

**Step 3: Commit**

```
feat: add 0.3s delay after lock icon disappears before showing Press E
```

---

### Task 7: Manual testing checklist

Test in Godot editor by running the floor scene:

1. **Locked chest shows lock icon:** Walk up to a locked chest (painted with marker 14,3). Verify spinning lock icon appears, NOT Press E.
2. **Key cursor click-to-unlock (door):** Pick up a key. Click the key button in UI. Cursor changes to key. Walk near a locked door (lock icon shows). Click ON the door. Verify: key consumed, lock opening animation plays, 0.3s pause, then Press E appears.
3. **Key cursor click-to-unlock (chest):** Same flow with a locked chest.
4. **Click off-target does nothing:** With key cursor active near a locked door, click on the wall/floor next to it. Verify nothing happens.
5. **Escape cancels key mode:** Activate key cursor, press Escape. Verify cursor resets to default.
6. **E-key still works:** Walk up to locked door without key cursor, press E with a key. Verify it still unlocks.
7. **Press E delay:** After any unlock, verify the Press E prompt appears ~0.3s after the lock icon disappears, not instantly.
8. **No keys left exits key mode:** Use last key to unlock. Verify key cursor deactivates and key button hides.
