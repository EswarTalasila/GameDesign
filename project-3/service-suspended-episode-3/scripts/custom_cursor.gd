extends Node

## Custom cursor system. Every cursor is a scene (Sprite2D root).
## The scene defines: texture, scale, position offset — what you see in the
## editor is what you get at runtime.
## Optional metadata on the scene root:
##   click_texture: Texture2D — shown while mouse button held

var _default_scene: PackedScene = preload("res://scenes/items/cursors/default_cursor.tscn")
var _layer: CanvasLayer
var _sprite: Sprite2D = null
var _normal_texture: Texture2D = null
var _click_texture: Texture2D = null
var _offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # DEBUG: show OS cursor to see offset
	_layer = CanvasLayer.new()
	_layer.layer = 128
	add_child(_layer)
	process_priority = -100
	_load_scene(_default_scene)

func _process(_delta: float) -> void:
	if _sprite:
		_sprite.global_position = get_viewport().get_mouse_position() + _offset
		# Check mouse state directly so UI consuming clicks doesn't block the visual
		var pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		_sprite.texture = _click_texture if pressed else _normal_texture

## Swap to a different cursor scene. What you set in the editor is what shows.
func set_cursor_scene(scene: PackedScene) -> void:
	_load_scene(scene)

## Reset to the default cursor.
func reset_cursor() -> void:
	_load_scene(_default_scene)

func _load_scene(scene: PackedScene) -> void:
	# Remove old
	if _sprite and is_instance_valid(_sprite):
		_sprite.queue_free()
	_sprite = null
	_normal_texture = null
	_click_texture = null
	_offset = Vector2.ZERO

	# Instance new
	var instance = scene.instantiate()
	if not instance is Sprite2D:
		push_error("Cursor scene root must be Sprite2D: " + scene.resource_path)
		instance.queue_free()
		return

	_sprite = instance
	_normal_texture = _sprite.texture
	_offset = _sprite.position
	_sprite.position = Vector2.ZERO  # position is used as offset, not world pos

	# Read click texture from metadata if present
	if _sprite.has_meta("click_texture"):
		_click_texture = _sprite.get_meta("click_texture")
	else:
		_click_texture = _normal_texture

	_layer.add_child(_sprite)
