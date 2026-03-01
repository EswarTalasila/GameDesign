extends Node2D

@onready var bubble: PanelContainer = $CanvasLayer/DialogBubble
@onready var player: CharacterBody2D = $FloorWalls/Player
@onready var punch_zone: Area2D = $PunchMachine/InteractZone
@onready var prompt_label: Label = $PunchMachine/PromptLabel

@export var cart_index: int = 0

var _near_punch: bool = false

var _intro_lines: Array[Dictionary] = [
	{"text": "Another car... The train stretches on forever.", "speaker": "You"},
	{"text": "There's a ticket punch machine here.", "speaker": ""},
	{"text": "Maybe if I punch my ticket, I can move forward.", "speaker": "You"},
]

var _return_lines: Array[Dictionary] = [
	{"text": "Back again. The next car awaits.", "speaker": "You"},
]

var _current_line: int = 0
var _dialog_done: bool = false

func _ready() -> void:
	bubble.finished.connect(_on_bubble_finished)
	punch_zone.body_entered.connect(_on_punch_zone_entered)
	punch_zone.body_exited.connect(_on_punch_zone_exited)
	prompt_label.visible = false

	# Show intro or return dialog
	await get_tree().create_timer(0.5).timeout
	if GameState.current_cart_index > 0:
		_intro_lines = _return_lines
	_show_next_line()

func _show_next_line() -> void:
	if _current_line >= _intro_lines.size():
		_dialog_done = true
		return
	var line = _intro_lines[_current_line]
	bubble.show_text(line["text"], line["speaker"])

func _on_bubble_finished() -> void:
	_current_line += 1

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and not bubble.visible and _current_line < _intro_lines.size():
		_show_next_line()

	if event.is_action_pressed("interact") and _near_punch:
		_enter_dungeon()

func _on_punch_zone_entered(_body: Node2D) -> void:
	_near_punch = true
	prompt_label.visible = true

func _on_punch_zone_exited(_body: Node2D) -> void:
	_near_punch = false
	prompt_label.visible = false

func _enter_dungeon() -> void:
	player.set_physics_process(false)
	GameState.start_dungeon(cart_index, "standard", 5)

	var loading = preload("res://scenes/ui/loading_screen.tscn").instantiate()
	get_tree().root.add_child(loading)
	loading.transition_to("res://scenes/dungeon/dungeon.tscn")
