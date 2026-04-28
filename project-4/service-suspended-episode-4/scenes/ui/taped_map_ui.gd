extends CanvasLayer

signal closed

const MAP_TEXTURE := preload("res://assets/ui/map/taped_map_ui.png")
const MAP_CLOCK_TEXTURES := [
	preload("res://assets/ui/clock/map_clock_1.png"),
	preload("res://assets/ui/clock/map_clock_2.png"),
	preload("res://assets/ui/clock/map_clock_3.png"),
	preload("res://assets/ui/clock/map_clock_4.png"),
	preload("res://assets/ui/clock/map_clock_5.png"),
	preload("res://assets/ui/clock/map_clock_6.png"),
]
const TREE_TEXTURE_PATH := "res://assets/ui/map/trees/position_%d_%s.png"

@export var ui_scale: float = 5.0
# Clock is scaled independently (matches game 3 ratio: clock=2, map=5)
@export var clock_scale: float = 2.0
@export var dim_alpha: float = 0.42
@export var fade_in_time: float = 0.18
@export var fade_out_time: float = 0.14
@export var reveal_time: float = 2.6

@onready var dimmer: ColorRect = $DimLayer/Dimmer
@onready var map_sprite: Sprite2D = $ContentLayer/MapSprite
@onready var clock_sprite: Sprite2D = $ContentLayer/ClockSprite
@onready var reveal_root: Node2D = $ContentLayer/RevealRoot

var _tree_sprites: Array[Sprite2D] = []
var _clock_anim_index: int = 0
var _clock_anim_timer: float = 0.0
var _is_open: bool = false
var _is_closing: bool = false
var _is_revealing: bool = false

func _ready() -> void:
	add_to_group("map_ui_overlay")
	$DimLayer.layer = 8
	$ContentLayer.layer = 30
	_setup_fullscreen_rect(dimmer)
	_build_tree_sprites()
	_configure_visuals()
	_update_layout()
	_reset_visual_state()
	_apply_current_state()
	_fade_in()

func _process(delta: float) -> void:
	if not clock_sprite.visible:
		return
	_clock_anim_timer += delta
	if _clock_anim_timer < 0.5:
		return
	_clock_anim_timer = 0.0
	_clock_anim_index = (_clock_anim_index + 1) % MAP_CLOCK_TEXTURES.size()
	clock_sprite.texture = MAP_CLOCK_TEXTURES[_clock_anim_index]

func _input(event: InputEvent) -> void:
	if _is_closing:
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
		return
	if not (event is InputEventMouseButton):
		return
	var click_event := event as InputEventMouseButton
	if click_event.button_index != MOUSE_BUTTON_LEFT or not click_event.pressed:
		return
	if GameState.selected_inventory_item == GameState.ITEM_CLOCK and can_accept_clock_from_inventory() and _is_point_inside_sprite(click_event.position, map_sprite):
		get_viewport().set_input_as_handled()
		place_clock_from_inventory()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_update_layout()

func is_blocking_pause() -> bool:
	return visible and not _is_closing

func can_accept_clock_from_inventory() -> bool:
	return _is_open and not _is_closing and not _is_revealing and not GameState.clock_on_map and GameState.has_inventory_item(GameState.ITEM_CLOCK)

func place_clock_from_inventory() -> void:
	if not can_accept_clock_from_inventory():
		return
	GameState.clear_selected_inventory_item()
	GameState.clear_ritual_focus_item()
	_start_reveal()

func close() -> void:
	if _is_closing or _is_revealing:
		return
	_is_closing = true
	_is_open = false
	GameState.clear_ritual_focus_item()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(dimmer, "modulate:a", 0.0, fade_out_time)
	tween.tween_property(map_sprite, "modulate:a", 0.0, fade_out_time)
	tween.tween_property(clock_sprite, "modulate:a", 0.0, fade_out_time)
	for sprite in _tree_sprites:
		tween.tween_property(sprite, "modulate:a", 0.0, fade_out_time)
	await tween.finished
	closed.emit()

