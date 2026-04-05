extends CanvasLayer

## Close-up electrical panel puzzle.
## Closed → click to open → wires visible → cut in correct order with wire cutter.

signal puzzle_closed
signal puzzle_solved

@onready var _panel_sprite: Sprite2D = $PanelSprite
@onready var _wire_container: Node2D = $PanelSprite/Wires

var _closed_tex = preload("res://assets/ui/electrical_panel/panel_closed.png")
var _open_tex = preload("res://assets/ui/electrical_panel/panel_open.png")

# Cut textures per wire name
var _cut_textures = {
	"WireRed": preload("res://assets/ui/electrical_panel/wire_red_cut.png"),
	"WireBlue": preload("res://assets/ui/electrical_panel/wire_blue_cut.png"),
	"WireGreen": preload("res://assets/ui/electrical_panel/wire_green_cut.png"),
	"WireBlack": preload("res://assets/ui/electrical_panel/wire_black_cut.png"),
}

var _is_open: bool = false
# Required cut order — wire node names in sequence. Empty = any order.
var _wire_order: Array[String] = ["WireRed", "WireBlue", "WireGreen", "WireBlack"]
var _next_cut_index: int = 0
var _cut_wires: Dictionary = {}  # wire_name -> true

func _ready() -> void:
	layer = 8
	_panel_sprite.texture = _closed_tex
	if _wire_container:
		_wire_container.visible = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		puzzle_closed.emit()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse = event.position

		# Let inventory clicks through — delegate to room coordinator
		var coordinator = get_tree().root.find_child("Node2D", true, false)
		if coordinator and coordinator.has_method("_handle_inventory_click"):
			if coordinator._handle_inventory_click(mouse):
				return

		# Panel area
		var panel_center = _panel_sprite.position
		var panel_half = Vector2(64, 64) * _panel_sprite.scale
		var panel_rect = Rect2(panel_center - panel_half, panel_half * 2)

		if not panel_rect.has_point(mouse):
			return

		if not _is_open:
			_open_panel()
			get_viewport().set_input_as_handled()
			return

		# Try cutting a wire if in wire cutter mode
		if GameState.wire_cutter_mode and _wire_container.visible:
			_try_cut_at(mouse)
			get_viewport().set_input_as_handled()

func _open_panel() -> void:
	_is_open = true
	_panel_sprite.texture = _open_tex
	if _wire_container:
		_wire_container.visible = true
	# Pulse wire cutter icon now that wires are visible
	if GameState.has_wire_cutter:
		var coordinator = get_tree().root.find_child("Node2D", true, false)
		if coordinator and coordinator.has_method("pulse_inventory_item"):
			coordinator.pulse_inventory_item("wire_cutter")

func _try_cut_at(mouse_pos: Vector2) -> void:
	# Convert mouse to local space of the wire container
	# Wires are children of PanelSprite which is scaled 5x at (960,540)
	var local = (mouse_pos - _panel_sprite.position) / _panel_sprite.scale

	# Check each uncut wire — find the closest one to the click
	var best_wire: String = ""
	var best_dist: float = 20.0  # max click distance in local pixels

	for wire_sprite in _wire_container.get_children():
		if wire_sprite is Sprite2D and not _cut_wires.has(wire_sprite.name):
			# Check if click is on a non-transparent pixel of the wire
			var tex = wire_sprite.texture
			if tex == null:
				continue
			var sprite_local = local - wire_sprite.position
			# Texture is centered, convert to texture coords
			var tex_size = Vector2(tex.get_width(), tex.get_height())
			var tex_coord = sprite_local + tex_size / 2.0
			if tex_coord.x < 0 or tex_coord.y < 0 or tex_coord.x >= tex_size.x or tex_coord.y >= tex_size.y:
				continue
			# Check if pixel is non-transparent
			var img = tex.get_image()
			var px = img.get_pixel(int(tex_coord.x), int(tex_coord.y))
			if px.a > 0.1:
				var d = sprite_local.length()
				if d < best_dist:
					best_dist = d
					best_wire = wire_sprite.name

	if best_wire.is_empty():
		return

	_cut_wire(best_wire)

func _cut_wire(wire_name: String) -> void:
	_cut_wires[wire_name] = true
	var wire_sprite = _wire_container.get_node(wire_name)
	if wire_sprite and _cut_textures.has(wire_name):
		wire_sprite.texture = _cut_textures[wire_name]

	# Check if all wires are cut
	if _cut_wires.size() >= _wire_container.get_child_count():
		# Check if cut order matches the required sequence
		var cut_order_keys = _cut_wires.keys()
		if _wire_order.is_empty() or cut_order_keys == Array(_wire_order):
			_on_all_wires_cut()
		else:
			_on_wrong_order()

func _on_all_wires_cut() -> void:
	puzzle_solved.emit()

func _on_wrong_order() -> void:
	# All wires cut but in wrong order — door stays locked
	# TODO: penalty, reset wires, feedback, etc.
	pass
