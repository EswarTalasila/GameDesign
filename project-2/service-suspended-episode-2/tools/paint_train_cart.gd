@tool
extends EditorScript

# Paints a compartment-style train cart layout onto the FloorWalls TileMapLayer
# Run via: Script Editor -> File -> Run (Ctrl+Shift+X)

func _run():
	var scene_root = get_editor_interface().get_edited_scene_root()
	if not scene_root:
		print("No scene open!")
		return
	
	var tile_map = scene_root.get_node_or_null("FloorWalls")
	if not tile_map:
		print("No FloorWalls TileMapLayer found!")
		return
	
	var tile_set = tile_map.tile_set
	if not tile_set:
		print("No TileSet assigned!")
		return
	
	# Clear existing tiles
	tile_map.clear()
	
	# Terrain IDs: 0 = floor (lower/dark brown carpet), 1 = wall (upper/dark wood panels)
	var FLOOR = 0
	var WALL = 1
	
	# Train cart dimensions (in tiles)
	# ~26 tiles wide, ~14 tiles tall
	# Layout: 3 compartments on top, corridor on bottom
	var cart_width = 26
	var cart_height = 14
	
	# Collect cells by terrain type
	var wall_cells: Array[Vector2i] = []
	var floor_cells: Array[Vector2i] = []
	
	for x in range(cart_width):
		for y in range(cart_height):
			var is_wall = false
			
			# Outer walls
			if x == 0 or x == cart_width - 1 or y == 0 or y == cart_height - 1:
				is_wall = true
			
			# Compartment divider wall (horizontal) separating compartments from corridor
			# Corridor is bottom 4 rows (y = 10 to 13), compartments are top (y = 1 to 9)
			if y == 9 and x > 0 and x < cart_width - 1:
				is_wall = true
			
			# Compartment vertical dividers
			# Compartment 1: x = 1-7
			# Divider at x = 8
			# Compartment 2: x = 9-15
			# Divider at x = 16
			# Compartment 3: x = 17-24
			if (x == 8 or x == 16) and y >= 1 and y <= 9:
				is_wall = true
			
			# Doorways into compartments from corridor (gaps in the horizontal divider)
			# Door for compartment 1 at x = 4,5
			# Door for compartment 2 at x = 12,13
			# Door for compartment 3 at x = 20,21
			if y == 9:
				if x == 4 or x == 5 or x == 12 or x == 13 or x == 20 or x == 21:
					is_wall = false
			
			# Cart entry/exit doors at each end of corridor
			# Left door at x = 0, y = 11,12
			if x == 0 and (y == 11 or y == 12):
				is_wall = false
			# Right door at x = cart_width-1, y = 11,12
			if x == cart_width - 1 and (y == 11 or y == 12):
				is_wall = false
			
			if is_wall:
				wall_cells.append(Vector2i(x, y))
			else:
				floor_cells.append(Vector2i(x, y))
	
	# Paint terrain using Godot's terrain system
	# set_cells_terrain_connect(layer, cells, terrain_set, terrain)
	tile_map.set_cells_terrain_connect(floor_cells, 0, FLOOR)
	tile_map.set_cells_terrain_connect(wall_cells, 0, WALL)
	
	print("Train cart painted! %d floor tiles, %d wall tiles" % [floor_cells.size(), wall_cells.size()])
	print("Layout: 3 compartments + corridor, entry/exit doors on each end")
