extends Node2D

@export var stackable: bool = false

@onready var base: Sprite2D = $Base

func _ready() -> void:
	base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func is_stackable() -> bool:
	return stackable
