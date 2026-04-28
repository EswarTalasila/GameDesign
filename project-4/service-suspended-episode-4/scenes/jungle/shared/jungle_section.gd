extends Node2D
class_name JungleSection

## Universal layer handler for jungle variant scenes.
## Combines project-2 tile-entity spawning with project-3 layer structure.
##
## All layers use the combined tileset (jungle + autumn + winter + wasteland).
## Pick any source when painting — they all share the same 16x16 grid.
##
## Expected child TileMapLayers (all optional — script adapts to what exists):
##   Floor          — ground tiles, z=-1, no collision
##   BottomWalls    — lower walls the player bumps into, collision
##   TopWalls       — walls that render over the player, z=5, no collision
##   SideWalls      — side boundaries, collision
##   Furniture      — decorative / interactive objects, y_sort, collision
##   Furniture2     — extra furniture layer, y_sort, collision
##   Overhead       — canopy / ceiling, z=10, no collision
##   EnemyMarkers   — marker tiles for enemy spawn points (erased at runtime)
##   Items          — marker tiles for pickups / interactables (erased at runtime)
##
## Runtime containers:
##   Entities       — y_sort container for spawned entities
##   Doors          — y_sort container for spawned doors
##   Traps          — z=-1 container for spawned traps

## Season override for standalone testing. Set in inspector before running.
@export_enum("jungle", "autumn", "winter", "wasteland") var season: String = "jungle"
## When the season is wasteland, choose between the default water and the blood-water sheet.
@export_enum("normal", "blood") var wasteland_water_style: String = "normal"
## Test helpers used only when running a variant scene directly.
@export var standalone_spawn_player: bool = true
@export var standalone_show_game_ui: bool = true
@export var standalone_tick_trial_timer: bool = false
@export var standalone_trial_duration: float = 15.0
## Floor2 can carry painted collision, such as blocking water edge tiles.
@export var floor2_collision_enabled: bool = true

var _tile_entities: Array = TileEntities.get_table()
var _ghost_death_scene := preload("res://scenes/ui/ghost_hands_death.tscn")
var _death_screen_scene := preload("res://scenes/ui/death_screen.tscn")
var _loading_screen_scene := preload("res://scenes/ui/loading_screen.tscn")
var _taped_map_ui_scene := preload("res://scenes/ui/taped_map_ui.tscn")

# --- Tilemap layers ---
var _floor_layer: TileMapLayer
var _floor2: TileMapLayer
var _floor3: TileMapLayer
var _floor4: TileMapLayer
var _bottom_walls: TileMapLayer
var _top_walls: TileMapLayer
var _side_walls: TileMapLayer
var _side_walls2: TileMapLayer
var _furniture: TileMapLayer
var _furniture2: TileMapLayer
var _overhead: TileMapLayer
var _enemy_layer: TileMapLayer
var _items_layer: TileMapLayer

# --- Runtime containers ---
var _entities: Node2D
var _doors: Node2D
var _traps: Node2D

# --- Standalone mode (when running variant directly via "Play This Scene") ---
var _standalone: bool = false
var _paused: bool = false
var _pause_menu: CanvasLayer = null
var _standalone_player = null
var _standalone_death_screen = null

func _ready() -> void:
	y_sort_enabled = true
	_find_layers()
	_setup_layers()
	_setup_runtime_containers()
	_setup_collision()
	_setup_tile_entities()
	_setup_tile_animations()
	# Apply season swap (works in both standalone and coordinator modes)
	if season != "jungle":
		var swapper = SeasonSwapper.new()
		add_child(swapper)
		swapper.swap_season(season, self)

	# If this scene is the root (no coordinator parent), bootstrap standalone mode
	if get_parent() == get_tree().root or get_parent() is Window:
		_bootstrap_standalone()

func _bootstrap_standalone() -> void:
	_standalone = true
	# Reset cursor to default (project-3 scene-based cursor)
	CustomCursor.reset_cursor()
	GameState.reset_health()
	GameState.ensure_starting_special_tickets(6)
	GameState.ensure_starting_voodoo_dolls(1)
	GameState.ensure_statue_ritual_seeded()
	GameState.ensure_starting_clock()
	GameState.ensure_starting_keys(1)
	if standalone_tick_trial_timer:
		GameState.trial_start = false
		GameState.trial_time_remaining = 0.0
		GameState.start_trial(standalone_trial_duration)

	if standalone_spawn_player:
		_spawn_standalone_player()

	if standalone_show_game_ui:
		_spawn_standalone_game_ui()

	if not GameState.player_died.is_connected(_on_standalone_player_died):
		GameState.player_died.connect(_on_standalone_player_died)
	if not GameState.inventory_selection_changed.is_connected(_on_inventory_selection_changed):
		GameState.inventory_selection_changed.connect(_on_inventory_selection_changed)

