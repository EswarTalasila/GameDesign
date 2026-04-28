extends Node
class_name SeasonSwapper

## Swaps all painted tiles from one season to another at runtime.
## Paint everything in "jungle" (base). Call swap_season() to recolor
## the entire map to autumn, winter, or wasteland — or back to jungle.
##
## Two swap strategies:
##   1. Source swap — remap source IDs when tiles exist in separate sheets
##      (ground, main, anims, water)
##   2. Column shift — same source, shift X atlas coord to another column
##      (rocks sheet: 4 seasons side-by-side in one atlas)

## Source ID mapping in combined_terrain.tres:
##   jungle:    ground=0, main=1, extras=2, anims=3, water=4, rocks=5
##   autumn:    ground=6, main=7, anims=8, water=9
##   winter:    ground=10, main=11, water=12
##   wasteland: main=13, ground=14, water=15, blood_water=16

const WASTELAND_WATER_SOURCE := 15
const WASTELAND_BLOOD_WATER_SOURCE := 16

const SEASON_MAP = {
	"jungle": {
		"ground": 0,
		"main": 1,
		"anims": 3,
		"water": 4,
	},
	"autumn": {
		"ground": 6,
		"main": 7,
		"anims": 8,
		"water": 9,
	},
	"winter": {
		"ground": 10,
		"main": 11,
		"anims": -1,
		"water": 12,
	},
	"wasteland": {
		"ground": 14,
		"main": 13,
		"anims": -1,
		"water": WASTELAND_WATER_SOURCE,
	},
}

const GROUND_SOURCES = [0, 6, 10, 14]
const MAIN_SOURCES = [1, 7, 11, 13]
const ANIMS_SOURCES = [3, 8]
const WATER_SOURCES = [4, 9, 12, WASTELAND_WATER_SOURCE, WASTELAND_BLOOD_WATER_SOURCE]

## Rocks atlas (Source 5): 4 seasonal columns, 3 tiles wide each, with gaps.
## Layout: wasteland(4-6), jungle(8-10), winter(12-14), autumn(16-18).
const ROCKS_SOURCE = 5
const ROCKS_COLUMN_WIDTH = 3
const ROCKS_SEASON_COL = {
	"wasteland": 4,
	"jungle": 8,
	"winter": 12,
	"autumn": 16,
}
const ROCKS_COLUMN_STARTS = [4, 8, 12, 16]

var _current_season: String = "jungle"

func get_season() -> String:
	return _current_season

func swap_season(season: String, root: Node = null) -> void:
	if season == _current_season:
		return
	if season not in SEASON_MAP:
		push_error("SeasonSwapper: unknown season '%s'" % season)
		return

	var target = root if root else get_parent()
	var mapping = _resolve_mapping(season, target)
	var layers = _find_all_tilemaplayers(target)

	for layer in layers:
		_swap_layer(layer, mapping, season)

	# Swap tree seasons
	for tree in _find_all_trees(target):
		tree.set_season(season)

	# Swap tile animation sources
	for animator in _find_all_tile_animators(target):
		animator.swap_source(season)

	_current_season = season

func _resolve_mapping(season: String, target: Node) -> Dictionary:
	var mapping: Dictionary = SEASON_MAP[season].duplicate()
	if season == "wasteland":
		mapping["water"] = _resolve_wasteland_water_source(target)
	return mapping

func _resolve_wasteland_water_source(target: Node) -> int:
	if target and "wasteland_water_style" in target:
		var style := String(target.get("wasteland_water_style"))
		if style == "blood":
			return WASTELAND_BLOOD_WATER_SOURCE
	return WASTELAND_WATER_SOURCE

func _swap_layer(layer: TileMapLayer, mapping: Dictionary, season: String) -> void:
	var cells = layer.get_used_cells()
	for cell in cells:
		var src = layer.get_cell_source_id(cell)
		var atlas = layer.get_cell_atlas_coords(cell)
		var alt = layer.get_cell_alternative_tile(cell)

		# Rocks: shift X column within the same source
		if src == ROCKS_SOURCE:
			var local_x = _get_rocks_local_x(atlas.x)
			if local_x >= 0:
				var new_x = ROCKS_SEASON_COL[season] + local_x
				layer.set_cell(cell, src, Vector2i(new_x, atlas.y), alt)
			continue

		# Everything else: remap source ID
		var new_src = _remap_source(src, mapping)
		if new_src != src and new_src >= 0:
			layer.set_cell(cell, new_src, atlas, alt)

func _get_rocks_local_x(x: int) -> int:
	## Find which season column this x belongs to, return local X within that column.
	for col_start in ROCKS_COLUMN_STARTS:
		if x >= col_start and x < col_start + ROCKS_COLUMN_WIDTH:
			return x - col_start
	return -1

func _remap_source(src: int, mapping: Dictionary) -> int:
	if src in GROUND_SOURCES:
		return mapping.ground
	elif src in MAIN_SOURCES:
		return mapping.main
	elif src in ANIMS_SOURCES:
		return mapping.anims if mapping.anims >= 0 else src
	elif src in WATER_SOURCES:
		return mapping.water
	else:
		return src

func _find_all_tilemaplayers(node: Node) -> Array[TileMapLayer]:
	var result: Array[TileMapLayer] = []
	if node is TileMapLayer:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_all_tilemaplayers(child))
	return result

func _find_all_trees(node: Node) -> Array:
	var result := []
	if node.has_method("set_season") and node.get_script() and "jungle_tree" in node.get_script().resource_path:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_all_trees(child))
	return result

func _find_all_tile_animators(node: Node) -> Array:
	var result := []
	if node.has_method("swap_source") and node.get_script() and "tile_animator" in node.get_script().resource_path:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_all_tile_animators(child))
	return result
