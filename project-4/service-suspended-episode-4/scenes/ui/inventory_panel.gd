extends Control

# Numbered icon arrays (index = count 0-9)
var _key_icons: Array[Texture2D] = []
var _ticket_icons: Array[Texture2D] = []
var _special_icon = preload("res://assets/items/icons/special_ticket/inventory_icon.png")
var _punch_icon = preload("res://assets/ui/hole_punch/punch_0.png")
var _bg_texture = preload("res://assets/ui/inventory/inventory.png")

var _key_sprite: Sprite2D
var _ticket_sprite: Sprite2D
var _special_sprite: Sprite2D
var _punch_sprite: Sprite2D

const BG_SCALE = Vector2(2, 2)
# Slot centers in native 64x80 coords, scaled by BG_SCALE for final position
# Layout: TL=keys, TR=tickets, BL=punch, BR=special
const SLOT_TL = Vector2(18, 28)
const SLOT_TR = Vector2(46, 28)
const SLOT_BL = Vector2(18, 56)
const SLOT_BR = Vector2(46, 56)
const ICON_SCALE = Vector2(0.7, 0.7)

func _ready() -> void:
	visible = false
	_load_icons()
	_build_slots()
	GameState.ticket_collected.connect(_on_count_changed)
	GameState.ticket_picked_up.connect(_on_count_changed_single)
	GameState.key_collected.connect(_on_count_changed_single)
	GameState.special_ticket_collected.connect(_on_count_changed)

func _load_icons() -> void:
	for i in range(10):
		_key_icons.append(load("res://assets/ui/key_icons/key_Numbered_%02d.png" % i))
		_ticket_icons.append(load("res://assets/ui/tickets/ticket_Numbered_%d.png" % i))

func toggle() -> void:
	visible = !visible
	if visible:
		_update_icons()

func _build_slots() -> void:
	var bg = Sprite2D.new()
	bg.texture = _bg_texture
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.centered = false
	bg.scale = BG_SCALE
	add_child(bg)

	_key_sprite = _make_icon(SLOT_TL * BG_SCALE, _key_icons[0])
	add_child(_key_sprite)

	_ticket_sprite = _make_icon(SLOT_TR * BG_SCALE, _ticket_icons[0])
	add_child(_ticket_sprite)

	_punch_sprite = _make_icon(SLOT_BL * BG_SCALE, _punch_icon)
	add_child(_punch_sprite)

	_special_sprite = _make_icon(SLOT_BR * BG_SCALE, _special_icon)
	add_child(_special_sprite)

	_update_icons()

func _make_icon(pos: Vector2, texture: Texture2D) -> Sprite2D:
	var sprite = Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.position = pos
	sprite.scale = ICON_SCALE
	return sprite

func _update_icons() -> void:
	_key_sprite.texture = _key_icons[clampi(GameState.keys_collected, 0, 9)]
	_ticket_sprite.texture = _ticket_icons[clampi(GameState.tickets_held, 0, 9)]
	_special_sprite.texture = _special_icon

func _on_count_changed(_a, _b) -> void:
	_update_icons()

func _on_count_changed_single(_a) -> void:
	_update_icons()
