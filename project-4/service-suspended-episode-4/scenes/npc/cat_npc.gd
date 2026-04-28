@tool
extends CharacterBody2D
class_name CatNPC

const FRAMES_ROOT := "res://assets/sprites/npc/cat"
const MISSING_KEY_TEXT := "I need a key..."
const TILE_SIZE := Vector2(16, 16)
const TILE_BLOCKER_PADDING := {
	"BottomWalls": 0,
	"SideWalls": 0,
	"SideWalls2": 1,
	"Furniture": 0,
	"Furniture2": 0,
}
const DIRECTIONS := [
	"south",
	"south_east",
	"east",
	"north_east",
	"north",
	"north_west",
	"west",
	"south_west",
]
const WALK_ANIMATION_BY_DIRECTION := {
	"south": "walk_south",
	"south_east": "walk_south_east",
	"east": "walk_east",
	"north_east": "walk_north_east",
	"north": "walk_north",
	"north_west": "walk_north_west",
	"west": "walk_west",
	"south_west": "walk_south_west",
}
const BLINK_ANIMATION_BY_DIRECTION := {
	"south": "blink_south",
	"south_east": "blink_south_east",
	"south_west": "blink_south_west",
}
const INTERACTION_PRIORITY := 0

static var _shared_frames: SpriteFrames

var _unlock_sound = preload("res://assets/sounds/door_unlock.mp3")

@export_enum("south", "south_east", "east", "north_east", "north", "north_west", "west", "south_west")
var facing_direction: String = "south":
	set(value):
		facing_direction = value
		_refresh_state()

@export var locked: bool = true:
	set(value):
		locked = value
		_refresh_state()

@export var walking: bool = false:
	set(value):
		walking = value
		_refresh_state()

@export var talking: bool = false:
	set(value):
		talking = value
		_refresh_state()

@export var walk_velocity: Vector2 = Vector2.ZERO
@export_range(0.5, 10.0, 0.1) var blink_interval_min: float = 2.4
@export_range(0.5, 10.0, 0.1) var blink_interval_max: float = 4.8
@export var dialogue_resource: DialogueResource
@export var dialogue_start: String = "start"
@export var interaction_key: String = "interact"
@export var heard_flag: String = ""
@export var campfire_target_path: NodePath
@export var guide_route_path: NodePath
@export var post_arrival_dialogue_start: String = "campfire"
@export_enum("south", "south_east", "east", "north_east", "north", "north_west", "west", "south_west")
var arrival_facing_direction: String = "east"
@export_range(16.0, 120.0, 1.0) var walk_speed: float = 54.0
@export_range(2.0, 24.0, 1.0) var waypoint_reach_distance: float = 5.0
@export_range(1, 12, 1) var nearest_walkable_search_radius: int = 8

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_area: Area2D = $InteractionArea
@onready var interaction_shape: CollisionShape2D = $InteractionArea/CollisionShape2D
@onready var prompt_sprite: AnimatedSprite2D = $PromptSprite
@onready var lock_prompt: AnimatedSprite2D = $LockPrompt

signal unlock_animation_finished

var _blink_active: bool = false
var _blink_generation: int = 0
var _unlocking: bool = false
var _dialogue_running: bool = false
var _player_nearby: bool = false
var _player_body: CharacterBody2D = null
var _guiding: bool = false
var _arrived: bool = false
var _guide_points: Array[Vector2] = []
var _guide_index: int = 0

func _ready() -> void:
	add_to_group("priority_interactable")
	animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	animated_sprite.sprite_frames = _get_shared_frames()
	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)
	if not interaction_area.body_entered.is_connected(_on_body_entered):
		interaction_area.body_entered.connect(_on_body_entered)
	if not interaction_area.body_exited.is_connected(_on_body_exited):
		interaction_area.body_exited.connect(_on_body_exited)
	if not Engine.is_editor_hint():
		_restore_runtime_state()
	_refresh_state(true)

