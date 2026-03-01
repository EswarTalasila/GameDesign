extends Node2D

@onready var floor_walls: TileMapLayer = $FloorWalls
@onready var player: CharacterBody2D = $Entities/Player
@onready var tickets_container: Node2D = $Entities/Tickets
@onready var traps_container: Node2D = $Entities/Traps
@onready var exit_door: Area2D = $Entities/ExitDoor
@onready var ticket_label: Label = $CanvasLayer/TicketCounter
@onready var dialog: PanelContainer = $CanvasLayer/DialogBubble

var config: DungeonConfig
var generator: DungeonGenerator
var _ticket_scene = preload("res://scenes/pickups/ticket_pickup.tscn")
var _trap_scene = preload("res://scenes/traps/trap_spikes.tscn")

# Atlas source IDs (assigned at runtime)
var SRC_FLOOR: int = -1
var SRC_WALL: int = -1
var SRC_DECOR: int = -1

# --- Tile coordinates (atlas coords within each spritesheet) ---
# Floor: dark stone tiles from row 0-1 of floor_and_stairs.png
var _floor_tiles = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(0, 1), Vector2i(1, 1)]

# Wall: tiles from walls.png
# Row 0 = wall caps/tops (battlements)
# Row 1 = wall face (stone front with windows etc.)
# Row 2 = lower wall / horizontal stone bands
var _wall_top_tiles = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
var _wall_face_tiles = [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)]
var _wall_base_tiles = [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)]

var _mutation_lines: Array[String] = [
	"The walls have shifted...",
	"Something feels different this time.",
	"The dungeon remembers you.",
	"Reality is fraying at the edges.",
	"The corridors are whispering.",
	"You've been here before. Or have you?",
	"The traps know where you walk.",
	"Time folds in on itself.",
]

func _ready() -> void:
	config = DungeonConfig.new()
	generator = DungeonGenerator.new()

	# Build TileSet at runtime from the spritesheet PNGs
	var tileset = _build_tileset()
	floor_walls.tile_set = tileset

	var seed_val = GameState.get_effective_seed()
	var loop = GameState.loop_count
	var result = generator.generate(config, seed_val, loop)

	# Paint the dungeon using context-aware tile placement
	_paint_dungeon(result)

	# Position player at spawn
	player.position = Vector2(result.spawn_pos) * 16 + Vector2(8, 8)

	# Spawn tickets
	for pos in result.ticket_positions:
		var ticket = _ticket_scene.instantiate()
		ticket.position = Vector2(pos) * 16 + Vector2(8, 8)
		tickets_container.add_child(ticket)

	# Spawn traps
	for pos in result.trap_positions:
		var trap = _trap_scene.instantiate()
		trap.position = Vector2(pos) * 16 + Vector2(8, 8)
		traps_container.add_child(trap)

	# Position exit door
	exit_door.position = Vector2(result.exit_pos) * 16 + Vector2(8, 8)
	exit_door.visible = false
	exit_door.monitoring = false

	# Connect signals
	GameState.all_tickets_collected.connect(_on_all_tickets_collected)
	GameState.ticket_collected.connect(_on_ticket_collected)
	GameState.player_died.connect(_on_player_died)

	_update_ticket_label()

	# Show mutation flavor text
	if loop > 0 and dialog:
		var line = _mutation_lines[mini(loop - 1, _mutation_lines.size() - 1)]
		dialog.show_text(line, "???")

# --- TileSet creation ---

func _build_tileset() -> TileSet:
	var ts = TileSet.new()
	ts.tile_size = Vector2i(16, 16)

	# Add physics layer for wall collision
	ts.add_physics_layer()

	# Full-tile collision polygon (relative to tile center)
	var wall_polygon = PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)
	])

	# Source 0: Floor (no collision)
	var floor_src = TileSetAtlasSource.new()
	floor_src.texture = preload("res://assets/tilesets/dungeon/dungeon_tileset_floor_and_stairs.png")
	floor_src.texture_region_size = Vector2i(16, 16)
	for tile in _floor_tiles:
		floor_src.create_tile(tile)
	SRC_FLOOR = ts.add_source(floor_src)

	# Source 1: Walls (with collision)
	var wall_src = TileSetAtlasSource.new()
	wall_src.texture = preload("res://assets/tilesets/dungeon/dungeon_tileset_walls.png")
	wall_src.texture_region_size = Vector2i(16, 16)
	var all_wall_tiles = {}
	for tile in _wall_top_tiles + _wall_face_tiles + _wall_base_tiles:
		if not all_wall_tiles.has(tile):
			wall_src.create_tile(tile)
			var td = wall_src.get_tile_data(tile, 0)
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, wall_polygon)
			all_wall_tiles[tile] = true
	SRC_WALL = ts.add_source(wall_src)

	return ts

