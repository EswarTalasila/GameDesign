extends CanvasLayer

## Map assembly UI. Drag pieces into position on the board.
## When all 4 are snapped, they merge into the complete map.
## Requires all 4 pieces to be collected before completion.

signal board_closed
signal map_completed

var _piece_textures: Array = []
var _piece_sprites: Array[Sprite2D] = []
var _dragging: Sprite2D = null
var _drag_offset: Vector2 = Vector2.ZERO
var _snapped: Array[bool] = [false, false, false, false]
var _complete_map_tex = preload("res://assets/ui/map/map_base.png")

const SNAP_DISTANCE = 15.0
const PIECE_SCALE = Vector2(5, 5)

@onready var _board_sprite: Sprite2D = $BoardSprite

func _ready() -> void:
	layer = 8
	for i in range(1, 5):
		_piece_textures.append(load("res://assets/ui/map/piece_%d.png" % i))
	_spawn_pieces()

func _spawn_pieces() -> void:
	var scatter_positions = [
		Vector2(300, 300),
		Vector2(1600, 250),
		Vector2(350, 750),
		Vector2(1550, 700),
	]

	for i in range(4):
		if not GameState.has_map_piece(i + 1):
			continue
		var sprite = Sprite2D.new()
		sprite.texture = _piece_textures[i]
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = PIECE_SCALE
		sprite.position = scatter_positions[i]
		sprite.set_meta("piece_id", i)
		add_child(sprite)
		_piece_sprites.append(sprite)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		board_closed.emit()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_try_grab(event.position)
		else:
			_release()

	if event is InputEventMouseMotion and _dragging:
		_dragging.position = event.position + _drag_offset

func _try_grab(mouse: Vector2) -> void:
	var coordinator = get_tree().root.find_child("Node2D", true, false)
	if coordinator and coordinator.has_method("_handle_inventory_click"):
		if coordinator._handle_inventory_click(mouse):
			return

	for i in range(_piece_sprites.size() - 1, -1, -1):
		var sprite = _piece_sprites[i]
		var piece_id = sprite.get_meta("piece_id")
		if _snapped[piece_id]:
			continue
		var half = Vector2(sprite.texture.get_width(), sprite.texture.get_height()) * sprite.scale / 2.0
		var rect = Rect2(sprite.position - half, half * 2)
		if rect.has_point(mouse):
			_dragging = sprite
			_drag_offset = sprite.position - mouse
			move_child(sprite, -1)
			return

func _release() -> void:
	if _dragging == null:
		return
	var piece_id = _dragging.get_meta("piece_id")
	var target = _board_sprite.position
	var dist = _dragging.position.distance_to(target)
	if dist < SNAP_DISTANCE * PIECE_SCALE.x:
		_dragging.position = target
		_snapped[piece_id] = true
	_dragging = null
	_check_complete()

func _check_complete() -> void:
	# Need all 4 pieces collected AND all snapped
	if GameState.collected_map_pieces.size() < 4:
		return
	for i in range(4):
		if not _snapped[i]:
			return
	# All 4 snapped — merge into complete map
	_merge_into_map()

func _merge_into_map() -> void:
	for sprite in _piece_sprites:
		sprite.queue_free()
	_piece_sprites.clear()
	_board_sprite.texture = _complete_map_tex
	GameState.map_assembled = true
