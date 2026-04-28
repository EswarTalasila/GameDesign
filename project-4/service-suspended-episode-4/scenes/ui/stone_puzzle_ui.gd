extends CanvasLayer

signal closed

const STONE_ROCK_SCENE := preload("res://scenes/stone_puzzle/stone_rock.tscn")
const SLOT_ORDER := [
	"North",
	"NorthEast",
	"East",
	"SouthEast",
	"South",
	"SouthWest",
	"West",
	"NorthWest",
]

@export var ui_rock_scale_multiplier: Vector2 = Vector2.ONE
@export var orbit_radius_x_min: float = 300.0
@export var orbit_radius_x_max: float = 360.0
@export var orbit_radius_y_min: float = 228.0
@export var orbit_radius_y_max: float = 284.0
@export var orbit_speed_min: float = 0.28
@export var orbit_speed_max: float = 0.58
@export var slot_snap_distance: float = 86.0
@export_range(0.0, 1.0) var dim_alpha: float = 0.72

@onready var dimmer: ColorRect = $Dimmer
@onready var content: Node2D = $Content
@onready var board: Sprite2D = $Content/Board
@onready var floating_rocks: Node2D = $Content/FloatingRocks
@onready var slots: Node2D = $Content/Slots

var _altar: Node = null
var _is_open: bool = false
var _is_closing: bool = false
var _was_paused: bool = false
var _piece_nodes: Dictionary = {}
var _piece_draw_order: Array[String] = []
var _orbit_states: Dictionary = {}
var _floating_piece_ids: Array[String] = []
var _slot_piece_by_name: Dictionary = {}
var _piece_slot_by_id: Dictionary = {}
var _slot_markers: Dictionary = {}
var _drag_piece_id: String = ""
var _drag_origin_slot: String = ""
var _drag_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("stone_puzzle_ui_overlay")
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	dimmer.color = Color(0, 0, 0, dim_alpha)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dimmer.modulate.a = 0.0
	content.modulate.a = 0.0
	for slot_name in SLOT_ORDER:
		_slot_markers[slot_name] = slots.get_node(slot_name)
	_center_content()

func is_blocking_pause() -> bool:
	return _is_open or visible

func open(altar: Node = null) -> void:
	if _is_open or _is_closing:
		return
	_altar = altar
	_is_open = true
	visible = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	_center_content()
	_spawn_stones()
	dimmer.modulate.a = 0.0
	content.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(dimmer, "modulate:a", 1.0, 0.14)
	tween.tween_property(content, "modulate:a", 1.0, 0.14)

func close() -> void:
	if not _is_open or _is_closing:
		return
	_is_closing = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(dimmer, "modulate:a", 0.0, 0.12)
	tween.tween_property(content, "modulate:a", 0.0, 0.12)
	await tween.finished
	_clear_stones()
	_drag_piece_id = ""
	_drag_origin_slot = ""
	_altar = null
	_is_open = false
	_is_closing = false
	visible = false
	get_tree().paused = _was_paused
	closed.emit()

func _process(delta: float) -> void:
	if not _is_open or _is_closing:
		return
	_update_floating_rocks(delta)

func _input(event: InputEvent) -> void:
	if not _is_open or _is_closing:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		if event.pressed:
			_begin_drag(event.position)
		else:
			_end_drag(event.position)
		return
	if event is InputEventMouseMotion and not _drag_piece_id.is_empty():
		get_viewport().set_input_as_handled()
		var rock: Node2D = _piece_nodes.get(_drag_piece_id)
		if rock:
			rock.global_position = event.position + _drag_offset

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_center_content()

func _spawn_stones() -> void:
	_clear_stones()
	for piece_id in GameState.get_deposited_stone_piece_ids():
		var rock := STONE_ROCK_SCENE.instantiate() as Node2D
		if rock.has_method("setup"):
			rock.setup(piece_id)
		rock.scale = ui_rock_scale_multiplier
		floating_rocks.add_child(rock)
		_piece_nodes[piece_id] = rock
		_piece_draw_order.append(piece_id)
	_reset_to_floating_pool()

func _clear_stones() -> void:
	for rock in _piece_nodes.values():
		if is_instance_valid(rock):
			rock.queue_free()
	_piece_nodes.clear()
	_piece_draw_order.clear()
	_orbit_states.clear()
	_floating_piece_ids.clear()
	_slot_piece_by_name.clear()
	_piece_slot_by_id.clear()

func _reset_to_floating_pool() -> void:
	_slot_piece_by_name.clear()
	_piece_slot_by_id.clear()
	_floating_piece_ids = GameState.get_deposited_stone_piece_ids()
	_orbit_states.clear()
	for index in range(_floating_piece_ids.size()):
		var piece_id := _floating_piece_ids[index]
		var speed := randf_range(orbit_speed_min, orbit_speed_max)
		if index % 2 == 0:
			speed *= -1.0
		_orbit_states[piece_id] = {
			"angle": -PI * 0.5 + (TAU / float(max(_floating_piece_ids.size(), 1))) * index,
			"speed": speed,
			"radius_x": randf_range(minf(orbit_radius_x_min, orbit_radius_x_max), maxf(orbit_radius_x_min, orbit_radius_x_max)),
			"radius_y": randf_range(minf(orbit_radius_y_min, orbit_radius_y_max), maxf(orbit_radius_y_min, orbit_radius_y_max)),
			"bob_phase": randf() * TAU,
		}
		var rock: Node2D = _piece_nodes.get(piece_id)
		if rock:
			rock.z_index = 2
			if rock.has_method("set_selected"):
				rock.set_selected(false)
	_update_floating_rocks(0.0)

