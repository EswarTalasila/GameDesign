extends CanvasLayer

## Close-up clock UI. Shows no-hands or with-hands version.
## Inventory clicks work while this is open.

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
		var mouse = event.position

		# Let inventory clicks through — find room coordinator and delegate
		var coordinator = get_tree().root.find_child("Node2D", true, false)
		if coordinator and coordinator.has_method("_handle_inventory_click"):
			var handled = coordinator._handle_inventory_click(mouse)
			if handled:
				return

		# Check if clicking the clock with clock hands to insert them
		if GameState.has_clock_hands and not GameState.clock_hands_inserted:
			var center = _clock_sprite.position
			var half = Vector2(64, 64) * _clock_sprite.scale
			if Rect2(center - half, half * 2).has_point(mouse):
				_insert_hands()
				get_viewport().set_input_as_handled()

func _insert_hands() -> void:
	GameState.insert_clock_hands()
	_clock_sprite.texture = _ui_with_hands
	hands_inserted.emit()
