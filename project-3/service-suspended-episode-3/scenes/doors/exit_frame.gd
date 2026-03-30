extends Node2D

signal exit_used

var _unlocked: bool = false
var _player_nearby: bool = false

@onready var _area: Area2D = $Area2D
@onready var _prompt: AnimatedSprite2D = $Area2D/PressEPrompt
@onready var _lock_prompt: AnimatedSprite2D = $Area2D/LockPrompt

func _ready() -> void:
	_area.body_entered.connect(_on_zone_entered)
	_area.body_exited.connect(_on_zone_exited)
	_prompt.visible = false
	_lock_prompt.visible = false
	GameState.all_special_tickets_collected.connect(_on_special_unlock)
	if GameState.special_tickets_collected >= GameState.special_tickets_required:
		_unlocked = true
	add_to_group("special_exit")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _player_nearby:
		if _unlocked:
			_activate_exit()
		else:
			_show_dialog("This door needs all %d golden tickets. You have %d." % [GameState.special_tickets_required, GameState.special_tickets_collected])

func _on_zone_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player_nearby = true
		if _unlocked:
			_prompt.visible = true
		else:
			_lock_prompt.visible = true
			_lock_prompt.play("locked")

func _on_zone_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player_nearby = false
		_prompt.visible = false
		_lock_prompt.visible = false

func _on_special_unlock() -> void:
	_unlocked = true
	_lock_prompt.play("opening")
	await _lock_prompt.animation_finished
	_lock_prompt.visible = false
	if _player_nearby:
		_prompt.visible = true

func _activate_exit() -> void:
	set_process_input(false)
	_prompt.visible = false
	_swap_to_lit_tiles()
	await get_tree().create_timer(0.8).timeout
	exit_used.emit()

func _swap_to_lit_tiles() -> void:
	# Walk up tree to find the DungeonSection parent
	var section: DungeonSection = null
	var node = get_parent()
	while node:
		if node is DungeonSection:
			section = node
			break
		node = node.get_parent()
	if not section:
		return
	var walls = section.get_bottom_walls()
	if not walls:
		return
	# Convert global_position to tilemap cell
	var local_pos = walls.to_local(global_position)
	var center_cell = walls.local_to_map(local_pos)
	# Swap 3x2 grid (offsets -1,-1 to +1,0) by adding +3 to atlas Y
	for dx in range(-1, 2):
		for dy in range(-1, 1):
			var cell = center_cell + Vector2i(dx, dy)
			var src = walls.get_cell_source_id(cell)
			if src < 0:
				continue
			var atlas = walls.get_cell_atlas_coords(cell)
			walls.set_cell(cell, src, atlas + Vector2i(0, 3))

func _show_dialog(text: String) -> void:
	var bubbles = get_tree().get_nodes_in_group("dialog_bubble")
	if bubbles.size() > 0:
		bubbles[0].show_text(text, "You")

func _exit_tree() -> void:
	if GameState.all_special_tickets_collected.is_connected(_on_special_unlock):
		GameState.all_special_tickets_collected.disconnect(_on_special_unlock)
