extends Node

## Attach as a child of the JungleSection root.
## Scans ALL TileMapLayers for tiles painted from the animations source
## and cycles their atlas coords through the 4 animation frames.
##
## Collision: jungle_section skips anim tiles in _generate_collision().
## This script adds collision back ONLY for the bottom tile of multi-tile
## objects (torches, lanterns) — detected as vertically adjacent anim tiles.
##
## Sheet layout (RA_Jungle_Animations.png — 20 cols × 22 rows at 16px):
##   4 variant blocks separated by red-X divider columns (4, 9, 14, 19).
##   Within each block, the 4 columns are the 4 animation frames.
##   Paint using the first frame column of any block.

@export var fps: float = 5.0

const ANIMS_SOURCES := { "jungle": 3, "autumn": 8 }
const ALL_ANIMS_SOURCE_IDS := [3, 8]
const BLOCK_STARTS := [0, 5, 10, 15]
const FRAMES_PER_BLOCK := 4

var _anim_cells: Array[Dictionary] = []  # {layer, cell, block_base, row, src}
var _current_frame: int = 0
var _timer: float = 0.0

func _ready() -> void:
	await get_tree().process_frame
	_scan_all_layers()

func _scan_all_layers() -> void:
	_anim_cells.clear()
	var root = get_parent()
	if not root:
		return

	# Collect all animation tiles, keyed per-layer so multi-tile detection
	# only groups tiles on the SAME layer (not across Floor3 + Floor4 etc.)
	var per_layer_positions: Dictionary = {}  # layer → Dictionary[Vector2i, true]

	for layer in _find_all_tilemaplayers(root):
		var layer_cells: Dictionary = {}
		for cell in layer.get_used_cells():
			var src = layer.get_cell_source_id(cell)
			if src not in ALL_ANIMS_SOURCE_IDS:
				continue
			var atlas = layer.get_cell_atlas_coords(cell)
			var block_base = _get_block_base(atlas.x)
			if block_base < 0:
				continue
			_anim_cells.append({
				"layer": layer,
				"cell": cell,
				"block_base": block_base,
				"row": atlas.y,
				"src": src,
			})
			layer_cells[cell] = true
		if not layer_cells.is_empty():
			per_layer_positions[layer] = layer_cells

	# Add collision for bottom tiles of multi-tile objects (torch bases).
	# Only groups tiles on the SAME layer — a flower on Floor3 next to
	# a shrub on Floor4 won't accidentally get collision.
	for entry in _anim_cells:
		var layer_cells = per_layer_positions.get(entry.layer, {})
		var above = Vector2i(entry.cell.x, entry.cell.y - 1)
		if above in layer_cells:
			_add_collision(entry.layer, entry.cell)

func _add_collision(layer: TileMapLayer, cell: Vector2i) -> void:
	var world_pos = layer.to_global(layer.map_to_local(cell))
	var body = StaticBody2D.new()
	body.collision_mask = 0
	body.global_position = world_pos
	get_parent().add_child(body)
	var col_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(14, 14)
	col_shape.shape = shape
	body.add_child(col_shape)

func _get_block_base(col: int) -> int:
	for base in BLOCK_STARTS:
		if col >= base and col < base + FRAMES_PER_BLOCK:
			return base
	return -1

func _process(delta: float) -> void:
	if _anim_cells.is_empty():
		return

	_timer += delta
	var frame_duration = 1.0 / fps
	if _timer < frame_duration:
		return
	_timer -= frame_duration

	_current_frame = (_current_frame + 1) % FRAMES_PER_BLOCK

	for entry in _anim_cells:
		var new_col = entry.block_base + _current_frame
		entry.layer.set_cell(entry.cell, entry.src, Vector2i(new_col, entry.row))

func swap_source(new_season: String) -> void:
	var new_src = ANIMS_SOURCES.get(new_season, -1)
	if new_src < 0:
		return
	for entry in _anim_cells:
		if entry.src == new_src:
			continue
		var new_col = entry.block_base + _current_frame
		entry.layer.set_cell(entry.cell, new_src, Vector2i(new_col, entry.row))
		entry.src = new_src

func _find_all_tilemaplayers(node: Node) -> Array[TileMapLayer]:
	var result: Array[TileMapLayer] = []
	if node is TileMapLayer:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_all_tilemaplayers(child))
	return result
