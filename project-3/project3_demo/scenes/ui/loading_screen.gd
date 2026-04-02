extends CanvasLayer

signal transition_finished
signal cover_finished
signal uncover_finished

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var background: ColorRect = $Background

@export var fade_in_time: float = 0.5
@export var min_display_time: float = 3.0
@export var fade_out_time: float = 0.5
@export var cover_display_time: float = 1.0

var _next_scene_path: String = ""

func _ready() -> void:
	# Center the animation on screen
	var viewport_size = get_viewport().get_visible_rect().size
	anim.position = viewport_size / 2
	anim.modulate = Color(1, 1, 1, 0)
	anim.play("loading")

	# If run standalone (F6), just show the animation
	if _next_scene_path == "":
		var tween = create_tween()
		tween.tween_property(anim, "modulate:a", 1.0, fade_in_time)

func transition_to(scene_path: String) -> void:
	_next_scene_path = scene_path
	ResourceLoader.load_threaded_request(scene_path)
	_play_transition()

func _play_transition() -> void:
	anim.play("loading")

	var tween = create_tween()
	tween.tween_property(anim, "modulate:a", 1.0, fade_in_time)
	tween.tween_interval(min_display_time)
	await tween.finished

	# Make sure the scene is loaded
	var status = ResourceLoader.load_threaded_get_status(_next_scene_path)
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		status = ResourceLoader.load_threaded_get_status(_next_scene_path)

	# Fade out
	var fade_tween = create_tween()
	fade_tween.tween_property(anim, "modulate:a", 0.0, fade_out_time)
	await fade_tween.finished

	var scene = ResourceLoader.load_threaded_get(_next_scene_path)
	get_tree().change_scene_to_packed(scene)
	transition_finished.emit()
	queue_free()


# --- Cover / Uncover mode (no scene change) ---

func cover() -> void:
	anim.play("loading")
	var tween = create_tween()
	tween.tween_property(anim, "modulate:a", 1.0, fade_in_time)
	await tween.finished
	cover_finished.emit()

func uncover() -> void:
	await get_tree().create_timer(cover_display_time).timeout
	var tween = create_tween()
	tween.tween_property(anim, "modulate:a", 0.0, fade_out_time)
	await tween.finished
	uncover_finished.emit()
	queue_free()