func _configure_visuals() -> void:
	map_sprite.texture = MAP_TEXTURE
	map_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_sprite.scale = Vector2.ONE * ui_scale
	clock_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clock_sprite.scale = Vector2.ONE * clock_scale
	for sprite in _tree_sprites:
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2.ONE * ui_scale

func _build_tree_sprites() -> void:
	for child in reveal_root.get_children():
		child.queue_free()
	_tree_sprites.clear()
	for assignment in GameState.get_map_tree_reveal_order():
		var sprite := Sprite2D.new()
		var position_index: int = int(assignment.get("position", 0))
		var color_name := String(assignment.get("color", ""))
		sprite.texture = load(TREE_TEXTURE_PATH % [position_index, color_name]) as Texture2D
		sprite.visible = false
		reveal_root.add_child(sprite)
		_tree_sprites.append(sprite)

func _update_layout() -> void:
	var center := get_viewport().get_visible_rect().size * 0.5
	map_sprite.position = center
	clock_sprite.position = center
	reveal_root.position = center
	for sprite in _tree_sprites:
		sprite.position = Vector2.ZERO

func _reset_visual_state() -> void:
	visible = true
	dimmer.color = Color(0.05, 0.04, 0.08, 1.0)
	dimmer.modulate = Color(1, 1, 1, 0)
	map_sprite.modulate = Color(1, 1, 1, 0)
	map_sprite.scale = Vector2.ONE * (ui_scale * 0.96)
	clock_sprite.visible = false
	clock_sprite.modulate = Color(1, 1, 1, 0)
	for sprite in _tree_sprites:
		sprite.visible = false
		sprite.modulate = Color(1, 1, 1, 0)

func _apply_current_state() -> void:
	if GameState.clock_on_map:
		_show_revealed_map()
	else:
		GameState.set_ritual_focus_item(GameState.ITEM_CLOCK)

func _fade_in() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(dimmer, "modulate:a", dim_alpha, fade_in_time)
	tween.tween_property(map_sprite, "modulate:a", 1.0, fade_in_time)
	tween.tween_property(map_sprite, "scale", Vector2.ONE * ui_scale, fade_in_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished
	_is_open = true

func _start_reveal() -> void:
	if _is_revealing:
		return
	_is_revealing = true
	clock_sprite.visible = true
	clock_sprite.modulate = Color(1, 1, 1, 0)
	clock_sprite.texture = MAP_CLOCK_TEXTURES[0]
	_clock_anim_index = 0
	_clock_anim_timer = 0.0
	for sprite in _tree_sprites:
		sprite.visible = true
		sprite.modulate = Color(1, 1, 1, 0)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(clock_sprite, "modulate:a", 1.0, 0.18)
	for sprite in _tree_sprites:
		tween.tween_property(sprite, "modulate:a", 1.0, reveal_time)
	await tween.finished
	GameState.clock_on_map = true
	if QuestManager.has_objective("use_clock_map"):
		QuestManager.complete("use_clock_map")
	_is_revealing = false

func _show_revealed_map() -> void:
	clock_sprite.visible = true
	clock_sprite.modulate = Color.WHITE
	clock_sprite.texture = MAP_CLOCK_TEXTURES[_clock_anim_index]
	for sprite in _tree_sprites:
		sprite.visible = true
		sprite.modulate = Color.WHITE
	GameState.clear_ritual_focus_item()

func _setup_fullscreen_rect(rect: ColorRect) -> void:
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _is_point_inside_sprite(point: Vector2, sprite: Sprite2D) -> bool:
	if sprite.texture == null or sprite.modulate.a <= 0.0:
		return false
	var size := sprite.texture.get_size() * sprite.scale
	var center := sprite.get_global_transform_with_canvas().origin
	var rect := Rect2(center - size * 0.5, size)
	return rect.has_point(point)
