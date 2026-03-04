extends Node2D

@export var state_textures: Array[AtlasTexture] = []

var _state: int = 0
var _player_nearby: bool = false

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _prompt: Label = $Area2D/Label

func _ready() -> void:
	if state_textures.size() > 0:
		_sprite.texture = state_textures[0]
	$Area2D.body_entered.connect(_on_zone_entered)
	$Area2D.body_exited.connect(_on_zone_exited)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _player_nearby:
		_cycle()

func _on_zone_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player_nearby = true
		_prompt.visible = true

func _on_zone_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player_nearby = false
		_prompt.visible = false

func _cycle() -> void:
	_state = (_state + 1) % state_textures.size()
	_sprite.texture = state_textures[_state]
