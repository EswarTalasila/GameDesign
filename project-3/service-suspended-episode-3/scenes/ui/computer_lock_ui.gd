extends CanvasLayer

## Computer lock screen UI. Type characters, backspace to delete, enter to submit.

signal puzzle_closed
signal puzzle_solved

var code: String = "free"

var _input_buffer: String = ""
var _max_chars: int = 4
var _locked: bool = false  # prevent input during success/wrong display

@onready var _screen: AnimatedSprite2D = $Screen

func _ready() -> void:
	layer = 8
	_screen.play("no_input")

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

		# Accept printable characters
		var unicode = event.unicode
		if unicode > 31 and unicode < 127 and _input_buffer.length() < _max_chars:
			get_viewport().set_input_as_handled()
			_input_buffer += char(unicode)
			_update_display()

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
