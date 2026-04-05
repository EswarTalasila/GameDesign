extends Node2D

## Room section script — layer setup for room-style tilesets.
## Controls rendering order and collision per layer.
## Collision is generated from painted tiles on wall/furniture layers only.
## Floor/TopWalls/Overhead never collide.

var _floor_layer: TileMapLayer
var _bottom_walls: TileMapLayer
var _top_walls: TileMapLayer
var _side_walls: TileMapLayer
var _furniture_layer: TileMapLayer
var _furniture2_layer: TileMapLayer
var _overhead_layer: TileMapLayer

func _ready() -> void:
	_find_layers()
	_setup_layers()

func _find_layers() -> void:
	_floor_layer = get_node_or_null("Floor")
	_bottom_walls = get_node_or_null("BottomWalls")
	_top_walls = get_node_or_null("TopWalls")
	_side_walls = get_node_or_null("SideWalls")
	_furniture_layer = get_node_or_null("Furniture")
	_furniture2_layer = get_node_or_null("Furniture2")
	_overhead_layer = get_node_or_null("Overhead")

func _setup_layers() -> void:
	# Disable tileset collision on ALL layers first
	for layer in [_floor_layer, _bottom_walls, _top_walls, _side_walls, _furniture_layer, _furniture2_layer, _overhead_layer]:
		if layer:
			layer.collision_enabled = false

	# Floor renders behind
	if _floor_layer:
		_floor_layer.z_index = -1

	# TopWalls render over player
	if _top_walls:
		_top_walls.z_index = 5

	# Furniture y-sorted
	if _furniture_layer:
		_furniture_layer.y_sort_enabled = true
	if _furniture2_layer:
		_furniture2_layer.y_sort_enabled = true

	# Overhead renders on top of everything
	if _overhead_layer:
		_overhead_layer.z_index = 10

	# Generate collision bodies for wall and furniture layers
	_generate_collision(_bottom_walls)
	_generate_collision(_side_walls)
	_generate_collision(_furniture_layer)
	_generate_collision(_furniture2_layer)

func _generate_collision(layer: TileMapLayer) -> void:
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
	# Match the layer's global transform
	body.global_position = layer.global_position

	for cell in used_cells:
		var pos = layer.map_to_local(cell)
		var col = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = tile_size
		col.shape = shape
		col.position = pos
		body.add_child(col)