# --- Painting ---

func _paint_dungeon(result: Dictionary) -> void:
	var grid = result.grid
	var w: int = result.width
	var h: int = result.height
	var rng = RandomNumberGenerator.new()
	rng.seed = GameState.get_effective_seed() + 999

	for y in range(h):
		for x in range(w):
			var pos = Vector2i(x, y)

			if grid[y][x]:
				# Floor cell — pick a random floor tile
				var tile = _floor_tiles[rng.randi() % _floor_tiles.size()]
				floor_walls.set_cell(pos, SRC_FLOOR, tile)
			else:
				# Wall cell — check neighbors to decide what to show
				var floor_n = _is_floor(grid, x, y - 1, w, h)
				var floor_s = _is_floor(grid, x, y + 1, w, h)
				var floor_e = _is_floor(grid, x + 1, y, w, h)
				var floor_w = _is_floor(grid, x - 1, y, w, h)

				var has_any_floor_neighbor = floor_n or floor_s or floor_e or floor_w
				if not has_any_floor_neighbor:
					# Also check diagonals
					has_any_floor_neighbor = (
						_is_floor(grid, x - 1, y - 1, w, h) or
						_is_floor(grid, x + 1, y - 1, w, h) or
						_is_floor(grid, x - 1, y + 1, w, h) or
						_is_floor(grid, x + 1, y + 1, w, h)
					)

				if not has_any_floor_neighbor:
					# Deep interior wall — leave empty (dark void)
					continue

				# Edge wall — pick tile based on which side faces floor
				if floor_s:
					# Floor is below this wall → player sees wall top/cap
					var tile = _wall_top_tiles[rng.randi() % _wall_top_tiles.size()]
					floor_walls.set_cell(pos, SRC_WALL, tile)
				elif floor_n:
					# Floor is above this wall → player sees wall base
					var tile = _wall_base_tiles[rng.randi() % _wall_base_tiles.size()]
					floor_walls.set_cell(pos, SRC_WALL, tile)
				else:
					# Side wall or diagonal-only neighbor → wall face
					var tile = _wall_face_tiles[rng.randi() % _wall_face_tiles.size()]
					floor_walls.set_cell(pos, SRC_WALL, tile)

func _is_floor(grid: Array, x: int, y: int, w: int, h: int) -> bool:
	if x < 0 or x >= w or y < 0 or y >= h:
		return false
	return grid[y][x]

# --- HUD & signals ---

func _update_ticket_label() -> void:
	ticket_label.text = "Tickets: %d / %d" % [GameState.tickets_collected, GameState.tickets_required]

func _on_ticket_collected(_current: int, _total: int) -> void:
	_update_ticket_label()

func _on_all_tickets_collected() -> void:
	exit_door.appear()

func _on_player_died() -> void:
	player.set_physics_process(false)
	var death_screen = preload("res://scenes/ui/death_screen.tscn").instantiate()
	death_screen.show_death("res://scenes/dungeon/dungeon.tscn")
	get_tree().root.add_child(death_screen)

func _exit_tree() -> void:
	if GameState.all_tickets_collected.is_connected(_on_all_tickets_collected):
		GameState.all_tickets_collected.disconnect(_on_all_tickets_collected)
	if GameState.ticket_collected.is_connected(_on_ticket_collected):
		GameState.ticket_collected.disconnect(_on_ticket_collected)
	if GameState.player_died.is_connected(_on_player_died):
		GameState.player_died.disconnect(_on_player_died)
