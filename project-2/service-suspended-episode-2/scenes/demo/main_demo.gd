extends Node2D

# === Main Demo ===
# Dungeon level with ticket pickups, traps, doors, and ticket punch UI overlay.
# Collect all tickets → exit door appears → Press E → loading screen → reset.
# Die to trap → death screen → respawn burns a ticket from your count.

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

# --- Shader ---
var _burn_shader = preload("res://shaders/burn_dissolve.gdshader")

# --- Walls spritesheet (for door frame overlays) ---
var _walls_tex = preload("res://assets/tilesets/dungeon/dungeon_tileset_walls.png")

# --- Scenes ---
var _ticket_scene = preload("res://scenes/pickups/ticket_pickup.tscn")
var _trap_scene = preload("res://scenes/traps/trap_spikes.tscn")

# --- Door config ---
# Paint the closed door tile (7,4) on the tilemap — the script auto-detects it.
@export var door_source_id: int = 1
@export var door_closed_tile: Vector2i = Vector2i(7, 4)
@export var door_open_tile: Vector2i = Vector2i(10, 4)
@export var trap_count: int = 4

# --- Nodes ---
@onready var player: CharacterBody2D = $GameWorld/TileMapLayer/Player
@onready var punch_btn: TextureButton = $UILayer/PunchButton
@onready var ticket_btn: TextureButton = $UILayer/TicketButton
@onready var flying_ticket: AnimatedSprite2D = $UILayer/FlyingTicket
@onready var cursor_sprite: Sprite2D = $CursorLayer/CursorSprite
@onready var tilemap: TileMapLayer = $GameWorld/TileMapLayer

# --- State ---
var punch_mode: bool = false
var is_animating: bool = false
var _dead: bool = false

# --- Door state ---
var _doors: Array[Dictionary] = []
var _nearest_door: Dictionary = {}

# --- Exit door state ---
var _exit_door_data: Dictionary = {}
var _near_exit_door: bool = false

func _ready() -> void:
	_disable_autoload_cursor()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	# Load all 27 ticket frame textures
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

	# Cursor setup
	cursor_sprite.texture = _cursor_default
	cursor_sprite.centered = false
	cursor_sprite.scale = Vector2(2, 2)
	cursor_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# Add collision to wall tiles
	_setup_wall_collision()

	# Find painted door tiles and make them interactive
	_setup_doors()

	# Scatter ticket pickups and traps on random floor tiles
	_spawn_tickets()
	_spawn_traps()

	# Connect GameState signals so UI updates on pickup and exit door spawns
	GameState.ticket_collected.connect(_on_ticket_collected)
	GameState.all_tickets_collected.connect(_on_all_tickets_collected)
	GameState.player_died.connect(_on_player_died)


func _process(_delta: float) -> void:
	# Always track cursor, even during death screen (so user can click buttons)
	cursor_sprite.global_position = get_viewport().get_mouse_position()

func _input(event: InputEvent) -> void:
	if _dead:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			cursor_sprite.texture = _punch_cursor_closed if punch_mode else _cursor_clicked
		else:
			cursor_sprite.texture = _punch_cursor_open if punch_mode else _cursor_default

	# Punch-click on the floating ticket
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if punch_mode and flying_ticket.visible and not is_animating:
			var click = get_viewport().get_mouse_position()
			var ticket_pos = flying_ticket.get_global_transform_with_canvas().origin
			if click.distance_to(ticket_pos) < 100:
				_punch_ticket()

	# Door interaction — open the nearest closed door
	if event.is_action_pressed("interact") and not _nearest_door.is_empty() and not _nearest_door.open:
		_open_door(_nearest_door)

	# Exit door interaction
	if event.is_action_pressed("interact") and _near_exit_door and not _exit_door_data.is_empty():
		_use_exit_door()

# ── UI ticket button (punch flow) ──

func _on_punch_pressed() -> void:
	if is_animating:
		return
	punch_mode = not punch_mode
	cursor_sprite.texture = _punch_cursor_open if punch_mode else _cursor_default

