@tool
extends Node2D

var _slot_size: Vector2 = Vector2(64, 64)
var _show_box: bool = true
var _box_color: Color = Color(0.25, 0.7, 1.0, 0.28)

@export var slot_size: Vector2 = Vector2(64, 64):
	set(value):
		_slot_size = value
		queue_redraw()
	get:
		return _slot_size
@export var show_box: bool = true:
	set(value):
		_show_box = value
		queue_redraw()
	get:
		return _show_box
@export var box_color: Color = Color(0.25, 0.7, 1.0, 0.28):
	set(value):
		_box_color = value
		queue_redraw()
	get:
		return _box_color

func _draw() -> void:
	if not Engine.is_editor_hint() or not _show_box:
		return
	var rect: Rect2 = Rect2(-_slot_size * 0.5, _slot_size)
	draw_rect(rect, _box_color, false, 1.0)
	draw_line(Vector2(-5, 0), Vector2(5, 0), _box_color, 1.0)
	draw_line(Vector2(0, -5), Vector2(0, 5), _box_color, 1.0)

func contains_global_point(point: Vector2) -> bool:
	var local_point: Vector2 = to_local(point)
	return Rect2(-_slot_size * 0.5, _slot_size).has_point(local_point)
