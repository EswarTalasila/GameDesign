extends Node

var tex_default: Texture2D = preload("res://assets/ui/cursor/frame_1.png")
var tex_clicked: Texture2D = preload("res://assets/ui/cursor/frame_0.png")
var _sprite: Sprite2D

func _ready() -> void:
	# Hide OS cursor
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	# Create cursor sprite on a high canvas layer
	var layer = CanvasLayer.new()
	layer.layer = 128
	add_child(layer)

	_sprite = Sprite2D.new()
	_sprite.texture = tex_default
	_sprite.centered = false
	_sprite.scale = Vector2(2, 2)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.add_child(_sprite)

	# Process as early as possible
	process_priority = -100

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_sprite.global_position = event.position
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_sprite.texture = tex_clicked
		else:
			_sprite.texture = tex_default
