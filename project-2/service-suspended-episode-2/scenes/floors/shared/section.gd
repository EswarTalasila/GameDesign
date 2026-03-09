extends Node2D
class_name DungeonSection

# Reusable section script — attach to any section variant scene root.
# Expects child nodes named: Terrain, BottomWalls, TopWalls, Doors, Overhead, SideWalls
# Terrain should have children: Furniture, Furniture2, EnemyMarkers, Items (optional)

var _tile_entities: Array = TileEntities.get_table()

# --- Tilemap layers (found dynamically) ---
var _terrain: TileMapLayer
var _furniture: TileMapLayer
var _furniture2: TileMapLayer
var _bottom_walls: TileMapLayer
var _top_walls: TileMapLayer
var _doors: Node2D
var _traps: Node2D
var _overhead: TileMapLayer
var _enemy_layer: TileMapLayer
var _items_layer: TileMapLayer

func _ready() -> void:
	y_sort_enabled = true
	_find_layers()
	_setup_auto_collision()
	_setup_tile_entities()

# ── Layer discovery ──

func _find_layers() -> void:
	_terrain = get_node_or_null("Terrain")
	if _terrain:
		# Floor tiles always render behind everything (fixes negative-y sections)
		_terrain.z_index = -1
		_furniture = _terrain.get_node_or_null("Furniture")
		_furniture2 = _terrain.get_node_or_null("Furniture2")
		_enemy_layer = _terrain.get_node_or_null("EnemyMarkers")
		_items_layer = _terrain.get_node_or_null("Items")
	_bottom_walls = get_node_or_null("BottomWalls")
	_top_walls = get_node_or_null("TopWalls")
	_doors = get_node_or_null("Doors")
	if _doors:
		_doors.y_sort_enabled = true
	_overhead = get_node_or_null("Overhead")
	# Disable collision on TopWalls — visual only, no physics
	if _top_walls:
		_top_walls.collision_enabled = false
	# Reparent Furniture layers to section root so they participate in y-sort chain
	for furn in [_furniture, _furniture2]:
		if furn:
			var pos = furn.global_position
			furn.get_parent().remove_child(furn)
			add_child(furn)
			furn.global_position = pos
			furn.y_sort_enabled = true
	# Traps container — non-y-sorted, renders above terrain but below walls/entities
	_traps = Node2D.new()
	_traps.name = "Traps"
	_traps.z_index = -1
	add_child(_traps)

# ── Auto-collision for wall & furniture tile sources ──

func _setup_auto_collision() -> void:
	if not _terrain:
		return
	var ts = _terrain.tile_set
	if ts == null:
		return

	var half = Vector2(ts.tile_size) / 2.0
	var polygon = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y)
	])

	# Source 0 = floor/stairs (y_sort_origin for Stairs layer depth sorting)
	# Terrain layer ignores this (no y_sort), but Stairs layer needs it
	# so stair tiles sort at same y as wall tiles, with tree order as tiebreaker.
	var floor_src = ts.get_source(0) as TileSetAtlasSource
	if floor_src:
		for i in range(floor_src.get_tiles_count()):
			var td = floor_src.get_tile_data(floor_src.get_tile_id(i), 0)
			td.y_sort_origin = int(half.y)

	# Source 1 = walls (y_sort_origin at tile bottom for depth sorting)
	var wall_src = ts.get_source(1) as TileSetAtlasSource
	if wall_src:
		for i in range(wall_src.get_tiles_count()):
			var td = wall_src.get_tile_data(wall_src.get_tile_id(i), 0)
			td.y_sort_origin = int(half.y)
			if td.get_collision_polygons_count(0) == 0:
				td.add_collision_polygon(0)
				td.set_collision_polygon_points(0, 0, polygon)

	# Source 2 = decorations/furniture
	# y_sort_origin at bottom for depth sorting; tall furniture collides on bottom row only
	var deco_src = ts.get_source(2) as TileSetAtlasSource
	if deco_src:
		for i in range(deco_src.get_tiles_count()):
			var tile_id = deco_src.get_tile_id(i)
			if tile_id.x >= 14 and tile_id.y >= 5:
				continue  # skip carpets
			var td = deco_src.get_tile_data(tile_id, 0)
			var atlas_size = deco_src.get_tile_size_in_atlas(tile_id)
			var px = Vector2(atlas_size) * Vector2(ts.tile_size)
			var half_px = px / 2.0
			td.y_sort_origin = int(half_px.y)
			if td.get_collision_polygons_count(0) == 0:
				var col_poly: PackedVector2Array
				if atlas_size.y > 1:
					# Bottom row only for tall furniture
					col_poly = PackedVector2Array([
						Vector2(-half_px.x, half_px.y - ts.tile_size.y),
						Vector2(half_px.x, half_px.y - ts.tile_size.y),
						Vector2(half_px.x, half_px.y),
						Vector2(-half_px.x, half_px.y),
					])
				else:
					col_poly = PackedVector2Array([
						Vector2(-half_px.x, -half_px.y),
						Vector2(half_px.x, -half_px.y),
						Vector2(half_px.x, half_px.y),
						Vector2(-half_px.x, half_px.y),
					])
				td.add_collision_polygon(0)
				td.set_collision_polygon_points(0, 0, col_poly)

