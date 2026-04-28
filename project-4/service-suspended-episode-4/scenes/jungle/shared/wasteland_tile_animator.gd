extends Node

## Attach as a child of the JungleSection root (or any Node2D with TileMapLayers).
## Scans ALL TileMapLayers for tiles painted from the wasteland main source (src=13)
## that fall within the animated rows, and cycles their atlas coords through the
## 4 animation frames — identical behaviour to tile_animator.gd for jungle/autumn.
##
## Collision: animated tiles that form 2-tile-tall objects (e.g. lanterns) get a
## static collision box at the base tile, just like the jungle torch logic.
## Flowers / single-tile plants need no collision — their presence in floor-style
## layers means _generate_collision() already skips them (see jungle_section.gd).
##
## Sheet layout (RA_Wasteland_Godot.png — 48 cols × 23 rows at 16px):
##   Rows 0-12  — static tileset tiles (terrain, walls, trees, decorations).
##   Rows 13-22 — animation tiles: lanterns and flowers, separated by red-X columns.
##   Block pattern matches RA_Jungle_Animations: 4 frames then 1 red-X divider col.
##   Block starts (cols): 0, 5, 10, 15, 20, 25, 30, 35, 40  → 9 blocks × 5 cols.
##   Cols 45-47 are unused / non-animated trailing space.
##   Paint using the FIRST frame column of any block (col 0, 5, 10, 15, …).

@export var fps: float = 5.0

const WASTELAND_SOURCE_ID := 13
## Atlas rows at or above this value belong to the animation section.
## Adjust if the break point in RA_Wasteland_Godot.png does not match row 13.
const ANIM_ROW_START := 13
const BLOCK_STARTS := [0, 5, 10, 15, 20, 25, 30, 35, 40]
const FRAMES_PER_BLOCK := 4

var _anim_cells: Array[Dictionary] = []  # {layer, cell, block_base, row}
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

	# Per-layer position set — used for multi-tile collision detection.
	var per_layer_positions: Dictionary = {}  # TileMapLayer → Dictionary[Vector2i, true]

	for layer in _find_all_tilemaplayers(root):
		var layer_cells: Dictionary = {}
		for cell in layer.get_used_cells():
			var src = layer.get_cell_source_id(cell)
			if src != WASTELAND_SOURCE_ID:
				continue
			var atlas = layer.get_cell_atlas_coords(cell)
			if atlas.y < ANIM_ROW_START:
				continue
			var block_base = _get_block_base(atlas.x)
			if block_base < 0:
				continue
			_anim_cells.append({
				"layer": layer,
				"cell": cell,
				"block_base": block_base,
				"row": atlas.y,
			})
			layer_cells[cell] = true
		if not layer_cells.is_empty():
			per_layer_positions[layer] = layer_cells

	# Add collision for the BOTTOM tile of any 2-tile-tall object (e.g. lanterns).
	# Same logic as tile_animator.gd: if the tile above is also an anim tile on the
	# same layer, this tile is the base → give it a collision box.
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
		entry.layer.set_cell(entry.cell, WASTELAND_SOURCE_ID, Vector2i(new_col, entry.row))

func _find_all_tilemaplayers(node: Node) -> Array[TileMapLayer]:
	var result: Array[TileMapLayer] = []
	if node is TileMapLayer:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_all_tilemaplayers(child))
	return result
