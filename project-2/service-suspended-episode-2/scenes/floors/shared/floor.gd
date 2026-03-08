extends Node2D
class_name DungeonFloor

# Floor coordinator — loads section variants into slots, manages boundaries,
# ticket spawning, UI, punch flow, death/respawn, cursor, and exit door.
# Attach to a floor scene root. Expects child structure:
#   GameWorld (Node2D, y_sort_enabled)
#     Sections/SectionA, SectionB, SectionC, SectionD (each with a section instance)
#     Player
#   Boundaries/SectionA, SectionB, SectionC, SectionD (Area2D)
#   UILayer (CanvasLayer)
#   CursorLayer (CanvasLayer)

# --- Config ---
@export var floor_id: int = 1

# --- Ticket textures ---
var _ticket_textures: Array[Texture2D] = []

# --- Hole punch textures ---
var _punch_icon_open = preload("res://assets/ui/hole_punch/punch_0.png")
var _punch_icon_closed = preload("res://assets/ui/hole_punch/punch_1.png")
var _punch_cursor_open = preload("res://assets/ui/hole_punch/punch_2.png")
var _punch_cursor_closed = preload("res://assets/ui/hole_punch/punch_3.png")

# --- Default cursor textures ---
var _cursor_default = preload("res://assets/ui/cursor/frame_1.png")
var _cursor_clicked = preload("res://assets/ui/cursor/frame_0.png")

# --- Key cursor textures ---
var _key_cursor = preload("res://assets/ui/cursor/key_cursor.png")
var _key_cursor_click = preload("res://assets/ui/cursor/key_cursor_click.png")

# --- Shader ---
var _burn_shader = preload("res://shaders/burn_dissolve.gdshader")

var _saving_icon_scene = preload("res://scenes/ui/saving_icon.tscn")

# --- Walls spritesheet (for exit door overlay) ---
var _walls_tex = preload("res://assets/tilesets/dungeon/dungeon_tileset_walls.png")

# --- Section keys ---
const SECTION_KEYS = ["a", "b", "c", "d"]

# --- Nodes ---
@onready var player: CharacterBody2D = $GameWorld/Player
@onready var punch_btn: TextureButton = $UILayer/PunchButton
@onready var ticket_btn: TextureButton = $UILayer/TicketButton
@onready var key_btn: TextureButton = $UILayer/KeyButton
@onready var flying_ticket: AnimatedSprite2D = $UILayer/FlyingTicket
@onready var cursor_sprite: Sprite2D = $CursorLayer/CursorSprite

# --- Section tracking ---
var _current_section_key: String = ""  # which section the player is in ("a", "b", etc.)
var _section_containers: Dictionary = {}  # "a" -> Node2D container under Sections
var _section_instances: Dictionary = {}  # "a" -> current DungeonSection instance

# --- State ---
var punch_mode: bool = false
var is_animating: bool = false
var _dead: bool = false

# --- Exit door state ---
var _exit_door_data: Dictionary = {}
var _near_exit_door: bool = false


func _ready() -> void:
	_disable_autoload_cursor()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	# Discover section containers
	var sections_node = $GameWorld/Sections
	for key in SECTION_KEYS:
		var container_name = "Section" + key.to_upper()
		var container = sections_node.get_node_or_null(container_name)
		if container:
			_section_containers[key] = container
			# The first child is the instanced section variant
			if container.get_child_count() > 0:
				_section_instances[key] = container.get_child(0)

	# Connect boundary Area2Ds
	var boundaries = $Boundaries
	for key in SECTION_KEYS:
		var area_name = "Section" + key.to_upper()
		var area = boundaries.get_node_or_null(area_name)
		if area and area is Area2D:
			area.body_entered.connect(_on_boundary_entered.bind(key))
			area.body_exited.connect(_on_boundary_exited.bind(key))

	# Load ticket textures
	for i in range(27):
		_ticket_textures.append(load("res://assets/ui/ticket_frames/ticket_%d.png" % i))

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

	# Burn shader material
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
	key_btn.pressed.connect(_on_key_pressed)
	GameState.key_collected.connect(_on_key_collected)
	GameState.key_mode_changed.connect(_on_key_mode_changed)
	key_btn.visible = GameState.keys_collected > 0

	# Cursor setup
	cursor_sprite.texture = _cursor_default
	cursor_sprite.centered = false
	cursor_sprite.scale = Vector2(2, 2)
	cursor_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# Tickets are now painted as marker tiles in section Items layers
	# and spawned by section.gd via tile_entities — no random spawning needed

	# Connect GameState signals
	GameState.ticket_collected.connect(_on_ticket_collected)
	GameState.all_tickets_collected.connect(_on_all_tickets_collected)
	GameState.player_died.connect(_on_player_died)

	# Set initial checkpoint at player spawn position
	GameState.set_checkpoint(player.global_position, _current_section_key)
	GameState.checkpoint_set.connect(_on_checkpoint_set)


