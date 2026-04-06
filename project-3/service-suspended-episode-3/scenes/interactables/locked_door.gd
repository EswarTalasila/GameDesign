extends Area2D

## Locked door — shows animated lock icon, Press E prompt when puzzle is solved.
## Does not open visually. Press E when locked flashes the lock red.

@onready var _prompt: AnimatedSprite2D = $PressEPrompt
@onready var _lock_icon: AnimatedSprite2D = $LockIcon

var _player_in_range: bool = false
var _unlocked: bool = false

## Scene to load when the player uses the unlocked door
@export var next_scene: String = ""

func _ready() -> void:
	add_to_group("locked_doors")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_prompt.visible = false
	_lock_icon.visible = false

func unlock() -> void:
	_unlocked = true
	_lock_icon.visible = false
	if _player_in_range:
		_prompt.visible = true

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		_player_in_range = true
		if _unlocked:
			_prompt.visible = true
		else:
			_lock_icon.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		_player_in_range = false
		_prompt.visible = false
		_lock_icon.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range or not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	if not _unlocked:
		_flash_lock()
	else:
		_on_door_used()

func _flash_lock() -> void:
	var tween = create_tween()
	tween.tween_property(_lock_icon, "modulate", Color(1, 0.3, 0.3), 0.15)
	tween.tween_property(_lock_icon, "modulate", Color.WHITE, 0.15)

func _on_door_used() -> void:
	var ending = preload("res://scenes/ui/ending_screen.tscn").instantiate()
	get_tree().root.add_child(ending)
