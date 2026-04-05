extends CanvasLayer

## Close-up clock UI. Shows no-hands or with-hands version.
## When clock hands cursor is active and player clicks the clock, hands get inserted.

signal clock_closed
signal hands_inserted

@onready var _clock_sprite: Sprite2D = $ClockSprite

var _ui_no_hands = preload("res://assets/ui/clock/ui_no_hands.png")
var _ui_with_hands = preload("res://assets/ui/clock/ui_with_hands.png")

func _ready() -> void:
	layer = 8
	if GameState.clock_hands_inserted:
		_clock_sprite.texture = _ui_with_hands
	else:
		_clock_sprite.texture = _ui_no_hands

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		clock_closed.emit()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Check if clicking the clock with clock hands cursor
		if GameState.has_clock_hands and not GameState.clock_hands_inserted:
			var mouse = event.position
			var center = _clock_sprite.position
			var half = Vector2(64, 64) * _clock_sprite.scale
			if Rect2(center - half, half * 2).has_point(mouse):
				_insert_hands()
				get_viewport().set_input_as_handled()

func _insert_hands() -> void:
	GameState.insert_clock_hands()
	_clock_sprite.texture = _ui_with_hands
	CustomCursor.reset_cursor()
	hands_inserted.emit()
