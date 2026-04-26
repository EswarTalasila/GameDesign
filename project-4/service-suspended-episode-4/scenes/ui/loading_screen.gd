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
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.color = Color.BLACK

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

	# Fade in loading screen to fully cover the main menu
	var tween = create_tween()
	tween.tween_property(anim, "modulate:a", 1.0, fade_in_time)
	tween.tween_interval(min_display_time)
	await tween.finished

	# Wait for the scene to finish loading
	var status = ResourceLoader.load_threaded_get_status(_next_scene_path)
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		status = ResourceLoader.load_threaded_get_status(_next_scene_path)

	# Swap scene WHILE loading screen still covers everything
	var scene = ResourceLoader.load_threaded_get(_next_scene_path)
	get_tree().change_scene_to_packed(scene)

	# Wait a frame for the new scene to initialize
	await get_tree().process_frame

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
	var tween = create_tween().set_parallel(true)
	tween.tween_property(anim, "modulate:a", 0.0, fade_out_time)
	tween.tween_property(background, "color:a", 0.0, fade_out_time)
	await tween.finished
	uncover_finished.emit()
	queue_free()
