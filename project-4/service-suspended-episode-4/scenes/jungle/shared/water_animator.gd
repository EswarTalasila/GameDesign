extends Node

## Attach as a child of any TileMapLayer that has water tiles.
## Paint using Frame 1 tiles (atlas coords 0,0 to 11,4) from your chosen water source.
## This script cycles all water tiles through the 8 animation frames automatically.
##
## Supports multiple water sources — select which one in the inspector.
## When you switch water_style, the script also repaints all existing water tiles
## to the new source so you can preview different water colors in-game.

## Set to "auto" to inherit the season from the variant's JungleSection parent.
@export_enum("auto", "jungle", "autumn", "winter", "wasteland") var water_style: String = "auto":
	set(value):
		water_style = value
		if _tilemap and not _water_cells.is_empty():
			_swap_water_source()

@export var fps: float = 5.0

## Source IDs in combined_terrain.tres (update if sources change)
const WATER_SOURCES = {
	"jungle": 4,
	"autumn": 9,
	"winter": 12,
	"wasteland": 15,
}

## Frame block origins — same layout for all water sheets (2×4 grid, 12×5 blocks).
const FRAME_ORIGINS: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(13, 0),
	Vector2i(0, 5),
	Vector2i(13, 5),
	Vector2i(0, 10),
	Vector2i(13, 10),
	Vector2i(0, 15),
	Vector2i(13, 15),
]

const BLOCK_W := 12
const BLOCK_H := 5

var _tilemap: TileMapLayer
var _water_cells: Array[Dictionary] = []  # {cell: Vector2i, local: Vector2i}
var _current_frame: int = 0
var _timer: float = 0.0

func _resolve_style() -> String:
	if water_style != "auto":
		return water_style
	# Walk up the tree to find a JungleSection and read its season
	var node = get_parent()
	while node:
		if node is JungleSection:
			return node.season
		node = node.get_parent()
	return "jungle"

func _get_source_id() -> int:
	return WATER_SOURCES.get(_resolve_style(), 4)

func _ready() -> void:
	_tilemap = get_parent() as TileMapLayer
	if not _tilemap:
		push_warning("WaterAnimator: parent must be a TileMapLayer")
		return
	_scan_water_cells()

func _scan_water_cells() -> void:
	_water_cells.clear()
	var origin = FRAME_ORIGINS[0]

	# Scan for water tiles from ANY water source
	for cell in _tilemap.get_used_cells():
		var src = _tilemap.get_cell_source_id(cell)
		if src in WATER_SOURCES.values():
			var atlas = _tilemap.get_cell_atlas_coords(cell)
			# Find local position within whichever frame block this tile is in
			for frame_origin in FRAME_ORIGINS:
				var lx = atlas.x - frame_origin.x
				var ly = atlas.y - frame_origin.y
				if lx >= 0 and lx < BLOCK_W and ly >= 0 and ly < BLOCK_H:
					_water_cells.append({"cell": cell, "local": Vector2i(lx, ly)})
					break

func _swap_water_source() -> void:
	## Repaint all water cells to the currently selected source.
	var source_id = _get_source_id()
	var origin = FRAME_ORIGINS[_current_frame]
	for entry in _water_cells:
		var new_atlas = origin + entry.local
		_tilemap.set_cell(entry.cell, source_id, new_atlas)

func _process(delta: float) -> void:
	if _water_cells.is_empty():
		return

	_timer += delta
	var frame_duration = 1.0 / fps
	if _timer < frame_duration:
		return
	_timer -= frame_duration

	_current_frame = (_current_frame + 1) % FRAME_ORIGINS.size()
	var source_id = _get_source_id()
	var origin = FRAME_ORIGINS[_current_frame]

	for entry in _water_cells:
		var new_atlas = origin + entry.local
		_tilemap.set_cell(entry.cell, source_id, new_atlas)
