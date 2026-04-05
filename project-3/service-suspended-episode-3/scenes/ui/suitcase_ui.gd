extends CanvasLayer

## Suitcase combination lock UI with pixel art buttons and digits.
## 4 digit slots, each with Up/Down buttons and a digit display.
## Position them in the editor on top of the UIBase sprite.
## Correct combo: 0647.

signal puzzle_closed
signal puzzle_solved

const CORRECT_COMBO = [0, 6, 4, 7]

@onready var _panel: Sprite2D = $UIBase

var _digit_textures: Array = []
var _up_normal_tex = preload("res://assets/ui/suitcase/up_normal.png")
var _up_clicked_tex = preload("res://assets/ui/suitcase/up_clicked.png")
var _down_normal_tex = preload("res://assets/ui/suitcase/down_normal.png")
var _down_clicked_tex = preload("res://assets/ui/suitcase/down_clicked.png")

var _digits: Array[int] = [0, 0, 0, 0]
var _digit_sprites: Array[Sprite2D] = []
var _up_sprites: Array[Sprite2D] = []
var _down_sprites: Array[Sprite2D] = []

func _ready() -> void:
	layer = 8
	for i in range(10):
		_digit_textures.append(load("res://assets/ui/suitcase/digit_%d.png" % i))
	# Gather the slot nodes
	for i in range(4):
		var slot = _panel.get_node("Slot%d" % (i + 1))
		_up_sprites.append(slot.get_node("Up"))
		_down_sprites.append(slot.get_node("Down"))
		_digit_sprites.append(slot.get_node("Digit"))
		_digit_sprites[i].texture = _digit_textures[0]
		_up_sprites[i].texture = _up_normal_tex
		_down_sprites[i].texture = _down_normal_tex

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		puzzle_closed.emit()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_handle_click(event.position)
		else:
			_reset_buttons()

func _handle_click(mouse: Vector2) -> void:
	var local = (mouse - _panel.position) / _panel.scale

	for i in range(4):
		if _hit_test(local, _up_sprites[i]):
			_up_sprites[i].texture = _up_clicked_tex
			_digits[i] = (_digits[i] + 1) % 10
			_digit_sprites[i].texture = _digit_textures[_digits[i]]
			_check_combo()
			get_viewport().set_input_as_handled()
			return
		if _hit_test(local, _down_sprites[i]):
			_down_sprites[i].texture = _down_clicked_tex
			_digits[i] = (_digits[i] - 1 + 10) % 10
			_digit_sprites[i].texture = _digit_textures[_digits[i]]
			_check_combo()
			get_viewport().set_input_as_handled()
			return

func _hit_test(local_pos: Vector2, sprite: Sprite2D) -> bool:
	var tex = sprite.texture
	if tex == null:
		return false
	# Convert to sprite-local coords (accounting for parent slot offset)
	var sprite_global_offset = sprite.position + sprite.get_parent().position
	var sprite_local = local_pos - sprite_global_offset
	var tex_size = Vector2(tex.get_width(), tex.get_height())
	var tex_coord = sprite_local + tex_size / 2.0
	if tex_coord.x < 0 or tex_coord.y < 0 or tex_coord.x >= tex_size.x or tex_coord.y >= tex_size.y:
		return false
	var img = tex.get_image()
	var px = img.get_pixel(int(tex_coord.x), int(tex_coord.y))
	return px.a > 0.1

func _reset_buttons() -> void:
	for up in _up_sprites:
		up.texture = _up_normal_tex
	for down in _down_sprites:
		down.texture = _down_normal_tex

func _check_combo() -> void:
	if _digits == CORRECT_COMBO:
		puzzle_solved.emit()