func _physics_process(delta: float) -> void:
	if _player_nearby:
		_update_prompt_visibility()
	if _guiding:
		_process_guided_walk(delta)
		return
	if locked or _unlocking or not walking:
		velocity = Vector2.ZERO
		return
	if walk_velocity.length_squared() <= 0.0:
		velocity = Vector2.ZERO
		return
	velocity = walk_velocity
	move_and_slide()
	var derived_direction := _direction_from_vector(walk_velocity)
	if derived_direction != facing_direction:
		facing_direction = derived_direction

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event.is_action_pressed(interaction_key) and _player_nearby:
		if is_instance_valid(_player_body) and not _is_primary_interaction_target(_player_body):
			return
		if _can_attempt_unlock():
			get_viewport().set_input_as_handled()
			if _try_unlock_with_key():
				return
			_show_dialog(MISSING_KEY_TEXT)
			return
		if _can_start_dialogue():
			get_viewport().set_input_as_handled()
			_start_dialogue()
		return
	if not (event is InputEventMouseButton):
		return
	var click_event := event as InputEventMouseButton
	if click_event.button_index != MOUSE_BUTTON_LEFT or not click_event.pressed:
		return
	if not _can_attempt_unlock():
		return
	if not (GameState.key_mode or GameState.selected_inventory_item == GameState.ITEM_KEY):
		return
	if not _is_click_on_zone():
		return
	_try_unlock_with_key()

func set_talking(active: bool) -> void:
	talking = active

func set_walking(active: bool) -> void:
	walking = active

func set_facing_direction(direction: String) -> void:
	if direction in DIRECTIONS:
		facing_direction = direction

func play_unlock_animation() -> void:
	if _unlocking or not locked:
		return
	_unlocking = true
	walking = false
	talking = false
	_stop_blinking()
	lock_prompt.visible = true
	lock_prompt.play("unlocked")
	_play_animation("unlock", true)
	_update_prompt_visibility()

func _start_dialogue() -> void:
	if Engine.is_editor_hint():
		return
	if dialogue_resource == null:
		return
	if _arrived and is_instance_valid(_player_body):
		_face_target(_player_body.global_position)
	if _can_trade_map_pieces():
		await _run_map_exchange()
		return
	_dialogue_running = true
	talking = true
	_update_prompt_visibility()
	var start := _resolve_dialogue_start()
	var quest_intro_step := start == dialogue_start and QuestManager.has_objective("explore_variant_2")
	var quest_campfire_step := start == post_arrival_dialogue_start and QuestManager.has_objective("talk_cat")
	await _show_dialogue_branch(start)
	if quest_intro_step:
		_advance_quest_after_cat_intro()
	if quest_campfire_step:
		_advance_quest_after_cat_campfire_talk()
	if heard_flag != "" and not GameState.get(heard_flag):
		GameState.set(heard_flag, true)
	_dialogue_running = false
	talking = false
	_update_prompt_visibility()

func _on_body_entered(body: Node) -> void:
	if _is_player(body):
		_player_nearby = true
		_player_body = body as CharacterBody2D
		if _arrived and is_instance_valid(_player_body):
			_face_target(_player_body.global_position)
		_update_prompt_visibility()

func _on_body_exited(body: Node) -> void:
	if _is_player(body):
		_player_nearby = false
		if body == _player_body:
			_player_body = null
		_update_prompt_visibility()

func _on_animation_finished() -> void:
	var current := String(animated_sprite.animation)
	if current == "unlock":
		_unlocking = false
		locked = false
		facing_direction = "south"
		unlock_animation_finished.emit()
		_after_unlock_sequence()
		return
	if current == _get_blink_animation():
		_blink_active = false
		_refresh_state(true)

func _refresh_state(force_play: bool = false) -> void:
	if not is_node_ready():
		return
	_update_prompt_visibility()
	if _unlocking:
		_play_animation("unlock", force_play)
		return
	if _blink_active and not _can_blink():
		_blink_active = false
	var animation := _resolve_animation()
	_play_animation(animation, force_play)
	_reschedule_blink()

