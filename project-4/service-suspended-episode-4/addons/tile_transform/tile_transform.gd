@tool
extends EditorPlugin

## Hover over any placed tile in the 2D viewport and press:
##   R         — rotate 180° (flip both axes)
##   X         — flip horizontally (mirror atlas X within block)
##   Y         — flip vertically (mirror atlas Y within block)
##
## Works by swapping atlas coordinates to the mirrored position
## within the same tile block. No alternative tiles needed —
## the tileset stays untouched.
##
## For water tiles (sources 4,9,12,15): mirrors within 12×5 frame blocks.
## For all other tiles: mirrors within the full atlas source dimensions.

const WATER_SOURCES := [4, 9, 12, 15]
const WATER_BLOCK_W := 12
const WATER_BLOCK_H := 5
const WATER_FRAME_ORIGINS: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(13, 0),
	Vector2i(0, 5), Vector2i(13, 5),
	Vector2i(0, 10), Vector2i(13, 10),
	Vector2i(0, 15), Vector2i(13, 15),
]

func _enter_tree() -> void:
	pass

func _exit_tree() -> void:
	pass

func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	if not event.pressed or event.echo:
		return false

	var key = event.keycode
	if key != KEY_R and key != KEY_X and key != KEY_Y:
		return false

	var selection = get_editor_interface().get_selection().get_selected_nodes()
	var layer: TileMapLayer = null
	for node in selection:
		if node is TileMapLayer:
			layer = node
			break
	if not layer:
		return false

	var mouse_global = layer.get_global_mouse_position()
	var cell = layer.local_to_map(layer.to_local(mouse_global))

	var src = layer.get_cell_source_id(cell)
	if src == -1:
		return false

	var atlas = layer.get_cell_atlas_coords(cell)
	var alt = layer.get_cell_alternative_tile(cell)
	var new_atlas: Vector2i

	if src in WATER_SOURCES:
		new_atlas = _mirror_water(atlas, key)
	else:
		new_atlas = _mirror_generic(atlas, src, layer.tile_set, key)

	if new_atlas == atlas:
		return false

	# Verify the target coord actually has a tile defined
	var source = layer.tile_set.get_source(src) as TileSetAtlasSource
	if not source or not source.has_tile(new_atlas):
		return false

	# Apply with undo support
	get_undo_redo().create_action("Flip tile")
	get_undo_redo().add_do_method(layer, "set_cell", cell, src, new_atlas, alt)
	get_undo_redo().add_undo_method(layer, "set_cell", cell, src, atlas, alt)
	get_undo_redo().commit_action()

	return true

func _mirror_water(atlas: Vector2i, key: int) -> Vector2i:
	# Find which frame block this tile belongs to
	for origin in WATER_FRAME_ORIGINS:
		var lx = atlas.x - origin.x
		var ly = atlas.y - origin.y
		if lx >= 0 and lx < WATER_BLOCK_W and ly >= 0 and ly < WATER_BLOCK_H:
			match key:
				KEY_X:
					lx = WATER_BLOCK_W - 1 - lx
				KEY_Y:
					ly = WATER_BLOCK_H - 1 - ly
				KEY_R:
					lx = WATER_BLOCK_W - 1 - lx
					ly = WATER_BLOCK_H - 1 - ly
			return origin + Vector2i(lx, ly)
	return atlas

func _mirror_generic(atlas: Vector2i, src_id: int, tileset: TileSet, key: int) -> Vector2i:
	var source = tileset.get_source(src_id) as TileSetAtlasSource
	if not source:
		return atlas

	var tex = source.texture
	if not tex:
		return atlas

	var tile_size = tileset.tile_size
	var cols = tex.get_width() / tile_size.x
	var rows = tex.get_height() / tile_size.y

	var new_x = atlas.x
	var new_y = atlas.y

	match key:
		KEY_X:
			new_x = cols - 1 - atlas.x
		KEY_Y:
			new_y = rows - 1 - atlas.y
		KEY_R:
			new_x = cols - 1 - atlas.x
			new_y = rows - 1 - atlas.y

	return Vector2i(new_x, new_y)