func _process(_delta: float) -> void:
	cursor_sprite.global_position = get_viewport().get_mouse_position()


func _input(event: InputEvent) -> void:
	if _dead:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if punch_mode:
				cursor_sprite.texture = _punch_cursor_closed
			elif GameState.key_mode:
				cursor_sprite.texture = _key_cursor_click
			else:
				cursor_sprite.texture = _cursor_clicked
		else:
			if punch_mode:
				cursor_sprite.texture = _punch_cursor_open
			elif GameState.key_mode:
				cursor_sprite.texture = _key_cursor
			else:
				cursor_sprite.texture = _cursor_default

	# Punch-click on the floating ticket
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if punch_mode and flying_ticket.visible and not is_animating:
			var click = get_viewport().get_mouse_position()
			var ticket_pos = flying_ticket.get_global_transform_with_canvas().origin
			if click.distance_to(ticket_pos) < 100:
				_punch_ticket()

	# Cancel active modes with Escape (one layer per press)
	if event.is_action_pressed("ui_cancel"):
		if GameState.key_mode:
			GameState.set_key_mode(false)
			if punch_mode and flying_ticket.visible:
				cursor_sprite.texture = _punch_cursor_open
			else:
				cursor_sprite.texture = _cursor_default
		elif punch_mode and not flying_ticket.visible:
			punch_mode = false
			cursor_sprite.texture = _cursor_default
		elif flying_ticket.visible and not is_animating:
			_cancel_floating_ticket()

	# Exit door interaction
	if event.is_action_pressed("interact") and _near_exit_door and not _exit_door_data.is_empty():
		_use_exit_door()


# ── Section boundary tracking ──

func _on_boundary_entered(body: Node2D, section_key: String) -> void:
	if body == player:
		_current_section_key = section_key
		GameState.set_checkpoint(player.global_position, section_key)

func _on_boundary_exited(_body: Node2D, _section_key: String) -> void:
	pass  # Could clear _current_section_key, but overlapping boundaries handle transitions


# ── Section variant swapping ──

func _swap_current_section() -> void:
	if _current_section_key.is_empty():
		return
	var key = _current_section_key
	var next_variant = GameState.advance_section_variant(floor_id, key)
	var path = "res://scenes/floors/floor_%d/sections/section_%s/section_%s_v%d.tscn" % [floor_id, key, key, next_variant]

	var container = _section_containers.get(key)
	if not container:
		return

	# Remove old section
	for child in container.get_children():
		child.queue_free()

	# Instance new variant
	var scene = load(path)
	if scene:
		var instance = scene.instantiate()
		container.add_child(instance)
		_section_instances[key] = instance


# ── UI ticket button (punch flow) ──

func _on_punch_pressed() -> void:
	if is_animating:
		return
	punch_mode = not punch_mode
	if punch_mode:
		GameState.set_key_mode(false)
	cursor_sprite.texture = _punch_cursor_open if punch_mode else _cursor_default

func _on_key_pressed() -> void:
	if is_animating:
		return
	GameState.set_key_mode(not GameState.key_mode)
	if GameState.key_mode:
		punch_mode = false
	cursor_sprite.texture = _key_cursor if GameState.key_mode else _cursor_default

func _on_key_collected(_current: int) -> void:
	key_btn.visible = GameState.keys_collected > 0
	if GameState.keys_collected <= 0 and GameState.key_mode:
		GameState.set_key_mode(false)

func _on_key_mode_changed(active: bool) -> void:
	if not active:
		cursor_sprite.texture = _cursor_default
	else:
		cursor_sprite.texture = _key_cursor

func _on_ticket_pressed() -> void:
	if is_animating:
		return
	if flying_ticket.visible:
		_cancel_floating_ticket()
		return
	var remaining = GameState.tickets_required - GameState.tickets_collected
	if remaining <= 0:
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

