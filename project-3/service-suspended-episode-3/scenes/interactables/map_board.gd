extends Area2D

## Map board on the wall. Tracks tile states based on collected/assembled pieces.
## Tile states (source 1, Furniture layer):
##   Empty:        (44,28)(45,28)(44,29)(45,29)
##   Piece loaded: piece1→(44,25) piece2→(45,25) piece3→(44,26) piece4→(45,26)
##   Assembled:    (44,22)(45,22)(44,23)(45,23)

@onready var _prompt: AnimatedSprite2D = $PressEPrompt

var _player_in_range: bool = false
var _ui_open: bool = false
var _board_ui_scene = preload("res://scenes/ui/map_board_ui.tscn")
var _board_ui: CanvasLayer = null

const TILE_SOURCE = 1

# Map from piece_id (1-4) to tile coords: [map_cell, empty_atlas, loaded_atlas, final_atlas]
const PIECE_TILES = {
	1: {"empty": Vector2i(44, 28), "loaded": Vector2i(44, 25), "final": Vector2i(44, 22)},
	2: {"empty": Vector2i(45, 28), "loaded": Vector2i(45, 25), "final": Vector2i(45, 22)},
	3: {"empty": Vector2i(44, 29), "loaded": Vector2i(44, 26), "final": Vector2i(44, 23)},
	4: {"empty": Vector2i(45, 29), "loaded": Vector2i(45, 26), "final": Vector2i(45, 23)},
}

var _tile_layer: TileMapLayer = null
var _board_cells: Dictionary = {}  # piece_id -> map cell position

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_find_board_tiles()
	_update_board_tiles()

func _find_board_tiles() -> void:
	var room_section = get_tree().root.find_child("RoomSection", true, false)
	if room_section == null:
		return
	# Find the Furniture layer with our board tiles
	for child in room_section.get_children():
		if child is TileMapLayer and child.name == "Furniture":
			_tile_layer = child
			break
	if _tile_layer == null:
		return
	# Find the map cells that correspond to each piece's empty atlas coords
	for cell in _tile_layer.get_used_cells():
		var src = _tile_layer.get_cell_source_id(cell)
		var atlas = _tile_layer.get_cell_atlas_coords(cell)
		if src != TILE_SOURCE:
			continue
		for piece_id in PIECE_TILES:
			var info = PIECE_TILES[piece_id]
			if atlas == info["empty"] or atlas == info["loaded"] or atlas == info["final"]:
				_board_cells[piece_id] = cell

func _update_board_tiles() -> void:
	if _tile_layer == null:
		return
	for piece_id in PIECE_TILES:
		if not _board_cells.has(piece_id):
			continue
		var cell = _board_cells[piece_id]
		var info = PIECE_TILES[piece_id]
		var target_atlas: Vector2i
		if GameState.map_assembled:
			target_atlas = info["final"]
		elif piece_id in GameState.board_pieces:
			target_atlas = info["loaded"]
		else:
			target_atlas = info["empty"]
		_tile_layer.set_cell(cell, TILE_SOURCE, target_atlas)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		_player_in_range = true
		_prompt.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		_player_in_range = false
		_prompt.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and not _ui_open and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_open_ui()

func _open_ui() -> void:
	_ui_open = true
	_prompt.visible = false
	# Move all collected pieces to the board
	for piece_id in GameState.collected_map_pieces:
		if piece_id not in GameState.board_pieces:
			GameState.board_pieces.append(piece_id)
	# Remove map icon from inventory
	var coordinator = get_tree().root.find_child("Node2D", true, false)
	if coordinator and coordinator.has_method("remove_item"):
		coordinator.remove_item("map")
	_update_board_tiles()
	get_tree().paused = true
	_board_ui = _board_ui_scene.instantiate()
	_board_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	_board_ui.board_closed.connect(_close_ui)
	get_tree().root.add_child(_board_ui)

func _close_ui() -> void:
	_ui_open = false
	get_tree().paused = false
	var coordinator = get_tree().root.find_child("Node2D", true, false)
	if coordinator and coordinator.has_method("stop_pulse"):
		coordinator.stop_pulse("clock")
	if _board_ui:
		_board_ui.queue_free()
		_board_ui = null
	_update_board_tiles()
	if _player_in_range:
		_prompt.visible = true