func _spawn_standalone_player() -> void:
	var player_scene = preload("res://scenes/player/player.tscn")
	var player = player_scene.instantiate()
	var spawn = get_node_or_null("PlayerSpawn")
	if spawn:
		player.position = spawn.position
	else:
		player.position = Vector2(100, 100)
	add_child(player)
	_standalone_player = player
	# Add a camera to the player if it doesn't have one
	if not player.get_node_or_null("Camera2D"):
		var cam = Camera2D.new()
		cam.name = "Camera2D"
		cam.make_current()
		player.add_child(cam)

func _spawn_standalone_game_ui() -> void:
	var game_ui = preload("res://scenes/ui/jungle_game_ui.tscn").instantiate()
	add_child(game_ui)
	var inventory_panel: Node = game_ui.get_node_or_null("UILayer/InventoryPanel")
	if inventory_panel and inventory_panel.has_signal("pause_requested"):
		inventory_panel.pause_requested.connect(_on_hud_pause_requested)

var _clock_ui: CanvasLayer = null
var _map_ui: CanvasLayer = null

func _unhandled_input(event: InputEvent) -> void:
	if not _standalone:
		return
	if _ghost_death_active:
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		if _clock_ui:
			_close_clock()
			get_viewport().set_input_as_handled()
			return
		if _map_ui:
			_close_map()
			get_viewport().set_input_as_handled()
			return
		if _has_blocking_ui_overlay():
			get_viewport().set_input_as_handled()
			return
		_toggle_pause()
	if _map_ui and event.is_action_pressed("toggle_inventory"):
		get_viewport().set_input_as_handled()
		return
	# Toggle inventory opens/closes clock if player has it
	if event.is_action_pressed("toggle_inventory") and GameState.has_clock:
		if _clock_ui:
			_close_clock()
		else:
			_open_clock()
		get_viewport().set_input_as_handled()
	# Clicking clock in inventory also opens it
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if GameState.selected_inventory_item == GameState.ITEM_CLOCK and not _clock_ui:
			GameState.toggle_selected_inventory_item(GameState.ITEM_CLOCK)  # deselect
			_open_clock()
			get_viewport().set_input_as_handled()

func _open_clock() -> void:
	if _clock_ui or _paused:
		return
	var scene = load("res://scenes/ui/clock_ui.tscn")
	_clock_ui = scene.instantiate()
	_clock_ui.clock_closed.connect(_on_clock_closed)
	_clock_ui.variant_selected.connect(_on_clock_variant_selected)
	add_child(_clock_ui)

func _close_clock() -> void:
	if _clock_ui:
		if _clock_ui.has_method("close"):
			_clock_ui.close()
		else:
			_on_clock_closed()

func _open_map() -> void:
	if _map_ui or _paused:
		return
	if _clock_ui:
		_close_clock()
	var map_ui: CanvasLayer = _taped_map_ui_scene.instantiate()
	_map_ui = map_ui
	if _map_ui.has_signal("closed"):
		_map_ui.closed.connect(_on_map_closed)
	add_child(_map_ui)

func _close_map() -> void:
	if _map_ui:
		if _map_ui.has_method("close"):
			_map_ui.close()
		else:
			_on_map_closed()

func _on_clock_closed() -> void:
	if _clock_ui:
		_clock_ui.queue_free()
	_clock_ui = null

func _on_map_closed() -> void:
	if _map_ui:
		_map_ui.queue_free()
	_map_ui = null

func _on_clock_variant_selected(variant: int) -> void:
	if not GameState.trial_start and variant != GameState.current_variant:
		return
	GameState.current_variant = variant
	_on_clock_closed()

