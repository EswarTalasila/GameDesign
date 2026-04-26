extends Node2D

signal pause_requested

const SLOT_SELECTED_MULT := 1.1388889
const SLOT_PULSE_MULT := 1.26
const SLOT_PULSE_TIME := 0.26
const SLOT_PULSE_BRIGHT := 1.45
const COUNT_Z_INDEX := 100
const COUNTER_DIGITS_SCENE := preload("res://scenes/ui/counter_digits.tscn")
const SPECIAL_TICKET_ICON_SCENE := preload("res://scenes/items/icons/special_ticket_inventory_icon.tscn")
const VOODOO_ICON_SCENE := preload("res://scenes/items/icons/voodoo_doll_inventory_icon.tscn")
const CLOCK_ICON_SCENE := preload("res://scenes/items/icons/clock_inventory_icon.tscn")
const PAUSE_NORMAL := preload("res://assets/ui/buttons/play_pause/pause_normal.png")
const PAUSE_PRESSED := preload("res://assets/ui/buttons/play_pause/pause_pressed.png")
const PLAY_NORMAL := preload("res://assets/ui/buttons/play_pause/play_normal.png")

var _slot_counts: Dictionary[Node2D, Node2D] = {}
var _slot_icon_roots: Dictionary[Node2D, Node2D] = {}
var _slot_base_scales: Dictionary[Node2D, Vector2] = {}
var _slot_special_icons: Dictionary[Node2D, Node2D] = {}
var _slot_voodoo_icons: Dictionary[Node2D, Node2D] = {}
var _slot_clock_icons: Dictionary[Node2D, Node2D] = {}
var _ritual_focus_active: bool = false
var _ritual_focus_item: String = ""
var _pulse_tween: Tween = null
var _pulse_target: Node2D = null
var _pause_visual_pressed: bool = false

@onready var slot_1: Node2D = $Slot1
@onready var slot_2: Node2D = $Slot2
@onready var slot_3: Node2D = $Slot3
@onready var slot_4: Node2D = $Slot4
@onready var pause_slot: Sprite2D = $PauseSlot

func _ready() -> void:
	for slot: Node2D in _get_slots():
		_configure_slot(slot)
	GameState.inventory_changed.connect(_refresh)
	GameState.inventory_selection_changed.connect(_on_selection_changed)
	GameState.ritual_focus_changed.connect(_on_ritual_focus_changed)
	_refresh()
	_on_ritual_focus_changed(not GameState.ritual_focus_item.is_empty(), GameState.ritual_focus_item)
	_on_selection_changed(GameState.selected_inventory_item)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	var slot_index: int = _find_clicked_slot_index(event.position)
	if slot_index == -1:
		return
	var item_id: String = GameState.get_inventory_slot_item(slot_index)
	if item_id.is_empty():
		return
	GameState.toggle_selected_inventory_item(item_id)

func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	if _is_point_inside_sprite(event.position, pause_slot):
		get_viewport().set_input_as_handled()
		_press_pause()

func _configure_slot(slot: Node2D) -> void:
	var icon_root: Node2D = slot.get_node_or_null("IconRoot") as Node2D
	if icon_root == null:
		icon_root = Node2D.new()
		icon_root.name = "IconRoot"
		slot.add_child(icon_root)
	var count_sprite: Node2D = slot.get_node_or_null("Count") as Node2D
	if count_sprite == null:
		count_sprite = COUNTER_DIGITS_SCENE.instantiate() as Node2D
		count_sprite.name = "Count"
		count_sprite.position = Vector2(22, 22)
		slot.add_child(count_sprite)
	count_sprite.z_index = COUNT_Z_INDEX
	count_sprite.visible = false
	_slot_icon_roots[slot] = icon_root
	_slot_counts[slot] = count_sprite
	_slot_base_scales[slot] = icon_root.scale
	_slot_special_icons[slot] = _get_or_create_scene_icon(slot, "SpecialTicketInventoryIcon", SPECIAL_TICKET_ICON_SCENE)
	_slot_voodoo_icons[slot] = _get_or_create_scene_icon(slot, "VoodooDollInventoryIcon", VOODOO_ICON_SCENE)
	_slot_clock_icons[slot] = _get_or_create_scene_icon(slot, "ClockInventoryIcon", CLOCK_ICON_SCENE)