func _on_ticket_pressed() -> void:
	var remaining = GameState.tickets_required - GameState.tickets_collected
	if is_animating or remaining <= 0 or flying_ticket.visible:
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
	punch_mode = false
	cursor_sprite.texture = _cursor_default
	player.set_physics_process(false)

	punch_btn.texture_normal = _punch_icon_closed
	await get_tree().create_timer(0.2).timeout
	punch_btn.texture_normal = _punch_icon_open

	var tween = create_tween()
	tween.tween_method(_set_burn_radius, 0.0, 2.0, 1.5)
	await tween.finished

	flying_ticket.visible = false
	GameState.collect_ticket()
	_update_ticket_count_display()
	await get_tree().create_timer(0.3).timeout

	var loading = preload("res://scenes/ui/loading_screen.tscn").instantiate()
	get_tree().root.add_child(loading)
	loading.transition_to("res://scenes/demo/main_demo.tscn")

func _set_burn_radius(value: float) -> void:
	flying_ticket.material.set_shader_parameter("radius", value)

# ── Ticket count display ──

func _update_ticket_count_display() -> void:
	# Ticket UI shows inventory count (how many you HAVE), not remaining
	var count = GameState.tickets_collected
	var frame_idx = clampi(count, 0, 9) + 2  # frames 2-11 = digits 0-9
	ticket_btn.texture_normal = _ticket_textures[frame_idx]
	if count >= GameState.tickets_required:
		ticket_btn.modulate = Color(0.4, 1.0, 0.4)  # green tint when full
	else:
		ticket_btn.modulate = Color.WHITE

func _on_ticket_collected(_current: int, _total: int) -> void:
	_update_ticket_count_display()

# ── Wall collision ──

func _setup_wall_collision() -> void:
	var ts = tilemap.tile_set
	if ts == null:
		return

	var half = Vector2(ts.tile_size) / 2.0
	var polygon = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y)
	])

	var wall_source_id := 1
	var src = ts.get_source(wall_source_id) as TileSetAtlasSource
	if src == null:
		return
	for tile_idx in range(src.get_tiles_count()):
		var tile_id = src.get_tile_id(tile_idx)
		var td = src.get_tile_data(tile_id, 0)
		if td.get_collision_polygons_count(0) == 0:
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, polygon)

# ── Floor cell helpers ──

func _get_floor_cells(exclude_near_player: float = 3.0) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var player_cell = tilemap.local_to_map(player.position)
	var door_set: Dictionary = {}
	for door in _doors:
		door_set[door.cell] = true

	for cell in tilemap.get_used_cells():
		if tilemap.get_cell_source_id(cell) == 0:
			if cell.distance_to(player_cell) < exclude_near_player:
				continue
			if door_set.has(cell):
				continue
			cells.append(cell)
	return cells

# ── Ticket spawning ──

func _spawn_tickets() -> void:
	var floor_cells = _get_floor_cells()
	floor_cells.shuffle()
	var count = mini(GameState.tickets_required - GameState.tickets_collected, floor_cells.size())
	for i in range(count):
		var world_pos = tilemap.map_to_local(floor_cells[i])
		var ticket = _ticket_scene.instantiate()
		ticket.position = world_pos
		$GameWorld.add_child(ticket)

# ── Trap spawning ──

func _spawn_traps() -> void:
	var floor_cells = _get_floor_cells(4.0)
	floor_cells.shuffle()
	var count = mini(trap_count, floor_cells.size())
	for i in range(count):
		var world_pos = tilemap.map_to_local(floor_cells[i])
		var trap = _trap_scene.instantiate()
		trap.position = world_pos
		trap.cycle_time = 1.5  # blink on/off
		$GameWorld.add_child(trap)

# ── Door system (auto-detected from tilemap) ──