func _begin_drag(mouse_position: Vector2) -> void:
	if not _drag_piece_id.is_empty():
		return
	for index in range(_piece_draw_order.size() - 1, -1, -1):
		var piece_id := _piece_draw_order[index]
		var rock = _piece_nodes.get(piece_id)
		if rock == null or not is_instance_valid(rock):
			continue
		if rock.has_method("contains_global_point") and not rock.contains_global_point(mouse_position):
			continue
		_drag_piece_id = piece_id
		_drag_origin_slot = String(_piece_slot_by_id.get(piece_id, ""))
		if not _drag_origin_slot.is_empty():
			_slot_piece_by_name.erase(_drag_origin_slot)
			_piece_slot_by_id.erase(piece_id)
		else:
			_floating_piece_ids.erase(piece_id)
		_drag_offset = rock.global_position - mouse_position
		rock.z_index = 12
		if rock.has_method("set_selected"):
			rock.set_selected(true)
		_piece_draw_order.remove_at(index)
		_piece_draw_order.append(piece_id)
		return

func _end_drag(mouse_position: Vector2) -> void:
	if _drag_piece_id.is_empty():
		return
	var piece_id := _drag_piece_id
	var origin_slot := _drag_origin_slot
	var rock: Node2D = _piece_nodes.get(piece_id)
	_drag_piece_id = ""
	_drag_origin_slot = ""
	if rock == null or not is_instance_valid(rock):
		return
	var target_slot := _find_slot_target(mouse_position)
	if not target_slot.is_empty():
		_snap_piece_to_slot(piece_id, target_slot)
	elif not origin_slot.is_empty():
		_snap_piece_to_slot(piece_id, origin_slot)
	else:
		_return_piece_to_floating(piece_id)
	if rock.has_method("set_selected"):
		rock.set_selected(false)
	_check_solution_if_ready()

func _find_slot_target(mouse_position: Vector2) -> String:
	var best_slot := ""
	var best_distance := slot_snap_distance
	for slot_name in SLOT_ORDER:
		if _slot_piece_by_name.has(slot_name):
			continue
		var marker: Marker2D = _slot_markers.get(slot_name)
		if marker == null:
			continue
		var distance := marker.global_position.distance_to(mouse_position)
		if distance <= best_distance:
			best_slot = slot_name
			best_distance = distance
	return best_slot

func _snap_piece_to_slot(piece_id: String, slot_name: String) -> void:
	var marker: Marker2D = _slot_markers.get(slot_name)
	var rock: Node2D = _piece_nodes.get(piece_id)
	if marker == null or rock == null:
		return
	_slot_piece_by_name[slot_name] = piece_id
	_piece_slot_by_id[piece_id] = slot_name
	_floating_piece_ids.erase(piece_id)
	rock.global_position = marker.global_position
	rock.z_index = 6

func _return_piece_to_floating(piece_id: String) -> void:
	if not _floating_piece_ids.has(piece_id):
		_floating_piece_ids.append(piece_id)
	if not _orbit_states.has(piece_id):
		_orbit_states[piece_id] = {
			"angle": randf() * TAU,
			"speed": randf_range(orbit_speed_min, orbit_speed_max),
			"radius_x": randf_range(minf(orbit_radius_x_min, orbit_radius_x_max), maxf(orbit_radius_x_min, orbit_radius_x_max)),
			"radius_y": randf_range(minf(orbit_radius_y_min, orbit_radius_y_max), maxf(orbit_radius_y_min, orbit_radius_y_max)),
			"bob_phase": randf() * TAU,
		}
	var rock: Node2D = _piece_nodes.get(piece_id)
	if rock:
		rock.z_index = 2

func _update_floating_rocks(delta: float) -> void:
	for piece_id in _floating_piece_ids:
		if piece_id == _drag_piece_id or _piece_slot_by_id.has(piece_id):
			continue
		var rock: Node2D = _piece_nodes.get(piece_id)
		if rock == null or not is_instance_valid(rock):
			continue
		var orbit: Dictionary = _orbit_states.get(piece_id, {})
		var angle: float = float(orbit.get("angle", 0.0)) + float(orbit.get("speed", 0.0)) * delta
		var bob_phase: float = float(orbit.get("bob_phase", 0.0)) + delta * 1.55
		var offset := Vector2(
			cos(angle) * float(orbit.get("radius_x", orbit_radius_x_max)),
			sin(angle) * float(orbit.get("radius_y", orbit_radius_y_max)) + sin(bob_phase) * 6.0
		)
		rock.global_position = content.global_position + offset
		rock.z_index = 2 if offset.y <= 0.0 else 4
		orbit["angle"] = angle
		orbit["bob_phase"] = bob_phase
		_orbit_states[piece_id] = orbit

func _check_solution_if_ready() -> void:
	if _slot_piece_by_name.size() < GameState.STONE_PUZZLE_TOTAL:
		return
	var solution := GameState.get_stone_solution_colors()
	for index in range(SLOT_ORDER.size()):
		var piece_id := String(_slot_piece_by_name.get(SLOT_ORDER[index], ""))
		if GameState.get_stone_piece_color(piece_id) != String(solution[index]):
			_reset_to_floating_pool()
			return
	if _altar and _altar.has_method("complete_puzzle"):
		_altar.complete_puzzle()
	close()

func _center_content() -> void:
	content.position = get_viewport().get_visible_rect().size * 0.5
