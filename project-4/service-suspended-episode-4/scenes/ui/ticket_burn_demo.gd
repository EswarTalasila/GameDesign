extends Node2D

# === Ticket Punch Demo ===
# Black screen with UI base tray at bottom.
# Hole punch icon and numbered ticket counter sit on the base.
# Click the ticket counter → ticket flies into the scene and floats.
# Click the hole punch icon → cursor becomes hole punch.
# Click the floating ticket with hole punch → it burns away, count decreases.

# --- Ticket textures (loaded at runtime) ---
# Frame map from Aseprite:
#   0 = front, 1 = back
#   2-11 = numbered (digits 0-9)
#   12-18 = fly_in animation
#   19-26 = idle_float animation
var _ticket_textures: Array[Texture2D] = []

# --- Hole punch textures ---
var _punch_icon_open = preload("res://assets/ui/hole_punch/punch_0.png")
var _punch_icon_closed = preload("res://assets/ui/hole_punch/punch_1.png")
var _punch_cursor_open = preload("res://assets/ui/hole_punch/punch_2.png")
var _punch_cursor_closed = preload("res://assets/ui/hole_punch/punch_3.png")

# --- Default cursor textures ---
var _cursor_default = preload("res://assets/ui/cursor/frame_1.png")
var _cursor_clicked = preload("res://assets/ui/cursor/frame_0.png")

# --- Shader ---
var _burn_shader = preload("res://shaders/burn_dissolve.gdshader")

# --- Nodes ---
@onready var punch_btn: TextureButton = $CanvasLayer/PunchButton
@onready var ticket_btn: TextureButton = $CanvasLayer/TicketButton
@onready var flying_ticket: AnimatedSprite2D = $CanvasLayer/FlyingTicket
@onready var cursor_sprite: Sprite2D = $CursorLayer/CursorSprite

# --- State ---
var ticket_count: int = 5
var punch_mode: bool = false
var is_animating: bool = false

func _ready() -> void:
	# Hide the autoload custom cursor so we control it ourselves
	if has_node("/root/CustomCursor"):
		var cc = get_node("/root/CustomCursor")
		if cc.has_method("set_process"):
			cc.set_process(false)
			cc.set_process_input(false)
		# Hide its sprite children
		for child in cc.get_children():
			if child is CanvasLayer:
				for grandchild in child.get_children():
					if grandchild is Sprite2D:
						grandchild.visible = false

	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	# Load all 27 ticket frame textures
	for i in range(27):
		_ticket_textures.append(load("res://assets/ui/ticket_frames/ticket_%d.png" % i))

	# Show numbered ticket for current count on the base button
	_update_ticket_count_display()

	# Build SpriteFrames for fly-in and idle float
	var frames = SpriteFrames.new()

	frames.add_animation("fly_in")
	frames.set_animation_speed("fly_in", 12.0)
	frames.set_animation_loop("fly_in", false)
	for i in range(12, 19):
		frames.add_frame("fly_in", _ticket_textures[i])

	frames.add_animation("idle_float")
	frames.set_animation_speed("idle_float", 6.0)
	frames.set_animation_loop("idle_float", true)
	for i in range(19, 27):
		frames.add_frame("idle_float", _ticket_textures[i])

	if frames.has_animation("default"):
		frames.remove_animation("default")

	flying_ticket.sprite_frames = frames
	flying_ticket.visible = false

	# Burn shader material on flying ticket
	var mat = ShaderMaterial.new()
	mat.shader = _burn_shader
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.03
	var noise_tex = NoiseTexture2D.new()
	noise_tex.noise = noise
	mat.set_shader_parameter("position", Vector2(0.5, 0.5))
	mat.set_shader_parameter("radius", 0.0)
	mat.set_shader_parameter("borderWidth", 0.02)
	mat.set_shader_parameter("burnMult", 0.135)
	mat.set_shader_parameter("noiseTexture", noise_tex)
	mat.set_shader_parameter("burnColor", Color(0.9, 0.4, 0.1, 1.0))
	flying_ticket.material = mat

	# Connect buttons
	punch_btn.pressed.connect(_on_punch_pressed)
	ticket_btn.pressed.connect(_on_ticket_pressed)

	# Cursor setup
	cursor_sprite.texture = _cursor_default
	cursor_sprite.centered = false
	cursor_sprite.scale = Vector2(2, 2)
	cursor_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		cursor_sprite.global_position = event.position

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			cursor_sprite.texture = _punch_cursor_closed if punch_mode else _cursor_clicked
		else:
			cursor_sprite.texture = _punch_cursor_open if punch_mode else _cursor_default

	# Punch-click on the floating ticket
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if punch_mode and flying_ticket.visible and not is_animating:
			var click = event.position
			var ticket_pos = flying_ticket.get_global_transform_with_canvas().origin
			if click.distance_to(ticket_pos) < 100:
				_punch_ticket()

func _on_punch_pressed() -> void:
	if is_animating:
		return
	punch_mode = not punch_mode
	cursor_sprite.texture = _punch_cursor_open if punch_mode else _cursor_default

func _on_ticket_pressed() -> void:
	if is_animating or ticket_count <= 0 or flying_ticket.visible:
		return
	_fly_in_ticket()

func _fly_in_ticket() -> void:
	is_animating = true
	flying_ticket.visible = true
	flying_ticket.modulate = Color.WHITE
	flying_ticket.material.set_shader_parameter("radius", 0.0)

	flying_ticket.play("fly_in")
	await flying_ticket.animation_finished

	flying_ticket.play("idle_float")
	is_animating = false

func _punch_ticket() -> void:
	is_animating = true

	# Exit punch mode
	punch_mode = false
	cursor_sprite.texture = _cursor_default

	# Quick punch icon close/open animation
	punch_btn.texture_normal = _punch_icon_closed
	await get_tree().create_timer(0.2).timeout
	punch_btn.texture_normal = _punch_icon_open

	# Burn the ticket away
	var tween = create_tween()
	tween.tween_method(_set_burn_radius, 0.0, 2.0, 1.5)
	await tween.finished

	flying_ticket.visible = false

	# Decrement count
	ticket_count -= 1
	_update_ticket_count_display()

	is_animating = false

func _set_burn_radius(value: float) -> void:
	flying_ticket.material.set_shader_parameter("radius", value)

func _update_ticket_count_display() -> void:
	if ticket_count <= 0:
		ticket_btn.texture_normal = _ticket_textures[2]  # "0" frame
		ticket_btn.modulate = Color(1, 1, 1, 0.4)
	else:
		# Frames 2-11 are numbered digits 0-9
		var frame_idx = clampi(ticket_count, 0, 9) + 2
		ticket_btn.texture_normal = _ticket_textures[frame_idx]
		ticket_btn.modulate = Color.WHITE

func _exit_tree() -> void:
	# Restore the autoload custom cursor
	if has_node("/root/CustomCursor"):
		var cc = get_node("/root/CustomCursor")
		cc.set_process(true)
		cc.set_process_input(true)
		for child in cc.get_children():
			if child is CanvasLayer:
				for grandchild in child.get_children():
					if grandchild is Sprite2D:
						grandchild.visible = true
