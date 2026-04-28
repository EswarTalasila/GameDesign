extends CanvasLayer

## Clock UI overlay with 6-variant selection.
## Opens showing the selection frame for the current variant.
## Hover over a section (60° slice) to preview that variant's selection.
## Click to switch variants.

signal clock_closed
signal variant_selected(variant: int)

@export_range(0.0, 1.0) var dim_alpha: float = 0.68
@export var fade_in_time: float = 0.18
@export var fade_out_time: float = 0.14

@onready var _dimmer: ColorRect = $Dimmer
@onready var _clock_sprite: Sprite2D = $ClockSprite

var _selection_textures: Array[Texture2D] = []

# Clock face center in the 128x128 sprite
const CLOCK_CENTER = Vector2(64, 64)
const CLOCK_RADIUS = 38.0
# Rotation offset to align section boundaries with the clock art
const BOUNDS_ROTATION = 0.0

var _hovered_variant: int = 0  # 0 = none, 1-6 = section
var _selection_in_progress: bool = false

var _tooltip: Label = null
var _message_label: Label = null
var _message_tween: Tween = null
var _is_open: bool = false
var _is_closing: bool = false

func _ready() -> void:
	layer = 8
	_setup_fullscreen_rect(_dimmer)
	_selection_textures = [
		preload("res://assets/ui/clock/clock_selection_1.png"),
		preload("res://assets/ui/clock/clock_selection_2.png"),
		preload("res://assets/ui/clock/clock_selection_3.png"),
		preload("res://assets/ui/clock/clock_selection_4.png"),
		preload("res://assets/ui/clock/clock_selection_5.png"),
		preload("res://assets/ui/clock/clock_selection_6.png"),
	]
	_update_display()
	_setup_tooltip()
	_setup_message_label()
	_reset_fade_state()
	_fade_in()

func _setup_tooltip() -> void:
	var font_path = "res://assets/fonts/DotGothic16-Regular.ttf"
	_tooltip = Label.new()
	if ResourceLoader.exists(font_path):
		_tooltip.add_theme_font_override("font", load(font_path))
	_tooltip.add_theme_font_size_override("font_size", 24)
	_tooltip.add_theme_color_override("font_color", Color(0.9, 0.9, 0.8))
	_tooltip.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_tooltip.add_theme_constant_override("shadow_offset_x", 1)
	_tooltip.add_theme_constant_override("shadow_offset_y", 1)
	_tooltip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tooltip.visible = false
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var clock_bottom = _clock_sprite.position.y + 64 * _clock_sprite.scale.y
	_tooltip.position = Vector2(_clock_sprite.position.x - 150, clock_bottom + 16)
	_tooltip.custom_minimum_size = Vector2(300, 0)
	add_child(_tooltip)

func _setup_message_label() -> void:
	_message_label = Label.new()
	var font_path = "res://assets/fonts/DotGothic16-Regular.ttf"
	if ResourceLoader.exists(font_path):
		_message_label.add_theme_font_override("font", load(font_path))
	_message_label.add_theme_font_size_override("font_size", 30)
	_message_label.add_theme_color_override("font_color", Color.WHITE)
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

func _update_display() -> void:
	var idx = clampi(GameState.current_variant - 1, 0, 5)
	_clock_sprite.texture = _selection_textures[idx]

func _update_tooltip(variant: int) -> void:
	if variant == 0:
		_tooltip.visible = false
		return
	var warning := GameState.get_jungle_clock_warning(variant)
	if not warning.is_empty() and variant != GameState.current_variant:
		_tooltip.text = "Variant %d Locked" % variant
	else:
		_tooltip.text = "Variant %d" % variant
	_tooltip.visible = true

func _process(_delta: float) -> void:
	if _selection_in_progress or not _is_open or _is_closing:
		return
	var mouse = get_viewport().get_mouse_position()
	var local = (mouse - _clock_sprite.position) / _clock_sprite.scale + Vector2(64, 64)
	var from_center = local - CLOCK_CENTER
	var dist = from_center.length()

	if dist <= CLOCK_RADIUS:
		var section = _get_section(from_center)
		if section != _hovered_variant:
			_hovered_variant = section
			_clock_sprite.texture = _selection_textures[section - 1]
			_update_tooltip(section)
	else:
		if _hovered_variant != 0:
			_hovered_variant = 0
			_update_display()
			_update_tooltip(0)

func _get_section(from_center: Vector2) -> int:
	## Divide the clock face into 6 equal 60° sections.
	## Section 1 starts at top (12 o'clock), going clockwise.
	var rot = deg_to_rad(BOUNDS_ROTATION)
	var angle = atan2(from_center.x, -from_center.y) - rot
	if angle < 0:
		angle += TAU
	if angle >= TAU:
		angle -= TAU
	var section_angle = TAU / 6.0  # 60° per section
	var section = int(angle / section_angle) + 1
	return clampi(section, 1, 6)

func _input(event: InputEvent) -> void:
	if _selection_in_progress or _is_closing:
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _hovered_variant > 0:
			if _hovered_variant == GameState.current_variant:
				_show_message("You are already here.")
			else:
				var warning := GameState.get_jungle_clock_warning(_hovered_variant)
				if not warning.is_empty():
					_show_message(warning)
				else:
					_select_variant(_hovered_variant)
			get_viewport().set_input_as_handled()

func _select_variant(variant: int) -> void:
	if variant == GameState.current_variant:
		return
	_selection_in_progress = true
	GameState.has_selected_variant = true
	variant_selected.emit(variant)

func close() -> void:
	if _is_closing:
		return
	_is_closing = true
	_is_open = false
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_dimmer, "modulate:a", 0.0, fade_out_time)
	tween.tween_property(_clock_sprite, "modulate:a", 0.0, fade_out_time)
	if _tooltip:
		tween.tween_property(_tooltip, "modulate:a", 0.0, fade_out_time)
	if _message_label:
		tween.tween_property(_message_label, "modulate:a", 0.0, fade_out_time)
	await tween.finished
	clock_closed.emit()

func _fade_in() -> void:
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_dimmer, "modulate:a", dim_alpha, fade_in_time)
	tween.tween_property(_clock_sprite, "modulate:a", 1.0, fade_in_time)
	await tween.finished
	_is_open = true

func _reset_fade_state() -> void:
	_dimmer.modulate = Color(1, 1, 1, 0)
	_clock_sprite.modulate = Color(1, 1, 1, 0)
	if _tooltip:
		_tooltip.modulate = Color.WHITE
	if _message_label:
		_message_label.modulate = Color(1, 1, 1, 0)

func _setup_fullscreen_rect(rect: ColorRect) -> void:
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
