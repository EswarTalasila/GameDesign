extends Node

var _default_tex: Texture2D = preload("res://assets/ui/cursor/frame_1.png")
var _default_click: Texture2D = preload("res://assets/ui/cursor/frame_0.png")
var _current_tex: Texture2D
var _current_click: Texture2D
var _sprite: Sprite2D
var _offset: Vector2 = Vector2.ZERO
var _current_scale: Vector2 = Vector2(2, 2)
var _default_scale: Vector2 = Vector2(2, 2)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	var layer = CanvasLayer.new()
	layer.layer = 128
	add_child(layer)

	_current_tex = _default_tex
	_current_click = _default_click

	_sprite = Sprite2D.new()
	_sprite.texture = _current_tex
	_sprite.centered = false
	_sprite.scale = _default_scale
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.add_child(_sprite)

	process_priority = -100

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_sprite.global_position = event.position + _offset
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_sprite.texture = _current_click
		else:
			_sprite.texture = _current_tex

func set_cursor(tex: Texture2D, click_tex: Texture2D = null, offset: Vector2 = Vector2.ZERO, cursor_scale: Vector2 = Vector2(2, 2)) -> void:
	_current_tex = tex
	_current_click = click_tex if click_tex else tex
	_offset = offset
	_current_scale = cursor_scale
	_sprite.texture = _current_tex
	_sprite.scale = _current_scale

func reset_cursor() -> void:
	_current_tex = _default_tex
	_current_click = _default_click
	_offset = Vector2.ZERO
	_current_scale = _default_scale
	_sprite.texture = _current_tex
	_sprite.scale = _default_scale