func _resolve_animation() -> String:
	if locked:
		if talking and animated_sprite.sprite_frames.has_animation("locked_speaking"):
			return "locked_speaking"
		if _blink_active:
			return _get_blink_animation()
		return "locked"
	if walking:
		return WALK_ANIMATION_BY_DIRECTION.get(facing_direction, "walk_south")
	if _blink_active:
		return _get_blink_animation()
	return "dir_%s" % facing_direction

func _reschedule_blink() -> void:
	_blink_generation += 1
	if _blink_active or not _can_blink():
		return
	var generation := _blink_generation
	_wait_for_blink(generation)

func _wait_for_blink(generation: int) -> void:
	var delay := randf_range(blink_interval_min, blink_interval_max)
	await get_tree().create_timer(delay).timeout
	if generation != _blink_generation or not _can_blink():
		return
	_blink_active = true
	_play_animation(_get_blink_animation(), true)

func _stop_blinking() -> void:
	_blink_generation += 1
	_blink_active = false

func _can_blink() -> bool:
	if _unlocking or walking or talking:
		return false
	return animated_sprite.sprite_frames.has_animation(_get_blink_animation())

func _get_blink_animation() -> String:
	if locked:
		return "locked_blink"
	return BLINK_ANIMATION_BY_DIRECTION.get(facing_direction, "")

func _play_animation(name: String, force_restart: bool = false) -> void:
	if name == "":
		return
	if animated_sprite.animation == name and animated_sprite.is_playing() and not force_restart:
		return
	animated_sprite.play(name)

func _update_prompt_visibility() -> void:
	if not is_node_ready():
		return
	var has_priority := not is_instance_valid(_player_body) or _is_primary_interaction_target(_player_body)
	var show_interact := has_priority and _player_nearby and dialogue_resource != null and not _dialogue_running and not _unlocking and not _guiding and (not locked or not _has_heard_intro())
	var show_lock := _unlocking or (has_priority and _player_nearby and locked and not show_interact)
	prompt_sprite.visible = show_interact
	lock_prompt.visible = show_lock
	if show_lock:
		var animation_name := "unlocked" if _unlocking else "locked"
		if lock_prompt.animation != animation_name or not lock_prompt.is_playing():
			lock_prompt.play(animation_name)

func can_claim_priority_interaction(player: CharacterBody2D) -> bool:
	if not is_instance_valid(player) or player != _player_body:
		return false
	return _can_attempt_unlock() or _can_start_dialogue()

func get_interaction_priority_point() -> Vector2:
	return interaction_area.global_position

func get_interaction_priority_rank() -> int:
	return INTERACTION_PRIORITY

func _is_primary_interaction_target(player: CharacterBody2D) -> bool:
	if not is_instance_valid(player):
		return false
	var best_node: Node = null
	var best_distance := INF
	var best_priority := INF
	for candidate in get_tree().get_nodes_in_group("priority_interactable"):
		if not is_instance_valid(candidate) or not candidate.has_method("can_claim_priority_interaction"):
			continue
		if not bool(candidate.call("can_claim_priority_interaction", player)):
			continue
		if not candidate.has_method("get_interaction_priority_point") or not candidate.has_method("get_interaction_priority_rank"):
			continue
		var point: Vector2 = candidate.call("get_interaction_priority_point")
		var priority: int = int(candidate.call("get_interaction_priority_rank"))
		var distance := player.global_position.distance_squared_to(point)
		if best_node == null or distance < best_distance or (is_equal_approx(distance, best_distance) and priority < best_priority):
			best_node = candidate
			best_distance = distance
			best_priority = priority
	return best_node == self

func _can_start_dialogue() -> bool:
	return _player_nearby and not _dialogue_running and dialogue_resource != null and not _unlocking and not _guiding and (not locked or not _has_heard_intro() or _arrived)

func _can_attempt_unlock() -> bool:
	return _player_nearby and locked and not _unlocking and not _dialogue_running and not _guiding and not _arrived and _has_heard_intro()

func _has_heard_intro() -> bool:
	return heard_flag != "" and bool(GameState.get(heard_flag))

