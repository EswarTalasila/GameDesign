extends CharacterBody2D

signal defeated(enemy: CharacterBody2D)

enum State { DORMANT, SPAWNING, IDLE, WALKING, ATTACKING, HIT, DYING, DEAD }

@export var move_speed: float = 50.0
@export var detection_radius: float = 80.0
@export var attack_range: float = 24.0
@export var idle_pause: float = 0.6
@export var attack_damage_frames: Array[int] = [5, 9]  # frames in attack anim that deal damage
@export var health: int = 2

var _shadow_hit_sound = preload("res://assets/sounds/shadow_hit.mp3")
var _health_pickup_scene = preload("res://scenes/pickups/health_pickup.tscn")
var _voodoo_pickup_scene = preload("res://scenes/pickups/voodoo_doll_pickup.tscn")

const HEALTH_DROP_SCENE_PATH := "res://scenes/pickups/health_pickup.tscn"
const VOODOO_DROP_SCENE_PATH := "res://scenes/pickups/voodoo_doll_pickup.tscn"
const HEALTH_DROP_CHANCE := 0.5
const VOODOO_DROP_CHANCE := 0.25

var _state: State = State.DORMANT
var _player: CharacterBody2D = null
var _idle_timer: float = 0.0
var _hit_frames_dealt: Array[int] = []  # tracks which damage frames already fired
var _facing_east: bool = true  # default facing direction
var _persistent_section: Node2D = null
var _persistent_section_path: String = ""
var _persistent_enemy_id: String = ""
var _drops_spawned: bool = false
var _defeat_emitted: bool = false

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _detection: Area2D = $DetectionZone
@onready var _hitbox: Area2D = $HitBox

func _ready() -> void:
	add_to_group("jungle_hunt_target")
	_persistent_section = _get_persistent_section()
	if _persistent_section:
		_persistent_section_path = _persistent_section.scene_file_path
		_persistent_enemy_id = GameState.make_jungle_enemy_id(
			_persistent_section_path,
			_persistent_section.to_local(global_position)
		)
		if GameState.is_jungle_enemy_defeated(_persistent_enemy_id):
			queue_free()
			return
	_sprite.play("dormant")
	_hitbox.monitoring = false
	_hitbox.monitorable = false
	$CollisionShape2D.disabled = true
	_detection.body_entered.connect(_on_detection_entered)
	_sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(delta: float) -> void:
	match _state:
		State.DORMANT, State.SPAWNING, State.HIT, State.DYING, State.DEAD:
			return
		State.IDLE:
			_face_player()
			_idle_timer -= delta
			if _idle_timer <= 0.0:
				_change_state(State.WALKING)
		State.WALKING:
			_face_player()
			if _player and is_instance_valid(_player):
				var dir = (_player.global_position - global_position).normalized()
				velocity = dir * move_speed
				move_and_slide()
				if global_position.distance_to(_player.global_position) <= attack_range:
					_change_state(State.ATTACKING)
		State.ATTACKING:
			var f = _sprite.frame
			if f in attack_damage_frames and f not in _hit_frames_dealt:
				_hit_frames_dealt.append(f)
				_deal_damage()

func _face_player() -> void:
	if _player and is_instance_valid(_player):
		var was_facing_east = _facing_east
		_facing_east = _player.global_position.x >= global_position.x
		# Mirror hitbox to match facing direction
		$HitBox/CollisionShape2D.position.x = 16 if _facing_east else -16
		# If direction changed mid-animation, switch to the correct directional variant
		if was_facing_east != _facing_east:
			_play_directional(_get_anim_base())

func _dir_suffix() -> String:
	return "_east" if _facing_east else "_west"

func _get_anim_base() -> String:
	match _state:
		State.SPAWNING: return "spawn"
		State.IDLE: return "idle"
		State.WALKING: return "walk"
		State.ATTACKING: return "attack"
		State.DYING: return "death"
	return "idle"

func _play_directional(anim_base: String) -> void:
	var anim_name = anim_base + _dir_suffix()
	if _sprite.animation != anim_name:
		_sprite.play(anim_name)

func _change_state(new_state: State) -> void:
	_state = new_state
	match new_state:
		State.SPAWNING:
			_face_player()
			_play_directional("spawn")
		State.IDLE:
			_play_directional("idle")
			_idle_timer = idle_pause
			$CollisionShape2D.disabled = false
		State.WALKING:
			_play_directional("walk")
		State.ATTACKING:
			_hit_frames_dealt.clear()
			velocity = Vector2.ZERO
			_play_directional("attack")
			_hitbox.monitoring = true
		State.DYING:
			velocity = Vector2.ZERO
			_hitbox.monitoring = false
			set_collision_layer_value(1, false)
			_play_directional("death")
		State.DEAD:
			visible = false
			set_physics_process(false)

func _deal_damage() -> void:
	var bodies = _hitbox.get_overlapping_bodies()
	for body in bodies:
		if body.name == "Player" and body.has_method("take_hit"):
			body.take_hit()
			break

