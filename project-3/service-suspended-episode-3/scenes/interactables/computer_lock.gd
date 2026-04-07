extends Area2D

## Computer lock terminal. Press E to open. Type the code, hit Enter.

@export var code: String = "free"
@export var reward_piece_id: int = 3

@onready var _prompt: AnimatedSprite2D = $PressEPrompt

var _player_in_range: bool = false
var _ui_open: bool = false
var _ui_scene = preload("res://scenes/ui/computer_lock_ui.tscn")
var _ui: CanvasLayer = null
var _map_pickup_scene = preload("res://scenes/pickups/map_piece_pickup.tscn")

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if GameState.computer_lock_solved:
		_prompt.visible = false

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" and not GameState.computer_lock_solved:
		_player_in_range = true
		_prompt.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		_player_in_range = false
		_prompt.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and not _ui_open and not GameState.computer_lock_solved and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_open_ui()

func _open_ui() -> void:
	_ui_open = true
	_prompt.visible = false
	get_tree().paused = true
	_ui = _ui_scene.instantiate()
	_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	_ui.code = code
	_ui.puzzle_closed.connect(_close_ui)
	_ui.puzzle_solved.connect(_on_solved)
	get_tree().root.add_child(_ui)

func _close_ui() -> void:
	_ui_open = false
	get_tree().paused = false
	if _ui:
		_ui.queue_free()
		_ui = null
	if _player_in_range and not GameState.computer_lock_solved:
		_prompt.visible = true

func _on_solved() -> void:
	GameState.computer_lock_solved = true
	_close_ui()
	if not GameState.has_map_piece(reward_piece_id):
		var pickup = _map_pickup_scene.instantiate()
		pickup.piece_id = reward_piece_id
		pickup.global_position = $RewardSpawn.global_position
		get_parent().add_child(pickup)
