# Checkpoint, Respawn & ESC Cancellation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add checkpoint-based respawn (no scene reload, costs 1 ticket), full ESC cancellation stack for key cursor and floating ticket, and checkpoint state to GameState.

**Architecture:** GameState gains checkpoint position/signal. floor.gd respawn rewired to teleport-in-place instead of scene reload. ESC input handler gains layered cancellation. Saving icon integration deferred until user exports Aseprite assets.

**Tech Stack:** Godot 4.6, GDScript

---

### Task 1: Add Checkpoint State to GameState

**Files:**
- Modify: `service-suspended-episode-2/scripts/game_state.gd`

**Step 1: Add checkpoint variables and signal**

Add after line 10 (`signal key_mode_changed`):
```gdscript
signal checkpoint_set(position: Vector2, section: String)
```

Add after line 19 (`var key_mode: bool = false`):
```gdscript
var checkpoint_position: Vector2 = Vector2.ZERO
var checkpoint_section: String = ""
```

**Step 2: Add set_checkpoint function**

Add after `set_key_mode()` (after line 79):
```gdscript
func set_checkpoint(pos: Vector2, section: String = "") -> void:
	checkpoint_position = pos
	checkpoint_section = section
	checkpoint_set.emit(pos, section)
```

**Step 3: Reset checkpoint in reset()**

Add to `reset()` function body (after line 100 `current_floor = 1`):
```gdscript
	checkpoint_position = Vector2.ZERO
	checkpoint_section = ""
```

**Step 4: Commit**
```
feat: add checkpoint state and signal to GameState
```

---

### Task 2: Set Checkpoint on Floor Entry

**Files:**
- Modify: `service-suspended-episode-2/scenes/floors/shared/floor.gd`

**Step 1: Set initial checkpoint at end of _ready()**

Add at the end of `_ready()` (after line 140):
```gdscript
	# Set initial checkpoint at player spawn position
	GameState.set_checkpoint(player.global_position, _current_section_key)
```

**Step 2: Update checkpoint on section boundary entry**

Modify `_on_boundary_entered()` (line 177-179) to also set checkpoint:
```gdscript
func _on_boundary_entered(body: Node2D, section_key: String) -> void:
	if body == player:
		_current_section_key = section_key
		GameState.set_checkpoint(player.global_position, section_key)
```

**Step 3: Commit**
```
feat: set checkpoint on floor entry and section transitions
```

---

### Task 3: Rewrite Respawn to Teleport Instead of Reload

**Files:**
- Modify: `service-suspended-episode-2/scenes/floors/shared/floor.gd`

**Step 1: Replace _on_death_respawn()**

Replace the entire `_on_death_respawn()` function (lines 390-409) with:
```gdscript
func _on_death_respawn(death_screen: CanvasLayer) -> void:
	death_screen.queue_free()
	# Deduct 1 ticket
	GameState.tickets_collected = maxi(GameState.tickets_collected - 1, 0)
	_update_ticket_count_display()
	# Teleport player to checkpoint
	player.global_position = GameState.checkpoint_position
	# Re-enable player
	_dead = false
	player.visible = true
	player.collision_layer = 1
	player.collision_mask = 1
	player.set_physics_process(true)
```

**Step 2: Disable respawn button when player has 0 tickets**

In `_on_player_died()` (line 368), after instantiating the death screen and connecting signals, add:
```gdscript
	if GameState.tickets_collected <= 0:
		death.respawn_btn.disabled = true
		death.respawn_btn.modulate = Color(1, 1, 1, 0.4)
```

This goes after line 379 (`death.respawn_requested.connect(...)`).

**Step 3: Verify reload still works unchanged**

`_on_death_reload()` (lines 381-388) stays as-is — full scene reload with variant re-randomization.

**Step 4: Commit**
```
feat: respawn teleports to checkpoint instead of reloading scene
```

---

### Task 4: ESC Cancellation Stack

