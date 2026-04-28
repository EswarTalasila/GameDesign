@tool
extends Node2D

const STONE_PUZZLE_UI_SCENE := preload("res://scenes/ui/stone_puzzle_ui.tscn")
const STONE_ROCK_SCENE := preload("res://scenes/stone_puzzle/stone_rock.tscn")
const STONE_ALTAR_INTRO_DIALOGUE := preload("res://dialogues/stone_altar_intro.dialogue")
const INTERACTION_PRIORITY := 2
const MAP_PIECE_TOTAL := 4
const MAP_PIECE_QUEST_ID := "find_map_pieces"
const TALK_CAT_OBJECTIVE_ID := "talk_cat"
const SLOT_ORDER := [
	"North",
	"NorthEast",
	"East",
	"SouthEast",
	"South",
	"SouthWest",
	"West",
	"NorthWest",
]

@export_range(0, 4, 1) var reward_map_piece_id: int = 0
@export var intro_text: String = "TODO"
@export var orbit_radius_x_min: float = 26.0
@export var orbit_radius_x_max: float = 42.0
@export var orbit_radius_y_min: float = 12.0
@export var orbit_radius_y_max: float = 20.0
@export var orbit_speed_min: float = 0.45
@export var orbit_speed_max: float = 0.8
@export var floating_rock_scale_multiplier: Vector2 = Vector2(0.3, 0.3)
@export var solved_rock_scale_multiplier: Vector2 = Vector2(0.3, 0.3)
@export_group("Editor Preview")
@export var editor_preview_enabled: bool = false:
	set(value):
		editor_preview_enabled = value
		_queue_editor_preview_refresh()
@export_enum("North", "NorthEast", "East", "SouthEast", "South", "SouthWest", "West", "NorthWest")
var editor_preview_slot: String = "North":
	set(value):
		editor_preview_slot = value
		_queue_editor_preview_refresh()
@export_enum("black_1", "black_2", "red", "yellow", "green", "blue", "purple", "white")
var editor_preview_piece_id: String = "black_1":
	set(value):
		editor_preview_piece_id = value
		_queue_editor_preview_refresh()

@onready var prompt: AnimatedSprite2D = $InteractZone/PressEPrompt
@onready var interact_zone: Area2D = $InteractZone
@onready var float_anchor: Marker2D = $FloatAnchor
@onready var floating_rocks: Node2D = $FloatingRocks
@onready var solved_rocks: Node2D = $SolvedRocks
@onready var preview_rocks: Node2D = $PreviewRocks
@onready var solved_slots: Node2D = $SolvedSlots

var _player_nearby: bool = false
var _player_body: CharacterBody2D = null
var _ui_open: bool = false
var _rock_nodes: Array[Node2D] = []
var _rock_orbits: Array[Dictionary] = []
var _solved_rock_nodes: Array[Node2D] = []
var _solved_slot_markers: Dictionary = {}
var _editor_preview_rock: Node2D = null

func _ready() -> void:
	_cache_slot_markers()
	_configure_rock_rendering()
	if Engine.is_editor_hint():
		prompt.visible = false
		_refresh_editor_preview()
		return
	add_to_group("priority_interactable")
	prompt.visible = false
	interact_zone.body_entered.connect(_on_body_entered)
	interact_zone.body_exited.connect(_on_body_exited)
	if not GameState.stone_puzzle_state_changed.is_connected(_on_stone_puzzle_state_changed):
		GameState.stone_puzzle_state_changed.connect(_on_stone_puzzle_state_changed)
	_refresh_altar_rocks()
	_update_prompt()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_sync_editor_preview()
		return
	if _player_nearby:
		_update_prompt()
	_update_floating_rocks(delta)

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if not _player_nearby or _ui_open or GameState.stone_puzzle_solved:
		return
	if not event.is_action_pressed("interact"):
		return
	if is_instance_valid(_player_body) and not _is_primary_interaction_target(_player_body):
		return
	get_viewport().set_input_as_handled()
	_handle_interaction()