func _try_unlock_with_key() -> bool:
	if not GameState.use_key():
		return false
	_clear_key_selection()
	_play_sfx(_unlock_sound)
	play_unlock_animation()
	return true

func _after_unlock_sequence() -> void:
	if Engine.is_editor_hint():
		return
	GameState.cat_rescued = true
	_advance_quest_after_cat_freed()
	_play_freed_dialogue_and_guide()

func _play_freed_dialogue_and_guide() -> void:
	_dialogue_running = true
	talking = true
	_update_prompt_visibility()
	if dialogue_resource != null:
		DialogueManager.show_dialogue_balloon(dialogue_resource, "freed")
		await DialogueManager.dialogue_ended
	_dialogue_running = false
	talking = false
	_begin_campfire_walk()

func _begin_campfire_walk() -> void:
	var route_points := _build_route_points(Vector2.ZERO)
	if not route_points.is_empty():
		guide_to(route_points[-1])
		return
	var target_node := _get_campfire_target_node()
	if target_node == null:
		_finish_guided_walk()
		return
	guide_to(target_node.global_position)

func guide_to(target_global_position: Vector2) -> void:
	_guide_points = _build_path_points(target_global_position)
	if _guide_points.is_empty():
		_guide_points = [target_global_position]
	_guide_index = 0
	_guiding = true
	_arrived = false
	walking = true
	_update_prompt_visibility()

func _process_guided_walk(delta: float) -> void:
	if _guide_index >= _guide_points.size():
		_finish_guided_walk()
		return
	var target := _guide_points[_guide_index]
	var current_position := global_position
	var offset := target - current_position
	if offset.length() <= waypoint_reach_distance:
		_guide_index += 1
		if _guide_index >= _guide_points.size():
			global_position = target
			_finish_guided_walk()
			return
		target = _guide_points[_guide_index]
		offset = target - current_position
	if offset.length_squared() <= 0.0:
		walk_velocity = Vector2.ZERO
		velocity = Vector2.ZERO
		move_and_slide()
		return
	walk_velocity = offset.normalized() * walk_speed
	velocity = walk_velocity
	move_and_slide()
	_face_target(global_position + walk_velocity)
	_refresh_state()

func _finish_guided_walk() -> void:
	_guiding = false
	_arrived = true
	walk_velocity = Vector2.ZERO
	velocity = Vector2.ZERO
	walking = false
	facing_direction = arrival_facing_direction
	GameState.cat_at_campfire = true
	_advance_quest_after_cat_arrival()
	_refresh_state(true)

func _restore_runtime_state() -> void:
	if not GameState.cat_rescued and not GameState.cat_at_campfire:
		return
	locked = false
	_unlocking = false
	_guiding = false
	_arrived = true
	walking = false
	walk_velocity = Vector2.ZERO
	velocity = Vector2.ZERO
	_snap_to_campfire_target()
	GameState.cat_rescued = true
	GameState.cat_at_campfire = true

func _snap_to_campfire_target() -> void:
	var route_points := _build_route_points(Vector2.ZERO)
	if not route_points.is_empty():
		global_position = route_points[-1]
	else:
		var target_node := _get_campfire_target_node()
		if target_node != null:
			global_position = target_node.global_position
	facing_direction = arrival_facing_direction

func _get_campfire_target_node() -> Node2D:
	if campfire_target_path.is_empty():
		return null
	return get_node_or_null(campfire_target_path) as Node2D

func _build_path_points(target_global_position: Vector2) -> Array[Vector2]:
	var route_points := _build_route_points(target_global_position)
	if not route_points.is_empty():
		return route_points
	if target_global_position.distance_to(global_position) <= 0.5:
		return []
	return [target_global_position]

