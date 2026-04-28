@tool
extends Node2D

## Jungle tree — draws a seasonal atlas region on a subdivided 2D mesh so the
## canopy can sway while the planted trunk stays anchored at the root.

@export_range(1, 4) var variant: int = 1:
	set(value):
		variant = value
		_queue_visual_refresh()

@export_enum("green", "blue", "red") var color: String = "green":
	set(value):
		color = value
		_queue_visual_refresh()

@export var shadow: bool = false:
	set(value):
		shadow = value
		_queue_visual_refresh()

@export var flipped: bool = false:
	set(value):
		flipped = value
		_queue_visual_refresh()

@export_enum("auto", "jungle", "autumn", "winter", "wasteland") var season: String = "auto":
	set(value):
		season = value
		_queue_visual_refresh()

@export var sway_enabled: bool = true:
	set(value):
		sway_enabled = value
		_queue_material_refresh()

@export var sway_speed: float = 1.5:
	set(value):
		sway_speed = value
		_queue_material_refresh()

@export var sway_amount: float = 0.08:
	set(value):
		sway_amount = value
		_queue_material_refresh()

@export_range(0.1, 1.0, 0.01) var sway_canopy_bottom: float = 0.56:
	set(value):
		sway_canopy_bottom = value
		_queue_material_refresh()

@export_range(1, 9, 1) var hits_to_harvest: int = 3
@export_range(1, 9, 1) var wood_reward_amount: int = 1
@export_range(1, 4, 1) var dead_tree_variant: int = 4
@export var pickup_spawn_distance: float = 20.0
@export var pickup_player_clearance: float = 10.0
@export var pickup_vertical_offset: float = 10.0
@export var pickup_travel_time: float = 0.16
@export var debug_logging: bool = false

const TREE_W := 64.0
const TREE_H := 80.0
const TREE_HALF_W := TREE_W * 0.5
## Bottom of the mesh quad (trunk base sits slightly below the origin).
const TREE_MESH_BOTTOM_Y := 10.0
const MESH_ROW_COUNT := 12
const TREE_MATERIAL := preload("res://assets/shaders/tree_shader.tres")
const WOOD_PICKUP_SCENE := preload("res://scenes/pickups/wood_pickup.tscn")
const SEASON_PATH := {
	"jungle": "res://assets/tilesets/jungle/godot/RA_Jungle.png",
	"autumn": "res://assets/tilesets/jungle/autumn/RA_Jungle_Autumn.png",
	"winter": "res://assets/tilesets/jungle/winter/RA_Jungle_Winter.png",
	"wasteland": "res://assets/tilesets/wasteland/RA_Wasteland_Godot.png",
}
## Wasteland uses three explicit dead-tree forms from the atlas.
## These are 4x4 tile windows taken from the exact coordinates provided for the
## left/right tree columns so the season swap lines up with the intended art.
const WASTELAND_TREE_REGIONS := {
	false: {
		1: Rect2(256, 64, 64, 64),
		2: Rect2(256, 128, 64, 64),
		3: Rect2(256, 192, 64, 64),
	},
	true: {
		1: Rect2(320, 64, 64, 64),
		2: Rect2(320, 128, 64, 64),
		3: Rect2(320, 192, 64, 64),
	},
}

var _visual: MeshInstance2D
var _last_region := Rect2()
var _last_path := ""
var _sway_phase := 0.0
var _material_instance: ShaderMaterial
var _current_texture: Texture2D
var _visual_refresh_queued := false
var _material_refresh_queued := false
var _harvest_hits: int = 0
var _harvested: bool = false

@onready var _hit_shape: CollisionShape2D = $HitBody/CollisionShape2D

func _ready() -> void:
	_remove_legacy_visual("AnimatedSprite2D")
	_remove_legacy_visual("TrunkSprite")
	_remove_legacy_visual("CanopySprite")
	_remove_legacy_visual("TreeSprite2")
	_remove_legacy_visual("TreeSprite")
	_remove_legacy_visual("TreeMesh2")

	if _sway_phase == 0.0:
		_sway_phase = randf() * TAU

	_harvest_hits = 0
	_harvested = variant == dead_tree_variant
	if _hit_shape:
		_hit_shape.disabled = _harvested

	_visual = _ensure_visual()
	_update_visual()