func _refresh() -> void:
	var slots: Array[Node2D] = _get_slots()
	for i in range(slots.size()):
		var slot: Node2D = slots[i]
		var item_id: String = GameState.get_inventory_slot_item(i)
		_set_slot_scene_icon_visible(_slot_special_icons, slot, item_id == GameState.ITEM_SPECIAL_TICKET)
		_set_slot_scene_icon_visible(_slot_voodoo_icons, slot, item_id == GameState.ITEM_VOODOO_DOLL)
		_set_slot_scene_icon_visible(_slot_clock_icons, slot, item_id == GameState.ITEM_CLOCK)
		_update_count_sprite(slot, item_id)
	_update_slot_visuals()

func _update_count_sprite(slot: Node2D, item_id: String) -> void:
	var count_sprite: Node2D = _slot_counts.get(slot) as Node2D
	if count_sprite == null:
		return
	if item_id.is_empty() or not _is_stackable_slot(slot):
		count_sprite.visible = false
		return
	var count: int = clampi(GameState.get_inventory_count(item_id), 0, 9)
	if count_sprite.has_method("set_count"):
		count_sprite.set_count(count)
	else:
		count_sprite.set("value", count)
	count_sprite.visible = count > 0

func _on_selection_changed(_item_id: String) -> void:
	_update_slot_visuals()

func _on_ritual_focus_changed(active: bool, item_id: String) -> void:
	_ritual_focus_active = active and not item_id.is_empty()
	_ritual_focus_item = item_id if _ritual_focus_active else ""
	_update_slot_visuals()

func _find_clicked_slot_index(mouse_pos: Vector2) -> int:
	var slots: Array[Node2D] = _get_slots()
	for i in range(slots.size()):
		if _is_point_inside_slot(mouse_pos, slots[i]):
			return i
	return -1

func _is_point_inside_slot(point: Vector2, slot: Node2D) -> bool:
	if not _has_visible_item(slot):
		return false
	if slot.has_method("contains_global_point"):
		return slot.contains_global_point(point)
	return false

func _is_point_inside_sprite(point: Vector2, sprite: Sprite2D) -> bool:
	if not sprite.visible or sprite.texture == null:
		return false
	var size: Vector2 = sprite.texture.get_size() * sprite.scale
	var center: Vector2 = sprite.get_global_transform_with_canvas().origin
	var rect: Rect2 = Rect2(center - size * 0.5, size)
	return rect.has_point(point)

func _update_slot_visuals() -> void:
	var slots: Array[Node2D] = _get_slots()
	for i in range(slots.size()):
		var slot: Node2D = slots[i]
		var icon_root: Node2D = _slot_icon_roots.get(slot) as Node2D
		if icon_root == null:
			continue
		var slot_item: String = GameState.get_inventory_slot_item(i)
		var scene_scale: Vector2 = _get_slot_base_scale(slot)
		var selected: bool = slot_item == GameState.selected_inventory_item and not slot_item.is_empty()
		icon_root.scale = scene_scale * SLOT_SELECTED_MULT if selected else scene_scale
		icon_root.modulate = Color.WHITE if _has_visible_item(slot) else Color(1, 1, 1, 0)
	_update_ritual_focus_pulse()

