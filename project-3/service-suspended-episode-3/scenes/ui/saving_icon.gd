extends AnimatedSprite2D

# Plays the saving animation once, then fades out and self-destructs.

func _ready() -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	# Bottom-right, inset by one icon width + padding
	position = Vector2(viewport_size.x - 140, viewport_size.y - 140)
	scale = Vector2(2, 2)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	modulate = Color(1, 1, 1, 0)

	# Build SpriteFrames from individual frame PNGs
	var frames = SpriteFrames.new()
	frames.add_animation("save")
	frames.set_animation_speed("save", 10.0)
	frames.set_animation_loop("save", false)
	for i in range(10):
		var tex = load("res://assets/ui/saving_icon/frames/frame_%d.png" % i)
		frames.add_frame("save", tex)
	if frames.has_animation("default"):
		frames.remove_animation("default")
	sprite_frames = frames

	# Fade in
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	tween.tween_callback(func(): play("save"))

	animation_finished.connect(_on_animation_finished)

func _on_animation_finished() -> void:
	# Hold for a moment then fade out
	var tween = create_tween()
	tween.tween_interval(0.5)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