func _make_door_atlas(tile_coord: Vector2i) -> AtlasTexture:
	var tex = AtlasTexture.new()
	tex.atlas = _walls_tex
	tex.region = Rect2(tile_coord.x * 16, tile_coord.y * 16, 16, 16)
	return tex

func _setup_doors() -> void:
	var tile_size = Vector2(tilemap.tile_set.tile_size)
	var closed_tex = _make_door_atlas(door_closed_tile)
	var open_tex = _make_door_atlas(door_open_tile)

	var door_cells: Array[Vector2i] = []
	for cell in tilemap.get_used_cells():
		if tilemap.get_cell_source_id(cell) == door_source_id and tilemap.get_cell_atlas_coords(cell) == door_closed_tile:
			door_cells.append(cell)

	for cell in door_cells:
		tilemap.erase_cell(cell)

	for cell in door_cells:
		var world_pos = tilemap.map_to_local(cell)

		var sprite = Sprite2D.new()
		sprite.texture = closed_tex.duplicate()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = world_pos
		$GameWorld.add_child(sprite)

		var body = StaticBody2D.new()
		body.position = world_pos
		var body_col = CollisionShape2D.new()
		var body_shape = RectangleShape2D.new()
		body_shape.size = tile_size
		body_col.shape = body_shape
		body.add_child(body_col)
		$GameWorld.add_child(body)

		var zone = Area2D.new()
		zone.position = world_pos
		zone.collision_layer = 0
		zone.collision_mask = 1
		var zone_col = CollisionShape2D.new()
		var zone_shape = RectangleShape2D.new()
		zone_shape.size = tile_size * 3
		zone_col.shape = zone_shape
		zone.add_child(zone_col)
		$GameWorld.add_child(zone)

		var prompt = Label.new()
		prompt.text = "Press E"
		prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prompt.position = Vector2(-20, -tile_size.y - 8)
		prompt.add_theme_font_size_override("font_size", 8)
		prompt.visible = false
		zone.add_child(prompt)

		var door_data = {
			"cell": cell,
			"sprite": sprite,
			"body": body,
			"body_col": body_col,
			"zone": zone,
			"prompt": prompt,
			"open": false,
			"open_tex": open_tex.duplicate(),
		}
		_doors.append(door_data)

		var idx = _doors.size() - 1
		zone.body_entered.connect(_on_door_zone_entered.bind(idx))
		zone.body_exited.connect(_on_door_zone_exited.bind(idx))

func _on_door_zone_entered(body: Node2D, idx: int) -> void:
	if body == player:
		_nearest_door = _doors[idx]
		if not _doors[idx].open:
			_doors[idx].prompt.visible = true

func _on_door_zone_exited(body: Node2D, idx: int) -> void:
	if body == player:
		_doors[idx].prompt.visible = false
		if _nearest_door == _doors[idx]:
			_nearest_door = {}

func _open_door(door: Dictionary) -> void:
	door.open = true
	door.prompt.visible = false
	door.sprite.texture = door.open_tex
	door.body_col.set_deferred("disabled", true)
	_nearest_door = {}

# ── Exit door (spawns when all tickets collected) ──

func _on_all_tickets_collected() -> void:
	# Deferred to avoid "flushing queries" error from physics callback
	call_deferred("_spawn_exit_door")

