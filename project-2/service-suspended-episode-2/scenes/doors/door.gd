extends Node2D

@export var closed_texture: AtlasTexture
@export var open_texture: AtlasTexture

var _open: bool = false
var _player_nearby: bool = false

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _body_col: CollisionShape2D = $StaticBody2D/CollisionShape2D
@onready var _prompt: Label = $Area2D/Label

func _ready() -> void:
	$Area2D.body_entered.connect(_on_zone_entered)
	$Area2D.body_exited.connect(_on_zone_exited)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _player_nearby and not _open:
		_open_door()

func _on_zone_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player_nearby = true
		if not _open:
			_prompt.visible = true

func _on_zone_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player_nearby = false
		_prompt.visible = false

func _open_door() -> void:
	_open = true
	_prompt.visible = false
	_sprite.texture = open_texture
	_body_col.set_deferred("disabled", true)
