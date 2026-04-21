extends CharacterBody2D

@export var speed: float = 120.0
@export var attack_damage: int = 1
@export var vision_overlay_enabled: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _hitbox: Area2D = $AttackHitBox

var _hit_sound = preload("res://assets/sounds/player_hit.mp3")
var _vision_shader = preload("res://assets/shaders/vision_cone.gdshader")

var direction: Vector2 = Vector2.ZERO
var last_direction: String = "south"
var _attacking: bool = false
var _hit_stunned: bool = false
var _invincible: bool = false
var _dead: bool = false
var _vision_material: ShaderMaterial
var lights_disabled: bool = false

# Conductor watching penalty
var _conductor_grace: float = 0.0
var _conductor_cd: float = 0.0

const _dir_vectors = {
	"east": Vector2(1, 0), "west": Vector2(-1, 0),
	"north": Vector2(0, -1), "south": Vector2(0, 1),
	"north_east": Vector2(0.707, -0.707), "north_west": Vector2(-0.707, -0.707),
	"south_east": Vector2(0.707, 0.707), "south_west": Vector2(-0.707, 0.707),
}

func _ready() -> void:
	animated_sprite.animation_finished.connect(_on_animation_finished)
	_hitbox.monitoring = false
	_hitbox.monitorable = false
	if vision_overlay_enabled:
		_setup_vision_overlay()
	GameState.conductor_watching_changed.connect(_on_conductor_watching_changed)

func _on_conductor_watching_changed(watching: bool) -> void:
	if watching:
		_conductor_grace = 1.0
		_conductor_cd = 0.0
		_tween_light_tint(Vector3(0.8, 0.1, 0.1), 0.6, 0.5)
		_tween_screen_tinge(true)
	else:
		_conductor_grace = 0.0
		_conductor_cd = 0.0
		_tween_light_tint(Vector3(0.0, 0.0, 0.0), 0.0, 0.5)
		_tween_screen_tinge(false)

func _tween_light_tint(color: Vector3, strength: float, duration: float) -> void:
	if not _vision_material:
		return
	var tween = create_tween().set_parallel(true)
	var cur_r = _vision_material.get_shader_parameter("light_tint")
	var cur_s = _vision_material.get_shader_parameter("light_tint_strength")
	# Tween tint color
	tween.tween_method(func(v: Vector3): _vision_material.set_shader_parameter("light_tint", v),
		cur_r if cur_r else Vector3.ZERO, color, duration)
	# Tween tint strength
	tween.tween_method(func(v: float): _vision_material.set_shader_parameter("light_tint_strength", v),
		cur_s if cur_s else 0.0, strength, duration)

var _red_tinge: ColorRect = null
var _watch_label: Label = null

func _tween_screen_tinge(on: bool) -> void:
	if _red_tinge == null:
		var tinge_layer = CanvasLayer.new()
		tinge_layer.layer = 4
		add_child(tinge_layer)
		_red_tinge = ColorRect.new()
		_red_tinge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_red_tinge.color = Color(0.6, 0.0, 0.0, 0.0)
		_red_tinge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tinge_layer.add_child(_red_tinge)

		# Warning label
		var dot_gothic = load("res://assets/fonts/DotGothic16-Regular.ttf")
		_watch_label = Label.new()
		_watch_label.text = "The conductor is watching — do not move!"
		_watch_label.modulate = Color(1, 1, 1, 0)
		_watch_label.add_theme_color_override("font_color", Color.WHITE)
		_watch_label.add_theme_font_override("font", dot_gothic)
		_watch_label.add_theme_font_size_override("font_size", 28)
		_watch_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_watch_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		_watch_label.offset_top = -60
		var label_layer = CanvasLayer.new()
		label_layer.layer = 9  # above tinge (4), above vision (5), below HUD (10)
		add_child(label_layer)
		label_layer.add_child(_watch_label)

	var tween = create_tween().set_parallel(true)
	if on:
		tween.tween_property(_red_tinge, "color:a", 0.25, 0.5)
		tween.tween_property(_watch_label, "modulate:a", 1.0, 0.5)
	else:
		tween.tween_property(_red_tinge, "color:a", 0.0, 0.5)
		tween.tween_property(_watch_label, "modulate:a", 0.0, 0.5)