func _queue_visual_refresh() -> void:
	if not is_node_ready():
		return
	if _visual_refresh_queued:
		return
	_visual_refresh_queued = true
	call_deferred("_deferred_update_visual")

func _queue_material_refresh() -> void:
	if not is_node_ready():
		return
	if _material_refresh_queued:
		return
	_material_refresh_queued = true
	call_deferred("_deferred_apply_tree_material")

func _deferred_update_visual() -> void:
	_visual_refresh_queued = false
	if is_inside_tree():
		_update_visual()

func _deferred_apply_tree_material() -> void:
	_material_refresh_queued = false
	if is_inside_tree():
		_apply_tree_material()

func _remove_legacy_visual(node_name: String) -> void:
	var old: Node = get_node_or_null(node_name)
	if old != null:
		old.queue_free()

func _ensure_visual() -> MeshInstance2D:
	var visual := get_node_or_null("TreeMesh") as MeshInstance2D
	if visual == null:
		visual = MeshInstance2D.new()
		visual.name = "TreeMesh"
		add_child(visual)
		if Engine.is_editor_hint():
			var tree := get_tree()
			if tree and tree.edited_scene_root:
				visual.owner = tree.edited_scene_root
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visual.z_index = 0
	visual.z_as_relative = true
	return visual

func _rebuild_mesh(uv_rect: Rect2 = Rect2(0, 0, 1, 1), mesh_h: float = TREE_H) -> void:
	## Build a subdivided quad. uv_rect maps the mesh UVs to a specific
	## region of the full sheet texture (normalized 0-1 coords).
	## mesh_h overrides the render height so the sprite is not stretched when the
	## source region is shorter or taller than the default TREE_H.
	if _visual == null:
		return

	var top_y := -mesh_h + TREE_MESH_BOTTOM_Y  ## trunk base anchored at y≈0
	var bottom_y := TREE_MESH_BOTTOM_Y

	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	for row in range(MESH_ROW_COUNT + 1):
		var t := float(row) / float(MESH_ROW_COUNT)
		var y := lerpf(top_y, bottom_y, t)
		var uv_y := uv_rect.position.y + t * uv_rect.size.y
		vertices.push_back(Vector2(-TREE_HALF_W, y))
		vertices.push_back(Vector2(TREE_HALF_W, y))
		uvs.push_back(Vector2(uv_rect.position.x, uv_y))
		uvs.push_back(Vector2(uv_rect.position.x + uv_rect.size.x, uv_y))

	for row in range(MESH_ROW_COUNT):
		var base := row * 2
		indices.push_back(base)
		indices.push_back(base + 1)
		indices.push_back(base + 2)
		indices.push_back(base + 1)
		indices.push_back(base + 3)
		indices.push_back(base + 2)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_visual.mesh = mesh

func _apply_tree_material() -> void:
	if _visual == null or _current_texture == null:
		return

	if not sway_enabled:
		_visual.material = null
		return

	var base_shader := TREE_MATERIAL
	if base_shader == null:
		return

	# VisualShader needs to be wrapped in a ShaderMaterial
	_material_instance = ShaderMaterial.new()
	_material_instance.shader = base_shader
	_material_instance.set_shader_parameter("Storm_Strength", sway_amount)
	_material_instance.set_shader_parameter("Weather_Flag", _resolve_weather())
	_visual.material = _material_instance

func _resolve_season() -> String:
	if season != "" and season != "auto":
		return season

	var node := get_parent()
	while node:
		if node is JungleSection:
			return node.season
		node = node.get_parent()
	return "jungle"

func _resolve_weather() -> bool:
	var node := get_parent()
	while node:
		if node.get("rain_enabled") != null:
			return node.rain_enabled
		node = node.get_parent()
	return false

