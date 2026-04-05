extends Area2D

## Suitcase with combination lock. Press E to open close-up UI.
## Combo is 0647. When solved, swaps closed tiles for open tiles and gives item.

@onready var _prompt: AnimatedSprite2D = $PressEPrompt

var _player_in_range: bool = false
var _ui_open: bool = false
var _solved: bool = false
var _suitcase_ui_scene = preload("res://scenes/ui/suitcase_ui.tscn")
var _suitcase_ui: CanvasLayer = null

# Closed suitcase atlas coords (3,19)→(5,20) = 3 wide × 2 tall
const CLOSED_ATLAS_MIN = Vector2i(3, 19)
const CLOSED_ATLAS_MAX = Vector2i(5, 20)
# Open suitcase atlas coords (6,17)→(8,20) = 3 wide × 4 tall
const OPEN_ATLAS_MIN = Vector2i(6, 17)
const OPEN_ATLAS_MAX = Vector2i(8, 20)
# Source ID for Inside_C.png
const TILE_SOURCE = 1

# The map cells where the closed suitcase was found (set by scanner match)
var _closed_cells: Array[Vector2i] = []
var _tile_layer: TileMapLayer = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		_player_in_range = true
		if not _solved:
			_prompt.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		_player_in_range = false
		_prompt.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and not _ui_open and not _solved and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_open_ui()

func _open_ui() -> void:
	_ui_open = true
	_prompt.visible = false
	get_tree().paused = true
	_suitcase_ui = _suitcase_ui_scene.instantiate()
	_suitcase_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	_suitcase_ui.puzzle_closed.connect(_close_ui)
	_suitcase_ui.puzzle_solved.connect(_on_solved)
	get_tree().root.add_child(_suitcase_ui)

func _close_ui() -> void:
	_ui_open = false
	get_tree().paused = false
	if _suitcase_ui:
		_suitcase_ui.queue_free()
		_suitcase_ui = null
	if _player_in_range and not _solved:
		_prompt.visible = true

func _on_solved() -> void:
	_solved = true
	_swap_to_open_tiles()
	_close_ui()
	GameState.collect_clock_hands()

func _swap_to_open_tiles() -> void:
	if _tile_layer == null:
		_find_tile_layer()
	if _tile_layer == null or _closed_cells.is_empty():
		return

	# Find the bottom-left cell of the closed suitcase
	var min_cell = _closed_cells[0]
	var max_cell = _closed_cells[0]
	for cell in _closed_cells:
		min_cell = Vector2i(mini(min_cell.x, cell.x), mini(min_cell.y, cell.y))
		max_cell = Vector2i(maxi(max_cell.x, cell.x), maxi(max_cell.y, cell.y))

	# Erase closed tiles
	for cell in _closed_cells:
		_tile_layer.erase_cell(cell)

	# Paint open tiles — bottom rows align
	# Closed bottom-left = (min_cell.x, max_cell.y)
	# Open is 3 wide × 4 tall, so it extends 2 tiles higher
	var open_width = OPEN_ATLAS_MAX.x - OPEN_ATLAS_MIN.x + 1  # 3
	var open_height = OPEN_ATLAS_MAX.y - OPEN_ATLAS_MIN.y + 1  # 4
	var bottom_left_x = min_cell.x
	var bottom_y = max_cell.y

	for dx in range(open_width):
		for dy in range(open_height):
			var map_cell = Vector2i(bottom_left_x + dx, bottom_y - (open_height - 1) + dy)
			var atlas_coord = Vector2i(OPEN_ATLAS_MIN.x + dx, OPEN_ATLAS_MIN.y + dy)
			_tile_layer.set_cell(map_cell, TILE_SOURCE, atlas_coord)

func _find_tile_layer() -> void:
	# Search for the Furniture2 layer that has our closed tiles
	var room_section = get_tree().root.find_child("RoomSection", true, false)
	if room_section == null:
		return
	for child in room_section.get_children():
		if child is TileMapLayer:
			for cell in child.get_used_cells():
				var atlas = child.get_cell_atlas_coords(cell)
				var src = child.get_cell_source_id(cell)
				if src == TILE_SOURCE and atlas.x >= CLOSED_ATLAS_MIN.x and atlas.x <= CLOSED_ATLAS_MAX.x \
				   and atlas.y >= CLOSED_ATLAS_MIN.y and atlas.y <= CLOSED_ATLAS_MAX.y:
					_tile_layer = child
					if not _closed_cells.has(cell):
						_closed_cells.append(cell)
