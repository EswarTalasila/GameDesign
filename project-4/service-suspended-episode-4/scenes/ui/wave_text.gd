@tool
extends Control

@export var text: String = "Choose a boon":
	set(value):
		text = value
		_rebuild()

@export var font: Font:
	set(value):
		font = value
		_rebuild()

@export var font_size: int = 42:
	set(value):
		font_size = value
		_rebuild()

@export var letter_spacing: float = 0.0:
	set(value):
		letter_spacing = value
		_rebuild()

@export var font_color: Color = Color.WHITE:
	set(value):
		font_color = value
		_rebuild()

@export var shadow_color: Color = Color(0, 0, 0, 0):
	set(value):
		shadow_color = value
		_rebuild()

@export var shadow_offset_x: int = 0:
	set(value):
		shadow_offset_x = value
		_rebuild()

@export var shadow_offset_y: int = 0:
	set(value):
		shadow_offset_y = value
		_rebuild()

@export var wave_amplitude: float = 3.0
@export var wave_speed: float = 2.4
@export var wave_step: float = 0.52

var _time: float = 0.0
var _letters: Array[Label] = []
var _base_positions: Array[Vector2] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rebuild()
	set_process(true)

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	for i in range(_letters.size()):
		var label: Label = _letters[i]
		var base_position: Vector2 = _base_positions[i]
		var phase: float = _time * wave_speed - float(i) * wave_step
		var lift: float = sin(phase) * wave_amplitude
		label.position = base_position + Vector2(0, -lift)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_rebuild()

func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		child.queue_free()
	_letters.clear()
	_base_positions.clear()
	if font == null or text.is_empty():
		return

	var chars: Array[String] = []
	var total_width: float = 0.0
	for i in range(text.length()):
		var character: String = text.substr(i, 1)
		chars.append(character)
		total_width += _get_char_size(character).x
		if i < text.length() - 1:
			total_width += letter_spacing

	var x: float = (size.x - total_width) * 0.5
	var y: float = (size.y - _get_char_size("M").y) * 0.5
	for character in chars:
		var label: Label = Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", font_color)
		label.add_theme_color_override("font_shadow_color", shadow_color)
		label.add_theme_constant_override("shadow_offset_x", shadow_offset_x)
		label.add_theme_constant_override("shadow_offset_y", shadow_offset_y)
		label.text = character
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(label)
		var char_size: Vector2 = _get_char_size(character)
		label.size = char_size
		var base_position: Vector2 = Vector2(x, y)
		label.position = base_position
		_letters.append(label)
		_base_positions.append(base_position)
		x += char_size.x + letter_spacing

func _get_char_size(character: String) -> Vector2:
	if character == " ":
		return Vector2(font.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x * 0.55, font_size)
	return font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
