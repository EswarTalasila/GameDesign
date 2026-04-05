@tool
extends Sprite2D

## Debug overlay for clock quadrant detection.
## Open this scene to see and adjust the quadrant bounds on top of the clock.
## Adjust clock_center and clock_radius exports, see the result live.

@export var clock_center: Vector2 = Vector2(52, 48):
	set(v):
		clock_center = v
		queue_redraw()

@export var clock_radius: float = 30.0:
	set(v):
		clock_radius = v
		queue_redraw()

## Rotate the quadrant bounds without rotating the sprite (degrees)
@export_range(-180, 180, 0.5) var bounds_rotation: float = 0.0:
	set(v):
		bounds_rotation = v
		queue_redraw()

func _draw() -> void:
	var c = clock_center - Vector2(64, 64)
	var rot = deg_to_rad(bounds_rotation)

	# Outer detection circle
	draw_arc(c, clock_radius, 0, TAU, 64, Color(0, 1, 0, 0.6), 2.0)

	# Quadrant divider lines — rotated by bounds_rotation
	var base_dirs = [
		Vector2(0, -1),   # 12 o'clock
		Vector2(1, 0),    # 3 o'clock
		Vector2(0, 1),    # 6 o'clock
		Vector2(-1, 0),   # 9 o'clock
	]
	for dir in base_dirs:
		var rotated = dir.rotated(rot)
		draw_line(c, c + rotated * clock_radius, Color(1, 1, 0, 0.8), 1.5)

	# Fill quadrants with light colors
	var colors = [
		Color(1, 0.2, 0.2, 0.15),  # V1 red
		Color(0.2, 0.2, 1, 0.15),  # V2 blue
		Color(0.2, 1, 0.2, 0.15),  # V3 green
		Color(1, 1, 0.2, 0.15),    # V4 yellow
	]
	for q in range(4):
		var start_angle = q * PI / 2.0 - PI / 2.0 + rot
		var points = PackedVector2Array()
		points.append(c)
		var steps = 16
		for s in range(steps + 1):
			var a = start_angle + (PI / 2.0) * s / steps
			points.append(c + Vector2(sin(a), -cos(a)) * clock_radius)
		draw_colored_polygon(points, colors[q])

	# Quadrant center dots
	var label_dist = clock_radius * 0.6
	for q in range(4):
		var a = q * PI / 2.0 + rot
		var dot_pos = c + Vector2(sin(a), -cos(a)) * label_dist
		draw_circle(dot_pos, 3.0, Color(1, 0.3, 0.3, 0.9))
