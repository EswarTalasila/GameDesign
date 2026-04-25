@tool
extends Node2D

@export_range(0, 9) var value: int = 0:
	set(next_value):
		value = clampi(next_value, 0, 9)
		_update_digits()

@export var preview_all_digits: bool = false:
	set(next_value):
		preview_all_digits = next_value
		_update_digits()

func _ready() -> void:
	_apply_texture_filter()
	_update_digits()

func set_count(count: int) -> void:
	value = count

func _apply_texture_filter() -> void:
	for child in _get_digit_nodes():
		child.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var preview: Node2D = get_node_or_null("PreviewRow") as Node2D
	if preview:
		for child in preview.get_children():
			if child is Sprite2D:
				child.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _update_digits() -> void:
	if not is_inside_tree():
		return
	var show_all: bool = Engine.is_editor_hint() and preview_all_digits
	var digits: Array[Sprite2D] = _get_digit_nodes()
	for i in range(digits.size()):
		digits[i].visible = show_all or i == value
	var preview: Node2D = get_node_or_null("PreviewRow") as Node2D
	if preview:
		preview.visible = Engine.is_editor_hint()

func _get_digit_nodes() -> Array[Sprite2D]:
	var digits: Array[Sprite2D] = []
	var digit_root: Node2D = get_node_or_null("Digits") as Node2D
	if digit_root == null:
		return digits
	for i in range(10):
		var digit: Sprite2D = digit_root.get_node_or_null("Digit%d" % i) as Sprite2D
		if digit:
			digits.append(digit)
	return digits