func complete_puzzle() -> void:
	if GameState.stone_puzzle_solved:
		return
	GameState.solve_stone_puzzle()
	_grant_map_piece_reward()
	_ui_open = false
	_update_prompt()

func can_claim_priority_interaction(player: CharacterBody2D) -> bool:
	return (
		is_instance_valid(player)
		and player == _player_body
		and _player_nearby
		and not _ui_open
		and not GameState.stone_puzzle_solved
	)

func get_interaction_priority_point() -> Vector2:
	return interact_zone.global_position

func get_interaction_priority_rank() -> int:
	return INTERACTION_PRIORITY

func _handle_interaction() -> void:
	var just_started := false
	if not GameState.stone_puzzle_started:
		GameState.start_stone_puzzle()
		_show_dialog(intro_text)
		just_started = true
	var deposited_any := not GameState.deposit_carried_stone_pieces().is_empty()
	if deposited_any:
		_refresh_altar_rocks()
	if just_started:
		return
	if GameState.can_attempt_stone_puzzle():
		_open_puzzle_ui()

func _open_puzzle_ui() -> void:
	var ui := _get_or_create_overlay()
	if ui == null:
		return
	if ui.has_signal("closed"):
		var closed_callable := Callable(self, "_on_puzzle_ui_closed")
		if not ui.is_connected("closed", closed_callable):
			ui.connect("closed", closed_callable)
	_ui_open = true
	_update_prompt()
	if ui.has_method("open"):
		ui.call("open", self)

func _on_puzzle_ui_closed() -> void:
	_ui_open = false
	_update_prompt()

func _on_body_entered(body: Node2D) -> void:
	if not _is_player(body):
		return
	_player_nearby = true
	_player_body = body
	_update_prompt()

func _on_body_exited(body: Node2D) -> void:
	if not _is_player(body):
		return
	_player_nearby = false
	if body == _player_body:
		_player_body = null
	_update_prompt()

func _on_stone_puzzle_state_changed() -> void:
	_refresh_altar_rocks()
	_update_prompt()

func _refresh_altar_rocks() -> void:
	_clear_floating_rocks()
	_clear_solved_rocks()
	if GameState.stone_puzzle_solved:
		_refresh_solved_rocks()
	else:
		_refresh_floating_rocks()

func _refresh_floating_rocks() -> void:
	if GameState.stone_puzzle_solved:
		return
	solved_rocks.visible = false
	floating_rocks.visible = true
	var piece_ids := GameState.get_deposited_stone_piece_ids()
	if piece_ids.is_empty():
		return
	for index in range(piece_ids.size()):
		var rock := STONE_ROCK_SCENE.instantiate() as Node2D
		if rock.has_method("setup"):
			rock.setup(piece_ids[index])
		rock.scale = floating_rock_scale_multiplier
		rock.z_index = 3
		floating_rocks.add_child(rock)
		_rock_nodes.append(rock)
		var angle := -PI * 0.5 + (TAU / float(piece_ids.size())) * index
		var speed := randf_range(orbit_speed_min, orbit_speed_max)
		if index % 2 == 0:
			speed *= -1.0
		_rock_orbits.append({
			"angle": angle,
			"radius_x": randf_range(minf(orbit_radius_x_min, orbit_radius_x_max), maxf(orbit_radius_x_min, orbit_radius_x_max)),
			"radius_y": randf_range(minf(orbit_radius_y_min, orbit_radius_y_max), maxf(orbit_radius_y_min, orbit_radius_y_max)),
			"speed": speed,
			"bob_phase": randf() * TAU,
		})
	_update_floating_rocks(0.0)

func _refresh_solved_rocks() -> void:
	floating_rocks.visible = false
	solved_rocks.visible = true
	var solution_piece_ids := _get_solved_piece_ids()
	for index in range(min(solution_piece_ids.size(), SLOT_ORDER.size())):
		var slot_name := String(SLOT_ORDER[index])
		var marker: Marker2D = _solved_slot_markers.get(slot_name)
		if marker == null:
			continue
		var rock := STONE_ROCK_SCENE.instantiate() as Node2D
		_configure_slot_rock(rock, solution_piece_ids[index], marker.position)
		solved_rocks.add_child(rock)
		_solved_rock_nodes.append(rock)

