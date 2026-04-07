extends Area2D

## Desk clock interactable — found on furniture in room variant 1.
## Press E: picks up clock (adds to inventory), shows close-up UI.
## After pickup, this interactable disables itself.

@onready var _prompt: AnimatedSprite2D = $PressEPrompt

var _player_in_range: bool = false
var _picked_up: bool = false
var _ui_open: bool = false
var _clock_ui_scene = preload("res://scenes/ui/clock_ui.tscn")
var _loading_screen_scene = preload("res://scenes/ui/loading_screen.tscn")
var _clock_ui: CanvasLayer = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# If clock already collected, hide this pickup
	if GameState.has_clock:
		_picked_up = true
		visible = false
		set_deferred("monitoring", false)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" and not _picked_up:
		_player_in_range = true
		_prompt.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		_player_in_range = false
		_prompt.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and not _picked_up and not _ui_open and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_pickup_clock()

func _pickup_clock() -> void:
	_picked_up = true
	_prompt.visible = false
	GameState.collect_clock()
	# Erase the clock tiles from the tilemap so it disappears from the desk
	_erase_source_tiles()
	_show_ui()

func _erase_source_tiles() -> void:
	# Find the Furniture layers and erase the clock tile at our position
	var room_section = get_tree().root.find_child("RoomSection", true, false)
	if room_section == null:
		return
	for child in room_section.get_children():
		if child is TileMapLayer:
			var ts = child.tile_set
			if ts == null:
				continue
			var tile_size = Vector2(ts.tile_size)
			# Check cells near our position
			for cell in child.get_used_cells():
				var cell_atlas = child.get_cell_atlas_coords(cell)
				if cell_atlas == Vector2i(31, 37):
					child.erase_cell(cell)

func _show_ui() -> void:
	_ui_open = true
	get_tree().paused = true
	_clock_ui = _clock_ui_scene.instantiate()
	_clock_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	_clock_ui.clock_closed.connect(_close_ui)
	_clock_ui.variant_selected.connect(_on_variant_selected)
	get_tree().root.add_child(_clock_ui)

func _close_ui() -> void:
	_ui_open = false
	get_tree().paused = false
	if _clock_ui:
		_clock_ui.queue_free()
		_clock_ui = null
	# Disable this interactable after pickup
	visible = false
	set_deferred("monitoring", false)

func _on_variant_selected(variant: int) -> void:
	_close_ui()
	GameState.current_variant = variant
	var scene_path = "res://escape_room_%d.tscn" % variant
	var loading = _loading_screen_scene.instantiate()
	loading.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(loading)
	loading.transition_to(scene_path)
