extends Node2D

signal ignited

const CAMPFIRE_UI_SCENE := preload("res://scenes/ui/campfire_ui.tscn")
const TRIAL_DIALOGUE := preload("res://dialogues/campfire_trial.dialogue")

@export var lit: bool = false:
	set(value):
		lit = value
		_apply_state()

@export var auto_start_trial: bool = true

@onready var off_sprite: Sprite2D = $OffSprite
@onready var on_sprite: Sprite2D = $OnSprite
@onready var fire: Node2D = $Fire
@onready var prompt: CanvasItem = $InteractZone/PressEPrompt
@onready var interact_zone: Area2D = $InteractZone

var _player_nearby: bool = false
var _intro_running: bool = false

func _ready() -> void:
	if GameState.trial_start:
		lit = true
	_apply_state()
	interact_zone.body_entered.connect(_on_body_entered)
	interact_zone.body_exited.connect(_on_body_exited)

func _input(event: InputEvent) -> void:
	if not lit or not _player_nearby:
		return
	if event.is_action_pressed("interact"):
		var ui: Node = _get_or_create_campfire_ui()
		if ui and ui.has_method("open"):
			ui.open()

func ignite() -> void:
	if lit:
		return
	lit = true
	_apply_state()
	ignited.emit()
	if auto_start_trial:
		GameState.start_trial()

func _on_body_entered(body: Node2D) -> void:
	if not body is CharacterBody2D:
		return
	_player_nearby = true
	if lit:
		_update_prompt()
	elif not GameState.campfire_intro_played and not _intro_running:
		_play_intro_and_ignite()

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player_nearby = false
		_update_prompt()

func _play_intro_and_ignite() -> void:
	_intro_running = true
	GameState.campfire_intro_played = true
	DialogueManager.show_dialogue_balloon(TRIAL_DIALOGUE, "start")
	await DialogueManager.dialogue_ended
	ignite()
	_intro_running = false
	_update_prompt()

func _apply_state() -> void:
	if not is_inside_tree():
		return
	off_sprite.visible = not lit
	on_sprite.visible = lit
	fire.visible = lit
	if fire.has_method("play_fire"):
		if lit:
			fire.play_fire()
		else:
			fire.stop()
	_update_prompt()

func _update_prompt() -> void:
	if prompt:
		prompt.visible = lit and _player_nearby and not _intro_running

func _get_or_create_campfire_ui() -> Node:
	var ui: Node = get_tree().get_first_node_in_group("campfire_ui_overlay")
	if ui:
		return ui
	ui = CAMPFIRE_UI_SCENE.instantiate()
	var scene_root: Node = get_tree().current_scene
	if scene_root:
		scene_root.add_child(ui)
	else:
		get_tree().root.add_child(ui)
	return ui
