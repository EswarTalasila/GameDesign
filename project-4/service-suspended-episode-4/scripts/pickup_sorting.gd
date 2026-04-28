class_name PickupSorting
extends RefCounted

static func sync_from_collision(pickup: Area2D) -> void:
	if pickup == null:
		return
	if Engine.is_editor_hint():
		return
	if pickup.has_meta("_pickup_sort_anchor_applied"):
		return
	var collision_shape := pickup.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null or collision_shape.shape == null:
		return
	var anchor_offset := collision_shape.position.y + _get_shape_bottom(collision_shape.shape)
	if is_zero_approx(anchor_offset):
		pickup.set_meta("_pickup_sort_anchor_applied", true)
		return
	pickup.position.y += anchor_offset
	for child in pickup.get_children():
		if child is Node2D:
			(child as Node2D).position.y -= anchor_offset
	pickup.set_meta("_pickup_sort_anchor_applied", true)

static func _get_shape_bottom(shape: Shape2D) -> float:
	if shape is CircleShape2D:
		return (shape as CircleShape2D).radius
	if shape is RectangleShape2D:
		return (shape as RectangleShape2D).size.y * 0.5
	if shape is CapsuleShape2D:
		var capsule := shape as CapsuleShape2D
		return (capsule.height * 0.5) + capsule.radius
	return 0.0