func _clear_floating_rocks() -> void:
	for rock in _rock_nodes:
		if is_instance_valid(rock):
			rock.queue_free()
	_rock_nodes.clear()
	_rock_orbits.clear()

func _clear_solved_rocks() -> void:
	for rock in _solved_rock_nodes:
		if is_instance_valid(rock):
			rock.queue_free()
	_solved_rock_nodes.clear()

func _update_floating_rocks(delta: float) -> void:
	if _rock_nodes.is_empty():
		return
	var center := float_anchor.global_position
	for index in range(_rock_nodes.size()):
		var rock := _rock_nodes[index]
		if not is_instance_valid(rock):
			continue
		var orbit: Dictionary = _rock_orbits[index]
		var angle: float = float(orbit["angle"]) + float(orbit["speed"]) * delta
		var bob_phase: float = float(orbit["bob_phase"]) + delta * 1.65
		var bob: float = sin(bob_phase) * 4.0
		var offset := Vector2(
			cos(angle) * float(orbit["radius_x"]),
			sin(angle) * float(orbit["radius_y"]) + bob
		)
		rock.global_position = center + offset
		rock.z_index = 3 if offset.y <= 0.0 else 5
		orbit["angle"] = angle
		orbit["bob_phase"] = bob_phase
		_rock_orbits[index] = orbit

func _update_prompt() -> void:
	if prompt == null:
		return
	var has_priority := not is_instance_valid(_player_body) or _is_primary_interaction_target(_player_body)
	prompt.visible = has_priority and _player_nearby and not _ui_open and not GameState.stone_puzzle_solved

func _show_dialog(text: String) -> void:
	if STONE_ALTAR_INTRO_DIALOGUE != null:
		DialogueManager.show_dialogue_balloon(STONE_ALTAR_INTRO_DIALOGUE, "start")
		return
	var bubbles := get_tree().get_nodes_in_group("dialog_bubble")
	if bubbles.size() > 0:
		bubbles[0].show_text(text, "Stone Altar")

func _grant_map_piece_reward() -> void:
	var piece_id := reward_map_piece_id
	if piece_id <= 0 or GameState.has_map_piece(piece_id):
		piece_id = _find_next_missing_map_piece_id()
	if piece_id <= 0 or GameState.has_map_piece(piece_id):
		return
	GameState.collect_map_piece(piece_id)
	_sync_map_piece_reward_quest()

func _find_next_missing_map_piece_id() -> int:
	for piece_id in range(1, MAP_PIECE_TOTAL + 1):
		if not GameState.has_map_piece(piece_id):
			return piece_id
	return 0

func _sync_map_piece_reward_quest() -> void:
	var quest_manager = get_node_or_null("/root/QuestManager")
	if quest_manager == null or not quest_manager.has_method("has_objective"):
		return
	if not bool(quest_manager.call("has_objective", MAP_PIECE_QUEST_ID)):
		return
	var collected_count := GameState.collected_map_pieces.size()
	if quest_manager.has_method("set_progress"):
		quest_manager.call("set_progress", MAP_PIECE_QUEST_ID, collected_count, MAP_PIECE_TOTAL)
	if collected_count < MAP_PIECE_TOTAL:
		return
	if quest_manager.has_method("complete"):
		quest_manager.call("complete", MAP_PIECE_QUEST_ID)
	if quest_manager.has_method("add_sub"):
		quest_manager.call("add_sub", TALK_CAT_OBJECTIVE_ID, "Talk to the cat", "escape")

