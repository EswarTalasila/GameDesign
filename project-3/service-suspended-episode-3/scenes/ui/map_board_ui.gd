extends CanvasLayer

## Map assembly UI. Drag pieces, then use clock to reveal colored paths.

signal board_closed

var _piece_textures: Array = []
var _piece_sprites: Array[Sprite2D] = []
var _dragging: Sprite2D = null
var _drag_offset: Vector2 = Vector2.ZERO
var _snapped: Array[bool] = [false, false, false, false]

const SNAP_DISTANCE = 30.0
const PIECE_SCALE = Vector2(5, 5)
const COLORS = ["Red", "Blue", "Green", "Black"]

@onready var _board_sprite: Sprite2D = $BoardSprite

var _clock_placed: bool = false
var _clock_sprite: Sprite2D = null
var _clock_variant_textures: Array = []
var _clock_anim_timer: float = 0.0
var _clock_anim_index: int = 0
var _reveal_progress: float = 0.0
var _revealing: bool = false
var _path_sprites: Array[Sprite2D] = []

func _ready() -> void:
	layer = 8
	for i in range(1, 5):
		_piece_textures.append(load("res://assets/ui/map/piece_%d.png" % i))
	for i in range(1, 5):
		_clock_variant_textures.append(load("res://assets/ui/clock/closeup_variant_%d.png" % i))

	if GameState.get("clock_on_map"):
		_show_completed_with_clock()
	elif GameState.map_assembled:
		_show_completed_map()
	else:
		_spawn_pieces()

func _show_completed_map() -> void:
	for i in range(4):
		var sprite = Sprite2D.new()
		sprite.texture = _piece_textures[i]
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = PIECE_SCALE
		sprite.position = _board_sprite.position
		add_child(sprite)

func _show_completed_with_clock() -> void:
	_show_completed_map()
	_place_clock_on_map()
	_reveal_paths_instant()

func _spawn_pieces() -> void:
	var scatter_positions = [
		Vector2(300, 300), Vector2(1600, 250),
		Vector2(350, 750), Vector2(1550, 700),
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

func _process(delta: float) -> void:
	# Clock cycling animation
	if _clock_placed and _clock_sprite:
		_clock_anim_timer += delta
		if _clock_anim_timer >= 0.5:
			_clock_anim_timer = 0.0
			_clock_anim_index = (_clock_anim_index + 1) % 4
			_clock_sprite.texture = _clock_variant_textures[_clock_anim_index]

	# Path reveal animation
	if _revealing:
		_reveal_progress += delta * 0.3  # takes ~3.3 seconds
		if _reveal_progress >= 1.0:
			_reveal_progress = 1.0
			_revealing = false
			GameState.set("clock_on_map", true)
		_update_path_reveal()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		board_closed.emit()
		return

	if GameState.map_assembled and _clock_placed:
		return  # Just viewing

	if GameState.map_assembled and not _clock_placed:
		# Check inventory click — clock icon
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var coordinator = get_tree().root.find_child("Node2D", true, false)
			if coordinator and coordinator.has_method("_handle_inventory_click"):
				coordinator._handle_inventory_click(event.position)
			# Check if clock was just activated and clicking on the map
			if GameState.clock_hands_inserted:
				var center = _board_sprite.position
				var half = Vector2(64, 64) * _board_sprite.scale
				if Rect2(center - half, half * 2).has_point(event.position):
					_place_clock_on_map()
					_start_path_reveal()
					get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_try_grab(event.position)
		else:
			_release()

	if event is InputEventMouseMotion and _dragging:
		_dragging.position = event.position + _drag_offset

func _place_clock_on_map() -> void:
	_clock_placed = true
	_clock_sprite = Sprite2D.new()
	_clock_sprite.texture = _clock_variant_textures[0]
	_clock_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_clock_sprite.scale = Vector2(2, 2)
	_clock_sprite.position = _board_sprite.position
	_clock_sprite.z_index = 10
	add_child(_clock_sprite)

func _start_path_reveal() -> void:
	_revealing = true
	_reveal_progress = 0.0
	_setup_random_paths()
	# Pulse clock in inventory
	var coordinator = get_tree().root.find_child("Node2D", true, false)
	if coordinator and coordinator.has_method("stop_pulse"):
		coordinator.stop_pulse("clock")

func _setup_random_paths() -> void:
	# Pick 4 random paths from 7, assign 1 color each
	var available_paths = [1, 2, 3, 4, 5, 6, 7]
	available_paths.shuffle()
	var chosen_paths = available_paths.slice(0, 4)
	var colors = COLORS.duplicate()
	colors.shuffle()

	# Sort by clockwise angle for wire cut order
	# For now store the assignment
	var assignments: Array = []
	for i in range(4):
		assignments.append({"path": chosen_paths[i], "color": colors[i]})

	# Create path sprites (hidden, revealed by shader/alpha)
	for a in assignments:
		var tex = load("res://assets/ui/map/path_%d_%s.png" % [a["path"], a["color"]])
		var sprite = Sprite2D.new()
		sprite.texture = tex
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = PIECE_SCALE
		sprite.position = _board_sprite.position
		sprite.modulate = Color(1, 1, 1, 0)  # start invisible
		sprite.z_index = 5
		add_child(sprite)
		_path_sprites.append(sprite)

	# Store wire order in GameState based on clockwise reading
	# TODO: calculate clockwise order from path positions
	var wire_order: Array[String] = []
	for a in assignments:
		wire_order.append("Wire" + a["color"])
	GameState.set("wire_cut_order", wire_order)

func _update_path_reveal() -> void:
	# Expand reveal — fade in paths radially from center
	for sprite in _path_sprites:
		sprite.modulate.a = _reveal_progress

func _reveal_paths_instant() -> void:
	_clock_placed = true
	_setup_random_paths()
	for sprite in _path_sprites:
		sprite.modulate.a = 1.0
	_place_clock_on_map()

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
	if GameState.collected_map_pieces.size() < 4:
		return
	for i in range(4):
		if not _snapped[i]:
			return
	GameState.map_assembled = true
	var coordinator = get_tree().root.find_child("Node2D", true, false)
	if coordinator and coordinator.has_method("pulse_inventory_item"):
		coordinator.pulse_inventory_item("clock")
