extends CanvasLayer

signal opened
signal closed

const BURN_SHADER := preload("res://assets/shaders/offering_burn_center.gdshader")
const BURN_SOUND := preload("res://assets/sounds/ticket_burn.mp3")
const STATUE_OFFERING_DIALOGUE := preload("res://dialogues/statue_offering.dialogue")

@export var ui_scale: float = 4.0
@export var center_offset: Vector2 = Vector2.ZERO
@export var intro_offset: Vector2 = Vector2(0, 72)
@export var hands_fade_time: float = 0.18
@export var hands_slide_time: float = 0.24
@export var slot_fade_time: float = 0.16
@export var close_time: float = 0.14
@export var breathing_fps: float = 8.0
@export var offering_scale_multiplier: float = 1.0
@export var offering_hold_time: float = 0.44
@export var offering_burn_time: float = 3.35
@export_range(1.0, 1.5, 0.01) var offering_burn_size: float = 1.3
@export var post_burn_close_delay: float = 0.0
@export_range(0.0, 1.0) var dim_alpha: float = 0.42
@export_range(0.0, 1.0) var glow_peak_strength: float = 0.38
@export_range(0.0, 1.0) var glow_idle_strength: float = 0.18
@export var glow_radius: float = 0.16
@export var glow_feather: float = 0.2
@export var burn_base_color: Color = Color(0.9, 0.4, 0.1, 1.0)
@export var burn_hot_color: Color = Color(1.0, 0.76, 0.18, 1.0)

@onready var dimmer: ColorRect = $DimLayer/Dimmer
@onready var glow: ColorRect = $ContentLayer/Glow
@onready var slot: Sprite2D = $ContentLayer/Slot
@onready var hands: AnimatedSprite2D = $ContentLayer/Hands
@onready var offering_icon: Sprite2D = $ContentLayer/OfferingIcon

var _target_statue: Node = null
var _is_open: bool = false
var _is_busy: bool = false
var _hands_base_position: Vector2 = Vector2.ZERO
var _slot_base_position: Vector2 = Vector2.ZERO
var _offering_icon_base_position: Vector2 = Vector2.ZERO
var _hands_base_scale: Vector2 = Vector2.ONE
var _slot_base_scale: Vector2 = Vector2.ONE
var _offering_icon_base_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	add_to_group("statue_ui_overlay")
	$DimLayer.layer = 8
	$ContentLayer.layer = 30
	_setup_fullscreen_rect(dimmer)
	_setup_fullscreen_rect(glow)
	_setup_glow_material()
	slot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hands.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	offering_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hands_base_position = hands.position
	_slot_base_position = slot.position
	_offering_icon_base_position = offering_icon.position
	_hands_base_scale = hands.scale
	_slot_base_scale = slot.scale
	_offering_icon_base_scale = offering_icon.scale
	_setup_offering_material()
	_apply_scale()
	_reset_visual_state()

func is_open_for_statue(statue: Node) -> bool:
	return _is_open and _target_statue == statue

func is_blocking_pause() -> bool:
	return _is_open or visible

func toggle_for_statue(statue: Node) -> void:
	if _is_busy:
		return
	if is_open_for_statue(statue):
		close()
	else:
		open_for(statue)

