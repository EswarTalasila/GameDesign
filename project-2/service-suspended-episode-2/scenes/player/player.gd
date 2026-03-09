extends CharacterBody2D

@export var speed: float = 120.0
@export var attack_damage: int = 1

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _hitbox: Area2D = $AttackHitBox

var direction: Vector2 = Vector2.ZERO
var last_direction: String = "south"
var _attacking: bool = false
var _hit_stunned: bool = false
var _invincible: bool = false

func _ready() -> void:
	animated_sprite.animation_finished.connect(_on_animation_finished)
	_hitbox.monitoring = false
	_hitbox.monitorable = false

func _get_direction_name(dir: Vector2) -> String:
	var angle = dir.angle()
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
	if _attacking or _hit_stunned:
		velocity = Vector2.ZERO
		move_and_slide()
		return

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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack") and not _attacking and not _hit_stunned:
		_start_attack()

func _start_attack() -> void:
	_attacking = true
	velocity = Vector2.ZERO
	_hitbox.monitoring = true
	_update_hitbox_position()
	_play_animation("attack_" + last_direction, true)

func _update_hitbox_position() -> void:
	var offsets = {
		"east": Vector2(12, 0), "west": Vector2(-12, 0),
		"north": Vector2(0, -12), "south": Vector2(0, 12),
		"north_east": Vector2(9, -9), "north_west": Vector2(-9, -9),
		"south_east": Vector2(9, 9), "south_west": Vector2(-9, 9),
	}
	$AttackHitBox/CollisionShape2D.position = offsets.get(last_direction, Vector2(0, 12))

func take_hit(damage: int = 1) -> void:
	if _invincible:
		return
	_hit_stunned = true
	_invincible = true
	_attacking = false
	_hitbox.monitoring = false
	GameState.damage_player(damage)
	_play_animation("hit_" + last_direction, true)
	_start_iframes()

func _start_iframes() -> void:
	# Blink the sprite during i-frames
	var blink_tween = create_tween().set_loops(5)
	blink_tween.tween_property(animated_sprite, "modulate:a", 0.3, 0.1)
	blink_tween.tween_property(animated_sprite, "modulate:a", 1.0, 0.1)
	await blink_tween.finished
	animated_sprite.modulate.a = 1.0
	_invincible = false

func _on_animation_finished() -> void:
	if _attacking:
		_attacking = false
		# Check for hits BEFORE disabling monitoring
		for body in _hitbox.get_overlapping_bodies():
			if body.has_method("take_damage"):
				body.take_damage(attack_damage)
		_hitbox.monitoring = false
	if _hit_stunned:
		_hit_stunned = false

func _play_animation(anim_name: String, force: bool = false) -> void:
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name):
		if force or animated_sprite.animation != anim_name:
			animated_sprite.play(anim_name)
	elif animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("idle_south"):
		if animated_sprite.animation != "idle_south":
			animated_sprite.play("idle_south")