func _get_solved_piece_ids() -> Array[String]:
	var solution_colors := GameState.get_stone_solution_colors()
	var piece_ids: Array[String] = []
	var black_index := 1
	for color_name in solution_colors:
		if color_name == "black":
			piece_ids.append("black_%d" % [black_index])
			black_index += 1
		else:
			piece_ids.append(color_name)
	return piece_ids

func _get_or_create_overlay() -> Node:
	var ui: Node = get_tree().get_first_node_in_group("stone_puzzle_ui_overlay")
	if ui:
		return ui
	ui = STONE_PUZZLE_UI_SCENE.instantiate()
	var scene_root: Node = get_tree().current_scene
	if scene_root:
		scene_root.add_child(ui)
	else:
		get_tree().root.add_child(ui)
	return ui

func _is_primary_interaction_target(player: CharacterBody2D) -> bool:
	if not is_instance_valid(player):
		return false
	var best_node: Node = null
	var best_distance := INF
	var best_priority := INF
	for candidate in get_tree().get_nodes_in_group("priority_interactable"):
		if not is_instance_valid(candidate) or not candidate.has_method("can_claim_priority_interaction"):
			continue
		if not bool(candidate.call("can_claim_priority_interaction", player)):
			continue
		if not candidate.has_method("get_interaction_priority_point") or not candidate.has_method("get_interaction_priority_rank"):
			continue
		var point: Vector2 = candidate.call("get_interaction_priority_point")
		var priority: int = int(candidate.call("get_interaction_priority_rank"))
		var distance := player.global_position.distance_squared_to(point)
		if best_node == null or distance < best_distance or (is_equal_approx(distance, best_distance) and priority < best_priority):
			best_node = candidate
			best_distance = distance
			best_priority = priority
	return best_node == self

func _is_player(body: Node) -> bool:
	return body is CharacterBody2D and (body.name == "Player" or body.is_in_group("Player"))

func _cache_slot_markers() -> void:
	_solved_slot_markers.clear()
	for slot_name in SLOT_ORDER:
		var slot_key := String(slot_name)
		_solved_slot_markers[slot_key] = solved_slots.get_node_or_null(slot_key)

func _configure_rock_rendering() -> void:
	solved_rocks.y_sort_enabled = false
	solved_rocks.z_index = 6
	preview_rocks.y_sort_enabled = false
	preview_rocks.z_index = 7

func _configure_slot_rock(rock: Node2D, piece_id: String, slot_position: Vector2) -> void:
	if rock.has_method("setup"):
		rock.setup(piece_id)
	rock.scale = solved_rock_scale_multiplier
	rock.position = slot_position
	rock.z_index = 1

func _queue_editor_preview_refresh() -> void:
	if not Engine.is_editor_hint():
		return
	call_deferred("_refresh_editor_preview")

func _refresh_editor_preview() -> void:
	if not Engine.is_editor_hint():
		_clear_editor_preview()
		return
	if not is_node_ready():
		return
	if _solved_slot_markers.is_empty():
		_cache_slot_markers()
	if not editor_preview_enabled:
		_clear_editor_preview()
		return
	var marker: Marker2D = _solved_slot_markers.get(editor_preview_slot)
	if marker == null:
		_clear_editor_preview()
		return
	if not is_instance_valid(_editor_preview_rock):
		_editor_preview_rock = STONE_ROCK_SCENE.instantiate() as Node2D
		preview_rocks.add_child(_editor_preview_rock)
	_configure_slot_rock(_editor_preview_rock, editor_preview_piece_id, marker.position)

func _sync_editor_preview() -> void:
	if not editor_preview_enabled:
		_clear_editor_preview()
		return
	if not is_instance_valid(_editor_preview_rock):
		_refresh_editor_preview()
		return
	var marker: Marker2D = _solved_slot_markers.get(editor_preview_slot)
	if marker == null:
		_clear_editor_preview()
		return
	_configure_slot_rock(_editor_preview_rock, editor_preview_piece_id, marker.position)

func _clear_editor_preview() -> void:
	if is_instance_valid(_editor_preview_rock):
		_editor_preview_rock.queue_free()
	_editor_preview_rock = null
