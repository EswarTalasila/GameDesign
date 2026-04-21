extends Node2D
class_name TrainSection

## Universal layer handler for train section scenes.
## Same layer philosophy as JungleSection but for the train environment.
##
## Expected child TileMapLayers (all optional):
##   Floor          — ground / track tiles, z=-1, no collision
##   BottomWalls    — lower walls (seats, panels), collision
##   TopWalls       — walls that render over player, z=5, no collision
##   SideWalls      — side boundaries (train walls), collision
##   Furniture      — interior objects (seats, luggage), y_sort, collision
##   Furniture2     — extra furniture, y_sort, collision
##   Overhead       — ceiling panels / lights, z=10, no collision
##
## Runtime containers created automatically:
##   Entities       — y_sort container for NPCs, interactables
##   Doors          — y_sort container for door scenes

var _floor_layer: TileMapLayer
var _bottom_walls: TileMapLayer
var _top_walls: TileMapLayer
var _side_walls: TileMapLayer
var _furniture: TileMapLayer
var _furniture2: TileMapLayer
var _overhead: TileMapLayer

var _entities: Node2D
var _doors: Node2D

func _ready() -> void:
	y_sort_enabled = true
	_find_layers()
	_setup_layers()
	_setup_runtime_containers()
	_setup_collision()

func _find_layers() -> void:
	_floor_layer = get_node_or_null("Floor")
	_bottom_walls = get_node_or_null("BottomWalls")
	_top_walls = get_node_or_null("TopWalls")
	_side_walls = get_node_or_null("SideWalls")
	_furniture = get_node_or_null("Furniture")
	_furniture2 = get_node_or_null("Furniture2")
	_overhead = get_node_or_null("Overhead")

func _setup_layers() -> void:
	if _floor_layer:
		_floor_layer.z_index = -1
		_floor_layer.collision_enabled = false

	if _bottom_walls:
		_bottom_walls.collision_enabled = false

	if _top_walls:
		_top_walls.z_index = 5
		_top_walls.collision_enabled = false

	if _side_walls:
		_side_walls.collision_enabled = false

	if _furniture:
		_furniture.y_sort_enabled = true
		_furniture.collision_enabled = false

	if _furniture2:
		_furniture2.y_sort_enabled = true
		_furniture2.collision_enabled = false

	if _overhead:
		_overhead.z_index = 10
		_overhead.collision_enabled = false

func _setup_runtime_containers() -> void:
	_entities = Node2D.new()
	_entities.name = "Entities"
	_entities.y_sort_enabled = true
	add_child(_entities)

	_doors = Node2D.new()
	_doors.name = "Doors"
	_doors.y_sort_enabled = true
	add_child(_doors)

func _setup_collision() -> void:
	_generate_collision(_bottom_walls)
	_generate_collision(_side_walls)
	_generate_collision(_furniture)
	_generate_collision(_furniture2)

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
	body.global_position = layer.global_position

	for cell in used_cells:
		var pos = layer.map_to_local(cell)
		var col = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = tile_size
		col.shape = shape
		col.position = pos
		body.add_child(col)

func get_floor() -> TileMapLayer:
	return _floor_layer

func get_bottom_walls() -> TileMapLayer:
	return _bottom_walls
