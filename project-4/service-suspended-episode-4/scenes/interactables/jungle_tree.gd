@tool
extends Node2D

## Animated jungle tree — place directly in variant scenes.
## Uses spritesheets from assets/tilesets/jungle/trees/
## Each sheet is 256x240 = 4 columns × 3 rows = 12 frames at 64x80.
##
## 6 tree shapes (type) × 3 colors = 18 combinations.

@export_range(1, 6) var tree_type: int = 1:
	set(value):
		tree_type = value
		_rebuild_frames()

@export_enum("green", "blue", "red") var tree_color: String = "green":
	set(value):
		tree_color = value
		_rebuild_frames()

@export var fps: float = 4.0:
	set(value):
		fps = value
		_rebuild_frames()

@export var autoplay: bool = true

const COLS := 4
const ROWS := 3
const FRAME_W := 64
const FRAME_H := 80
const FRAME_COUNT := 12  # 4 × 3

## Maps color name to the s_XX suffix in the filename.
const COLOR_MAP = {
	"green": "01",
	"blue": "02",
	"red": "03",
}

var _sprite: AnimatedSprite2D

func _ready() -> void:
	_sprite = get_node_or_null("AnimatedSprite2D")
	if not _sprite:
		_sprite = AnimatedSprite2D.new()
		_sprite.name = "AnimatedSprite2D"
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_sprite)
		if Engine.is_editor_hint():
			_sprite.owner = get_tree().edited_scene_root
	_rebuild_frames()

func _rebuild_frames() -> void:
	if not _sprite:
		_sprite = get_node_or_null("AnimatedSprite2D")
	if not _sprite:
		return

	var color_suffix = COLOR_MAP.get(tree_color, "01")
	var path := "res://assets/tilesets/jungle/trees/tree%02d_s_%s_animation.png" % [tree_type, color_suffix]

	var sheet: Texture2D = null
	if ResourceLoader.exists(path):
		sheet = load(path)
	else:
		# Fallback to tree01 green
		var fallback := "res://assets/tilesets/jungle/trees/tree01_s_01_animation.png"
		if ResourceLoader.exists(fallback):
			sheet = load(fallback)

	if sheet == null:
		return

	var img := sheet.get_image()
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("sway")
	frames.set_animation_speed("sway", fps)
	frames.set_animation_loop("sway", true)

	# Read frames left-to-right, top-to-bottom (4 cols × 3 rows)
	for row in range(ROWS):
		for col in range(COLS):
			var region := Rect2i(col * FRAME_W, row * FRAME_H, FRAME_W, FRAME_H)
			var frame_img := img.get_region(region)
			var tex := ImageTexture.create_from_image(frame_img)
			frames.add_frame("sway", tex)

	_sprite.sprite_frames = frames
	_sprite.animation = "sway"
	if autoplay:
		_sprite.play("sway")
