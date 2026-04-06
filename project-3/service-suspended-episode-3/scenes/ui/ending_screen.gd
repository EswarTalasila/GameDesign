extends CanvasLayer

## End-game screen. Black background, text fades in, then returns to main menu.

var _background: ColorRect
var _label: Label
var _dot_gothic = preload("res://assets/fonts/DotGothic16-Regular.ttf")

const ENDING_TEXT = """You managed to escape the room looped through time.

But don't celebrate yet.

You must now tackle the tracks of the train once more,
only this time you have limited time
before the conductor finds you."""

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS

	var viewport_size = get_viewport().get_visible_rect().size

	_background = ColorRect.new()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.color = Color(0, 0, 0, 0)
	_background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_background)

	_label = Label.new()
	_label.text = ENDING_TEXT
	_label.add_theme_font_override("font", _dot_gothic)
	_label.add_theme_font_size_override("font_size", 28)
	_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.65))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.modulate = Color(1, 1, 1, 0)
	add_child(_label)

	_play_sequence()

func _play_sequence() -> void:
	get_tree().paused = true

	# Fade to black
	var tween = create_tween()
	tween.tween_property(_background, "color:a", 1.0, 1.0)
	tween.tween_interval(0.5)
	# Fade in text
	tween.tween_property(_label, "modulate:a", 1.0, 1.5)
	await tween.finished

	# Wait for player input or timeout
	await _wait_for_input_or_timeout(8.0)

	# Fade out first message
	var out_tween = create_tween()
	out_tween.tween_property(_label, "modulate:a", 0.0, 1.0)
	await out_tween.finished

	# Show second message
	await get_tree().create_timer(0.5).timeout
	_label.text = "See you in Episode 4."
	var in_tween = create_tween()
	in_tween.tween_property(_label, "modulate:a", 1.0, 1.0)
	await in_tween.finished

	await _wait_for_input_or_timeout(4.0)

	# Fade out and return to title screen
	var final_tween = create_tween()
	final_tween.tween_property(_label, "modulate:a", 0.0, 1.0)
	final_tween.tween_interval(0.5)
	await final_tween.finished

	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _wait_for_input_or_timeout(timeout: float) -> void:
	var elapsed = 0.0
	while elapsed < timeout:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept"):
			return
