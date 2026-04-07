@tool
extends Node2D

## Overhead light fixture that projects a cone with a pool on the floor.
## Shows shape preview in the editor. Place at the light fixture position.

## Direction the light points (default: down/south in top-down view)
@export var light_direction: Vector2 = Vector2(0, 1):
	set(v):
		light_direction = v
		queue_redraw()

## How far the cone reaches (world pixels)
@export var light_range: float = 50.0:
	set(v):
		light_range = v
		queue_redraw()

## Half-angle of the cone (radians, ~30 degrees default)
@export var light_half_angle: float = 0.5:
	set(v):
		light_half_angle = v
		queue_redraw()

## Radius of the pool of light at the base (world pixels)
@export var pool_radius: float = 25.0:
	set(v):
		pool_radius = v
		queue_redraw()

## Half-width of the physical fixture (world pixels)
@export var bulb_width: float = 8.0:
	set(v):
		bulb_width = v
		queue_redraw()

## Glow radius around the fixture (world pixels)
@export var bulb_glow: float = 15.0:
	set(v):
		bulb_glow = v
		queue_redraw()

## Enable light flickering in variants that support ambient flicker.
@export var flicker: bool = true
@export var min_energy: float = 0.65
@export var max_energy: float = 1.0
@export var min_interval: float = 0.05
@export var max_interval: float = 0.3

var light_energy: float = 1.0

var _timer: Timer = null

func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group("world_lights")
		if flicker and _variant_allows_flicker():
			_timer = Timer.new()
			_timer.one_shot = true
			add_child(_timer)
			_timer.timeout.connect(_on_flicker_timeout)
			_on_flicker_timeout()

func _variant_allows_flicker() -> bool:
	var current_scene = get_tree().current_scene
	if current_scene == null:
		return true
	var scene_file = current_scene.scene_file_path.get_file()
	return scene_file != "escape_room_2.tscn"

func _on_flicker_timeout() -> void:
	light_energy = randf_range(min_energy, max_energy)
	if _timer == null:
		return
	_timer.wait_time = randf_range(min_interval, max_interval)
	_timer.start()

func _draw() -> void:
	var dir = light_direction.normalized()
	var perp = Vector2(-dir.y, dir.x)

	# Glow halo (outer soft circle at fixture)
	draw_arc(Vector2.ZERO, bulb_glow, 0, TAU, 32, Color(1, 1, 0.5, 0.2), 1.0)

	# Fixture width (inner hard circle)
	draw_arc(Vector2.ZERO, bulb_width, 0, TAU, 32, Color(1, 1, 0, 0.8), 2.0)

	# Pool circle at base
	var pool_center = dir * light_range * 0.7
	draw_arc(pool_center, pool_radius, 0, TAU, 32, Color(1, 0.8, 0.3, 0.5), 2.0)

	# Cone edges — from fixture width to pool edge
	var left_start = perp * bulb_width
	var right_start = -perp * bulb_width
	var left_end = pool_center + perp * pool_radius
	var right_end = pool_center - perp * pool_radius
	draw_line(left_start, left_end, Color(1, 0.9, 0.3, 0.6), 1.5)
	draw_line(right_start, right_end, Color(1, 0.9, 0.3, 0.6), 1.5)

	# Direction indicator
	draw_line(Vector2.ZERO, dir * light_range, Color(1, 1, 0, 0.3), 1.0)

	# Fill the cone area lightly
	var points = PackedVector2Array([left_start, left_end, right_end, right_start])
	draw_colored_polygon(points, Color(1, 0.9, 0.3, 0.1))
