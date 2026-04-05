extends Area2D

## Map board on the wall. Press E to open the map assembly UI.
## Only interactable if player has at least 1 map piece.

@onready var _prompt: AnimatedSprite2D = $PressEPrompt

var _player_in_range: bool = false
var _ui_open: bool = false
var _board_ui_scene = preload("res://scenes/ui/map_board_ui.tscn")
var _board_ui: CanvasLayer = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" and not GameState.map_assembled:
		_player_in_range = true
		_prompt.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		_player_in_range = false
		_prompt.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and not _ui_open and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_open_ui()

func _open_ui() -> void:
	_ui_open = true
	_prompt.visible = false
	get_tree().paused = true
	_board_ui = _board_ui_scene.instantiate()
	_board_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	_board_ui.board_closed.connect(_close_ui)
	_board_ui.map_completed.connect(_on_map_completed)
	get_tree().root.add_child(_board_ui)

func _close_ui() -> void:
	_ui_open = false
	get_tree().paused = false
	if _board_ui:
		_board_ui.queue_free()
		_board_ui = null
	if _player_in_range and not GameState.map_assembled:
		_prompt.visible = true

func _on_map_completed() -> void:
	GameState.map_assembled = true
	_close_ui()