func _on_inventory_selection_changed(item_id: String) -> void:
	if not _standalone:
		return
	if item_id == GameState.ITEM_MAP:
		GameState.clear_selected_inventory_item()
		if _map_ui:
			_close_map()
		else:
			_open_map()
		return
	if item_id != GameState.ITEM_CLOCK:
		return
	GameState.clear_selected_inventory_item()
	if _map_ui:
		if _map_ui.has_method("can_accept_clock_from_inventory") and _map_ui.can_accept_clock_from_inventory():
			_map_ui.place_clock_from_inventory()
		return
	_open_clock()

var _ghost_death_active: bool = false

func _process(delta: float) -> void:
	if _standalone and not _paused:
		if standalone_tick_trial_timer:
			GameState.tick_trial_time(delta)
		GameState.tick_campfire(delta)
		if GameState.trial_time_remaining <= 0.0 and GameState.trial_start:
			trigger_ghost_death_preview()

func start_ghost_death_sequence(player: CharacterBody2D) -> bool:
	if _ghost_death_active or not is_instance_valid(player):
		return false
	_ghost_death_active = true
	var ghost_death = _ghost_death_scene.instantiate()
	add_child(ghost_death)
	ghost_death.start(player)
	return true

func trigger_ghost_death_preview() -> bool:
	return start_ghost_death_sequence(_find_section_player())

func get_section_player() -> CharacterBody2D:
	return _find_section_player()

func _find_section_player() -> CharacterBody2D:
	if is_instance_valid(_standalone_player) and _standalone_player is CharacterBody2D:
		return _standalone_player
	for child in get_children():
		if child is CharacterBody2D:
			return child
	return null

func _on_standalone_player_died() -> void:
	if not _standalone or _standalone_death_screen:
		return
	var player := _find_section_player()
	if is_instance_valid(player):
		player.visible = false
		player.collision_layer = 0
		player.collision_mask = 0
	var death_screen = _death_screen_scene.instantiate()
	_standalone_death_screen = death_screen
	add_child(death_screen)
	death_screen.reload_requested.connect(_on_standalone_death_reload.bind(death_screen))
	if death_screen.has_signal("exit_requested"):
		death_screen.exit_requested.connect(_on_standalone_death_exit.bind(death_screen))

func _on_standalone_death_reload(death_screen: CanvasLayer) -> void:
	if death_screen:
		death_screen.queue_free()
	_standalone_death_screen = null
	_paused = false
	get_tree().paused = false
	GameState.reset()
	_transition_with_loading(get_tree().current_scene.scene_file_path)

func _on_standalone_death_exit(death_screen: CanvasLayer) -> void:
	if death_screen:
		death_screen.queue_free()
	_standalone_death_screen = null
	_paused = false
	get_tree().paused = false
	GameState.reset()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _transition_with_loading(scene_path: String) -> void:
	var loading_screen = _loading_screen_scene.instantiate()
	get_tree().root.add_child(loading_screen)
	loading_screen.transition_to(scene_path)

func _toggle_pause() -> void:
	if _paused:
		_resume()
	else:
		_pause()

func _on_hud_pause_requested() -> void:
	if _has_blocking_ui_overlay():
		return
	if not _paused:
		_pause()

func _has_blocking_ui_overlay() -> bool:
	for group in ["statue_ui_overlay", "campfire_ui_overlay", "campfire_relight_ui_overlay", "boon_ui_overlay", "map_ui_overlay", "stone_puzzle_ui_overlay"]:
		for node in get_tree().get_nodes_in_group(group):
			if node.has_method("is_blocking_pause") and node.is_blocking_pause():
				return true
			if node is CanvasItem and node.visible:
				return true
	return false

func _pause() -> void:
	_paused = true
	_set_hud_pause_state(true)
	get_tree().paused = true
	var pause_scene = preload("res://scenes/ui/pause_menu.tscn")
	_pause_menu = pause_scene.instantiate()
	_pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_menu)
	if _pause_menu.has_signal("resume_requested"):
		_pause_menu.resume_requested.connect(_resume)
	if _pause_menu.has_signal("restart_requested"):
		_pause_menu.restart_requested.connect(_on_restart)
	if _pause_menu.has_signal("quit_requested"):
		_pause_menu.quit_requested.connect(_on_quit)

func _resume() -> void:
	_paused = false
	get_tree().paused = false
	_set_hud_pause_state(false)
	if _pause_menu:
		_pause_menu.queue_free()
		_pause_menu = null

func _on_restart() -> void:
	_paused = false
	get_tree().paused = false
	_set_hud_pause_state(false)
	get_tree().reload_current_scene()