func _spawn_exit_door() -> void:
	# Place exit door at the center of all floor cells
	var floor_cells = _get_floor_cells(0.0)
	if floor_cells.is_empty():
		return
	var center = Vector2i.ZERO
	for cell in floor_cells:
		center += cell
	center /= floor_cells.size()

	# Find the closest actual floor cell to the center
	var best_cell = floor_cells[0]
	var best_dist = best_cell.distance_to(center)
	for cell in floor_cells:
		var d = cell.distance_to(center)
		if d < best_dist:
			best_dist = d
			best_cell = cell

	var tile_size = Vector2(tilemap.tile_set.tile_size)
	var world_pos = tilemap.map_to_local(best_cell)
	var closed_tex = _make_door_atlas(door_closed_tile)

	var sprite = Sprite2D.new()
	sprite.texture = closed_tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = world_pos
	# Scale up entrance to make it visible
	sprite.scale = Vector2(1.5, 1.5)
	$GameWorld.add_child(sprite)

	var zone = Area2D.new()
	zone.position = world_pos
	zone.collision_layer = 0
	zone.collision_mask = 1
	var zone_col = CollisionShape2D.new()
	var zone_shape = RectangleShape2D.new()
	zone_shape.size = tile_size * 3
	zone_col.shape = zone_shape
	zone.add_child(zone_col)
	$GameWorld.add_child(zone)

	var prompt = Label.new()
	prompt.text = "Press E"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.position = Vector2(-20, -tile_size.y - 12)
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

	# Reset tickets for next round
	GameState.tickets_collected = 0

	await get_tree().create_timer(0.3).timeout

	var loading = preload("res://scenes/ui/loading_screen.tscn").instantiate()
	get_tree().root.add_child(loading)
	loading.transition_to("res://scenes/demo/main_demo.tscn")

# ── Death / respawn (trap kills player) ──

func _on_player_died() -> void:
	if _dead:
		return
	_dead = true
	player.set_physics_process(false)
	# Hide player so traps can't re-trigger
	player.visible = false
	player.collision_layer = 0
	player.collision_mask = 0

	var death = preload("res://scenes/ui/death_screen.tscn").instantiate()
	get_tree().root.add_child(death)
	death.reload_requested.connect(_on_death_reload.bind(death))
	death.respawn_requested.connect(_on_death_respawn.bind(death))

func _on_death_reload(death_screen: CanvasLayer) -> void:
	death_screen.queue_free()
	# Free reload — reset tickets to 0, reload from scratch
	GameState.tickets_collected = 0
	var loading = preload("res://scenes/ui/loading_screen.tscn").instantiate()
	get_tree().root.add_child(loading)
	loading.transition_to("res://scenes/demo/main_demo.tscn")

func _on_death_respawn(death_screen: CanvasLayer) -> void:
	death_screen.queue_free()

	# Deduct a ticket to respawn
	GameState.tickets_collected = maxi(GameState.tickets_collected - 1, 0)
	_update_ticket_count_display()

	# Play ticket fly-in and burn animation
	flying_ticket.visible = true
	flying_ticket.modulate = Color.WHITE
	flying_ticket.material.set_shader_parameter("radius", 0.0)
	flying_ticket.play("fly_in")
	await flying_ticket.animation_finished
	flying_ticket.play("idle_float")
	await get_tree().create_timer(0.4).timeout

	var burn = create_tween()
	burn.tween_method(_set_burn_radius, 0.0, 2.0, 1.5)
	await burn.finished
	flying_ticket.visible = false
	await get_tree().create_timer(0.3).timeout

	# Loading screen → respawn with current ticket count preserved
	var loading = preload("res://scenes/ui/loading_screen.tscn").instantiate()
	get_tree().root.add_child(loading)
	loading.transition_to("res://scenes/demo/main_demo.tscn")

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
	# Disconnect GameState signals to avoid stale references
	if GameState.ticket_collected.is_connected(_on_ticket_collected):
		GameState.ticket_collected.disconnect(_on_ticket_collected)
	if GameState.all_tickets_collected.is_connected(_on_all_tickets_collected):
		GameState.all_tickets_collected.disconnect(_on_all_tickets_collected)
	if GameState.player_died.is_connected(_on_player_died):
		GameState.player_died.disconnect(_on_player_died)

	# Restore autoload cursor for other scenes
	if has_node("/root/CustomCursor"):
		var cc = get_node("/root/CustomCursor")
		cc.set_process(true)
		cc.set_process_input(true)
		for child in cc.get_children():
			if child is CanvasLayer:
				for grandchild in child.get_children():
					if grandchild is Sprite2D:
						grandchild.visible = true