# ── Entity spawning from marker tiles ──

func _setup_tile_entities() -> void:
	var tilemaps: Array[TileMapLayer] = []
	if _terrain:
		tilemaps.append(_terrain)
	if _furniture:
		tilemaps.append(_furniture)
	if _bottom_walls:
		tilemaps.append(_bottom_walls)
	if _top_walls:
		tilemaps.append(_top_walls)

	for entry in _tile_entities:
		if entry.get("floor_managed", false):
			continue
		var count := 0
		var size: Vector2i = entry.get("size", Vector2i(1, 1))

		# Route to the correct tilemap(s) based on optional "layer" key
		var scan_layers: Array[TileMapLayer] = []
		if entry.get("layer") == "enemy" and _enemy_layer:
			scan_layers = [_enemy_layer]
		elif entry.get("layer") == "items" and _items_layer:
			scan_layers = [_items_layer]
		else:
			scan_layers = tilemaps

		for tm in scan_layers:
			var matched_cells: Array[Vector2i] = []
			for cell in tm.get_used_cells():
				if tm.get_cell_source_id(cell) == entry.source and tm.get_cell_atlas_coords(cell) == entry.marker:
					matched_cells.append(cell)

			for cell in matched_cells:
				var world_pos = to_local(tm.to_global(tm.map_to_local(cell)))
				# Check for modifier tiles in the footprint before erasing
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
				# Erase all tiles in the entity's footprint (unless no_erase)
				if not entry.get("no_erase", false):
					for dx in range(size.x):
						for dy in range(size.y):
							tm.erase_cell(Vector2i(cell.x + dx, cell.y + dy))
				# Center entity on multi-tile footprint
				world_pos += Vector2((size.x - 1) * 8.0, (size.y - 1) * 8.0)
				var instance = entry.scene.instantiate()
				instance.position = world_pos
				for key in props:
					if key in instance:
						instance.set(key, props[key])
				# Route to non-y-sorted containers by entity type
				var path = entry.scene.resource_path
				if "door" in path and "exit" not in path:
					if _doors:
						_doors.add_child(instance)
					else:
						add_child(instance)
				elif "trap" in path:
					_traps.add_child(instance)
				else:
					add_child(instance)
				count += 1
		if count > 0:
			print(entry.scene.resource_path.get_file(), " spawned: ", count)

func get_terrain() -> TileMapLayer:
	return _terrain

func get_items_layer() -> TileMapLayer:
	return _items_layer

func get_bottom_walls() -> TileMapLayer:
	return _bottom_walls