func _on_quit() -> void:
	get_tree().quit()

func _set_hud_pause_state(paused: bool) -> void:
	var inventory_panel: Node = get_node_or_null("GameUI/UILayer/InventoryPanel")
	if inventory_panel and inventory_panel.has_method("set_paused"):
		inventory_panel.set_paused(paused)

# ── Layer discovery ──

func _find_layers() -> void:
	_floor_layer = get_node_or_null("Floor")
	_floor2 = get_node_or_null("Floor2")
	_floor3 = get_node_or_null("Floor3")
	_floor4 = get_node_or_null("Floor4")
	_bottom_walls = get_node_or_null("BottomWalls")
	_top_walls = get_node_or_null("TopWalls")
	_side_walls = get_node_or_null("SideWalls")
	_side_walls2 = get_node_or_null("SideWalls2")
	_furniture = get_node_or_null("Furniture")
	_furniture2 = get_node_or_null("Furniture2")
	_overhead = get_node_or_null("Overhead")
	_enemy_layer = get_node_or_null("EnemyMarkers")
	_items_layer = get_node_or_null("Items")

# ── Layer rendering / z-index / y-sort ──

func _setup_layers() -> void:
	if _floor_layer:
		_floor_layer.z_index = -1
		_floor_layer.collision_enabled = false

	if _floor2:
		_floor2.z_index = -1
		# Floor2 is used for painted water tiles. Generate explicit blockers so
		# collision survives runtime season swaps and water animation updates.
		_floor2.collision_enabled = false

	if _floor3:
		_floor3.z_index = -1
		_floor3.collision_enabled = false

	if _floor4:
		_floor4.z_index = -1
		_floor4.collision_enabled = false

	if _bottom_walls:
		_bottom_walls.collision_enabled = false

	if _top_walls:
		_top_walls.z_index = 5
		_top_walls.collision_enabled = false

	if _side_walls:
		_side_walls.collision_enabled = false

	if _side_walls2:
		_side_walls2.collision_enabled = false

	if _furniture:
		_furniture.y_sort_enabled = true
		_furniture.collision_enabled = false

	if _furniture2:
		_furniture2.y_sort_enabled = true
		_furniture2.collision_enabled = false

	if _overhead:
		_overhead.z_index = 10
		_overhead.collision_enabled = false

	if _enemy_layer:
		_enemy_layer.visible = false
		_enemy_layer.collision_enabled = false

	if _items_layer:
		_items_layer.visible = false
		_items_layer.collision_enabled = false

# ── Runtime containers for spawned entities ──

func _setup_runtime_containers() -> void:
	_entities = Node2D.new()
	_entities.name = "Entities"
	_entities.y_sort_enabled = true
	add_child(_entities)

	_doors = Node2D.new()
	_doors.name = "Doors"
	_doors.y_sort_enabled = true
	add_child(_doors)

	_traps = Node2D.new()
	_traps.name = "Traps"
	_traps.z_index = -1
	add_child(_traps)

# ── Collision generation (StaticBody per layer) ──

func _setup_collision() -> void:
	if floor2_collision_enabled:
		_generate_collision(_floor2, true)
	_generate_collision(_bottom_walls)
	_generate_collision(_side_walls)
	_generate_collision(_side_walls2)
	_generate_collision(_furniture)
	_generate_collision(_furniture2)

## Animation source IDs — tiles from these sources skip collision
## (flowers/grass don't need it; torches get their own from tile_animator)
const _ANIMS_SKIP_COLLISION := [3, 8]

func _generate_collision(layer: TileMapLayer, use_tile_shapes: bool = false) -> void:
	if layer == null:
		return
	var ts = layer.tile_set
	if ts == null:
		return
	var tile_size = Vector2(ts.tile_size)
	var used_cells = layer.get_used_cells()
	if used_cells.is_empty():
		return

	var body = StaticBody2D.new()
	body.collision_layer = 1
	add_child(body)
	body.global_position = layer.global_position
	var added_collision := false

	for cell in used_cells:
		# Skip animated tiles — they handle their own collision
		var src = layer.get_cell_source_id(cell)
		if src in _ANIMS_SKIP_COLLISION:
			continue
		# Skip wasteland animation tiles (src 13, rows >= 13 are the animation section)
		if src == 13 and layer.get_cell_atlas_coords(cell).y >= 13:
			continue
		var pos = layer.map_to_local(cell)
		if use_tile_shapes:
			var tile_data = layer.get_cell_tile_data(cell)
			if tile_data == null:
				continue
			var polygon_count := tile_data.get_collision_polygons_count(0)
			if polygon_count == 0:
				continue
			for polygon_index in range(polygon_count):
				var points: PackedVector2Array = tile_data.get_collision_polygon_points(0, polygon_index)
				if points.is_empty():
					continue
				var col_poly = CollisionPolygon2D.new()
				col_poly.polygon = points
				col_poly.position = pos
				body.add_child(col_poly)
				added_collision = true
			continue

		var col = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = tile_size
		col.shape = shape
		col.position = pos
		body.add_child(col)
		added_collision = true

	if not added_collision:
		body.queue_free()