func _build_path_from_waypoints(floor_layer: TileMapLayer, route_points: Array[Vector2]) -> Array[Vector2]:
	var walkable_cells := _collect_walkable_cells([floor_layer])
	if walkable_cells.is_empty():
		return route_points
	var blocked_cells := _collect_blocked_cells(floor_layer)
	var astar := _build_astar_grid(walkable_cells, blocked_cells)
	if astar == null:
		return route_points
	var points: Array[Vector2] = []
	var segment_start := global_position
	for waypoint in route_points:
		var segment_points := _build_grid_path_points(floor_layer, segment_start, waypoint, walkable_cells, blocked_cells, astar)
		if segment_points.is_empty():
			if points.is_empty() or points[-1].distance_to(waypoint) > 0.5:
				points.append(waypoint)
		else:
			for point in segment_points:
				if points.is_empty() or points[-1].distance_to(point) > 0.5:
					points.append(point)
		segment_start = waypoint
	return points

func _build_grid_path_points(
	floor_layer: TileMapLayer,
	start_global_position: Vector2,
	target_global_position: Vector2,
	walkable_cells: Dictionary = {},
	blocked_cells: Dictionary = {},
	astar: AStarGrid2D = null
) -> Array[Vector2]:
	if walkable_cells.is_empty():
		walkable_cells = _collect_walkable_cells([floor_layer])
	if walkable_cells.is_empty():
		return []
	if blocked_cells.is_empty():
		blocked_cells = _collect_blocked_cells(floor_layer)
	if astar == null:
		astar = _build_astar_grid(walkable_cells, blocked_cells)
	if astar == null:
		return []
	var start_cell := _find_nearest_walkable_cell(_world_to_cell(floor_layer, start_global_position), walkable_cells, blocked_cells)
	var target_cell := _find_nearest_walkable_cell(_world_to_cell(floor_layer, target_global_position), walkable_cells, blocked_cells)
	if not walkable_cells.has(start_cell) or not walkable_cells.has(target_cell):
		return []
	var cell_path := astar.get_id_path(start_cell, target_cell)
	if cell_path.is_empty():
		return []
	return _cell_path_to_points(floor_layer, cell_path, target_global_position)

func _build_astar_grid(walkable_cells: Dictionary, blocked_cells: Dictionary) -> AStarGrid2D:
	var bounds := _get_bounds_from_cells(walkable_cells)
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return null
	var astar := AStarGrid2D.new()
	astar.region = bounds
	astar.cell_size = TILE_SIZE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.update()
	for cell in _iter_region_cells(bounds):
		if not walkable_cells.has(cell) or blocked_cells.has(cell):
			astar.set_point_solid(cell, true)
	return astar

func _build_route_points(target_global_position: Vector2) -> Array[Vector2]:
	if guide_route_path.is_empty():
		return []
	var route_node := get_node_or_null(guide_route_path)
	if route_node == null:
		return []
	var points: Array[Vector2] = []
	if route_node is Path2D:
		var curve := (route_node as Path2D).curve
		if curve != null:
			for point in curve.get_baked_points():
				points.append((route_node as Path2D).to_global(point))
	elif route_node is Node:
		var marker_nodes: Array[Node2D] = []
		for child in route_node.get_children():
			if child is Node2D:
				marker_nodes.append(child as Node2D)
		marker_nodes.sort_custom(func(a: Node2D, b: Node2D): return a.name.naturalnocasecmp_to(b.name) < 0)
		for marker in marker_nodes:
			points.append(marker.global_position)
	return points

func _get_walkable_layers() -> Array[TileMapLayer]:
	var layers: Array[TileMapLayer] = []
	var base_floor := get_parent().get_node_or_null("Floor") as TileMapLayer
	if base_floor != null:
		layers.append(base_floor)
	return layers

func _collect_walkable_cells(layers: Array[TileMapLayer]) -> Dictionary:
	var walkable := {}
	for layer in layers:
		for cell in layer.get_used_cells():
			walkable[cell] = true
	return walkable

