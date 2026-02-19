extends CharacterBody2D

@export var speed: float = 120.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var direction: Vector2 = Vector2.ZERO
var last_direction: String = "south"

# Map input direction to animation direction name
func _get_direction_name(dir: Vector2) -> String:
	var angle = dir.angle()
	# Convert angle to 8-direction name
	# Godot angles: right=0, down=PI/2, left=PI, up=-PI/2
	var deg = rad_to_deg(angle)
	if deg < 0:
		deg += 360.0
	
	if deg >= 337.5 or deg < 22.5:
		return "east"
	elif deg >= 22.5 and deg < 67.5:
		return "south_east"
	elif deg >= 67.5 and deg < 112.5:
		return "south"
	elif deg >= 112.5 and deg < 157.5:
		return "south_west"
	elif deg >= 157.5 and deg < 202.5:
		return "west"
	elif deg >= 202.5 and deg < 247.5:
		return "north_west"
	elif deg >= 247.5 and deg < 292.5:
		return "north"
	elif deg >= 292.5 and deg < 337.5:
		return "north_east"
	return "south"

func _physics_process(_delta: float) -> void:
	direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if direction != Vector2.ZERO:
		direction = direction.normalized()
		velocity = direction * speed
		last_direction = _get_direction_name(direction)
		_play_animation("walk_" + last_direction)
	else:
		velocity = Vector2.ZERO
		_play_animation("idle_" + last_direction)
	
	move_and_slide()

func _play_animation(anim_name: String) -> void:
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name):
		if animated_sprite.animation != anim_name:
			animated_sprite.play(anim_name)
	elif animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("idle_south"):
		if animated_sprite.animation != "idle_south":
			animated_sprite.play("idle_south")
