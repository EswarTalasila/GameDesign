class_name DungeonGenerator
extends RefCounted

# BSP dungeon generator. Pure data — no scene tree dependencies.
# Returns a dictionary with floor_cells, wall_cells, rooms, spawn_pos, etc.

var _rng: RandomNumberGenerator
var _config: DungeonConfig
var _grid: Array  # 2D array: true = floor, false = wall
var _rooms: Array[Rect2i]

func generate(config: DungeonConfig, seed_value: int, loop_count: int = 0) -> Dictionary:
	_config = config
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_value
	_rooms = []

	# Initialize grid to all wall
	_grid = []
	for y in range(_config.height):
		var row = []
		row.resize(_config.width)
		row.fill(false)
		_grid.append(row)

	# BSP split and carve
	var root_rect = Rect2i(1, 1, _config.width - 2, _config.height - 2)
	_bsp_split(root_rect, 0)

	# Connect rooms with corridors
	_connect_rooms()

	# Choose spawn and exit rooms
	var spawn_room = _rooms[0]
	var exit_room = _rooms[_rooms.size() - 1]
	var spawn_pos = Vector2i(spawn_room.position.x + spawn_room.size.x / 2, spawn_room.position.y + spawn_room.size.y / 2)
	var exit_pos = Vector2i(exit_room.position.x + exit_room.size.x / 2, exit_room.position.y + exit_room.size.y / 2)

	# Collect floor and wall cells
	var floor_cells: Array[Vector2i] = []
	var wall_cells: Array[Vector2i] = []
	for y in range(_config.height):
		for x in range(_config.width):
			if _grid[y][x]:
				floor_cells.append(Vector2i(x, y))
			else:
				wall_cells.append(Vector2i(x, y))

	# Place tickets in rooms (not spawn or exit room)
	var ticket_positions = _place_tickets(spawn_room, exit_room)

	# Place traps
	var trap_positions = _place_traps(spawn_room, exit_room, loop_count)

	# Apply mutations for loop_count > 0
	if loop_count > 0:
		_apply_mutations(trap_positions, ticket_positions, loop_count, spawn_room, exit_room)

	return {
		"grid": _grid,
		"width": _config.width,
		"height": _config.height,
		"floor_cells": floor_cells,
		"wall_cells": wall_cells,
		"rooms": _rooms.duplicate(),
		"spawn_pos": spawn_pos,
		"exit_pos": exit_pos,
		"ticket_positions": ticket_positions,
		"trap_positions": trap_positions,
	}

# --- BSP ---

func _bsp_split(rect: Rect2i, depth: int) -> void:
	var min_size = _config.min_room_size * 2 + 1

	if depth >= _config.max_bsp_depth or (rect.size.x < min_size and rect.size.y < min_size):
		_carve_room(rect)
		return

	var split_h = rect.size.x < rect.size.y
	if rect.size.x >= min_size and rect.size.y >= min_size:
		split_h = _rng.randi() % 2 == 0

	if split_h:
		if rect.size.y < min_size:
			_carve_room(rect)
			return
		var split = _rng.randi_range(rect.position.y + _config.min_room_size, rect.position.y + rect.size.y - _config.min_room_size)
		_bsp_split(Rect2i(rect.position.x, rect.position.y, rect.size.x, split - rect.position.y), depth + 1)
		_bsp_split(Rect2i(rect.position.x, split, rect.size.x, rect.position.y + rect.size.y - split), depth + 1)
	else:
		if rect.size.x < min_size:
			_carve_room(rect)
			return
		var split = _rng.randi_range(rect.position.x + _config.min_room_size, rect.position.x + rect.size.x - _config.min_room_size)
		_bsp_split(Rect2i(rect.position.x, rect.position.y, split - rect.position.x, rect.size.y), depth + 1)
		_bsp_split(Rect2i(split, rect.position.y, rect.position.x + rect.size.x - split, rect.size.y), depth + 1)

func _carve_room(bounds: Rect2i) -> void:
	var margin_x = _rng.randi_range(1, max(1, (bounds.size.x - _config.min_room_size) / 2))
	var margin_y = _rng.randi_range(1, max(1, (bounds.size.y - _config.min_room_size) / 2))
	var room = Rect2i(
		bounds.position.x + margin_x,
		bounds.position.y + margin_y,
		max(_config.min_room_size, bounds.size.x - margin_x * 2),
		max(_config.min_room_size, bounds.size.y - margin_y * 2),
	)

	# Clamp to grid
	room.position.x = clampi(room.position.x, 1, _config.width - 2)
	room.position.y = clampi(room.position.y, 1, _config.height - 2)
	room.size.x = mini(room.size.x, _config.width - room.position.x - 1)
	room.size.y = mini(room.size.y, _config.height - room.position.y - 1)

	for y in range(room.position.y, room.position.y + room.size.y):
		for x in range(room.position.x, room.position.x + room.size.x):
			_grid[y][x] = true

	_rooms.append(room)

# --- Corridors ---

