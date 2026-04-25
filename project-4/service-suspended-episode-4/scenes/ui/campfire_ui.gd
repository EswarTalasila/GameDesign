extends CanvasLayer

signal closed

const BURN_SHADER := preload("res://assets/shaders/statue_ticket_burn.gdshader")
const BURN_SOUND := preload("res://assets/sounds/ticket_burn.mp3")
const BOON_UI_SCENE := preload("res://scenes/ui/boon_choice_ui.tscn")

@export var ui_scale: float = 4.0
@export var center_offset: Vector2 = Vector2.ZERO
@export var slot_fade_time: float = 0.16
@export var close_time: float = 0.14
@export var offering_scale_multiplier: float = 1.0
@export var offering_hold_time: float = 0.35
@export var offering_burn_time: float = 2.2
@export var offering_burn_radius_end: float = 1.08
@export_range(0.0, 1.0) var dim_alpha: float = 0.42

@onready var dimmer: ColorRect = $DimLayer/Dimmer
@onready var slot: Sprite2D = $ContentLayer/Slot
@onready var offering_icon: Sprite2D = $ContentLayer/OfferingIcon

var _is_open: bool = false
var _is_busy: bool = false
var _slot_base_position: Vector2 = Vector2.ZERO
var _offering_icon_base_position: Vector2 = Vector2.ZERO
var _slot_base_scale: Vector2 = Vector2.ONE
var _offering_icon_base_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	add_to_group("campfire_ui_overlay")
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

func is_blocking_pause() -> bool:
	return _is_open or visible

func open() -> void:
	if _is_busy or _is_open:
		return
	_is_open = true
	_is_busy = true
	visible = true
	GameState.set_ritual_focus_item(GameState.ITEM_VOODOO_DOLL)

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
		if _is_point_inside_sprite(event.position, slot) and GameState.selected_inventory_item == GameState.ITEM_VOODOO_DOLL:
			_burn_voodoo_doll()

func _burn_voodoo_doll() -> void:
	if not GameState.consume_inventory_item(GameState.ITEM_VOODOO_DOLL, 1):
		return
	_is_busy = true
	offering_icon.visible = true
	offering_icon.modulate = Color.WHITE
	var material: ShaderMaterial = offering_icon.material as ShaderMaterial
	if material:
		material.set_shader_parameter("radius", 0.0)
	_play_sfx(BURN_SOUND)
	await get_tree().create_timer(offering_hold_time).timeout
	var burn_tween: Tween = create_tween()
	burn_tween.tween_method(_set_offering_burn_radius, 0.0, offering_burn_radius_end, offering_burn_time)
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

func _set_offering_burn_radius(value: float) -> void:
	var material: ShaderMaterial = offering_icon.material as ShaderMaterial
	if material:
		material.set_shader_parameter("radius", value)

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
	offering_icon.scale = _offering_icon_base_scale * scale_vec * offering_scale_multiplier

func _setup_fullscreen_rect(rect: ColorRect) -> void:
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _setup_offering_material() -> void:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = BURN_SHADER
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.03
	var noise_tex: NoiseTexture2D = NoiseTexture2D.new()
	noise_tex.noise = noise
	material.set_shader_parameter("position", Vector2(0.5, 0.5))
	material.set_shader_parameter("radius", 0.0)
	material.set_shader_parameter("borderWidth", 0.2)
	material.set_shader_parameter("burnMult", 0.34)
	material.set_shader_parameter("noiseTexture", noise_tex)
	material.set_shader_parameter("burnColor", Color(1.0, 0.58, 0.12, 1.0))
	material.set_shader_parameter("pixel_size", 0.004)
	material.set_shader_parameter("blend_steps", 8.5)
	offering_icon.material = material

func _play_sfx(stream: AudioStream) -> void:
	var sfx: AudioStreamPlayer = AudioStreamPlayer.new()
	sfx.stream = stream
	get_tree().root.add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)

func _reset_visual_state() -> void:
	visible = false
	var target: Vector2 = _get_target_position()
	slot.position = _get_layout_position(target, _slot_base_position)
	offering_icon.position = _get_layout_position(target, _offering_icon_base_position)
	slot.modulate = Color(1, 1, 1, 0)
	offering_icon.modulate = Color(1, 1, 1, 0)
	offering_icon.visible = false
	dimmer.color = Color(0.05, 0.04, 0.08, 1.0)
	dimmer.modulate = Color(1, 1, 1, 0)
