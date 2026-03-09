extends Node2D
class_name DungeonFloor

# Floor coordinator — loads section variants into slots, manages boundaries,
# ticket spawning, UI, punch flow, death/respawn, cursor, and exit door.
# Attach to a floor scene root. Expects child structure:
#   GameWorld (Node2D, y_sort_enabled)
#     Sections/SectionA, SectionB, SectionC, SectionD (each with a section instance)
#     Player
#   Boundaries/SectionA, SectionB, SectionC, SectionD (Area2D)
#   GameUI (instance of game_ui.tscn — UILayer + CursorLayer)

# --- Config ---
@export var floor_id: int = 1

# --- Ticket textures (full 27-frame set for fly-in animation) ---
var _ticket_textures: Array[Texture2D] = []

# --- Numbered HUD icons ---
var _key_numbered: Array[Texture2D] = []
var _ticket_numbered: Array[Texture2D] = []
var _special_numbered: Array[Texture2D] = []

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

# --- Play/pause HUD textures ---
var _pause_normal = preload("res://assets/ui/buttons/play_pause/pause_normal.png")
var _pause_pressed = preload("res://assets/ui/buttons/play_pause/pause_pressed.png")
var _play_normal = preload("res://assets/ui/buttons/play_pause/play_normal.png")
var _play_pressed = preload("res://assets/ui/buttons/play_pause/play_pressed.png")

# --- Shader ---
var _burn_shader = preload("res://shaders/burn_dissolve.gdshader")

var _saving_icon_scene = preload("res://scenes/ui/saving_icon.tscn")

# --- Walls spritesheet (for exit door overlay) ---
var _walls_tex = preload("res://assets/tilesets/dungeon/dungeon_tileset_walls.png")

# --- Section keys ---
const SECTION_KEYS = ["a", "b", "c", "d"]

# --- Nodes ---
@onready var player: CharacterBody2D = $GameWorld/Player
@onready var punch_slot: Sprite2D = $GameUI/UILayer/InventoryPanel/PunchSlot
@onready var ticket_slot: Sprite2D = $GameUI/UILayer/InventoryPanel/TicketSlot
@onready var key_slot: Sprite2D = $GameUI/UILayer/InventoryPanel/KeySlot
@onready var special_slot: Sprite2D = $GameUI/UILayer/InventoryPanel/SpecialSlot
@onready var flying_ticket: AnimatedSprite2D = $GameUI/UILayer/FlyingTicket
@onready var pause_slot: Sprite2D = $GameUI/UILayer/InventoryPanel/PauseSlot
@onready var cursor_sprite: Sprite2D = $GameUI/CursorLayer/CursorSprite

# --- Section tracking ---
var _current_section_key: String = ""  # which section the player is in ("a", "b", etc.)
var _section_containers: Dictionary = {}  # "a" -> Node2D container under Sections
var _section_instances: Dictionary = {}  # "a" -> current DungeonSection instance

# --- State ---
var punch_mode: bool = false
var is_animating: bool = false
var _dead: bool = false
var _paused: bool = false


# --- Exit door state ---
var _exit_door_data: Dictionary = {}
var _near_exit_door: bool = false


