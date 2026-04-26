extends Node

@export var auto_start_delay: float = 0.8
@export var auto_start: bool = true
@export_enum("south", "south_east", "east", "north_east", "north", "north_west", "west", "south_west") var preview_direction: String = "south"

@onready var jungle: Node2D = $Jungle

var _preview_started: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.reset_health()
	GameState.trial_start = false
	GameState.trial_time_remaining = 0.0
	call_deferred("_configure_preview_player")
	if auto_start:
		call_deferred("_start_preview_after_delay")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_trigger_preview()
		_mark_input_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		_mark_input_handled()
		get_tree().reload_current_scene()

func _start_preview_after_delay() -> void:
	await get_tree().create_timer(auto_start_delay).timeout
	_trigger_preview()

func _trigger_preview() -> void:
	if _preview_started:
		return
	if jungle and jungle.has_method("trigger_ghost_death_preview"):
		_preview_started = bool(jungle.call("trigger_ghost_death_preview"))

func _configure_preview_player() -> void:
	var player := _get_preview_player()
	if player and player.has_method("set_preview_direction"):
		player.call("set_preview_direction", preview_direction)

func _get_preview_player() -> CharacterBody2D:
	if jungle and jungle.has_method("get_section_player"):
		var player = jungle.call("get_section_player")
		if player is CharacterBody2D:
			return player
	return null

func _mark_input_handled() -> void:
	var viewport := get_viewport()
	if viewport:
		viewport.set_input_as_handled()
