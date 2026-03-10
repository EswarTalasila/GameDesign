@tool
extends EditorScript
## Godot EditorScript version of shift_tiles.py
##
## Opens each narrative hub .tscn, finds all TileMapLayer nodes,
## shifts tile cells so the minimum coordinate is (0, 0),
## removes the Player node, adjusts remaining node positions,
## and saves as new section scenes.
##
## Usage: Open in Godot Script Editor → File → Run


const TILE_SIZE := 16

## Input/output pairs
const JOBS := [
	{
		"input": "res://scenes/train/narrative hub.tscn",
		"output": "res://scenes/train/sections/train_section_1.tscn",
	},
	{
		"input": "res://scenes/train/narrative hub 2.tscn",
		"output": "res://scenes/train/sections/train_section_2.tscn",
	},
]


func _run() -> void:
	# Ensure output directory exists
	if not DirAccess.dir_exists_absolute("res://scenes/train/sections"):
		DirAccess.make_dir_recursive_absolute("res://scenes/train/sections")

	for job in JOBS:
		_process_scene(job["input"], job["output"])

	print("Done! All train section scenes created.")


func _process_scene(input_path: String, output_path: String) -> void:
	print("\nProcessing: ", input_path)

	var packed := load(input_path) as PackedScene
	if not packed:
		push_error("Could not load: " + input_path)
		return

	var scene := packed.instantiate()
	if not scene:
		push_error("Could not instantiate: " + input_path)
		return

	# 1. Collect all TileMapLayer nodes and find global min cell
	var tilemap_layers: Array[TileMapLayer] = []
	_find_tilemap_layers(scene, tilemap_layers)

	var global_min_x := 999999
	var global_min_y := 999999

	for layer in tilemap_layers:
		var cells := layer.get_used_cells()
		for cell in cells:
			global_min_x = mini(global_min_x, cell.x)
			global_min_y = mini(global_min_y, cell.y)

	if global_min_x == 999999:
		print("  No tile cells found, skipping.")
		scene.queue_free()
		return

	var dx := -global_min_x
	var dy := -global_min_y
	print("  Global min cell: (%d, %d)" % [global_min_x, global_min_y])
	print("  Cell shift: dx=%d, dy=%d" % [dx, dy])

	# 2. Shift all tile cells
	for layer in tilemap_layers:
		var cells := layer.get_used_cells()
		# Collect all cell data first
		var cell_data: Array = []
		for cell in cells:
			var src := layer.get_cell_source_id(cell)
			var atlas := layer.get_cell_atlas_coords(cell)
			var alt := layer.get_cell_alternative_tile(cell)
			cell_data.append({
				"pos": cell,
				"source": src,
				"atlas": atlas,
				"alt": alt,
			})

		# Clear and re-set with shifted coordinates
		layer.clear()
		for data in cell_data:
			var old_pos: Vector2i = data["pos"]
			var new_pos := Vector2i(old_pos.x + dx, old_pos.y + dy)
			layer.set_cell(new_pos, data["source"], data["atlas"], data["alt"])

	# 3. Remove Player node
	var player := scene.find_child("Player", false, false)
	if player:
		player.get_parent().remove_child(player)
		player.queue_free()
		print("  Removed Player node")

	# 4. Shift non-tilemap direct children positions
	var pixel_offset := Vector2(dx * TILE_SIZE, dy * TILE_SIZE)
	for child in scene.get_children():
		if child is TileMapLayer:
			continue
		if "position" in child:
			child.position += pixel_offset
			print("  Shifted '%s' position by (%d, %d) px" % [child.name, pixel_offset.x, pixel_offset.y])

	# 5. Save as new scene
	var new_packed := PackedScene.new()
	var err := new_packed.pack(scene)
	if err != OK:
		push_error("Failed to pack scene: " + str(err))
		scene.queue_free()
		return

	err = ResourceSaver.save(new_packed, output_path)
	if err != OK:
		push_error("Failed to save: " + output_path + " error: " + str(err))
	else:
		print("  Saved: ", output_path)

	scene.queue_free()


func _find_tilemap_layers(node: Node, result: Array[TileMapLayer]) -> void:
	if node is TileMapLayer:
		result.append(node as TileMapLayer)
	for child in node.get_children():
		_find_tilemap_layers(child, result)
