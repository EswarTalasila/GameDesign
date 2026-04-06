extends CanvasLayer

## Intercom message system — buzzy static + text overlay.
## Plays a sequence of messages, then emits finished.

signal finished

var _static_sound = preload("res://assets/sounds/innercom_static.mp3")
var _dot_gothic = preload("res://assets/fonts/DotGothic16-Regular.ttf")

var _label: Label
var _bg: ColorRect
var _audio: AudioStreamPlayer
var _messages: Array = []
var _current: int = 0

func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS

	_bg = ColorRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_bg.custom_minimum_size = Vector2(0, 80)
	_bg.color = Color(0, 0, 0, 0.7)
	_bg.modulate = Color(1, 1, 1, 0)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_label = Label.new()
	_label.add_theme_font_override("font", _dot_gothic)
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_label.custom_minimum_size = Vector2(0, 80)
	_label.modulate = Color(1, 1, 1, 0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

	_audio = AudioStreamPlayer.new()
	_audio.stream = _static_sound
	_audio.volume_db = -8
	add_child(_audio)

## Play a sequence of messages.
## Each entry: { "text": String, "duration": float }
func play_messages(messages: Array) -> void:
	_messages = messages
	_current = 0
	_play_next()

func _play_next() -> void:
	if _current >= _messages.size():
		_hide()
		return

	var msg = _messages[_current]
	_label.text = msg["text"]

	# Static burst + fade in
	_audio.play()
	var tween = create_tween().set_parallel(true)
	tween.tween_property(_bg, "modulate:a", 1.0, 0.3)
	tween.tween_property(_label, "modulate:a", 1.0, 0.3)
	await tween.finished

	# Hold
	await get_tree().create_timer(msg["duration"]).timeout

	# Fade out
	var out_tween = create_tween().set_parallel(true)
	out_tween.tween_property(_bg, "modulate:a", 0.0, 0.3)
	out_tween.tween_property(_label, "modulate:a", 0.0, 0.3)
	await out_tween.finished

	# Pause between messages
	await get_tree().create_timer(0.5).timeout

	_current += 1
	_play_next()

func _hide() -> void:
	finished.emit()
	queue_free()
