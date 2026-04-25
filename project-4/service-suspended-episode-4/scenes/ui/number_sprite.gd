extends Sprite2D

@export_range(0, 9) var value: int = 0:
	set(next_value):
		value = clampi(next_value, 0, 9)
		_update_texture()

var _textures: Array[Texture2D] = []

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_load_textures()
	_update_texture()

func _load_textures() -> void:
	if not _textures.is_empty():
		return
	for i in range(10):
		_textures.append(load("res://assets/sprites/ui/numbers/%d.png" % i))

func _update_texture() -> void:
	if _textures.is_empty():
		_load_textures()
	if value >= 0 and value < _textures.size():
		texture = _textures[value]