func _ready() -> void:
	_disable_autoload_cursor()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	# Discover section containers and swap to correct variant from GameState
	var sections_node = $GameWorld/Sections
	for key in SECTION_KEYS:
		var container_name = "Section" + key.to_upper()
		var container = sections_node.get_node_or_null(container_name)
		if container:
			_section_containers[key] = container
			var stored_variant = GameState.get_section_variant(floor_id, key)
			if stored_variant != 1 and container.get_child_count() > 0:
				# Preserve position from v1, then swap to correct variant
				var old_pos = container.get_child(0).position
				container.get_child(0).queue_free()
				var path = "res://scenes/floors/floor_%d/sections/section_%s/section_%s_v%d.tscn" % [floor_id, key, key, stored_variant]
				var scene = load(path)
				if scene:
					var instance = scene.instantiate()
					container.add_child(instance)
					instance.position = old_pos
					_section_instances[key] = instance
			elif container.get_child_count() > 0:
				_section_instances[key] = container.get_child(0)

	# Connect boundary Area2Ds
	var boundaries = $Boundaries
	for key in SECTION_KEYS:
		var area_name = "Section" + key.to_upper()
		var area = boundaries.get_node_or_null(area_name)
		if area and area is Area2D:
			area.body_entered.connect(_on_boundary_entered.bind(key))
			area.body_exited.connect(_on_boundary_exited.bind(key))

	# Load ticket textures (full set for fly-in animation)
	for i in range(27):
		_ticket_textures.append(load("res://assets/ui/ticket_frames/ticket_%d.png" % i))

	# Load numbered HUD icons (0-9)
	for i in range(10):
		_key_numbered.append(load("res://assets/ui/key_icons/key_Numbered_%02d.png" % i))
		_ticket_numbered.append(load("res://assets/ui/tickets/ticket_Numbered_%d.png" % i))
		_special_numbered.append(load("res://assets/ui/special_tickets/special_Numbered_%d.png" % i))

	_update_hud_icons()

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

	# Key mode signals
	GameState.key_collected.connect(_on_key_collected)
	GameState.key_mode_changed.connect(_on_key_mode_changed)

	# Cursor setup
	cursor_sprite.texture = _cursor_default
	cursor_sprite.centered = false
	cursor_sprite.scale = Vector2(1, 1)
	cursor_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# Detect initial section (body_entered won't fire for already-overlapping bodies)
	_detect_initial_section()

	# Spawn only 2 special tickets from all painted markers across sections
	_setup_special_tickets()

	# Connect GameState signals
	GameState.ticket_picked_up.connect(_on_ticket_picked_up)
	GameState.ticket_collected.connect(_on_ticket_collected)
	GameState.all_tickets_collected.connect(_on_all_tickets_collected)
	GameState.player_died.connect(_on_player_died)
	GameState.special_ticket_collected.connect(_on_special_ticket_collected)

	# Set initial checkpoint at player spawn position
	GameState.set_checkpoint(player.global_position, _current_section_key)
	GameState.checkpoint_set.connect(_on_checkpoint_set)

	# Special tickets → exit door glow
	GameState.all_special_tickets_collected.connect(_on_all_special_tickets_collected)

	# (Inventory is now built into game_ui.tscn — no separate panel needed)


func _input(event: InputEvent) -> void:
	if _dead or _paused:
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

	# Left-click actions
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var click = get_viewport().get_mouse_position()
		# Punch-click on the floating ticket
		if punch_mode and flying_ticket.visible and not is_animating:
			var ticket_pos = flying_ticket.get_global_transform_with_canvas().origin
			if click.distance_to(ticket_pos) < 100:
				_punch_ticket()
		# Inventory slot clicks
		elif not is_animating:
			if _is_click_on_slot(click, pause_slot):
				_on_pause_slot_pressed()
			elif _is_click_on_slot(click, key_slot):
				_on_key_pressed()
			elif _is_click_on_slot(click, ticket_slot):
				_on_ticket_pressed()
			elif _is_click_on_slot(click, punch_slot):
				_on_punch_pressed()

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
		elif not is_animating:
			_open_pause_menu()

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

func _detect_initial_section() -> void:
	# body_entered doesn't fire for bodies already inside at _ready time.
	# Manually check which boundary area the player is in.
	var boundaries = $Boundaries
	for key in SECTION_KEYS:
		var area_name = "Section" + key.to_upper()
		var area = boundaries.get_node_or_null(area_name)
		if area and area is Area2D:
			for child in area.get_children():
				if child is CollisionShape2D and child.shape:
					var shape_pos = area.global_position + child.position
					var half = child.shape.size / 2
					var rect = Rect2(shape_pos - half, child.shape.size)
					if rect.has_point(player.global_position):
						_current_section_key = key
						return


# ── Special ticket spawning (floor-managed) ──

func _setup_special_tickets() -> void:
	# Find the floor_managed entry for special tickets
	var entry: Dictionary = {}
	for e in TileEntities.get_table():
		if e.get("floor_managed", false):
			entry = e
			break
	if entry.is_empty():
		return

	# Collect all marker positions across every section's Items layer
	var candidates: Array[Dictionary] = []  # { section, cell, world_pos }
	for key in SECTION_KEYS:
		var section = _section_instances.get(key) as DungeonSection
		if not section:
			continue
		var items_layer = section.get_items_layer()
		if not items_layer:
			continue
		for cell in items_layer.get_used_cells():
			if items_layer.get_cell_source_id(cell) == entry.source and items_layer.get_cell_atlas_coords(cell) == entry.marker:
				var world_pos = items_layer.to_global(items_layer.map_to_local(cell))
				candidates.append({ "section": section, "layer": items_layer, "cell": cell, "world_pos": world_pos })

	# Shuffle and pick up to special_tickets_required
	candidates.shuffle()
	var to_spawn = mini(candidates.size(), GameState.special_tickets_required)

	for i in range(candidates.size()):
		var c = candidates[i]
		# Erase the marker tile regardless
		c.layer.erase_cell(c.cell)
		if i < to_spawn:
			# Spawn entity at this position
			var instance = entry.scene.instantiate()
			c.section.add_child(instance)
			instance.global_position = c.world_pos

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

	# Preserve old section position, then remove
	var old_pos = Vector2.ZERO
	if container.get_child_count() > 0:
		old_pos = container.get_child(0).position
	for child in container.get_children():
		child.queue_free()

	# Instance new variant at same position
	var scene = load(path)
	if scene:
		var instance = scene.instantiate()
		container.add_child(instance)
		instance.position = old_pos
		_section_instances[key] = instance


