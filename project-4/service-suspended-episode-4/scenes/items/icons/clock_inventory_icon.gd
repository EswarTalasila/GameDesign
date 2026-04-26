extends Node2D

@export var stackable: bool = false
@export var default_texture: Texture2D
@export var active_texture: Texture2D

@onready var base: Sprite2D = $Base

func _ready() -> void:
	base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if GameState.clock_hands_inserted and active_texture != null:
		base.texture = active_texture
	elif default_texture != null:
		base.texture = default_texture

func is_stackable() -> bool:
	return stackable
