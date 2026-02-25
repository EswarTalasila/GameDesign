extends CanvasLayer

signal transition_finished

@onready var logo: TextureRect = $Control/Logo
@onready var background: ColorRect = $Control/Background

@export var fade_in_time: float = 1.0
@export var hold_time: float = 1.5
@export var fade_out_time: float = 1.0

var _next_scene_path: String = ""

func transition_to(scene_path: String) -> void:
	_next_scene_path = scene_path
	ResourceLoader.load_threaded_request(scene_path)
	_play_transition()

func _play_transition() -> void:
	# Start fully black, logo invisible
	background.modulate = Color.WHITE
	logo.modulate = Color(1, 1, 1, 0)

	var tween = create_tween()

	# Fade logo in
	tween.tween_property(logo, "modulate:a", 1.0, fade_in_time)

	# Hold
	tween.tween_interval(hold_time)

	# Fade logo out
	tween.tween_property(logo, "modulate:a", 0.0, fade_out_time)

	# Wait for tween to finish
	await tween.finished

	# Make sure the scene is loaded
	var status = ResourceLoader.load_threaded_get_status(_next_scene_path)
	while status == ResourceLoader.THREAD_LOADING:
		await get_tree().process_frame
		status = ResourceLoader.load_threaded_get_status(_next_scene_path)

	var scene = ResourceLoader.load_threaded_get(_next_scene_path)
	get_tree().change_scene_to_packed(scene)
	transition_finished.emit()
	queue_free()
