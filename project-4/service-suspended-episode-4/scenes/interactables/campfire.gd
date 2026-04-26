extends Node2D

signal ignited

const CAMPFIRE_UI_SCENE := preload("res://scenes/ui/campfire_ui.tscn")
const CAMPFIRE_RELIGHT_UI_SCENE := preload("res://scenes/ui/campfire_relight_ui.tscn")
const TRIAL_DIALOGUE := preload("res://dialogues/campfire_trial.dialogue")

@export var lit: bool = false:
	set(value):
		lit = value
		_apply_state()

@export var auto_start_trial: bool = true
@export var burn_duration_seconds: float = 60.0
@export_range(1, 9, 1) var upkeep_wood_cost: int = 1
@export_range(1, 9, 1) var relight_wood_cost: int = 3
@export_range(1, 9, 1) var relight_ticket_cost: int = 1
@export_range(0.05, 1.0, 0.01) var min_fire_scale_ratio: float = 0.22

@onready var off_sprite: Sprite2D = $OffSprite
@onready var on_sprite: Sprite2D = $OnSprite
@onready var fire: Node2D = $Fire
@onready var prompt: CanvasItem = $InteractZone/PressEPrompt
@onready var interact_zone: Area2D = $InteractZone

var _player_nearby: bool = false
var _intro_running: bool = false
var _base_fire_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	add_to_group("campfire")
	GameState.configure_campfire(burn_duration_seconds)
	_base_fire_scale = fire.scale
	lit = GameState.campfire_lit
	_apply_state()
	interact_zone.body_entered.connect(_on_body_entered)
	interact_zone.body_exited.connect(_on_body_exited)
	if not GameState.campfire_state_changed.is_connected(_on_campfire_state_changed):
		GameState.campfire_state_changed.connect(_on_campfire_state_changed)
	if not GameState.campfire_burn_changed.is_connected(_on_campfire_burn_changed):
		GameState.campfire_burn_changed.connect(_on_campfire_burn_changed)

func _input(event: InputEvent) -> void:
	if not _player_nearby or _intro_running:
		return
	if event.is_action_pressed("interact"):
		_open_interaction_ui()

func ignite() -> void:
	var was_lit := lit
	GameState.ignite_campfire(burn_duration_seconds)
	if auto_start_trial:
		GameState.start_trial()
	if not was_lit:
		ignited.emit()

func can_feed_fire() -> bool:
	return lit and GameState.has_inventory_item(GameState.ITEM_WOOD, upkeep_wood_cost)

func feed_fire_with_wood() -> bool:
	if not lit or not GameState.has_inventory_item(GameState.ITEM_WOOD, upkeep_wood_cost):
		return false
	if not GameState.consume_inventory_item(GameState.ITEM_WOOD, upkeep_wood_cost):
		return false
	GameState.ignite_campfire(burn_duration_seconds)
	return true

func can_relight_fire() -> bool:
	return (
		not lit
		and GameState.has_inventory_item(GameState.ITEM_WOOD, relight_wood_cost)
		and GameState.has_inventory_item(GameState.ITEM_SPECIAL_TICKET, relight_ticket_cost)
	)

func relight_fire() -> bool:
	if lit or not can_relight_fire():
		return false
	if not GameState.consume_inventory_item(GameState.ITEM_WOOD, relight_wood_cost):
		return false
	if not GameState.consume_inventory_item(GameState.ITEM_SPECIAL_TICKET, relight_ticket_cost):
		GameState.add_inventory_item(GameState.ITEM_WOOD, relight_wood_cost)
		return false
	ignite()
	return true

func get_upkeep_wood_cost() -> int:
	return upkeep_wood_cost

func get_relight_wood_cost() -> int:
	return relight_wood_cost

func get_relight_ticket_cost() -> int:
	return relight_ticket_cost

func _open_interaction_ui() -> void:
	var ui := _get_or_create_overlay(
		"campfire_ui_overlay" if lit else "campfire_relight_ui_overlay",
		CAMPFIRE_UI_SCENE if lit else CAMPFIRE_RELIGHT_UI_SCENE
	)
	if ui and ui.has_method("open"):
		ui.open(self)

func _on_body_entered(body: Node2D) -> void:
	if not body is CharacterBody2D:
		return
	_player_nearby = true
	if not lit and not GameState.campfire_intro_played and not _intro_running:
		_play_intro_and_ignite()
	else:
		_update_prompt()

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

func _on_campfire_state_changed(is_lit: bool) -> void:
	lit = is_lit

func _on_campfire_burn_changed(_remaining_seconds: float, _duration_seconds: float) -> void:
	_apply_fire_scale()

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
	_apply_fire_scale()
	_update_prompt()

func _apply_fire_scale() -> void:
	if fire == null:
		return
	var burn_ratio := 0.0
	if GameState.campfire_burn_duration > 0.0:
		burn_ratio = clampf(
			GameState.campfire_burn_remaining / GameState.campfire_burn_duration,
			0.0,
			1.0
		)
	var scale_ratio := lerpf(min_fire_scale_ratio, 1.0, burn_ratio)
	fire.scale = _base_fire_scale * scale_ratio

func _update_prompt() -> void:
	if prompt:
		prompt.visible = _player_nearby and not _intro_running

func _get_or_create_overlay(group_name: String, scene: PackedScene) -> Node:
	var ui: Node = get_tree().get_first_node_in_group(group_name)
	if ui:
		return ui
	ui = scene.instantiate()
	var scene_root: Node = get_tree().current_scene
	if scene_root:
		scene_root.add_child(ui)
	else:
		get_tree().root.add_child(ui)
	return ui