func _collect_blocked_cells(floor_layer: TileMapLayer) -> Dictionary:
	var blocked := {}
	var section_root := get_parent()
	if section_root == null:
		return blocked
	for layer_name in TILE_BLOCKER_PADDING.keys():
		var layer := section_root.get_node_or_null(String(layer_name)) as TileMapLayer
		if layer == null:
			continue
		var padding: int = int(TILE_BLOCKER_PADDING[layer_name])
		for cell in layer.get_used_cells():
			_mark_blocked_cell_area(blocked, cell, padding)
	for body in section_root.find_children("*", "StaticBody2D", true, false):
		if body == null or body == self:
			continue
		if body.get_parent() == section_root:
			continue
		if body is StaticBody2D and (body.collision_layer & 1) == 0:
			continue
		for shape_node in body.find_children("*", "CollisionShape2D", true, false):
			if shape_node == null or shape_node.disabled or shape_node.shape == null:
				continue
			for cell in _shape_to_cells(floor_layer, shape_node):
				_mark_blocked_cell_area(blocked, cell, 0)
	return blocked

func _mark_blocked_cell_area(blocked: Dictionary, center_cell: Vector2i, padding: int) -> void:
	for x in range(center_cell.x - padding, center_cell.x + padding + 1):
		for y in range(center_cell.y - padding, center_cell.y + padding + 1):
			blocked[Vector2i(x, y)] = true

func _shape_to_cells(floor_layer: TileMapLayer, shape_node: CollisionShape2D) -> Array[Vector2i]:
	var shape := shape_node.shape
	var rect := Rect2()
	if shape is RectangleShape2D:
		var rectangle := shape as RectangleShape2D
		rect = Rect2(
			shape_node.global_position - rectangle.size * 0.5,
			rectangle.size
		)
	elif shape is CircleShape2D:
		var circle := shape as CircleShape2D
		rect = Rect2(
			shape_node.global_position - Vector2(circle.radius, circle.radius),
			Vector2.ONE * circle.radius * 2.0
		)
	else:
		return []
	var top_left := _world_to_cell(floor_layer, rect.position)
	var bottom_right := _world_to_cell(floor_layer, rect.position + rect.size)
	var cells: Array[Vector2i] = []
	for x in range(top_left.x - 1, bottom_right.x + 2):
		for y in range(top_left.y - 1, bottom_right.y + 2):
			var cell := Vector2i(x, y)
			var cell_center := _cell_to_world(floor_layer, cell)
			var cell_rect := Rect2(cell_center - TILE_SIZE * 0.5, TILE_SIZE)
			if cell_rect.intersects(rect):
				cells.append(cell)
	return cells

func _world_to_cell(floor_layer: TileMapLayer, world_position: Vector2) -> Vector2i:
	return floor_layer.local_to_map(floor_layer.to_local(world_position))

func _cell_to_world(floor_layer: TileMapLayer, cell: Vector2i) -> Vector2:
	return floor_layer.to_global(floor_layer.map_to_local(cell))

func _find_nearest_walkable_cell(origin: Vector2i, walkable: Dictionary, blocked: Dictionary) -> Vector2i:
	if walkable.has(origin) and not blocked.has(origin):
		return origin
	var best := origin
	var best_distance := INF
	for radius in range(1, nearest_walkable_search_radius + 1):
		for x in range(origin.x - radius, origin.x + radius + 1):
			for y in range(origin.y - radius, origin.y + radius + 1):
				var cell := Vector2i(x, y)
				if not walkable.has(cell) or blocked.has(cell):
					continue
				var distance := Vector2(origin - cell).length_squared()
				if distance < best_distance:
					best = cell
					best_distance = distance
		if best_distance < INF:
			return best
	return best

func _get_bounds_from_cells(cells: Dictionary) -> Rect2i:
	var has_bounds := false
	var min_x := 0
	var min_y := 0
	var max_x := 0
	var max_y := 0
	for cell in cells.keys():
		var current := cell as Vector2i
		if not has_bounds:
			min_x = current.x
			min_y = current.y
			max_x = current.x
			max_y = current.y
			has_bounds = true
			continue
		min_x = mini(min_x, current.x)
		min_y = mini(min_y, current.y)
		max_x = maxi(max_x, current.x)
		max_y = maxi(max_y, current.y)
	if not has_bounds:
		return Rect2i()
	return Rect2i(Vector2i(min_x, min_y), Vector2i(max_x - min_x + 1, max_y - min_y + 1))