**Files:**
- Modify: `service-suspended-episode-2/scenes/floors/shared/floor.gd`

**Step 1: Add _cancel_floating_ticket() helper**

Add after `_fly_in_ticket()` (after line 244):
```gdscript
func _cancel_floating_ticket() -> void:
	if not flying_ticket.visible or is_animating:
		return
	is_animating = true
	var tween = create_tween()
	tween.tween_property(flying_ticket, "modulate:a", 0.0, 0.3)
	await tween.finished
	flying_ticket.visible = false
	flying_ticket.modulate = Color.WHITE
	punch_mode = false
	cursor_sprite.texture = _cursor_default
	is_animating = false
```

**Step 2: Replace the ESC handling in _input()**

Replace line 171-172:
```gdscript
	if event.is_action_pressed("ui_cancel") and GameState.key_mode:
		GameState.set_key_mode(false)
```

With the full ESC stack:
```gdscript
	if event.is_action_pressed("ui_cancel"):
		if GameState.key_mode:
			GameState.set_key_mode(false)
			# Restore punch cursor if ticket is floating, else default
			if punch_mode and flying_ticket.visible:
				cursor_sprite.texture = _punch_cursor_open
			else:
				cursor_sprite.texture = _cursor_default
		elif flying_ticket.visible and not is_animating:
			_cancel_floating_ticket()
```

**Step 3: Make ticket button click cancel floating ticket**

Modify `_on_ticket_pressed()` (lines 230-234). Replace:
```gdscript
func _on_ticket_pressed() -> void:
	var remaining = GameState.tickets_required - GameState.tickets_collected
	if is_animating or remaining <= 0 or flying_ticket.visible:
		return
	_fly_in_ticket()
```

With:
```gdscript
func _on_ticket_pressed() -> void:
	if is_animating:
		return
	if flying_ticket.visible:
		_cancel_floating_ticket()
		return
	var remaining = GameState.tickets_required - GameState.tickets_collected
	if remaining <= 0:
		return
	_fly_in_ticket()
```

**Step 4: Commit**
```
feat: ESC cancellation stack — key cursor, then floating ticket
```

---

### Task 5: Saving Icon Placeholder (Signal Wiring)

**Files:**
- Modify: `service-suspended-episode-2/scenes/floors/shared/floor.gd`

**Step 1: Wire up checkpoint_set signal for future saving icon**

Add to `_ready()` after the checkpoint set (after the line added in Task 2):
```gdscript
	GameState.checkpoint_set.connect(_on_checkpoint_set)
```

Add the handler function:
```gdscript
func _on_checkpoint_set(_pos: Vector2, _section: String) -> void:
	# TODO: play saving icon animation on UI layer
	# Will be wired to user's Aseprite-exported saving icon scene
	print("[Checkpoint] saved at section: ", _section)
```

Add cleanup in `_exit_tree()` (after line 433):
```gdscript
	if GameState.checkpoint_set.is_connected(_on_checkpoint_set):
		GameState.checkpoint_set.disconnect(_on_checkpoint_set)
```

**Step 2: Commit**
```
feat: wire checkpoint_set signal with placeholder for saving icon
```

---

### Summary of Changes

| File | What Changes |
|------|-------------|
| `game_state.gd` | +checkpoint_position, +checkpoint_section, +checkpoint_set signal, +set_checkpoint() |
| `floor.gd` | checkpoint set on _ready + section entry, respawn = teleport, ESC stack, ticket cancel, saving icon placeholder |
| `death_screen.gd` | No changes (respawn button disabling handled from floor.gd) |

### Not Implemented (User Action Required)
- Export saving icon from Aseprite → create scene → replace print placeholder
- Export updated death screen from Aseprite → replace existing death_screen.tscn
- Export updated loading screen from Aseprite → replace existing loading_screen.tscn
- Section transition Area2D zones (after static connector pieces are designed)
