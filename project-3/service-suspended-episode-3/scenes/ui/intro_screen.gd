extends CanvasLayer

## Opening monologue. Plays once at the start of the game.
## Black screen with train ambience, two opening text cards, then fades out to reveal the room.

var _bg: ColorRect
var _speaker_label: Label
var _body_label: Label
var _sfx: AudioStreamPlayer
var _skipped: bool = false

var _dot_gothic = preload("res://assets/fonts/DotGothic16-Regular.ttf")
var _train_sound = preload("res://assets/sounds/train_sounds.mp3")

const LINES = [
	"You find yourself in an isolated room, cut off from the rest of the train.",
	"You remember seeing the Conductor laughing as he closed and locked the door.",
]

func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS

	var vp = get_viewport().get_visible_rect().size

	# Full black background
	_bg = ColorRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0, 0, 0, 1)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)

	# Small top label kept empty for spacing consistency.
	_speaker_label = Label.new()
	_speaker_label.text = ""
	_speaker_label.add_theme_font_override("font", _dot_gothic)
	_speaker_label.add_theme_font_size_override("font_size", 18)
	_speaker_label.add_theme_color_override("font_color", Color(0.55, 0.52, 0.42))
	_speaker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speaker_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_speaker_label.position.y -= 48
	_speaker_label.modulate.a = 0.0
	add_child(_speaker_label)

	# Main monologue body text
	_body_label = Label.new()
	_body_label.add_theme_font_override("font", _dot_gothic)
	_body_label.add_theme_font_size_override("font_size", 28)
	_body_label.add_theme_color_override("font_color", Color(0.88, 0.84, 0.70))
	_body_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_body_label.add_theme_constant_override("shadow_offset_x", 1)
	_body_label.add_theme_constant_override("shadow_offset_y", 1)
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.custom_minimum_size = Vector2(vp.x * 0.65, 0)
	_body_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_body_label.position.x -= vp.x * 0.325
	_body_label.position.y -= 10
	_body_label.modulate.a = 0.0
	add_child(_body_label)

	# Train ambience — quiet, muffled feel
	_sfx = AudioStreamPlayer.new()
	_sfx.stream = _train_sound
	_sfx.volume_db = -18
	_sfx.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_sfx)
	_sfx.play()

	_play_sequence()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		_skipped = true
	elif event is InputEventMouseButton and event.pressed:
		_skipped = true

func _wait(duration: float) -> void:
	_skipped = false
	var elapsed = 0.0
	while elapsed < duration and not _skipped:
		await get_tree().process_frame
		elapsed += get_process_delta_time()

func _fade(node: CanvasItem, target_alpha: float, duration: float) -> void:
	var tween = create_tween()
	tween.tween_property(node, "modulate:a", target_alpha, duration)
	await tween.finished

func _play_sequence() -> void:
	# Brief silence — just the train sound
	await _wait(1.8)

	# Show each line
	for i in range(LINES.size()):
		_body_label.text = LINES[i]
		_body_label.modulate.a = 0.0
		_speaker_label.modulate.a = 0.0

		# Fade in speaker tag then body
		await _fade(_speaker_label, 0.8, 0.6)
		await _fade(_body_label, 1.0, 0.9)

		# Hold — skip-able
		await _wait(4.5)

		# Fade out
		var out = create_tween().set_parallel(true)
		out.tween_property(_body_label, "modulate:a", 0.0, 0.6)
		out.tween_property(_speaker_label, "modulate:a", 0.0, 0.4)
		await out.finished

		await _wait(0.4)

	# Fade out train sound and black overlay together → reveals the room
	var fade_out = create_tween().set_parallel(true)
	fade_out.tween_property(_bg, "color:a", 0.0, 1.4)
	fade_out.tween_method(func(v: float): _sfx.volume_db = v, -18.0, -80.0, 1.4)
	await fade_out.finished

	_sfx.stop()
	queue_free()
