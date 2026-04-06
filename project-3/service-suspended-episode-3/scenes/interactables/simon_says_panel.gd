extends Area2D

## Simon says panel. Press E to open. Two phases:
## Phase 1: Enter the key sequence (shown by door lights on room entry)
## Phase 2: Standard simon says with random sequences

@onready var _prompt: AnimatedSprite2D = $PressEPrompt

var _player_in_range: bool = false
var _ui_open: bool = false
var _simon_ui_scene = preload("res://scenes/ui/simon_says_ui.tscn")
var _simon_ui: CanvasLayer = null

const COLOR_TINTS = {
	"red": Vector3(0.8, 0.1, 0.1),
	"blue": Vector3(0.1, 0.1, 0.8),
	"green": Vector3(0.1, 0.8, 0.1),
	"black": Vector3(0.0, 0.0, 0.0),
}

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if GameState.simon_solved:
		_prompt.visible = false
	if GameState.simon_key_sequence.size() == 0:
		var key = ["red", "blue", "green", "black"]
		key.shuffle()
		GameState.simon_key_sequence = key
	# Flash light sequence after 5 second delay
	if not GameState.simon_solved:
		_flash_lights_on_entry()

func _flash_lights_on_entry() -> void:
	await get_tree().create_timer(5.0).timeout
	if not is_inside_tree():
		return
	var player = get_tree().root.find_child("Player", true, false)
	if player == null:
		return
	var mat = player._vision_material
	if mat == null:
		return
	for color_name in GameState.simon_key_sequence:
		if not is_inside_tree():
			return
		var tint = COLOR_TINTS.get(color_name, Vector3.ZERO)
		if color_name == "black":
			# Black = light off, no glow
			mat.set_shader_parameter("light_tint", Vector3.ZERO)
			mat.set_shader_parameter("light_tint_strength", 0.0)
		else:
			mat.set_shader_parameter("light_tint", tint)
			mat.set_shader_parameter("light_tint_strength", 0.6)
		await get_tree().create_timer(0.6).timeout
		mat.set_shader_parameter("light_tint", Vector3.ZERO)
		mat.set_shader_parameter("light_tint_strength", 0.0)
		await get_tree().create_timer(0.3).timeout

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" and not GameState.simon_solved:
		_player_in_range = true
		_prompt.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		_player_in_range = false
		_prompt.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and not _ui_open and not GameState.simon_solved and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_open_ui()

func _open_ui() -> void:
	_ui_open = true
	_prompt.visible = false
	get_tree().paused = true
	_simon_ui = _simon_ui_scene.instantiate()
	_simon_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	_simon_ui.puzzle_closed.connect(_close_ui)
	_simon_ui.puzzle_solved.connect(_on_solved)
	get_tree().root.add_child(_simon_ui)

func _close_ui() -> void:
	_ui_open = false
	get_tree().paused = false
	if _simon_ui:
		_simon_ui.queue_free()
		_simon_ui = null
	if _player_in_range and not GameState.simon_solved:
		_prompt.visible = true

func _on_solved() -> void:
	GameState.simon_solved = true
	_close_ui()