func _update_ritual_focus_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
	if _pulse_target:
		_apply_static_slot_visual(_pulse_target)
		_pulse_target = null
	var target: Node2D = _get_ritual_focus_slot()
	if target == null or not _has_visible_item(target):
		return
	var icon_root: Node2D = _slot_icon_roots.get(target) as Node2D
	if icon_root == null:
		return
	var target_item: String = _get_slot_item(target)
	var selected: bool = GameState.selected_inventory_item == target_item and not target_item.is_empty()
	var scene_scale: Vector2 = _get_slot_base_scale(target)
	var base_scale: Vector2 = scene_scale * SLOT_SELECTED_MULT if selected else scene_scale
	var base_modulate: Color = Color.WHITE
	if _ritual_focus_active:
		icon_root.scale = base_scale
		icon_root.modulate = base_modulate
		var peak_modulate: Color = Color(
			base_modulate.r * SLOT_PULSE_BRIGHT,
			base_modulate.g * SLOT_PULSE_BRIGHT,
			base_modulate.b * SLOT_PULSE_BRIGHT,
			base_modulate.a
		)
		_pulse_target = target
		_pulse_tween = create_tween().set_loops(0)
		_pulse_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_pulse_tween.tween_property(icon_root, "scale", base_scale * SLOT_PULSE_MULT, SLOT_PULSE_TIME).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		_pulse_tween.parallel().tween_property(icon_root, "modulate", peak_modulate, SLOT_PULSE_TIME).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		_pulse_tween.tween_property(icon_root, "scale", base_scale, SLOT_PULSE_TIME).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		_pulse_tween.parallel().tween_property(icon_root, "modulate", base_modulate, SLOT_PULSE_TIME).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _apply_static_slot_visual(slot: Node2D) -> void:
	var icon_root: Node2D = _slot_icon_roots.get(slot) as Node2D
	if icon_root == null:
		return
	var slot_item: String = _get_slot_item(slot)
	var scene_scale: Vector2 = _get_slot_base_scale(slot)
	icon_root.scale = scene_scale * SLOT_SELECTED_MULT if GameState.selected_inventory_item == slot_item and not slot_item.is_empty() else scene_scale
	icon_root.modulate = Color.WHITE if _has_visible_item(slot) else Color(1, 1, 1, 0)

func _get_slots() -> Array[Node2D]:
	return [slot_1, slot_2, slot_3, slot_4]

func _get_ritual_focus_slot() -> Node2D:
	if _ritual_focus_item.is_empty():
		return null
	var slots: Array[Node2D] = _get_slots()
	for i in range(slots.size()):
		if GameState.get_inventory_slot_item(i) == _ritual_focus_item:
			return slots[i]
	return null

func _get_slot_base_scale(slot: Node2D) -> Vector2:
	if _slot_base_scales.has(slot):
		return _slot_base_scales[slot]
	return Vector2.ONE

func _get_slot_item(slot: Node2D) -> String:
	var slots: Array[Node2D] = _get_slots()
	for i in range(slots.size()):
		if slots[i] == slot:
			return GameState.get_inventory_slot_item(i)
	return ""

func _get_or_create_scene_icon(slot: Node2D, icon_name: String, scene: PackedScene) -> Node2D:
	var icon_root: Node2D = _slot_icon_roots.get(slot) as Node2D
	if icon_root == null:
		icon_root = slot.get_node_or_null("IconRoot") as Node2D
	var scene_icon: Node2D = icon_root.get_node_or_null(icon_name) as Node2D
	if scene_icon == null:
		scene_icon = scene.instantiate() as Node2D
		scene_icon.name = icon_name
		scene_icon.scale = Vector2.ONE
		scene_icon.visible = false
		icon_root.add_child(scene_icon)
	return scene_icon

func _set_slot_scene_icon_visible(icon_map: Dictionary[Node2D, Node2D], slot: Node2D, should_show: bool) -> void:
	var scene_icon: Node2D = icon_map.get(slot) as Node2D
	if scene_icon:
		scene_icon.visible = should_show

func _get_visible_slot_scene_icon(slot: Node2D) -> Node2D:
	var special_icon: Node2D = _slot_special_icons.get(slot) as Node2D
	if special_icon != null and special_icon.visible:
		return special_icon
	var voodoo_icon: Node2D = _slot_voodoo_icons.get(slot) as Node2D
	if voodoo_icon != null and voodoo_icon.visible:
		return voodoo_icon
	var clock_icon: Node2D = _slot_clock_icons.get(slot) as Node2D
	if clock_icon != null and clock_icon.visible:
		return clock_icon
	return null

func _has_visible_item(slot: Node2D) -> bool:
	return _get_visible_slot_scene_icon(slot) != null

func _is_stackable_slot(slot: Node2D) -> bool:
	var scene_icon: Node2D = _get_visible_slot_scene_icon(slot)
	if scene_icon == null:
		return false
	if scene_icon.has_method("is_stackable"):
		return scene_icon.is_stackable()
	return false

func _press_pause() -> void:
	if _pause_visual_pressed:
		return
	_pause_visual_pressed = true
	pause_slot.texture = PAUSE_PRESSED
	await get_tree().create_timer(0.1).timeout
	_pause_visual_pressed = false
	pause_requested.emit()

func set_paused(paused: bool) -> void:
	if paused:
		pause_slot.texture = PLAY_NORMAL
	else:
		pause_slot.texture = PAUSE_NORMAL
