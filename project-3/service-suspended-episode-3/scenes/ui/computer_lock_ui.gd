extends CanvasLayer

## Computer lock screen UI. Type characters, backspace to delete, enter to submit.

signal puzzle_closed
signal puzzle_solved

var code: String = "free"

var _input_buffer: String = ""
var _max_chars: int = 4
var _locked: bool = false  # prevent input during success/wrong display

@onready var _screen: AnimatedSprite2D = $Screen

var _message_label: Label = null
var _message_tween: Tween = null

func _ready() -> void:
	layer = 8
	_screen.play("no_input")
	_setup_message_label()
	_show_message("Enter the password.")

func _setup_message_label() -> void:
	var dot_gothic = load("res://assets/fonts/DotGothic16-Regular.ttf")
	_message_label = Label.new()
	_message_label.add_theme_font_override("font", dot_gothic)
	_message_label.add_theme_font_size_override("font_size", 28)
	_message_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.65))
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_message_label.offset_top = -80
	_message_label.modulate = Color(1, 1, 1, 0)
	_message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_message_label)

func _show_message(text: String) -> void:
	if _message_tween and _message_tween.is_valid():
		_message_tween.kill()
	_message_label.text = text
	_message_label.modulate.a = 1.0
	_message_tween = create_tween()
	_message_tween.tween_interval(1.5)
	_message_tween.tween_property(_message_label, "modulate:a", 0.0, 0.5)

func _input(event: InputEvent) -> void:
	if _locked:
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		puzzle_closed.emit()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			_submit()
			return

		if event.keycode == KEY_BACKSPACE:
			get_viewport().set_input_as_handled()
			if _input_buffer.length() > 0:
				_input_buffer = _input_buffer.substr(0, _input_buffer.length() - 1)
				_update_display()
			return

		# Only accept letters
		var unicode = event.unicode
		if unicode > 31 and unicode < 127:
			get_viewport().set_input_as_handled()
			var c = char(unicode)
			if c.to_lower() >= "a" and c.to_lower() <= "z":
				if _input_buffer.length() < _max_chars:
					_input_buffer += c
					_update_display()
			else:
				_show_message("Letters only")

func _update_display() -> void:
	var count = _input_buffer.length()
	match count:
		0: _screen.play("no_input")
		1: _screen.play("input_1")
		2: _screen.play("input_2")
		3: _screen.play("input_3")
		4: _screen.play("input_4")

func _submit() -> void:
	_locked = true
	if _input_buffer.to_lower() == code.to_lower():
		_screen.play("success")
		await get_tree().create_timer(0.5).timeout
		puzzle_solved.emit()
	else:
		_screen.play("wrong")
		await get_tree().create_timer(0.5).timeout
		_input_buffer = ""
		_update_display()
		_locked = false