func _setup_vision_overlay() -> void:
	var layer = CanvasLayer.new()
	layer.layer = 5
	add_child(layer)

	var overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_vision_material = ShaderMaterial.new()
	_vision_material.shader = _vision_shader
	var vp_size = get_viewport().get_visible_rect().size
	_vision_material.set_shader_parameter("aspect_ratio", vp_size.x / vp_size.y)
	overlay.material = _vision_material

	layer.add_child(overlay)

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

func _physics_process(delta: float) -> void:
	# Freeze movement when reading lore
	if GameState.lore_open:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if _attacking or _hit_stunned:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Conductor watching — damage if player moves while being watched
	if GameState.conductor_watching:
		if _conductor_grace > 0.0:
			_conductor_grace -= delta
		else:
			if _conductor_cd > 0.0:
				_conductor_cd -= delta
			var moving = Input.get_vector("move_left", "move_right", "move_up", "move_down") != Vector2.ZERO
			if moving and _conductor_cd <= 0.0:
				_play_sfx(_hit_sound)
				GameState.damage_player(ceili(GameState.max_health / 4.0))
				_conductor_cd = 1.5

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

func _update_vision() -> void:
	if not _vision_material:
		return
	var face_dir = _dir_vectors.get(last_direction, Vector2(0, 1))
	_vision_material.set_shader_parameter("cone_direction", face_dir)
	_update_world_lights()

func _update_world_lights() -> void:
	var lights = get_tree().get_nodes_in_group("world_lights")
	var cam = get_viewport().get_camera_2d()
	if cam == null:
		return
	var vp_size = get_viewport().get_visible_rect().size
	var cam_pos = cam.get_screen_center_position()
	var zoom = cam.zoom

	var positions: Array = []
	var directions: Array = []
	var ranges: Array = []
	var angles: Array = []
	var pools: Array = []
	var widths: Array = []
	var glows: Array = []
	var energies: Array = []
	var count = 0 if lights_disabled else mini(lights.size(), 8)

	for i in range(count):
		var light = lights[i]
		var screen_offset = (light.global_position - cam_pos) * zoom
		var uv = Vector2(0.5 + screen_offset.x / vp_size.x, 0.5 + screen_offset.y / vp_size.y)
		positions.append(uv)
		directions.append(light.light_direction.normalized())
		ranges.append((light.light_range * zoom.y) / vp_size.y)
		angles.append(light.light_half_angle)
		pools.append((light.pool_radius * zoom.y) / vp_size.y)
		widths.append((light.bulb_width * zoom.y) / vp_size.y)
		glows.append((light.bulb_glow * zoom.y) / vp_size.y)
		energies.append(light.light_energy if "light_energy" in light else 1.0)

	while positions.size() < 8:
		positions.append(Vector2(-10, -10))
		directions.append(Vector2(0, 1))
		ranges.append(0.0)
		angles.append(0.0)
		pools.append(0.0)
		widths.append(0.0)
		glows.append(0.0)
		energies.append(1.0)

	_vision_material.set_shader_parameter("light_count", count)
	_vision_material.set_shader_parameter("light_positions", positions)
	_vision_material.set_shader_parameter("light_directions", directions)
	_vision_material.set_shader_parameter("light_ranges", ranges)
	_vision_material.set_shader_parameter("light_angles", angles)
	_vision_material.set_shader_parameter("light_pools", pools)
	_vision_material.set_shader_parameter("light_widths", widths)
	_vision_material.set_shader_parameter("light_glows", glows)
	_vision_material.set_shader_parameter("light_energies", energies)

func _play_sfx(stream: AudioStream) -> void:
	var sfx = AudioStreamPlayer.new()
	sfx.stream = stream
	get_tree().root.add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)

func take_hit(damage: int = 1) -> void:
	if _invincible or _dead:
		return
	_hit_stunned = true
	_invincible = true
	_attacking = false
	_hitbox.monitoring = false
	_play_sfx(_hit_sound)
	GameState.damage_player(damage)
	if GameState.player_health <= 0:
		_dead = true
		return
	_play_animation("hit_" + last_direction, true)
	_start_iframes()

func _start_iframes() -> void:
	var blink_tween = create_tween().set_loops(5)
	blink_tween.tween_property(animated_sprite, "modulate:a", 0.3, 0.1)
	blink_tween.tween_property(animated_sprite, "modulate:a", 1.0, 0.1)
	await blink_tween.finished
	animated_sprite.modulate.a = 1.0
	_invincible = false

func _on_animation_finished() -> void:
	if _attacking:
		_attacking = false
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
	_update_vision()