func _update_visual() -> void:
	if _visual == null:
		_visual = _ensure_visual()
		_rebuild_mesh()
	if _visual == null:
		return

	var resolved_season := _resolve_season()
	var path: String = SEASON_PATH.get(resolved_season, SEASON_PATH["jungle"])
	var base_region := _resolve_region_for_season(resolved_season)
	if path == _last_path and base_region == _last_region:
		_apply_tree_material()
		return

	_last_path = path
	_last_region = base_region

	if not ResourceLoader.exists(path):
		return

	var sheet := load(path) as Texture2D
	if sheet == null:
		return

	# Set the full sheet as texture — MeshInstance2D ignores AtlasTexture regions.
	# Instead we bake the region into the mesh UVs.
	_current_texture = sheet
	_visual.texture = sheet

	var sheet_size := Vector2(sheet.get_width(), sheet.get_height())
	var uv_rect := Rect2(
		base_region.position.x / sheet_size.x,
		base_region.position.y / sheet_size.y,
		base_region.size.x / sheet_size.x,
		base_region.size.y / sheet_size.y
	)
	## For wasteland trees the sprite height on the sheet varies per variant
	## (77 / 60 / 50 px). Use the actual region height as the mesh height so the
	## tree renders at its natural pixel proportions without vertical stretching.
	## Non-wasteland trees always use TREE_H (80) since their sheet rows are
	## exactly TREE_H pixels tall.
	var mesh_h := base_region.size.y if resolved_season == "wasteland" else TREE_H
	_rebuild_mesh(uv_rect, mesh_h)
	_apply_tree_material()

func _resolve_region_for_season(resolved_season: String) -> Rect2:
	if resolved_season == "wasteland":
		var wasteland_variant := clampi(variant, 1, 3)
		return WASTELAND_TREE_REGIONS[flipped].get(wasteland_variant, WASTELAND_TREE_REGIONS[false][1])

	var col := (variant - 1) * 2
	if flipped:
		col += 1

	var color_idx := 0
	if color == "blue":
		color_idx = 1
	elif color == "red":
		color_idx = 2

	var row := color_idx
	if shadow:
		row += 3
	return Rect2(col * TREE_W, row * TREE_H, TREE_W, TREE_H)

func set_season(new_season: String) -> void:
	season = new_season

func take_damage(_amount: int = 1) -> void:
	if Engine.is_editor_hint() or _harvested:
		return
	_harvest_hits += max(1, _amount)
	if debug_logging:
		print("[jungle_tree] hit tree=%s progress=%d/%d" % [name, _harvest_hits, hits_to_harvest])
	if _harvest_hits < hits_to_harvest:
		return
	_harvest_tree()

func _harvest_tree() -> void:
	_harvested = true
	if _hit_shape:
		_hit_shape.set_deferred("disabled", true)
	variant = dead_tree_variant
	_spawn_wood_pickup()

func _spawn_wood_pickup() -> void:
	if WOOD_PICKUP_SCENE == null:
		if debug_logging:
			push_warning("[jungle_tree] WOOD_PICKUP_SCENE missing")
		return
	var wood_pickup := WOOD_PICKUP_SCENE.instantiate()
	if wood_pickup == null:
		if debug_logging:
			push_warning("[jungle_tree] failed to instantiate wood pickup")
		return
	wood_pickup.set("amount", wood_reward_amount)
	var parent := get_parent()
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		if debug_logging:
			push_warning("[jungle_tree] no valid parent for wood pickup")
		return
	parent.add_child(wood_pickup)
	var start_position := global_position + Vector2(0, pickup_vertical_offset * 0.4)
	var target_position := _get_pickup_target_position()
	wood_pickup.global_position = start_position
	var tween := wood_pickup.create_tween()
	tween.tween_property(wood_pickup, "global_position", target_position, pickup_travel_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if debug_logging:
		print("[jungle_tree] harvested tree=%s spawned wood=%d at=%s" % [name, wood_reward_amount, target_position])

func _get_pickup_target_position() -> Vector2:
	var base_position := global_position + Vector2(0, pickup_vertical_offset)
	var player := _find_player()
	if player == null:
		return base_position + Vector2(0, 14)
	var to_player := player.global_position - global_position
	if to_player.length_squared() <= 0.0001:
		return base_position + Vector2(0, 14)
	var direction_to_player := to_player.normalized()
	var distance_to_player := to_player.length()
	var travel_distance: float = minf(pickup_spawn_distance, maxf(0.0, distance_to_player - pickup_player_clearance))
	return base_position + direction_to_player * travel_distance

func _find_player() -> Node2D:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return null
	return scene_root.find_child("Player", true, false) as Node2D