func _cancel_floating_ticket() -> void:
	if not flying_ticket.visible or is_animating:
		return
	is_animating = true
	var tween = create_tween()
	tween.tween_property(flying_ticket, "modulate:a", 0.0, 0.3)
	await tween.finished
	flying_ticket.visible = false
	flying_ticket.modulate = Color.WHITE
	punch_mode = false
	cursor_sprite.texture = _cursor_default
	is_animating = false

func _punch_ticket() -> void:
	is_animating = true
	punch_mode = false
	cursor_sprite.texture = _cursor_default
	player.set_physics_process(false)

	punch_btn.texture_normal = _punch_icon_closed
	await get_tree().create_timer(0.2).timeout
	punch_btn.texture_normal = _punch_icon_open

	# Swap the section the player is currently in
	_swap_current_section()

	var tween = create_tween()
	tween.tween_method(_set_burn_radius, 0.0, 2.0, 1.5)
	await tween.finished

	flying_ticket.visible = false
	GameState.collect_ticket()
	_update_ticket_count_display()
	await get_tree().create_timer(0.3).timeout

	# Reload floor scene
	var floor_path = "res://scenes/floors/floor_%d/floor_%d.tscn" % [floor_id, floor_id]
	var loading = preload("res://scenes/ui/loading_screen.tscn").instantiate()
	get_tree().root.add_child(loading)
	loading.transition_to(floor_path)

func _set_burn_radius(value: float) -> void:
	flying_ticket.material.set_shader_parameter("radius", value)


# ── Ticket count display ──

func _update_ticket_count_display() -> void:
	var count = GameState.tickets_collected
	var frame_idx = clampi(count, 0, 9) + 2
	ticket_btn.texture_normal = _ticket_textures[frame_idx]
	if count >= GameState.tickets_required:
		ticket_btn.modulate = Color(0.4, 1.0, 0.4)
	else:
		ticket_btn.modulate = Color.WHITE

func _on_ticket_collected(_current: int, _total: int) -> void:
	_update_ticket_count_display()

func _on_checkpoint_set(_pos: Vector2, _section: String) -> void:
	var icon = _saving_icon_scene.instantiate()
	$UILayer.add_child(icon)


# ── Exit door (spawns when all tickets collected) ──

func _on_all_tickets_collected() -> void:
	call_deferred("_spawn_exit_door")

func _spawn_exit_door() -> void:
	# Gather floor cells from all sections
	var all_cells: Array[Dictionary] = []
	for key in SECTION_KEYS:
		var section = _section_instances.get(key) as DungeonSection
		if not section:
			continue
		var terrain = section.get_terrain()
		if not terrain:
			continue
		for cell in section.get_floor_cells(Vector2.INF, 0.0):
			var world_pos = terrain.to_global(terrain.map_to_local(cell))
			all_cells.append({ "pos": world_pos })

	if all_cells.is_empty():
		return

	# Find center of all floor cells
	var center = Vector2.ZERO
	for entry in all_cells:
		center += entry.pos
	center /= all_cells.size()

	# Closest cell to center
	var best = all_cells[0]
	var best_dist = best.pos.distance_to(center)
	for entry in all_cells:
		var d = entry.pos.distance_to(center)
		if d < best_dist:
			best_dist = d
			best = entry

	var world_pos = best.pos

	var closed_tex = AtlasTexture.new()
	closed_tex.atlas = _walls_tex
	closed_tex.region = Rect2(112, 64, 16, 16)

	var sprite = Sprite2D.new()
	sprite.texture = closed_tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.global_position = world_pos
	sprite.scale = Vector2(1.5, 1.5)
	$GameWorld.add_child(sprite)

	var zone = Area2D.new()
	zone.global_position = world_pos
	zone.collision_layer = 0
	zone.collision_mask = 1
	var zone_col = CollisionShape2D.new()
	var zone_shape = RectangleShape2D.new()
	zone_shape.size = Vector2(48, 48)
	zone_col.shape = zone_shape
	zone.add_child(zone_col)
	$GameWorld.add_child(zone)

	var prompt = Label.new()
	prompt.text = "Press E"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.position = Vector2(-20, -20)
	prompt.add_theme_font_size_override("font_size", 8)
	prompt.visible = false
	zone.add_child(prompt)

	_exit_door_data = { "sprite": sprite, "zone": zone, "prompt": prompt }
	zone.body_entered.connect(_on_exit_zone_entered)
	zone.body_exited.connect(_on_exit_zone_exited)

	# Pop-in animation
	sprite.scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_exit_zone_entered(body: Node2D) -> void:
	if body == player:
		_near_exit_door = true
		_exit_door_data.prompt.visible = true

