extends CanvasLayer

signal closed

const BURN_SHADER := preload("res://assets/shaders/offering_burn_center.gdshader")
const BURN_SOUND := preload("res://assets/sounds/ticket_burn.mp3")
const BOON_UI_SCENE := preload("res://scenes/ui/boon_choice_ui.tscn")
const WOOD_ICON := preload("res://assets/items/icons/wood/inventory_icon.png")
const VOODOO_ICON := preload("res://assets/items/icons/voodoo_doll/inventory_icon.png")

@export var ui_scale: float = 4.0
@export var center_offset: Vector2 = Vector2.ZERO
@export var slot_fade_time: float = 0.16
@export var close_time: float = 0.14
@export var offering_scale_multiplier: float = 1.0
@export var voodoo_offering_fit_multiplier: float = 1.0
@export var wood_offering_fit_multiplier: float = 0.75
@export var offering_hold_time: float = 0.08
@export var offering_burn_time: float = 1.2
@export_range(1.0, 1.5, 0.01) var offering_burn_size: float = 1.3
@export var voodoo_burn_color: Color = Color(1.0, 0.58, 0.12, 1.0)
@export var wood_burn_color: Color = Color(0.86, 0.48, 0.16, 1.0)
@export var burn_hot_color: Color = Color(1.0, 0.76, 0.18, 1.0)
@export_range(0.0, 1.0) var dim_alpha: float = 0.42

@onready var dimmer: ColorRect = $DimLayer/Dimmer
@onready var slot: Sprite2D = $ContentLayer/Slot
@onready var offering_icon: Sprite2D = $ContentLayer/OfferingIcon

var _is_open: bool = false
var _is_busy: bool = false
var _campfire: Node = null
var _slot_base_position: Vector2 = Vector2.ZERO
var _offering_icon_base_position: Vector2 = Vector2.ZERO
var _slot_base_scale: Vector2 = Vector2.ONE
var _offering_icon_base_scale: Vector2 = Vector2.ONE
var _current_offering_fit_multiplier: float = 1.0

func _ready() -> void:
	add_to_group("campfire_ui_overlay")
	process_mode = Node.PROCESS_MODE_ALWAYS
	$DimLayer.layer = 8
	$ContentLayer.layer = 30
	_setup_fullscreen_rect(dimmer)
	slot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	offering_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_slot_base_position = slot.position
	_offering_icon_base_position = offering_icon.position
	_slot_base_scale = slot.scale
	_offering_icon_base_scale = offering_icon.scale
	_setup_offering_material()
	_apply_scale()
	_reset_visual_state()
	if not GameState.inventory_selection_changed.is_connected(_on_inventory_selection_changed):
		GameState.inventory_selection_changed.connect(_on_inventory_selection_changed)

func is_blocking_pause() -> bool:
	return _is_open or visible

func open(campfire: Node = null) -> void:
	if _is_busy or _is_open:
		return
	_campfire = campfire
	_is_open = true
	_is_busy = true
	visible = true
	_update_ritual_focus()

	var target: Vector2 = _get_target_position()
	slot.position = _get_layout_position(target, _slot_base_position)
	offering_icon.position = _get_layout_position(target, _offering_icon_base_position)
	slot.modulate.a = 0.0
	offering_icon.modulate = Color(1, 1, 1, 0)
	offering_icon.visible = false
	dimmer.modulate.a = 0.0

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(dimmer, "modulate:a", dim_alpha, slot_fade_time)
	tween.tween_property(slot, "modulate:a", 1.0, slot_fade_time)
	await tween.finished
	_is_busy = false
	_update_ritual_focus()

func close() -> void:
	if not _is_open or _is_busy:
		return
	_is_busy = true
	await _fade_out()
	_is_open = false
	_is_busy = false
	GameState.clear_ritual_focus_item()
	_reset_visual_state()
	closed.emit()

func _input(event: InputEvent) -> void:
	if not _is_open or _is_busy:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not _is_point_inside_sprite(event.position, slot):
			return
		if GameState.selected_inventory_item == GameState.ITEM_VOODOO_DOLL:
			_burn_voodoo_doll()
		elif GameState.selected_inventory_item == GameState.ITEM_WOOD:
			_offer_wood()

func _burn_voodoo_doll() -> void:
	if not GameState.consume_inventory_item(GameState.ITEM_VOODOO_DOLL, 1):
		return
	_is_busy = true
	_set_offering_icon_texture(GameState.ITEM_VOODOO_DOLL)
	offering_icon.visible = true
	offering_icon.modulate = Color.WHITE
	_prepare_offering_burn(GameState.ITEM_VOODOO_DOLL)
	_play_sfx(BURN_SOUND)
	await get_tree().create_timer(offering_hold_time).timeout
	var burn_tween: Tween = create_tween()
	burn_tween.tween_method(_set_offering_burn_integrity, 1.0, 0.0, offering_burn_time)
	await burn_tween.finished
	offering_icon.visible = false
	GameState.clear_selected_inventory_item()
	await _fade_out()
	_is_open = false
	_is_busy = false
	GameState.clear_ritual_focus_item()
	_reset_visual_state()
	_show_boon_ui()
	closed.emit()