# ── Inventory slot click detection ──

func _is_click_on_slot(click_pos: Vector2, slot: Sprite2D) -> bool:
	var slot_screen = slot.get_global_transform_with_canvas().origin
	return click_pos.distance_to(slot_screen) < 40.0


# ── UI slot actions (punch flow) ──

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
	_update_hud_icons()
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
	if GameState.tickets_held <= 0:
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

	# 1. Punch button close/open animation
	punch_slot.texture = _punch_icon_closed
	await get_tree().create_timer(0.2).timeout
	punch_slot.texture = _punch_icon_open

	# 2. Burn shader dissolves ticket (old tiles still visible)
	var tween = create_tween()
	tween.tween_method(_set_burn_radius, 0.0, 2.0, 1.5)
	await tween.finished

	# 3. Hide ticket, update state
	flying_ticket.visible = false
	GameState.tickets_held = maxi(GameState.tickets_held - 1, 0)
	GameState.collect_ticket()
	_update_hud_icons()

	# 4. Loading screen covers
	var loading_screen = preload("res://scenes/ui/loading_screen.tscn").instantiate()
	get_tree().root.add_child(loading_screen)
	loading_screen.cover()
	await loading_screen.cover_finished

	# 5. While covered: swap section, teleport player
	player.visible = false
	player.collision_layer = 0
	player.collision_mask = 0

	_swap_current_section()

	# Wait 2 physics frames for old section to free and new section to init
	await get_tree().physics_frame
	await get_tree().physics_frame

	# Teleport player to checkpoint
	player.global_position = GameState.checkpoint_position

	# Wait 1 more physics frame for physics server to register new position
	await get_tree().physics_frame

	# Re-enable player
	player.collision_layer = 1
	player.collision_mask = 1
	player.visible = true
	player.set_physics_process(true)
	is_animating = false

	# 6. Uncover loading screen (fades out + self-frees)
	loading_screen.uncover()
	await loading_screen.uncover_finished

func _set_burn_radius(value: float) -> void:
	flying_ticket.material.set_shader_parameter("radius", value)


# ── HUD icon updates ──

func _update_hud_icons() -> void:
	key_slot.texture = _key_numbered[clampi(GameState.keys_collected, 0, 9)]
	ticket_slot.texture = _ticket_numbered[clampi(GameState.tickets_held, 0, 9)]
	special_slot.texture = _special_numbered[clampi(GameState.special_tickets_collected, 0, 9)]

func _on_ticket_picked_up(_held: int) -> void:
	_update_hud_icons()

func _on_ticket_collected(_current: int, _total: int) -> void:
	_update_hud_icons()

func _on_special_ticket_collected(_current: int, _required: int) -> void:
	_update_hud_icons()

func _on_checkpoint_set(_pos: Vector2, _section: String) -> void:
	var icon = _saving_icon_scene.instantiate()
	$GameUI/UILayer.add_child(icon)


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

	# Stop glow tween if running
	if _exit_door_data.has("glow_tween"):
		_exit_door_data.glow_tween.kill()

	GameState.tickets_collected = 0
	GameState.tickets_held = 0
	GameState.special_tickets_collected = 0

	await get_tree().create_timer(0.3).timeout

	var next_floor = floor_id + 1
	if next_floor <= GameState.num_floors:
		GameState.current_floor = next_floor
		GameState.randomize_section_variants(next_floor)
		var floor_path = "res://scenes/floors/floor_%d/floor_%d.tscn" % [next_floor, next_floor]
		var loading_screen = preload("res://scenes/ui/loading_screen.tscn").instantiate()
		get_tree().root.add_child(loading_screen)
		loading_screen.transition_to(floor_path)
	else:
		print("Dungeon complete! All floors cleared.")


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
	if GameState.tickets_held <= 0:
		death.respawn_btn.disabled = true
		death.respawn_btn.modulate = Color(1, 1, 1, 0.4)

