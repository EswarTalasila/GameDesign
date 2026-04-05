extends Area2D

## In-world electrical panel interactable.
## Place in scene, set collision shape to cover the panel tiles.
## When player enters range and presses E, opens the close-up puzzle UI.

@onready var _prompt: AnimatedSprite2D = $PressEPrompt
var _player_in_range: bool = false
var _puzzle_open: bool = false
var _puzzle_ui_scene = preload("res://scenes/ui/electrical_panel_ui.tscn")
var _puzzle_ui: CanvasLayer = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		_player_in_range = true
		_prompt.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		_player_in_range = false
		_prompt.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and not _puzzle_open and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_open_puzzle()

func _open_puzzle() -> void:
	_puzzle_open = true
	_prompt.visible = false
	get_tree().paused = true
	_puzzle_ui = _puzzle_ui_scene.instantiate()
	_puzzle_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	_puzzle_ui.puzzle_closed.connect(_close_puzzle)
	_puzzle_ui.puzzle_solved.connect(_on_puzzle_solved)
	get_tree().root.add_child(_puzzle_ui)
	# Pulse wire cutter icon if player has it
	if GameState.has_wire_cutter:
		var coordinator = get_tree().root.find_child("Node2D", true, false)
		if coordinator and coordinator.has_method("pulse_inventory_item"):
			coordinator.pulse_inventory_item("wire_cutter")

func _on_puzzle_solved() -> void:
	# Unlock all locked doors in the scene
	for door in get_tree().get_nodes_in_group("locked_doors"):
		door.unlock()
	_close_puzzle()

func _close_puzzle() -> void:
	_puzzle_open = false
	get_tree().paused = false
	if _puzzle_ui:
		_puzzle_ui.queue_free()
		_puzzle_ui = null
	if _player_in_range:
		_prompt.visible = true