func _offer_wood() -> void:
	if _campfire == null or not is_instance_valid(_campfire):
		return
	if not _campfire.has_method("can_feed_fire") or not _campfire.can_feed_fire():
		return
	_is_busy = true
	_set_offering_icon_texture(GameState.ITEM_WOOD)
	offering_icon.visible = true
	offering_icon.modulate = Color.WHITE
	_prepare_offering_burn(GameState.ITEM_WOOD)
	_play_sfx(BURN_SOUND)
	await get_tree().create_timer(offering_hold_time).timeout
	var burn_tween: Tween = create_tween()
	burn_tween.tween_method(_set_offering_burn_integrity, 1.0, 0.0, offering_burn_time * 0.82)
	await burn_tween.finished
	if _campfire.has_method("feed_fire_with_wood"):
		_campfire.feed_fire_with_wood()
	offering_icon.visible = false
	await _fade_out()
	_is_open = false
	_is_busy = false
	GameState.clear_ritual_focus_item()
	_reset_visual_state()
	closed.emit()

func _fade_out() -> void:
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(slot, "modulate:a", 0.0, close_time)
	tween.tween_property(offering_icon, "modulate:a", 0.0, close_time)
	tween.tween_property(dimmer, "modulate:a", 0.0, close_time)
	await tween.finished

func _show_boon_ui() -> void:
	var ui: Node = BOON_UI_SCENE.instantiate()
	get_tree().current_scene.add_child(ui)
	if ui.has_method("open"):
		ui.open()

func _set_offering_burn_integrity(value: float) -> void:
	var material: ShaderMaterial = offering_icon.material as ShaderMaterial
	if material:
		material.set_shader_parameter("integrity", value)

func _is_point_inside_sprite(point: Vector2, sprite: Sprite2D) -> bool:
	if sprite.texture == null or sprite.modulate.a <= 0.0:
		return false
	var size: Vector2 = sprite.texture.get_size() * sprite.scale
	var center: Vector2 = sprite.get_global_transform_with_canvas().origin
	return Rect2(center - size * 0.5, size).has_point(point)

func _get_target_position() -> Vector2:
	return get_viewport().get_visible_rect().size * 0.5 + center_offset

func _get_layout_position(target: Vector2, base_position: Vector2) -> Vector2:
	return target + base_position * ui_scale

func _apply_scale() -> void:
	var scale_vec: Vector2 = Vector2.ONE * ui_scale
	slot.scale = _slot_base_scale * scale_vec
	offering_icon.scale = _offering_icon_base_scale * scale_vec * offering_scale_multiplier * _current_offering_fit_multiplier

func _setup_fullscreen_rect(rect: ColorRect) -> void:
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _setup_offering_material() -> void:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = BURN_SHADER
	material.set_shader_parameter("noise_texture", _make_noise_texture())
	material.set_shader_parameter("burn_texture", _make_burn_texture(voodoo_burn_color))
	material.set_shader_parameter("integrity", 1.0)
	material.set_shader_parameter("burn_size", offering_burn_size)
	offering_icon.material = material

func _play_sfx(stream: AudioStream) -> void:
	var sfx: AudioStreamPlayer = AudioStreamPlayer.new()
	sfx.stream = stream
	get_tree().root.add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)

func _set_offering_icon_texture(item_id: String) -> void:
	if item_id == GameState.ITEM_WOOD:
		offering_icon.texture = WOOD_ICON
		_current_offering_fit_multiplier = wood_offering_fit_multiplier
	else:
		offering_icon.texture = VOODOO_ICON
		_current_offering_fit_multiplier = voodoo_offering_fit_multiplier
	_apply_scale()

func _update_ritual_focus() -> void:
	if not _is_open:
		return
	GameState.set_ritual_focus_items([GameState.ITEM_VOODOO_DOLL, GameState.ITEM_WOOD])

func _on_inventory_selection_changed(_item_id: String) -> void:
	_update_ritual_focus()

func _prepare_offering_burn(item_id: String) -> void:
	var material: ShaderMaterial = offering_icon.material as ShaderMaterial
	if material == null:
		return
	var burn_color: Color = wood_burn_color if item_id == GameState.ITEM_WOOD else voodoo_burn_color
	material.set_shader_parameter("integrity", 1.0)
	material.set_shader_parameter("burn_size", offering_burn_size)
	material.set_shader_parameter("burn_texture", _make_burn_texture(burn_color))

func _make_burn_texture(base_color: Color) -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(0.05, 0.02, 0.01, 0.0),
		base_color.darkened(0.65),
		base_color,
		base_color.lerp(burn_hot_color, 0.7),
		burn_hot_color,
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.18, 0.45, 0.75, 1.0])
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	texture.width = 256
	return texture

func _make_noise_texture() -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.03
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var value := noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			image.set_pixel(x, y, Color(value, value, value, 1.0))
	return ImageTexture.create_from_image(image)

func _reset_visual_state() -> void:
	visible = false
	_current_offering_fit_multiplier = voodoo_offering_fit_multiplier
	offering_icon.texture = VOODOO_ICON
	_apply_scale()
	var target: Vector2 = _get_target_position()
	slot.position = _get_layout_position(target, _slot_base_position)
	offering_icon.position = _get_layout_position(target, _offering_icon_base_position)
	slot.modulate = Color(1, 1, 1, 0)
	offering_icon.modulate = Color(1, 1, 1, 0)
	offering_icon.visible = false
	dimmer.color = Color(0.05, 0.04, 0.08, 1.0)
	dimmer.modulate = Color(1, 1, 1, 0)