func _iter_region_cells(region: Rect2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(region.position.x, region.position.x + region.size.x):
		for y in range(region.position.y, region.position.y + region.size.y):
			cells.append(Vector2i(x, y))
	return cells

func _cell_path_to_points(floor_layer: TileMapLayer, cell_path: Array[Vector2i], target_global_position: Vector2) -> Array[Vector2]:
	var points: Array[Vector2] = []
	if cell_path.size() <= 1:
		points.append(target_global_position)
		return points
	for i in range(1, cell_path.size()):
		points.append(_cell_to_world(floor_layer, cell_path[i]))
	points.append(target_global_position)
	return points

func _resolve_dialogue_start() -> String:
	if _arrived or GameState.cat_at_campfire:
		if GameState.map_assembled or GameState.has_inventory_item(GameState.ITEM_MAP):
			return "map_after"
		if GameState.has_all_map_pieces():
			return "map_ready"
		return post_arrival_dialogue_start
	if heard_flag != "" and GameState.get(heard_flag):
		return "return"
	return dialogue_start

func _can_trade_map_pieces() -> bool:
	return (_arrived or GameState.cat_at_campfire) and not GameState.map_assembled and GameState.has_all_map_pieces()

func _run_map_exchange() -> void:
	_dialogue_running = true
	talking = true
	_update_prompt_visibility()
	await _show_dialogue_branch("map_ready")
	if not GameState.assemble_map():
		await _show_dialogue_branch("hands_full")
	else:
		if QuestManager.has_objective("talk_cat"):
			QuestManager.complete("talk_cat")
		QuestManager.add_sub("use_clock_map", "Use the clock on the map", "escape")
	_dialogue_running = false
	talking = false
	_update_prompt_visibility()

func _advance_quest_after_cat_intro() -> void:
	QuestManager.complete("explore_variant_2")
	QuestManager.add_sub("free_cat", "Free the cat", "escape")

func _advance_quest_after_cat_freed() -> void:
	if not QuestManager.has_objective("free_cat"):
		return
	QuestManager.complete("free_cat")
	QuestManager.add_sub("follow_cat", "Follow the cat", "escape")

func _advance_quest_after_cat_arrival() -> void:
	if QuestManager.has_objective("follow_cat"):
		QuestManager.complete("follow_cat")
	QuestManager.add_sub("talk_cat", "Talk to the cat", "escape")

func _advance_quest_after_cat_campfire_talk() -> void:
	QuestManager.complete("talk_cat")
	QuestManager.add_sub(
		"find_map_pieces",
		"Find the map pieces",
		"escape",
		{"progress_current": GameState.collected_map_pieces.size(), "progress_required": 4}
	)

func _show_dialogue_branch(start: String) -> void:
	DialogueManager.show_dialogue_balloon(dialogue_resource, start)
	await DialogueManager.dialogue_ended

func _face_target(target_world_position: Vector2) -> void:
	var offset := target_world_position - global_position
	if offset.length_squared() <= 0.001:
		return
	var direction := _direction_from_vector(offset.normalized())
	if direction != facing_direction:
		facing_direction = direction

func _clear_key_selection() -> void:
	if GameState.selected_inventory_item == GameState.ITEM_KEY:
		GameState.clear_selected_inventory_item()
	elif GameState.key_mode:
		GameState.set_key_mode(false)

func _is_click_on_zone() -> bool:
	var mouse_world := get_global_mouse_position()
	var zone_pos := interaction_area.global_position + interaction_shape.position
	var rect_shape := interaction_shape.shape as RectangleShape2D
	if rect_shape == null:
		return false
	var rect := Rect2(zone_pos - rect_shape.size * 0.5, rect_shape.size)
	return rect.has_point(mouse_world)

func _show_dialog(text: String) -> void:
	var bubbles := get_tree().get_nodes_in_group("dialog_bubble")
	if bubbles.size() > 0:
		bubbles[0].show_text(text, "You")

func _play_sfx(stream: AudioStream) -> void:
	var sfx := AudioStreamPlayer.new()
	sfx.stream = stream
	get_tree().root.add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)

