@tool
extends Node2D

## Reusable fire scene — place anywhere, configure in inspector.
## Uses spritesheets from assets/sprites/fire/<color>/group_<group>_<variation>.png
## Frame size is auto-detected from the spritesheet (always 8 frames wide).

@export_enum("yellow", "blue", "red", "green", "purple", "white",
	"yellow_floored", "blue_floored", "red_floored", "green_floored", "purple_floored", "white_floored")
var fire_color: String = "yellow":
	set(value):
		fire_color = value
		_rebuild_frames()

@export_range(4, 7) var fire_group: int = 4:
	set(value):
		fire_group = value
		_rebuild_frames()

@export_range(1, 5) var fire_variation: int = 1:
	set(value):
		fire_variation = value
		_rebuild_frames()

@export var fps: float = 10.0:
	set(value):
		fps = value
		_rebuild_frames()

@export var autoplay: bool = true

const FRAME_COUNT := 8

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

	var path := "res://assets/sprites/fire/%s/group_%d_%d.png" % [fire_color, fire_group, fire_variation]
	var sheet: Texture2D = null

	if ResourceLoader.exists(path):
		sheet = load(path)
	else:
		var fallback := "res://assets/sprites/fire/yellow/group_4_1.png"
		if ResourceLoader.exists(fallback):
			sheet = load(fallback)

	if sheet == null:
		return

	var img := sheet.get_image()
	var sheet_w := img.get_width()
	var sheet_h := img.get_height()

	# Auto-detect frame size: always 8 frames across, full height per frame
	var frame_w := sheet_w / FRAME_COUNT
	var frame_h := sheet_h

	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("burn")
	frames.set_animation_speed("burn", fps)
	frames.set_animation_loop("burn", true)

	for i in range(FRAME_COUNT):
		var region := Rect2i(i * frame_w, 0, frame_w, frame_h)
		var frame_img := img.get_region(region)
		var tex := ImageTexture.create_from_image(frame_img)
		frames.add_frame("burn", tex)

	_sprite.sprite_frames = frames
	_sprite.animation = "burn"
	if autoplay:
		_sprite.play("burn")

func stop() -> void:
	if _sprite:
		_sprite.stop()

func play_fire() -> void:
	if _sprite:
		_sprite.play("burn")
