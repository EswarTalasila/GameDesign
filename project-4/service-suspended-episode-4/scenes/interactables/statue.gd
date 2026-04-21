@tool
extends Node2D

## Statue scene — place directly in variant scenes, configure in inspector.
## Instance this 6 times, each with different direction/fire settings.
##
## Per-instance customization:
##   - direction: which way the statue faces (updates texture live)
##   - fire_behind: whether flame renders behind or in front of statue
##   - statue_id: 1-6 for ritual ordering
##   - Fire child: right-click instance → Editable Children → move Fire node
##
## Structure:
##   Statue (this node)
##   ├── Sprite2D           — static directional texture (z_index=0)
##   ├── GemSprite          — animated gem overlay (hidden until activated)
##   └── Fire (instance)    — fire.tscn, z_index set by fire_behind

const SPRITE_PATH = "res://assets/sprites/statue/statue_%s.png"
const GEM_PATH = "res://assets/sprites/statue/statue_gem_%d.png"
const GEM_FRAME_COUNT = 8

@export_enum("front", "front_right", "right", "back_right",
	"back", "back_left", "left", "front_left")
var direction: String = "front":
	set(value):
		direction = value
		_update_texture()
		if auto_layer_fire:
			_auto_fire_layer()

## When true, fire renders behind the statue. When false, in front.
@export var fire_behind: bool = false:
	set(value):
		fire_behind = value
		_update_fire_layer()

## Automatically set fire_behind based on direction.
## Disabled by default so the flame stays visible in front of the statue.
@export var auto_layer_fire: bool = false:
	set(value):
		auto_layer_fire = value
		if auto_layer_fire:
			_auto_fire_layer()

## Whether fire is lit. Toggle in inspector or call light_fire() / extinguish_fire().
@export var fire_lit: bool = true:
	set(value):
		fire_lit = value
		_update_fire_visibility()

## When true, pressing interact in range toggles the fire on/off.
@export var toggle_fire_on_interact: bool = true

## Statue index (1-6) for golden ticket ritual ordering.
@export_range(1, 6) var statue_id: int = 1

## Whether this statue's ticket has been burned correctly.
var ticket_burned: bool = false

## Emitted when the player interacts with this statue (presses E in range).
signal interacted(statue: Node2D)

var _sprite: Sprite2D
var _gem_sprite: AnimatedSprite2D
var _fire: Node2D
var _zone: Area2D
var _prompt: AnimatedSprite2D
var _player_nearby: bool = false

func _ready() -> void:
	_sprite = get_node_or_null("Sprite2D")
	_gem_sprite = get_node_or_null("GemSprite")
	_fire = get_node_or_null("Fire")
	_zone = get_node_or_null("InteractZone")
	if _zone:
		_prompt = _zone.get_node_or_null("PressEPrompt")
		if not Engine.is_editor_hint():
			_zone.body_entered.connect(_on_zone_entered)
			_zone.body_exited.connect(_on_zone_exited)
	if _prompt:
		_prompt.visible = false
	_update_texture()
	_setup_gem_animation()
	if auto_layer_fire:
		_auto_fire_layer()
	else:
		_update_fire_layer()
	# Gem hidden by default — shown after ticket is burned
	if _gem_sprite:
		_gem_sprite.visible = false
	_update_fire_visibility()

func _on_zone_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player_nearby = true
		if _prompt:
			_prompt.visible = true

func _on_zone_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player_nearby = false
		if _prompt:
			_prompt.visible = false

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event.is_action_pressed("interact") and _player_nearby:
		if toggle_fire_on_interact:
			toggle_fire()
		interacted.emit(self)

func _update_texture() -> void:
	if not _sprite:
		_sprite = get_node_or_null("Sprite2D")
	if not _sprite:
		return
	var path = SPRITE_PATH % direction
	if ResourceLoader.exists(path):
		_sprite.texture = load(path)
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _update_fire_layer() -> void:
	if not _fire:
		_fire = get_node_or_null("Fire")
	if not _fire:
		return
	# Behind = negative z_index, in front = positive
	_fire.z_index = -1 if fire_behind else 1

func _auto_fire_layer() -> void:
	## Front-facing directions: statue is "closer" so fire goes behind.
	## Back-facing directions: statue faces away so fire shows in front.
	var behind_directions = ["front", "front_right", "front_left"]
	fire_behind = direction in behind_directions

func _setup_gem_animation() -> void:
	if not _gem_sprite:
		return
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("glow")
	frames.set_animation_speed("glow", 8.0)
	frames.set_animation_loop("glow", true)

	for i in range(GEM_FRAME_COUNT):
		var path = GEM_PATH % i
		if ResourceLoader.exists(path):
			frames.add_frame("glow", load(path))

	_gem_sprite.sprite_frames = frames
	_gem_sprite.animation = "glow"

func _update_fire_visibility() -> void:
	if not _fire:
		_fire = get_node_or_null("Fire")
	if not _fire:
		return
	_fire.visible = fire_lit
	if fire_lit:
		if _fire.has_method("play_fire"):
			_fire.play_fire()
	else:
		if _fire.has_method("stop"):
			_fire.stop()

func light_fire() -> void:
	fire_lit = true

func extinguish_fire() -> void:
	fire_lit = false

func toggle_fire() -> void:
	fire_lit = not fire_lit

## Called when player burns a golden ticket at this statue.
func burn_ticket() -> void:
	ticket_burned = true
	if _gem_sprite:
		_gem_sprite.visible = true
		_gem_sprite.play("glow")

## Check if the correct ticket was burned in the right order.
func is_correct_offering(expected_index: int) -> bool:
	return ticket_burned and statue_id == expected_index
