@tool
extends EditorScript

# Run this in Godot: open this script, then Script → Run (Ctrl+Shift+X)
# Creates dungeon_terrain.tres with all non-transparent tiles from the dark dungeon spritesheets.

func _run() -> void:
	var ts = TileSet.new()
	ts.tile_size = Vector2i(16, 16)

	# Physics layer for wall collision (assign in editor after)
	ts.add_physics_layer()

	var sources = [
		"res://assets/tilesets/dungeon/dungeon_tileset_floor_and_stairs.png",
		"res://assets/tilesets/dungeon/dungeon_tileset_walls.png",
		"res://assets/tilesets/dungeon/dungeon_tileset_decorations.png",
		"res://assets/tilesets/dungeon/dungeon_tileset_water.png",
	]

	var names = ["Floor & Stairs", "Walls", "Decorations", "Water"]

	for i in range(sources.size()):
		var tex = load(sources[i]) as Texture2D
		if tex == null:
			print("Skipping (not found): ", sources[i])
			continue

		var src = TileSetAtlasSource.new()
		src.texture = tex
		src.texture_region_size = Vector2i(16, 16)

		var img = tex.get_image()
		var cols = img.get_width() / 16
		var rows = img.get_height() / 16
		var tile_count = 0

		for y in range(rows):
			for x in range(cols):
				if _has_visible_pixels(img, x * 16, y * 16, 16, 16):
					src.create_tile(Vector2i(x, y))
					tile_count += 1

		ts.add_source(src)
		print("[%d] %s: %d tiles (%dx%d grid)" % [i, names[i], tile_count, cols, rows])

	var err = ResourceSaver.save(ts, "res://assets/tilesets/dungeon/dungeon_terrain.tres")
	if err == OK:
		print("Saved dungeon_terrain.tres successfully!")
		print("Open it in the TileSet editor to start painting.")
		print("To add wall collision: select wall tiles → Paint tab → Physics Layer 0 → draw rectangle.")
	else:
		print("Error saving: ", err)

func _has_visible_pixels(img: Image, rx: int, ry: int, w: int, h: int) -> bool:
	for y in range(ry, ry + h):
		for x in range(rx, rx + w):
			if x < img.get_width() and y < img.get_height():
				if img.get_pixel(x, y).a > 0.01:
					return true
	return false
