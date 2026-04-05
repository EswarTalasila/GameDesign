@tool
extends Node2D

## Conductor patrols behind the wall, visible through transparent window tiles.
## Walks east, stops at window, looks south (through window), then continues.
## Triggers GameState.set_conductor_watching(true) while looking through window.
##
## Place this node behind the walls (z_index below wall layers).
## Set patrol_start, window_pos, and patrol_end in the editor.

## Where the conductor starts (off-screen left of window)
@export var patrol_start: Vector2 = Vector2(-50, 0):
	set(v):
		patrol_start = v
		queue_redraw()

## Where the conductor stops to look through the window
@export var window_pos: Vector2 = Vector2(100, 0):
	set(v):
		window_pos = v
		queue_redraw()

## Where the conductor exits (off-screen right of window)
@export var patrol_end: Vector2 = Vector2(250, 0):
	set(v):
		patrol_end = v
		queue_redraw()

## How long the conductor stares through the window (seconds)
@export var watch_duration: float = 8.0

## Time between patrols (seconds)
@export var patrol_interval: float = 15.0

## Walk speed (pixels per second)
@export var walk_speed: float = 40.0

var _conductor_scene = preload("res://scenes/npc/conductor.tscn")
var _conductor: CharacterBody2D = null
var _sprite: AnimatedSprite2D = null
var _patrolling: bool = false
var _intercom_dialogue = load("res://dialogues/intercom.dialogue")
var _intercom_static = preload("res://assets/sounds/innercom_static.mp3")

## If true, play intercom announcement before first patrol
@export var play_intercom: bool = true

## Delay after intercom before first patrol (seconds)
@export var post_intercom_delay: float = 5.0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# Render behind walls
	z_index = -2
	_spawn_conductor()
	if play_intercom and GameState.current_variant == 1:
		_play_intercom_then_patrol()
	else:
		_start_patrol_loop()

func _spawn_conductor() -> void:
	_conductor = _conductor_scene.instantiate()
	_conductor.position = patrol_start
	_conductor.visible = false
	add_child(_conductor)
	_sprite = _conductor.get_node("AnimatedSprite2D")
	# Disable physics on the conductor — we move it with tweens
	_conductor.get_node("CollisionShape2D").disabled = true

func _play_intercom_then_patrol() -> void:
	await get_tree().create_timer(2.0).timeout
	# Play static sound
	var sfx = AudioStreamPlayer.new()
	sfx.stream = _intercom_static
	sfx.volume_db = -8
	add_child(sfx)
	sfx.play()
	# Show dialogue balloon (same style as project 2)
	DialogueManager.show_dialogue_balloon(_intercom_dialogue, "announcement")
	await DialogueManager.dialogue_ended
	sfx.stop()
	sfx.queue_free()
	await get_tree().create_timer(post_intercom_delay).timeout
	_start_patrol_loop()

func _start_patrol_loop() -> void:
	while true:
		await get_tree().create_timer(patrol_interval).timeout
		if not is_inside_tree():
			return
		await _do_patrol()

func _do_patrol() -> void:
	_conductor.position = patrol_start
	_conductor.visible = true
	_sprite.play("walk_east")

	# Walk to window
	var walk_time = patrol_start.distance_to(window_pos) / walk_speed
	var tween = create_tween()
	tween.tween_property(_conductor, "position", window_pos, walk_time)
	await tween.finished

	# Stop and look south (through the window)
	_sprite.play("idle_south")
	GameState.set_conductor_watching(true)

	await get_tree().create_timer(watch_duration).timeout

	# Stop watching
	GameState.set_conductor_watching(false)

	# Walk away
	_sprite.play("walk_east")
	var exit_time = window_pos.distance_to(patrol_end) / walk_speed
	var exit_tween = create_tween()
	exit_tween.tween_property(_conductor, "position", patrol_end, exit_time)
	await exit_tween.finished

	_conductor.visible = false

# ── Editor preview ──

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	# Patrol path
	draw_line(patrol_start, window_pos, Color(0, 0.8, 1, 0.6), 2.0)
	draw_line(window_pos, patrol_end, Color(0, 0.8, 1, 0.6), 2.0)
	# Start marker
	draw_circle(patrol_start, 4.0, Color(0, 1, 0, 0.8))
	# Window position (where he stops)
	draw_circle(window_pos, 6.0, Color(1, 0, 0, 0.8))
	# End marker
	draw_circle(patrol_end, 4.0, Color(1, 0.5, 0, 0.8))
	# Look direction arrow (south)
	draw_line(window_pos, window_pos + Vector2(0, 20), Color(1, 0, 0, 0.6), 2.0)
	draw_line(window_pos + Vector2(0, 20), window_pos + Vector2(-5, 15), Color(1, 0, 0, 0.6), 2.0)
	draw_line(window_pos + Vector2(0, 20), window_pos + Vector2(5, 15), Color(1, 0, 0, 0.6), 2.0)
