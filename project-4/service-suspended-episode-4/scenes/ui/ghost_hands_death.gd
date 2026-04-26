extends CanvasLayer

const GHOST_HAND_SCENE := preload("res://scenes/ui/ghost_hand.tscn")

const FOOT_GRAB_FRAME_COUNT := 4
const FOOT_GRAB_ANIMATION_PREFIX := "foot_grab_"

const PHASE_1_MOVE_TIME := 1.2
const FOOT_GRAB_FRAME_TIME := 0.14
const FOOT_GRAB_HOLD_TIME := 0.25
const ORBIT_TIME := 3.0
const GRAB_TIME := 0.95
const FINAL_HOLD_TIME := 0.45
const HEALTH_DROP_HOLD_TIME := 0.55

@export_range(1, 12, 1) var hand_count_min: int = 4
@export_range(1, 12, 1) var hand_count_max: int = 6
@export var orbit_radius_min: float = 132.0
@export var orbit_radius_max: float = 184.0
@export var hand_spawn_distance_min: float = 158.0
@export var hand_spawn_distance_max: float = 228.0
@export var orbit_speed_min: float = 0.35
@export var orbit_speed_max: float = 0.68
@export var hand_scale: Vector2 = Vector2(0.58, 0.58)
@export var grab_scale: Vector2 = Vector2(0.84, 0.84)
@export var hand_z_index: int = 6
@export var camera_zoom_multiplier: float = 1.9

@onready var _vignette: ColorRect = $Vignette
@onready var _times_up: Control = $TimesUp

var _player = null
var _player_parent: Node = null
var _camera: Camera2D = null
var _original_zoom: Vector2 = Vector2.ONE

var _hands: Array[Node2D] = []
var _hand_orbits: Array[Dictionary] = []
var _grab_hand_index: int = -1
var _grab_hand: Node2D = null
var _grab_approach_from_right: bool = false

var _active: bool = false
var _phase: int = 0
var _phase_time: float = 0.0
var _finished: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_vignette.color = Color(0, 0, 0, 0)
	_times_up.modulate.a = 0.0

func start(player: CharacterBody2D) -> void:
	if not is_instance_valid(player):
		queue_free()
		return
	_player = player
	_player_parent = player.get_parent()
	_camera = player.get_viewport().get_camera_2d()
	if _camera:
		_original_zoom = _camera.zoom
	_active = true
	_phase = 1
	_phase_time = 0.0
	_start_phase_1()

func _process(delta: float) -> void:
	if not _active:
		return
	_phase_time += delta
	match _phase:
		1:
			_process_phase_1()
		2:
			_process_phase_2()
		3:
			_process_phase_3(delta)
		4:
			_process_phase_4(delta)

func _start_phase_1() -> void:
	var tween := create_tween()
	tween.tween_property(_times_up, "modulate:a", 1.0, 0.22)

func _process_phase_1() -> void:
	if _phase_time >= PHASE_1_MOVE_TIME:
		_advance_to_phase_2()

func _advance_to_phase_2() -> void:
	_phase = 2
	_phase_time = 0.0
	_freeze_player()
	_spawn_foot_grab()

func _freeze_player() -> void:
	if not is_instance_valid(_player):
		return
	_player.velocity = Vector2.ZERO
	_player.set_physics_process(false)
	_player.set_process_unhandled_input(false)

func _spawn_foot_grab() -> void:
	if not is_instance_valid(_player):
		return
	var direction_name: String = str(_player.last_direction)
	var animation_name := "%s%s" % [FOOT_GRAB_ANIMATION_PREFIX, direction_name]
	if _player.has_method("_play_animation"):
		_player._play_animation(animation_name, true)

func _process_phase_2() -> void:
	if _phase_time >= (FOOT_GRAB_FRAME_COUNT * FOOT_GRAB_FRAME_TIME) + FOOT_GRAB_HOLD_TIME:
		_advance_to_phase_3()