func _is_player(body: Node) -> bool:
	return body is CharacterBody2D and (body.name == "Player" or body.is_in_group("Player"))

func _direction_from_vector(value: Vector2) -> String:
	var angle := value.angle()
	var degrees := rad_to_deg(angle)
	if degrees < 0.0:
		degrees += 360.0
	if degrees >= 337.5 or degrees < 22.5:
		return "east"
	if degrees < 67.5:
		return "south_east"
	if degrees < 112.5:
		return "south"
	if degrees < 157.5:
		return "south_west"
	if degrees < 202.5:
		return "west"
	if degrees < 247.5:
		return "north_west"
	if degrees < 292.5:
		return "north"
	if degrees < 337.5:
		return "north_east"
	return facing_direction

static func _get_shared_frames() -> SpriteFrames:
	if _shared_frames != null:
		return _shared_frames
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	_add_direction_frames(frames)
	_add_animation_from_folder(frames, "blink_south", "%s/blink_south" % FRAMES_ROOT, 10.0, false)
	_add_animation_from_folder(frames, "blink_south_east", "%s/blink_south_east" % FRAMES_ROOT, 10.0, false)
	_add_animation_from_folder(frames, "blink_south_west", "%s/blink_south_west" % FRAMES_ROOT, 10.0, false)
	_add_animation_from_folder(frames, "walk_south", "%s/idle_walk_south" % FRAMES_ROOT, 10.0, true)
	_add_animation_from_folder(frames, "walk_south_east", "%s/idle_walk_south_east" % FRAMES_ROOT, 10.0, true)
	_add_animation_from_folder(frames, "walk_east", "%s/idle_walk_east" % FRAMES_ROOT, 10.0, true)
	_add_animation_from_folder(frames, "walk_north_east", "%s/idle_walk_north_east" % FRAMES_ROOT, 10.0, true)
	_add_animation_from_folder(frames, "walk_north", "%s/idle_walk_north" % FRAMES_ROOT, 10.0, true)
	_add_animation_from_folder(frames, "walk_north_west", "%s/idle_walk_north_west" % FRAMES_ROOT, 10.0, true)
	_add_animation_from_folder(frames, "walk_west", "%s/idle_walk_west" % FRAMES_ROOT, 10.0, true)
	_add_animation_from_folder(frames, "walk_south_west", "%s/idle_walk_south_west" % FRAMES_ROOT, 10.0, true)
	_add_animation_from_folder(frames, "locked", "%s/locked" % FRAMES_ROOT, 10.0, true)
	_add_animation_from_folder(frames, "locked_blink", "%s/locked_blink" % FRAMES_ROOT, 10.0, false)
	_add_animation_from_folder(frames, "locked_speaking", "%s/locked_speaking" % FRAMES_ROOT, 10.0, true)
	_add_animation_from_folder(frames, "unlock", "%s/unlock" % FRAMES_ROOT, 10.0, false)
	_shared_frames = frames
	return _shared_frames

static func _add_direction_frames(frames: SpriteFrames) -> void:
	for direction in DIRECTIONS:
		var path := "%s/directions/%s.png" % [FRAMES_ROOT, direction]
		var texture := load(path)
		if texture == null:
			push_error("Missing cat direction frame: %s" % path)
			continue
		var animation_name := "dir_%s" % direction
		frames.add_animation(animation_name)
		frames.set_animation_speed(animation_name, 1.0)
		frames.set_animation_loop(animation_name, true)
		frames.add_frame(animation_name, texture)

static func _add_animation_from_folder(frames: SpriteFrames, animation_name: String, folder: String, speed: float, loop: bool) -> void:
	var files := DirAccess.get_files_at(folder)
	files.sort()
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, speed)
	frames.set_animation_loop(animation_name, loop)
	for file_name in files:
		if not file_name.ends_with(".png"):
			continue
		var texture := load("%s/%s" % [folder, file_name])
		if texture != null:
			frames.add_frame(animation_name, texture)
