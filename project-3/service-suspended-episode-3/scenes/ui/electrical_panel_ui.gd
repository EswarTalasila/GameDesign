extends CanvasLayer

## Close-up electrical panel puzzle UI.
## Shows closed panel → click to open → wires visible → cut in order.

signal puzzle_closed

@onready var _panel_sprite: Sprite2D = $PanelSprite
@onready var _wire_container: Node2D = $PanelSprite/Wires

var _closed_tex = preload("res://assets/ui/electrical_panel/panel_closed.png")
var _open_tex = preload("res://assets/ui/electrical_panel/panel_open.png")

var _is_open: bool = false
var _has_cutter: bool = false
# Wire names in the required cut order. Set via set_wire_order().
var _wire_order: Array[String] = []
var _next_cut_index: int = 0

func _ready() -> void:
	layer = 8
	_panel_sprite.texture = _closed_tex
	if _wire_container:
		_wire_container.visible = false
	_has_cutter = GameState.has_wire_cutter

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		puzzle_closed.emit()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse = event.position
		# Check inventory click first — wire cutter toggle
		if GameState.has_wire_cutter:
			var punch_slot = get_tree().root.find_child("PunchSlot", true, false)
			if punch_slot and punch_slot.visible:
				var slot_pos = punch_slot.global_position
				var half = Vector2(24, 24)
				if Rect2(slot_pos - half, half * 2).has_point(mouse):
					GameState.set_wire_cutter_mode(not GameState.wire_cutter_mode)
					_has_cutter = GameState.has_wire_cutter
					get_viewport().set_input_as_handled()
					return
		# Panel area click
		var panel_center = _panel_sprite.position
		var panel_half = Vector2(64, 64) * _panel_sprite.scale
		var panel_rect = Rect2(panel_center - panel_half, panel_half * 2)
		if panel_rect.has_point(mouse):
			if not _is_open:
				_open_panel()
			get_viewport().set_input_as_handled()

func _open_panel() -> void:
	_is_open = true
	_panel_sprite.texture = _open_tex
	if _wire_container:
		_wire_container.visible = true

## Called by wire Line2D nodes when clicked.
func try_cut_wire(wire_name: String) -> bool:
	if not _has_cutter:
		return false
	_has_cutter = GameState.has_wire_cutter
	if not _has_cutter:
		return false
	if _wire_order.is_empty():
		return true
	if _next_cut_index >= _wire_order.size():
		return false
	if wire_name == _wire_order[_next_cut_index]:
		_next_cut_index += 1
		if _next_cut_index >= _wire_order.size():
			_on_all_wires_cut()
		return true
	else:
		_on_wrong_wire()
		return false

func set_wire_order(order: Array[String]) -> void:
	_wire_order = order
	_next_cut_index = 0

func _on_all_wires_cut() -> void:
	pass

func _on_wrong_wire() -> void:
	pass