func _advance_to_phase_3() -> void:
	_phase = 3
	_phase_time = 0.0
	if is_instance_valid(_player) and _player.has_method("hold_current_animation_last_frame"):
		_player.call("hold_current_animation_last_frame")
	_spawn_orbit_hands()
	var vignette_tween := create_tween()
	vignette_tween.tween_property(_vignette, "color:a", 0.62, 2.5)
	var text_tween := create_tween()
	text_tween.tween_interval(0.85)
	text_tween.tween_property(_times_up, "modulate:a", 0.0, 0.45)
	if _camera:
		var zoom_tween := create_tween()
		zoom_tween.tween_property(_camera, "zoom", _original_zoom * camera_zoom_multiplier, 2.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _spawn_orbit_hands() -> void:
	if not is_instance_valid(_player) or _player_parent == null:
		return
	var min_count := mini(hand_count_min, hand_count_max)
	var max_count := maxi(hand_count_min, hand_count_max)
	var min_orbit_radius := minf(orbit_radius_min, orbit_radius_max)
	var max_orbit_radius := maxf(orbit_radius_min, orbit_radius_max)
	var min_spawn_distance := minf(hand_spawn_distance_min, hand_spawn_distance_max)
	var max_spawn_distance := maxf(hand_spawn_distance_min, hand_spawn_distance_max)
	var hand_count := randi_range(min_count, max_count)
	var center: Vector2 = _player.global_position
	for i in range(hand_count):
		var hand := GHOST_HAND_SCENE.instantiate() as Node2D
		hand.call("set_pose_open")
		hand.scale = hand_scale * 0.45
		hand.modulate = Color(1, 1, 1, 0)
		hand.z_index = hand_z_index
		_player_parent.add_child(hand)
		_hands.append(hand)

		var angle := randf() * TAU
		var radius := randf_range(min_orbit_radius, max_orbit_radius)
		var speed := randf_range(orbit_speed_min, orbit_speed_max)
		if randi() % 2 == 0:
			speed *= -1.0
		var spawn_distance := randf_range(min_spawn_distance, max_spawn_distance)
		var spawn_position: Vector2 = center + Vector2(cos(angle), sin(angle) * 0.6) * spawn_distance
		hand.global_position = spawn_position
		hand.call("face_point", center)
		_hand_orbits.append({
			"angle": angle,
			"radius": radius,
			"speed": speed,
			"bob_phase": randf() * TAU,
		})

		var materialize := create_tween()
		materialize.tween_interval(randf_range(0.1, 0.75))
		materialize.tween_property(hand, "modulate:a", 0.78, 0.42)
		materialize.parallel().tween_property(hand, "scale", hand_scale, 0.42)

func _process_phase_3(delta: float) -> void:
	_update_orbit_hands(delta)
	if _phase_time >= ORBIT_TIME:
		_advance_to_phase_4()

func _update_orbit_hands(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	var center: Vector2 = _player.global_position
	for i in range(_hands.size()):
		if i == _grab_hand_index:
			continue
		var hand := _hands[i]
		if not is_instance_valid(hand):
			continue
		var orbit: Dictionary = _hand_orbits[i]
		var angle: float = float(orbit["angle"])
		var speed: float = float(orbit["speed"])
		var radius: float = float(orbit["radius"])
		var bob_phase: float = float(orbit["bob_phase"])
		angle += speed * delta
		bob_phase += delta * 1.8
		var bob: float = sin(bob_phase) * 9.0
		var orbit_offset: Vector2 = Vector2(
			cos(angle) * radius,
			sin(angle) * radius * 0.62 + bob
		)
		hand.global_position = center + orbit_offset
		hand.call("face_point", center)
		orbit["angle"] = angle
		orbit["bob_phase"] = bob_phase
		_hand_orbits[i] = orbit

func _advance_to_phase_4() -> void:
	_phase = 4
	_phase_time = 0.0
	if not is_instance_valid(_player) or _hands.is_empty():
		_finish_death()
		return

	var candidate_indexes: Array[int] = []
	var center: Vector2 = _player.global_position
	for i in range(_hands.size()):
		var hand := _hands[i]
		if not is_instance_valid(hand):
			continue
		var offset: Vector2 = hand.global_position - center
		if absf(offset.x) >= absf(offset.y):
			candidate_indexes.append(i)
	if candidate_indexes.is_empty():
		for i in range(_hands.size()):
			if is_instance_valid(_hands[i]):
				candidate_indexes.append(i)
	if candidate_indexes.is_empty():
		_finish_death()
		return

	_grab_hand_index = candidate_indexes[randi() % candidate_indexes.size()]
	_grab_hand = _hands[_grab_hand_index]
	_grab_approach_from_right = _grab_hand.global_position.x > center.x

	var grab_tween := create_tween()
	grab_tween.tween_property(_grab_hand, "global_position", center + Vector2(0, -8), GRAB_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	grab_tween.parallel().tween_property(_grab_hand, "scale", grab_scale, GRAB_TIME)
	grab_tween.tween_callback(_on_grab_reached)

func _process_phase_4(delta: float) -> void:
	_update_orbit_hands(delta)
	if is_instance_valid(_grab_hand) and is_instance_valid(_player):
		_grab_hand.call("face_point", _player.global_position)

func _on_grab_reached() -> void:
	if is_instance_valid(_grab_hand):
		_grab_hand.rotation = 0.0
		_grab_hand.call("set_pose_grab", _grab_approach_from_right)
	var tween := create_tween()
	tween.tween_interval(FINAL_HOLD_TIME)
	tween.tween_callback(_finish_death)

func _finish_death() -> void:
	if _finished:
		return
	_finished = true
	_active = false

	if _vignette.color.a < 0.82:
		var darken := create_tween()
		darken.tween_property(_vignette, "color:a", 0.82, 0.3)

	for hand in _hands:
		if is_instance_valid(hand):
			var fade := create_tween()
			fade.tween_property(hand, "modulate:a", 0.0, 0.35)
			fade.tween_callback(hand.queue_free)

	if GameState.player_health > 0:
		GameState.player_health = 0
		GameState.player_hit.emit(0)
		GameState.player_health_changed.emit(0)
		await get_tree().create_timer(HEALTH_DROP_HOLD_TIME).timeout
	GameState.on_player_death()
