class_name TileEntities

# Shared marker→entity table used by all dungeon sections.
# Each entry: { source, marker, scene, size, layer? }
# source 0 = floor, 1 = walls (terrain), 2 = decorations (furniture)
# Optional "layer" key routes scanning to a named TileMapLayer child.

static func get_table() -> Array:
	return [
		# Torches
		{ "source": 1, "marker": Vector2i(13, 6), "scene": preload("res://scenes/torches/torch.tscn"), "size": Vector2i(1, 1) },
		{ "source": 2, "marker": Vector2i(2, 3), "scene": preload("res://scenes/torches/torch_pillar2.tscn"), "size": Vector2i(1, 1) },
		{ "source": 2, "marker": Vector2i(5, 7), "scene": preload("res://scenes/torches/torch_wall.tscn"), "size": Vector2i(1, 2) },
		# Spikes
		{ "source": 0, "marker": Vector2i(8, 0), "scene": preload("res://scenes/traps/trap_spikes.tscn"), "size": Vector2i(1, 1) },
		# Doors
		{ "source": 1, "marker": Vector2i(7, 4), "scene": preload("res://scenes/doors/door_framed_wood.tscn"), "size": Vector2i(1, 1) },
		{ "source": 1, "marker": Vector2i(13, 4), "scene": preload("res://scenes/doors/door_framed_cell.tscn"), "size": Vector2i(1, 1) },
		{ "source": 2, "marker": Vector2i(0, 0), "scene": preload("res://scenes/doors/door_wood.tscn"), "size": Vector2i(1, 2) },
		{ "source": 2, "marker": Vector2i(2, 0), "scene": preload("res://scenes/doors/door_cell.tscn"), "size": Vector2i(1, 2) },
		# Lever
		{ "source": 2, "marker": Vector2i(9, 3), "scene": preload("res://scenes/interactables/lever.tscn"), "size": Vector2i(1, 1) },
		# Chest — if any tile in the 3x2 footprint is (14,3) the chest spawns locked
		{ "source": 2, "marker": Vector2i(5, 5), "scene": preload("res://scenes/interactables/chest.tscn"), "size": Vector2i(3, 2),
		  "modifiers": [{ "atlas": Vector2i(14, 3), "props": { "locked": true } }] },
		# Locked doors (framed variants)
		{ "source": 1, "marker": Vector2i(11, 9), "scene": preload("res://scenes/doors/door_framed_wood.tscn"), "size": Vector2i(1, 1), "props": { "locked": true } },
		{ "source": 1, "marker": Vector2i(13, 9), "scene": preload("res://scenes/doors/door_framed_cell.tscn"), "size": Vector2i(1, 1), "props": { "locked": true } },
		# Enemies (scanned from EnemyMarkers layer — separate tileset)
		{ "source": 0, "marker": Vector2i(0, 0), "scene": preload("res://scenes/enemies/sword_enemy.tscn"), "size": Vector2i(1, 2), "layer": "enemy" },
		# Ticket pickups (scanned from Items layer — source 0 in item_spawn_markers.tres)
		{ "source": 0, "marker": Vector2i(0, 0), "scene": preload("res://scenes/pickups/ticket_pickup.tscn"), "size": Vector2i(1, 1), "layer": "items" },
		# Key pickups (scanned from Items layer — source 1 in item_spawn_markers.tres)
		{ "source": 1, "marker": Vector2i(0, 0), "scene": preload("res://scenes/pickups/key_pickup.tscn"), "size": Vector2i(1, 1), "layer": "items" },
		# Health pickups (scanned from Items layer — source 2 in item_spawn_markers.tres)
		{ "source": 2, "marker": Vector2i(0, 0), "scene": preload("res://scenes/pickups/health_pickup.tscn"), "size": Vector2i(1, 1), "layer": "items" },
		# Special ticket pickups — floor_managed: floor.gd picks 2 at random from all painted markers
		{ "source": 3, "marker": Vector2i(0, 0), "scene": preload("res://scenes/pickups/special_ticket_pickup.tscn"), "size": Vector2i(1, 1), "layer": "items", "floor_managed": true },
	]
