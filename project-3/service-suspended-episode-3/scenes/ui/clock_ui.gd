extends CanvasLayer

## Clock close-up UI with variant selection.
## When clock has hands:
##   - First open (no selection): shows closeup_no_selection
##   - Hover over quadrant: shows that variant's closeup sprite
##   - Move off: returns to no_selection (or active variant if one is set)
##   - Click quadrant: loading screen → switch to that room variant
##   - Subsequent opens: shows active variant's closeup, hover still works

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

func _update_display() -> void:
	if not _has_hands:
		_clock_sprite.texture = _ui_no_hands
		return

	# If a variant is active, show that closeup. Otherwise no selection.
	if GameState.current_variant > 0 and GameState.current_variant <= 4:
		# Check if this is the first time (game starts in variant 1 but
		# we treat it as "no selection" until the player actually picks)
		if not GameState.has_selected_variant:
			_clock_sprite.texture = _closeup_no_selection
		else:
			_clock_sprite.texture = _closeup_variants[GameState.current_variant - 1]
	else:
		_clock_sprite.texture = _closeup_no_selection

func _process(_delta: float) -> void:
	if not _has_hands:
		return
	var mouse = get_viewport().get_mouse_position()
	# Convert mouse to local 128x128 sprite coords
	# Sprite is centered, so (0,0) in local = center of the 128x128 image
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
	# Angle from 12 o'clock, going clockwise, with rotation offset
	var rot = deg_to_rad(BOUNDS_ROTATION)
	var angle = atan2(from_center.x, -from_center.y) - rot
	if angle < 0:
		angle += TAU
	if angle >= TAU:
		angle -= TAU
	if angle < PI / 2.0:
		return 1  # Variant 1
	elif angle < PI:
		return 2  # Variant 2
	elif angle < 3.0 * PI / 2.0:
		return 3  # Variant 3
	else:
		return 4  # Variant 4

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		clock_closed.emit()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse = event.position

		# Inventory clicks
		var coordinator = get_tree().root.find_child("Node2D", true, false)
		if coordinator and coordinator.has_method("_handle_inventory_click"):
			if coordinator._handle_inventory_click(mouse):
				return

		# Insert clock hands if applicable
		if GameState.has_clock_hands and not GameState.clock_hands_inserted:
			var center = _clock_sprite.position
			var half = Vector2(64, 64) * _clock_sprite.scale
			if Rect2(center - half, half * 2).has_point(mouse):
				_insert_hands()
				get_viewport().set_input_as_handled()
				return

		# Select variant if hovering over a quadrant
		if _has_hands and _hovered_variant > 0:
			_select_variant(_hovered_variant)
			get_viewport().set_input_as_handled()

func _insert_hands() -> void:
	GameState.insert_clock_hands()
	_has_hands = true
	_clock_sprite.texture = _closeup_no_selection
	hands_inserted.emit()

func _select_variant(variant: int) -> void:
	GameState.has_selected_variant = true
	GameState.current_variant = variant
	variant_selected.emit(variant)