func _on_exit_zone_exited(body: Node2D) -> void:
	if body == player:
		_near_exit_door = false
		_exit_door_data.prompt.visible = false

func _use_exit_door() -> void:
	_near_exit_door = false
	_exit_door_data.prompt.visible = false
	player.set_physics_process(false)

	GameState.tickets_collected = 0

	await get_tree().create_timer(0.3).timeout

	# TODO: Transition to next floor or back to train
	var floor_path = "res://scenes/floors/floor_%d/floor_%d.tscn" % [floor_id, floor_id]
	var loading = preload("res://scenes/ui/loading_screen.tscn").instantiate()
	get_tree().root.add_child(loading)
	loading.transition_to(floor_path)


# ── Death / respawn ──

func _on_player_died() -> void:
	if _dead:
		return
	_dead = true
	player.set_physics_process(false)
	player.visible = false
	player.collision_layer = 0
	player.collision_mask = 0

	var death = preload("res://scenes/ui/death_screen.tscn").instantiate()
	get_tree().root.add_child(death)
	death.reload_requested.connect(_on_death_reload.bind(death))
	death.respawn_requested.connect(_on_death_respawn.bind(death))
	if GameState.tickets_collected <= 0:
		death.respawn_btn.disabled = true
		death.respawn_btn.modulate = Color(1, 1, 1, 0.4)

func _on_death_reload(death_screen: CanvasLayer) -> void:
	death_screen.queue_free()
	GameState.tickets_collected = 0
	GameState.keys_collected = 0
	var floor_path = "res://scenes/floors/floor_%d/floor_%d.tscn" % [floor_id, floor_id]
	var loading = preload("res://scenes/ui/loading_screen.tscn").instantiate()
	get_tree().root.add_child(loading)
	loading.transition_to(floor_path)

func _on_death_respawn(death_screen: CanvasLayer) -> void:
	death_screen.queue_free()
	# Deduct 1 ticket
	GameState.tickets_collected = maxi(GameState.tickets_collected - 1, 0)
	_update_ticket_count_display()
	# Teleport player to checkpoint
	player.global_position = GameState.checkpoint_position
	# Re-enable player
	_dead = false
	player.visible = true
	player.collision_layer = 1
	player.collision_mask = 1
	player.set_physics_process(true)


# ── Cursor management ──

func _disable_autoload_cursor() -> void:
	if has_node("/root/CustomCursor"):
		var cc = get_node("/root/CustomCursor")
		cc.set_process(false)
		cc.set_process_input(false)
		for child in cc.get_children():
			if child is CanvasLayer:
				for grandchild in child.get_children():
					if grandchild is Sprite2D:
						grandchild.visible = false

func _exit_tree() -> void:
	if GameState.ticket_collected.is_connected(_on_ticket_collected):
		GameState.ticket_collected.disconnect(_on_ticket_collected)
	if GameState.all_tickets_collected.is_connected(_on_all_tickets_collected):
		GameState.all_tickets_collected.disconnect(_on_all_tickets_collected)
	if GameState.player_died.is_connected(_on_player_died):
		GameState.player_died.disconnect(_on_player_died)
	if GameState.key_collected.is_connected(_on_key_collected):
		GameState.key_collected.disconnect(_on_key_collected)
	if GameState.key_mode_changed.is_connected(_on_key_mode_changed):
		GameState.key_mode_changed.disconnect(_on_key_mode_changed)
	if GameState.checkpoint_set.is_connected(_on_checkpoint_set):
		GameState.checkpoint_set.disconnect(_on_checkpoint_set)

	if has_node("/root/CustomCursor"):
		var cc = get_node("/root/CustomCursor")
		cc.set_process(true)
		cc.set_process_input(true)
		for child in cc.get_children():
			if child is CanvasLayer:
				for grandchild in child.get_children():
					if grandchild is Sprite2D:
						grandchild.visible = true