func open_for(statue: Node) -> void:
	if _is_busy:
		return
	_target_statue = statue
	_is_open = true
	_is_busy = true
	visible = true
	GameState.set_ritual_focus_item(GameState.ITEM_SPECIAL_TICKET)

	var target := _get_target_position()
	hands.position = _get_layout_position(target, _hands_base_position) + intro_offset
	slot.position = _get_layout_position(target, _slot_base_position)
	offering_icon.position = _get_layout_position(target, _offering_icon_base_position)
	hands.modulate.a = 0.0
	slot.modulate.a = 0.0
	offering_icon.modulate = Color(1, 1, 1, 0)
	offering_icon.visible = false
	dimmer.modulate.a = 0.0
	_set_glow_strength(0.0)
	_update_glow_center(target)
	hands.play("breathe")
	hands.stop()
	hands.frame = 0

	var hands_tween := create_tween().set_parallel(true)
	hands_tween.tween_property(hands, "position", _get_layout_position(target, _hands_base_position), hands_slide_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	hands_tween.tween_property(hands, "modulate:a", 1.0, hands_fade_time)
	hands_tween.tween_property(dimmer, "modulate:a", dim_alpha, hands_fade_time)
	await hands_tween.finished

	var slot_tween := create_tween().set_parallel(true)
	slot_tween.tween_property(slot, "modulate:a", 1.0, slot_fade_time)
	slot_tween.tween_method(_set_glow_strength, 0.0, glow_peak_strength, slot_fade_time)
	await slot_tween.finished

	var settle_tween := create_tween()
	settle_tween.tween_method(_set_glow_strength, glow_peak_strength, glow_idle_strength, 0.28)
	await settle_tween.finished

	hands.play("breathe")
	_is_busy = false
	opened.emit()

func close() -> void:
	if not _is_open or _is_busy:
		return
	_is_busy = true

	var hands_tween := create_tween().set_parallel(true)
	hands_tween.tween_property(hands, "modulate:a", 0.0, close_time)
	hands_tween.tween_property(slot, "modulate:a", 0.0, close_time)
	hands_tween.tween_property(offering_icon, "modulate:a", 0.0, close_time)
	hands_tween.tween_property(dimmer, "modulate:a", 0.0, close_time)
	hands_tween.tween_property(hands, "position", _get_layout_position(_get_target_position(), _hands_base_position) + intro_offset * 0.5, close_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	hands_tween.tween_method(_set_glow_strength, glow_idle_strength, 0.0, close_time)
	await hands_tween.finished

	_target_statue = null
	_is_open = false
	_is_busy = false
	GameState.clear_ritual_focus_item()
	_reset_visual_state()
	closed.emit()

func close_if_target(statue: Node) -> void:
	if _target_statue == statue:
		close()

func _input(event: InputEvent) -> void:
	if not _is_open or _is_busy:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _is_point_inside_sprite(event.position, slot) and GameState.selected_inventory_item == GameState.ITEM_SPECIAL_TICKET:
			_offer_special_ticket()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED and _is_open and not _is_busy:
		var target := _get_target_position()
		hands.position = _get_layout_position(target, _hands_base_position)
		slot.position = _get_layout_position(target, _slot_base_position)
		offering_icon.position = _get_layout_position(target, _offering_icon_base_position)
		_update_glow_center(target)

func _apply_scale() -> void:
	var scale_vec := Vector2.ONE * ui_scale
	hands.scale = _hands_base_scale * scale_vec
	slot.scale = _slot_base_scale * scale_vec
	offering_icon.scale = _offering_icon_base_scale * scale_vec * offering_scale_multiplier

func _get_layout_position(target: Vector2, base_position: Vector2) -> Vector2:
	return target + base_position * ui_scale

func _setup_fullscreen_rect(rect: ColorRect) -> void:
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _setup_glow_material() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode blend_add;

uniform vec2 center = vec2(0.5, 0.5);
uniform float radius = 0.16;
uniform float feather = 0.2;
uniform float strength = 0.0;
uniform vec4 glow_color : source_color = vec4(0.98, 0.84, 0.72, 1.0);

void fragment() {
	float d = distance(UV, center);
	float alpha = smoothstep(radius + feather, radius, d) * strength;
	COLOR = vec4(glow_color.rgb, alpha * glow_color.a);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	glow.material = material
	glow.color = Color.WHITE
	material.set_shader_parameter("radius", glow_radius)
	material.set_shader_parameter("feather", glow_feather)
	material.set_shader_parameter("strength", 0.0)

func _setup_offering_material() -> void:
	var material := ShaderMaterial.new()
	material.shader = BURN_SHADER
	material.set_shader_parameter("noise_texture", _make_noise_texture())
	material.set_shader_parameter("burn_texture", _make_burn_texture())
	material.set_shader_parameter("integrity", 1.0)
	material.set_shader_parameter("burn_size", offering_burn_size)
	offering_icon.material = material

func _get_target_position() -> Vector2:
	return get_viewport().get_visible_rect().size * 0.5 + center_offset

func _set_glow_strength(value: float) -> void:
	var material := glow.material as ShaderMaterial
	if material:
		material.set_shader_parameter("strength", value)

func _update_glow_center(target: Vector2) -> void:
	var material := glow.material as ShaderMaterial
	if material:
		var viewport_size := get_viewport().get_visible_rect().size
		if viewport_size.x > 0.0 and viewport_size.y > 0.0:
			material.set_shader_parameter("center", Vector2(target.x / viewport_size.x, target.y / viewport_size.y))

func _offer_special_ticket() -> void:
	if _target_statue == null:
		return
	if not GameState.consume_inventory_item(GameState.ITEM_SPECIAL_TICKET, 1):
		return
	_is_busy = true
	offering_icon.visible = true
	offering_icon.modulate = Color.WHITE
	var material := offering_icon.material as ShaderMaterial
	if material:
		material.set_shader_parameter("integrity", 1.0)
	_play_sfx(BURN_SOUND)
	await get_tree().create_timer(offering_hold_time).timeout
	var burn_tween := create_tween()
	burn_tween.tween_method(_set_offering_burn_integrity, 1.0, 0.0, offering_burn_time)
	await burn_tween.finished
	if post_burn_close_delay > 0.0:
		await get_tree().create_timer(post_burn_close_delay).timeout
	offering_icon.visible = false
	var accepted := false
	if _target_statue and _target_statue.has_method("resolve_special_ticket_offering"):
		accepted = _target_statue.resolve_special_ticket_offering()
	GameState.clear_selected_inventory_item()
	_is_busy = false
	await close()
	await _show_result_dialog("accepted" if accepted else "refused")

func _set_offering_burn_integrity(value: float) -> void:
	var material := offering_icon.material as ShaderMaterial
	if material:
		material.set_shader_parameter("integrity", value)

func _is_point_inside_sprite(point: Vector2, sprite: Sprite2D) -> bool:
	if sprite.texture == null or sprite.modulate.a <= 0.0:
		return false
	var size := sprite.texture.get_size() * sprite.scale
	var center := sprite.get_global_transform_with_canvas().origin
	var rect := Rect2(center - size * 0.5, size)
	return rect.has_point(point)

func _show_result_dialog(title: String) -> void:
	if STATUE_OFFERING_DIALOGUE == null:
		return
	DialogueManager.show_dialogue_balloon(STATUE_OFFERING_DIALOGUE, title)
	await DialogueManager.dialogue_ended

func _play_sfx(stream: AudioStream) -> void:
	var sfx := AudioStreamPlayer.new()
	sfx.stream = stream
	get_tree().root.add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)

func _make_burn_texture() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(0.05, 0.02, 0.01, 0.0),
		burn_base_color.darkened(0.65),
		burn_base_color,
		burn_base_color.lerp(burn_hot_color, 0.7),
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
	hands.stop()
	var target := _get_target_position()
	hands.position = _get_layout_position(target, _hands_base_position)
	slot.position = _get_layout_position(target, _slot_base_position)
	offering_icon.position = _get_layout_position(target, _offering_icon_base_position)
	hands.modulate = Color(1, 1, 1, 0)
	slot.modulate = Color(1, 1, 1, 0)
	offering_icon.modulate = Color(1, 1, 1, 0)
	offering_icon.visible = false
	dimmer.color = Color(0.05, 0.04, 0.08, 1.0)
	dimmer.modulate = Color(1, 1, 1, 0)
	_set_glow_strength(0.0)
