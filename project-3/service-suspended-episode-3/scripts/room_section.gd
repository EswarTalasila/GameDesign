extends Node2D

## Room section script — auto-collision and y-sort setup for room-style tilesets.
## Expects child TileMapLayers named:
##   Floor       — walkable ground, no collision
##   BottomWalls — lower wall portions, full-tile collision
##   TopWalls    — upper wall portions, renders over player, NO collision
##   SideWalls   — side-facing wall tiles framing the room
##   Furniture   — y-sorted, bottom-row collision for tall pieces
##   Overhead    — ceiling/top details, renders over everything, no collision

var _floor_layer: TileMapLayer
var _bottom_walls: TileMapLayer
var _top_walls: TileMapLayer
var _side_walls: TileMapLayer
var _furniture_layer: TileMapLayer
var _overhead_layer: TileMapLayer

func _ready() -> void:
	_find_layers()
	_setup_collision()
	_setup_y_sort()

func _find_layers() -> void:
	_floor_layer = get_node_or_null("Floor")
	_bottom_walls = get_node_or_null("BottomWalls")
	_top_walls = get_node_or_null("TopWalls")
	_side_walls = get_node_or_null("SideWalls")
	_furniture_layer = get_node_or_null("Furniture")
	_overhead_layer = get_node_or_null("Overhead")

func _setup_collision() -> void:
	# BottomWalls — every tile gets full collision
	if _bottom_walls:
		_add_collision_to_layer(_bottom_walls, false)

	# TopWalls — NO collision, visual only (renders over player)
	if _top_walls:
		_top_walls.collision_enabled = false

	# SideWalls — collision on each tile
	if _side_walls:
		_add_collision_to_layer(_side_walls, false)

	# Furniture — tall tiles get bottom-row-only collision
	if _furniture_layer:
		_add_collision_to_layer(_furniture_layer, true)

	# Overhead — no collision, renders on top of everything
	if _overhead_layer:
		_overhead_layer.collision_enabled = false
		_overhead_layer.z_index = 10

func _add_collision_to_layer(layer: TileMapLayer, bottom_row_only_for_tall: bool) -> void:
	var ts = layer.tile_set
	if ts == null:
		return
	if ts.get_physics_layers_count() == 0:
		ts.add_physics_layer()
		ts.set_physics_layer_collision_layer(0, 1)

	var tile_size = Vector2(ts.tile_size)
	var half = tile_size / 2.0

	for src_idx in range(ts.get_source_count()):
		var src_id = ts.get_source_id(src_idx)
		var src = ts.get_source(src_id)
		if src is TileSetAtlasSource:
			for i in range(src.get_tiles_count()):
				var tile_id = src.get_tile_id(i)
				var td = src.get_tile_data(tile_id, 0)
				if td == null:
					continue
				if td.get_collision_polygons_count(0) > 0:
					continue
				var atlas_size = src.get_tile_size_in_atlas(tile_id)
				var px = Vector2(atlas_size) * tile_size
				var half_px = px / 2.0

				var col_poly: PackedVector2Array
				if bottom_row_only_for_tall and atlas_size.y > 1:
					col_poly = PackedVector2Array([
						Vector2(-half_px.x, half_px.y - tile_size.y),
						Vector2(half_px.x, half_px.y - tile_size.y),
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
				td.y_sort_origin = int(half_px.y)

func _setup_y_sort() -> void:
	if _floor_layer:
		_floor_layer.z_index = -1

	# TopWalls render over player
	if _top_walls:
		_top_walls.z_index = 5

	if _furniture_layer:
		_furniture_layer.y_sort_enabled = true