# ── Entity spawning from marker tiles (project-2 style) ──

func _setup_tile_entities() -> void:
	var terrain_layers: Array[TileMapLayer] = []
	if _floor_layer:
		terrain_layers.append(_floor_layer)
	if _furniture:
		terrain_layers.append(_furniture)
	if _bottom_walls:
		terrain_layers.append(_bottom_walls)

	for entry in _tile_entities:
		if entry.get("floor_managed", false):
			continue

		var size: Vector2i = entry.get("size", Vector2i(1, 1))

		var scan_layers: Array[TileMapLayer] = []
		match entry.get("layer", ""):
			"enemy":
				if _enemy_layer:
					scan_layers = [_enemy_layer]
			"items":
				if _items_layer:
					scan_layers = [_items_layer]
			"walls":
				if _bottom_walls:
					scan_layers.append(_bottom_walls)
				if _top_walls:
					scan_layers.append(_top_walls)
			_:
				scan_layers = terrain_layers

		var count := 0
		for tm in scan_layers:
			var matched_cells: Array[Vector2i] = []
			for cell in tm.get_used_cells():
				if tm.get_cell_source_id(cell) == entry.source and tm.get_cell_atlas_coords(cell) == entry.marker:
					matched_cells.append(cell)

			for cell in matched_cells:
				var world_pos = to_local(tm.to_global(tm.map_to_local(cell)))
				var props = entry.get("props", {}).duplicate()
				var modifiers: Array = entry.get("modifiers", [])
				if modifiers.size() > 0:
					for dx in range(size.x):
						for dy in range(size.y):
							var check_cell = Vector2i(cell.x + dx, cell.y + dy)
							var check_atlas = tm.get_cell_atlas_coords(check_cell)
							for mod in modifiers:
								if check_atlas == mod.atlas:
									props.merge(mod.props)

				if not entry.get("no_erase", false):
					for dx in range(size.x):
						for dy in range(size.y):
							tm.erase_cell(Vector2i(cell.x + dx, cell.y + dy))

				world_pos += Vector2((size.x - 1) * 8.0, (size.y - 1) * 8.0)

				var instance = entry.scene.instantiate()
				instance.position = world_pos
				for key in props:
					if key in instance:
						instance.set(key, props[key])

				var path = entry.scene.resource_path
				if "door" in path and "exit" not in path:
					_doors.add_child(instance)
				elif "trap" in path:
					_traps.add_child(instance)
				else:
					_entities.add_child(instance)
				count += 1

		if count > 0:
			print(entry.scene.resource_path.get_file(), " spawned: ", count)

# ── Tile animations (flowers, torches, grass, glowing stones) ──

func _setup_tile_animations() -> void:
	var animator_script = load("res://scenes/jungle/shared/tile_animator.gd")
	if animator_script:
		var animator = Node.new()
		animator.name = "TileAnimator"
		animator.set_script(animator_script)
		add_child(animator)

	var wasteland_anim_script = load("res://scenes/jungle/shared/wasteland_tile_animator.gd")
	if wasteland_anim_script:
		var wasteland_animator = Node.new()
		wasteland_animator.name = "WastelandTileAnimator"
		wasteland_animator.set_script(wasteland_anim_script)
		add_child(wasteland_animator)

# ── Accessors ──

func get_floor() -> TileMapLayer:
	return _floor_layer

func get_items_layer() -> TileMapLayer:
	return _items_layer

func get_enemy_layer() -> TileMapLayer:
	return _enemy_layer

func get_bottom_walls() -> TileMapLayer:
	return _bottom_walls
