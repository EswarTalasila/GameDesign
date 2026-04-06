extends Node2D

## Draws pulsing sector glows over available clock quadrants.
## Matches the debug overlay's sector geometry exactly.

var clock_ui = null

const CLOCK_CENTER = Vector2(65, 66)
const CLOCK_RADIUS = 24.0
const BOUNDS_ROTATION = -25.0

const SECTOR_COLORS = [
	Color(1, 0.85, 0.4),  # V1 warm gold
	Color(1, 0.85, 0.4),  # V2 warm gold
	Color(1, 0.85, 0.4),  # V3 warm gold
	Color(1, 0.85, 0.4),  # V4 warm gold
]

func _draw() -> void:
	if clock_ui == null:
		return
	var c = CLOCK_CENTER - Vector2(64, 64)
	var rot = deg_to_rad(BOUNDS_ROTATION)
	var alpha = clock_ui._glow_alpha

	for q in range(4):
		var variant = q + 1
		if not clock_ui._is_variant_available(variant):
			continue
		var start_angle = q * PI / 2.0 - PI / 2.0 + rot
		var points = PackedVector2Array()
		points.append(c)
		var steps = 24
		for s in range(steps + 1):
			var a = start_angle + (PI / 2.0) * s / steps
			points.append(c + Vector2(sin(a), -cos(a)) * CLOCK_RADIUS)
		var color = SECTOR_COLORS[q]
		color.a = alpha
		draw_colored_polygon(points, color)