func _on_detection_entered(body: Node2D) -> void:
	if not body.name == "Player":
		return
	if _state == State.DORMANT:
		_player = body
		if not GameState.combat_tutorial_shown:
			GameState.combat_tutorial_shown = true
			_show_combat_tutorial()
			return
		_change_state(State.SPAWNING)
	elif _player == null:
		_player = body

func _show_combat_tutorial() -> void:
	var floor_node = get_tree().current_scene
	# Match floor.gd's _show_tip: floor=ALWAYS (keeps audio), GameWorld=DISABLED (freezes game)
	if floor_node and floor_node.has_node("GameWorld"):
		floor_node._showing_tip = true
		floor_node.process_mode = Node.PROCESS_MODE_ALWAYS
		floor_node.get_node("GameWorld").set_deferred("process_mode", Node.PROCESS_MODE_PAUSABLE)

	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	var bubbles = get_tree().get_nodes_in_group("dialog_bubble")
	if bubbles.size() > 0:
		var bubble = bubbles[0]
		bubble.process_mode = Node.PROCESS_MODE_ALWAYS
		bubble.show_text("Press SPACE to attack!", "Tip")
		while bubble.visible:
			await get_tree().process_frame
		bubble.process_mode = Node.PROCESS_MODE_INHERIT

	get_tree().paused = false
	if floor_node and floor_node.has_node("GameWorld"):
		floor_node.get_node("GameWorld").set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)
		floor_node.process_mode = Node.PROCESS_MODE_INHERIT
		floor_node._showing_tip = false
	process_mode = Node.PROCESS_MODE_INHERIT
	_change_state(State.SPAWNING)

func _on_animation_finished() -> void:
	match _state:
		State.SPAWNING:
			_change_state(State.IDLE)
		State.ATTACKING:
			_hitbox.monitoring = false
			_change_state(State.IDLE)
		State.HIT:
			if health <= 0:
				_change_state(State.DYING)
			else:
				_change_state(State.IDLE)
		State.DYING:
			_spawn_death_drops()
			_change_state(State.DEAD)

func _play_sfx(stream: AudioStream) -> void:
	var sfx = AudioStreamPlayer.new()
	sfx.stream = stream
	get_tree().root.add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)

func take_damage(amount: int = 1) -> void:
	if _state == State.DORMANT or _state == State.DYING or _state == State.DEAD or _state == State.HIT:
		return
	health -= amount
	_state = State.HIT
	velocity = Vector2.ZERO
	_hitbox.monitoring = false
	_play_sfx(_shadow_hit_sound)
	_play_directional("hit")

func _spawn_death_drops() -> void:
	if _drops_spawned:
		return
	_drops_spawned = true
	_emit_defeated()
	if not _persistent_enemy_id.is_empty():
		GameState.mark_jungle_enemy_defeated(_persistent_enemy_id)
	var drops: Array[Dictionary] = []
	if randf() < HEALTH_DROP_CHANCE:
		drops.append({
			"scene": _health_pickup_scene,
			"scene_path": HEALTH_DROP_SCENE_PATH,
		})
	if randf() < VOODOO_DROP_CHANCE:
		drops.append({
			"scene": _voodoo_pickup_scene,
			"scene_path": VOODOO_DROP_SCENE_PATH,
		})
	var offsets := _get_drop_offsets(drops.size())
	for i in range(drops.size()):
		_spawn_drop(drops[i], offsets[i])

func _spawn_drop(drop_data: Dictionary, offset: Vector2) -> void:
	var scene: PackedScene = drop_data.get("scene") as PackedScene
	if scene == null:
		return
	var drop = scene.instantiate()
	if drop == null:
		return
	var drop_position := global_position + offset
	if not _persistent_section_path.is_empty() and _persistent_section != null:
		var drop_id := GameState.add_jungle_persistent_enemy_drop(
			_persistent_section_path,
			String(drop_data.get("scene_path", "")),
			_persistent_section.to_local(drop_position)
		)
		if "persistent_drop_id" in drop:
			drop.set("persistent_drop_id", drop_id)
	var parent := _get_drop_parent()
	if parent == null:
		return
	parent.add_child(drop)
	drop.global_position = drop_position

func _get_drop_offsets(count: int) -> Array[Vector2]:
	if count <= 0:
		return []
	if count == 1:
		return [Vector2.ZERO]
	return [Vector2(-8, 0), Vector2(8, 0)]

func _emit_defeated() -> void:
	if _defeat_emitted:
		return
	_defeat_emitted = true
	defeated.emit(self)

func _get_persistent_section() -> Node2D:
	var node: Node = get_parent()
	while node:
		if node is JungleSection:
			return node
		node = node.get_parent()
	return null

func _get_drop_parent() -> Node:
	if _persistent_section:
		var entities := _persistent_section.get_node_or_null("Entities")
		if entities:
			return entities
	return get_parent()