func _on_death_reload(death_screen) -> void:
	GameState.tickets_collected = 0
	GameState.tickets_held = 0
	GameState.keys_collected = 0
	GameState.special_tickets_collected = 0
	GameState.reset_health()
	GameState.randomize_section_variants(floor_id)
	var floor_path = "res://scenes/floors/floor_%d/floor_%d.tscn" % [floor_id, floor_id]
	var loading_screen = preload("res://scenes/ui/loading_screen.tscn").instantiate()
	get_tree().root.add_child(loading_screen)
	loading_screen.cover()
	await loading_screen.cover_finished
	if death_screen:
		death_screen.queue_free()
	loading_screen.transition_to(floor_path)

func _on_death_respawn(death_screen: CanvasLayer) -> void:
	# Deduct 1 held ticket
	GameState.tickets_held = maxi(GameState.tickets_held - 1, 0)
	_update_hud_icons()
	GameState.reset_health()

	# Loading screen covers first, then free death screen
	var loading_screen = preload("res://scenes/ui/loading_screen.tscn").instantiate()
	get_tree().root.add_child(loading_screen)
	loading_screen.cover()
	await loading_screen.cover_finished
	death_screen.queue_free()

	# Teleport player to checkpoint while covered
	player.global_position = GameState.checkpoint_position
	await get_tree().physics_frame

	# Re-enable player
	_dead = false
	player.visible = true
	player.collision_layer = 1
	player.collision_mask = 1
	player.set_physics_process(true)

	# Uncover
	loading_screen.uncover()
	await loading_screen.uncover_finished


# ── Pause menu ──

func _on_pause_slot_pressed() -> void:
	pause_slot.texture = _pause_pressed
	await get_tree().create_timer(0.1).timeout
	_open_pause_menu()

func _open_pause_menu() -> void:
	_paused = true
	pause_slot.texture = _play_normal
	get_tree().paused = true
	var menu = preload("res://scenes/ui/pause_menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	menu.resume_requested.connect(_on_pause_resume.bind(menu))
	menu.restart_requested.connect(_on_pause_restart.bind(menu))
	menu.quit_requested.connect(_on_pause_quit.bind(menu))

func _on_pause_resume(menu: CanvasLayer) -> void:
	menu.queue_free()
	get_tree().paused = false
	_paused = false
	pause_slot.texture = _pause_normal

func _on_pause_restart(menu: CanvasLayer) -> void:
	menu.queue_free()
	get_tree().paused = false
	_paused = false
	_on_death_reload(null)

func _on_pause_quit(menu: CanvasLayer) -> void:
	menu.queue_free()
	get_tree().paused = false
	get_tree().quit()


# ── Special ticket → exit door glow ──

func _on_all_special_tickets_collected() -> void:
	if _exit_door_data.is_empty():
		return
	var lit_tex = AtlasTexture.new()
	lit_tex.atlas = _walls_tex
	lit_tex.region = Rect2(304, 64, 16, 16)
	_exit_door_data.sprite.texture = lit_tex
	var tween = create_tween().set_loops(0)
	tween.tween_property(_exit_door_data.sprite, "modulate", Color(1.3, 1.2, 0.8), 0.8)
	tween.tween_property(_exit_door_data.sprite, "modulate", Color.WHITE, 0.8)
	_exit_door_data["glow_tween"] = tween


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
	if GameState.ticket_picked_up.is_connected(_on_ticket_picked_up):
		GameState.ticket_picked_up.disconnect(_on_ticket_picked_up)
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
	if GameState.all_special_tickets_collected.is_connected(_on_all_special_tickets_collected):
		GameState.all_special_tickets_collected.disconnect(_on_all_special_tickets_collected)
	if GameState.special_ticket_collected.is_connected(_on_special_ticket_collected):
		GameState.special_ticket_collected.disconnect(_on_special_ticket_collected)

	if has_node("/root/CustomCursor"):
		var cc = get_node("/root/CustomCursor")
		cc.set_process(true)
		cc.set_process_input(true)
		for child in cc.get_children():
			if child is CanvasLayer:
				for grandchild in child.get_children():
					if grandchild is Sprite2D:
						grandchild.visible = true
