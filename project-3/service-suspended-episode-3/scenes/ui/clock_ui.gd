extends CanvasLayer

## Clock close-up UI with variant selection.
## When clock has hands:
##   - First open (no selection): shows closeup_no_selection
##   - Hover over quadrant: shows that variant's closeup sprite
##   - Move off: returns to no_selection (or active variant if one is set)
##   - Click quadrant: loading screen → switch to that room variant
##   - Subsequent opens: shows active variant's closeup, hover still works
##   - Locked variants show "The time resists..." on click
##   - Current variant shows "You are already here." on click
##   - Unlocked, non-current variants pulse with a sector glow

signal clock_closed
signal hands_inserted
signal variant_selected(variant: int)

@onready var _clock_sprite: Sprite2D = $ClockSprite

var _ui_no_hands = preload("res://assets/ui/clock/ui_no_hands.png")
var _ui_with_hands = preload("res://assets/ui/clock/ui_with_hands.png")
var _closeup_no_selection = preload("res://assets/ui/clock/closeup_no_selection.png")
var _closeup_variants: Array[Texture2D] = []

# Clock face center in the 128x128 sprite — matched from debug overlay
const CLOCK_CENTER = Vector2(65, 66)
# Radius from center that counts as "on the clock face"
const CLOCK_RADIUS = 24.0
# Rotation offset for quadrant boundaries (degrees)
const BOUNDS_ROTATION = -25.0

var _has_hands: bool = false
var _hovered_variant: int = 0  # 0 = none, 1-4 = quadrant

var _message_label: Label = null
var _message_tween: Tween = null
var _glow_overlay: Node2D = null
var _glow_alpha: float = 0.0
var _glow_time: float = 0.0

func _ready() -> void:
	layer = 8
	_closeup_variants = [
		preload("res://assets/ui/clock/closeup_variant_1.png"),
		preload("res://assets/ui/clock/closeup_variant_2.png"),
		preload("res://assets/ui/clock/closeup_variant_3.png"),
		preload("res://assets/ui/clock/closeup_variant_4.png"),
	]
	_has_hands = GameState.clock_hands_inserted
	_update_display()
	_setup_message_label()
	if _has_hands:
		_setup_glow_overlay()

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

func _setup_glow_overlay() -> void:
	_glow_overlay = Node2D.new()
	_glow_overlay.position = _clock_sprite.position
	_glow_overlay.scale = _clock_sprite.scale
	_glow_overlay.z_index = 1
	add_child(_glow_overlay)
	_glow_overlay.set_script(preload("res://scenes/ui/clock_glow_overlay.gd"))
	_glow_overlay.clock_ui = self

func _is_variant_locked(variant: int) -> bool:
	match variant:
		1: return false
		2: return not GameState.suitcase_solved
		3: return not GameState.simon_solved
		4: return not GameState.computer_lock_solved
	return true

func _is_variant_available(variant: int) -> bool:
	return not _is_variant_locked(variant) and variant != GameState.current_variant

func _update_display() -> void:
	if not _has_hands:
		_clock_sprite.texture = _ui_no_hands
		return

	if GameState.current_variant > 0 and GameState.current_variant <= 4:
		if not GameState.has_selected_variant:
			_clock_sprite.texture = _closeup_no_selection
		else:
			_clock_sprite.texture = _closeup_variants[GameState.current_variant - 1]
	else:
		_clock_sprite.texture = _closeup_no_selection

func _process(delta: float) -> void:
	if not _has_hands:
		return

	# Pulse glow
	_glow_time += delta
	_glow_alpha = (sin(_glow_time * 2.5) + 1.0) / 2.0 * 0.25 + 0.05
	if _glow_overlay:
		_glow_overlay.queue_redraw()

	var mouse = get_viewport().get_mouse_position()
	var local = (mouse - _clock_sprite.position) / _clock_sprite.scale + Vector2(64, 64)
	var from_center = local - CLOCK_CENTER
	var dist = from_center.length()

	if dist <= CLOCK_RADIUS:
		var quadrant = _get_quadrant(from_center)
		if quadrant != _hovered_variant:
			_hovered_variant = quadrant
			_clock_sprite.texture = _closeup_variants[quadrant - 1]
	else:
		if _hovered_variant != 0:
			_hovered_variant = 0
			_update_display()

func _get_quadrant(from_center: Vector2) -> int:
	var rot = deg_to_rad(BOUNDS_ROTATION)
	var angle = atan2(from_center.x, -from_center.y) - rot
	if angle < 0:
		angle += TAU
	if angle >= TAU:
		angle -= TAU
	if angle < PI / 2.0:
		return 1
	elif angle < PI:
		return 2
	elif angle < 3.0 * PI / 2.0:
		return 3
	else:
		return 4

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		clock_closed.emit()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse = event.position

		var coordinator = get_tree().root.find_child("Node2D", true, false)
		if coordinator and coordinator.has_method("_handle_inventory_click"):
			if coordinator._handle_inventory_click(mouse):
				return

		if GameState.has_clock_hands and not GameState.clock_hands_inserted:
			var center = _clock_sprite.position
			var half = Vector2(64, 64) * _clock_sprite.scale
			if Rect2(center - half, half * 2).has_point(mouse):
				_insert_hands()
				get_viewport().set_input_as_handled()
				return

		if _has_hands and _hovered_variant > 0:
			if _hovered_variant == GameState.current_variant:
				_show_message("You are already here.")
			elif _is_variant_locked(_hovered_variant):
				_show_message("The time resists...")
			else:
				_select_variant(_hovered_variant)
			get_viewport().set_input_as_handled()

func _insert_hands() -> void:
	GameState.insert_clock_hands()
	_has_hands = true
	_clock_sprite.texture = _closeup_no_selection
	hands_inserted.emit()
	_setup_glow_overlay()

func _select_variant(variant: int) -> void:
	GameState.has_selected_variant = true
	GameState.current_variant = variant
	variant_selected.emit(variant)