func _connect_rooms() -> void:
	for i in range(_rooms.size() - 1):
		var a = _room_center(_rooms[i])
		var b = _room_center(_rooms[i + 1])
		if _rng.randi() % 2 == 0:
			_carve_h_corridor(a.x, b.x, a.y)
			_carve_v_corridor(a.y, b.y, b.x)
		else:
			_carve_v_corridor(a.y, b.y, a.x)
			_carve_h_corridor(a.x, b.x, b.y)

func _room_center(room: Rect2i) -> Vector2i:
	return Vector2i(room.position.x + room.size.x / 2, room.position.y + room.size.y / 2)

func _carve_h_corridor(x1: int, x2: int, y: int) -> void:
	var sx = mini(x1, x2)
	var ex = maxi(x1, x2)
	for x in range(sx, ex + 1):
		for w in range(_config.corridor_width):
			var cy = clampi(y + w, 1, _config.height - 2)
			if x >= 0 and x < _config.width:
				_grid[cy][x] = true

func _carve_v_corridor(y1: int, y2: int, x: int) -> void:
	var sy = mini(y1, y2)
	var ey = maxi(y1, y2)
	for y in range(sy, ey + 1):
		for w in range(_config.corridor_width):
			var cx = clampi(x + w, 1, _config.width - 2)
			if y >= 0 and y < _config.height:
				_grid[y][cx] = true

# --- Placement ---

func _get_room_floor_cells(room: Rect2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	# Inset by 1 to avoid placing on room edges
	for y in range(room.position.y + 1, room.position.y + room.size.y - 1):
		for x in range(room.position.x + 1, room.position.x + room.size.x - 1):
			if _grid[y][x]:
				cells.append(Vector2i(x, y))
	return cells

func _place_tickets(spawn_room: Rect2i, exit_room: Rect2i) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	var candidate_rooms: Array[Rect2i] = []

	for room in _rooms:
		if room != spawn_room and room != exit_room:
			candidate_rooms.append(room)

	if candidate_rooms.is_empty():
		candidate_rooms = _rooms.duplicate()

	var placed = 0
	var attempts = 0
	while placed < _config.base_ticket_count and attempts < 200:
		var room = candidate_rooms[_rng.randi() % candidate_rooms.size()]
		var cells = _get_room_floor_cells(room)
		if cells.is_empty():
			attempts += 1
			continue
		var pos = cells[_rng.randi() % cells.size()]
		if not positions.has(pos):
			positions.append(pos)
			placed += 1
		attempts += 1

	return positions

func _place_traps(spawn_room: Rect2i, exit_room: Rect2i, loop_count: int) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	var total_traps = _config.base_trap_count + loop_count * _config.traps_per_loop

	# Collect all floor cells not in spawn room
	var spawn_cells = _get_room_floor_cells(spawn_room)
	var all_floor: Array[Vector2i] = []
	for y in range(_config.height):
		for x in range(_config.width):
			if _grid[y][x]:
				var cell = Vector2i(x, y)
				if not spawn_cells.has(cell):
					all_floor.append(cell)

	var placed = 0
	var attempts = 0
	while placed < total_traps and attempts < 500:
		var pos = all_floor[_rng.randi() % all_floor.size()]
		if not positions.has(pos):
			positions.append(pos)
			placed += 1
		attempts += 1

	return positions

# --- Mutations ---

func _apply_mutations(trap_positions: Array[Vector2i], ticket_positions: Array[Vector2i], loop_count: int, spawn_room: Rect2i, exit_room: Rect2i) -> void:
	# Shift trap positions by random offset
	for i in range(trap_positions.size()):
		var offset = Vector2i(
			_rng.randi_range(-loop_count, loop_count),
			_rng.randi_range(-loop_count, loop_count)
		)
		var new_pos = trap_positions[i] + offset
		new_pos.x = clampi(new_pos.x, 1, _config.width - 2)
		new_pos.y = clampi(new_pos.y, 1, _config.height - 2)
		if _grid[new_pos.y][new_pos.x]:
			trap_positions[i] = new_pos

	# Reshuffle tickets to different rooms
	ticket_positions.clear()
	var new_tickets = _place_tickets(spawn_room, exit_room)
	for pos in new_tickets:
		ticket_positions.append(pos)

	# Loop 2+: flood a room edge with traps
	if loop_count >= 2 and _rooms.size() > 2:
		var flood_room = _rooms[_rng.randi_range(1, _rooms.size() - 2)]
		for x in range(flood_room.position.x, flood_room.position.x + flood_room.size.x):
			var edge_pos = Vector2i(x, flood_room.position.y)
			if _grid[edge_pos.y][edge_pos.x] and not trap_positions.has(edge_pos):
				trap_positions.append(edge_pos)

	# Loop 3+: add dead-end corridors
	if loop_count >= 3:
		for i in range(loop_count - 2):
			var room = _rooms[_rng.randi() % _rooms.size()]
			var center = _room_center(room)
			var dir = _rng.randi() % 4
			var length = _rng.randi_range(3, 6)
			for step in range(length):
				var pos = center
				match dir:
					0: pos += Vector2i(step, 0)
					1: pos += Vector2i(-step, 0)
					2: pos += Vector2i(0, step)
					3: pos += Vector2i(0, -step)
				if pos.x > 0 and pos.x < _config.width - 1 and pos.y > 0 and pos.y < _config.height - 1:
					_grid[pos.y][pos.x] = true
