extends Node

var _default_scene: PackedScene = preload("res://scenes/items/default_cursor.tscn")
var _layer: CanvasLayer
var _sprite: Sprite2D = null
var _current_scene: PackedScene = null
var _click_texture: Texture2D = null
var _normal_texture: Texture2D = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	_layer = CanvasLayer.new()
	_layer.layer = 128
	add_child(_layer)

	process_priority = -100
	_apply_scene(_default_scene)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _sprite:
		_sprite.global_position = event.position
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and _sprite:
		if event.pressed and _click_texture:
			_sprite.texture = _click_texture
		elif not event.pressed and _normal_texture:
			_sprite.texture = _normal_texture

## Set cursor from a scene. The scene root should be a Sprite2D.
## Scale, offset, texture — all come from the scene as-is.
## click_tex is optional for the clicked state.
func set_cursor_scene(scene: PackedScene, click_tex: Texture2D = null) -> void:
	_current_scene = scene
	_apply_scene(scene)
	_click_texture = click_tex

## Reset to default cursor scene.
func reset_cursor() -> void:
	_current_scene = _default_scene
	_apply_scene(_default_scene)
	_click_texture = null

func _apply_scene(scene: PackedScene) -> void:
	if _sprite:
		_sprite.queue_free()
		_sprite = null
	var instance = scene.instantiate()
	if instance is Sprite2D:
		_sprite = instance
	else:
		# If root isn't Sprite2D, find first Sprite2D child
		for child in instance.get_children():
			if child is Sprite2D:
				_sprite = child
				_sprite.get_parent().remove_child(_sprite)
				instance.queue_free()
				break
	if _sprite:
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_normal_texture = _sprite.texture
		if _click_texture == null:
			_click_texture = _normal_texture
		_layer.add_child(_sprite)
