@tool
extends Node2D
class_name StoneRock

const STONE_TEXTURE_PATH := "res://assets/sprites/stone_puzzle/stones/%s_stone.png"
const PIECE_COLORS := {
	"black_1": "black",
	"black_2": "black",
	"red": "red",
	"yellow": "yellow",
	"green": "green",
	"blue": "blue",
	"purple": "purple",
	"white": "white",
}

@export_enum("black_1", "black_2", "red", "yellow", "green", "blue", "purple", "white")
var piece_id: String = "black_1":
	set(value):
		piece_id = value
		if rock_color.is_empty():
			rock_color = _get_color_for_piece(piece_id)
		_refresh_preview()

@export_enum("black", "red", "yellow", "green", "blue", "purple", "white")
var rock_color: String = "":
	set(value):
		rock_color = value
		_refresh_preview()

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	if rock_color.is_empty():
		rock_color = _get_color_for_piece(piece_id)
	_apply_visual()

func setup(new_piece_id: String) -> void:
	piece_id = new_piece_id
	rock_color = _get_color_for_piece(piece_id)
	_apply_visual()

func get_piece_color() -> String:
	return rock_color if not rock_color.is_empty() else _get_color_for_piece(piece_id)

func contains_global_point(point: Vector2) -> bool:
	if sprite == null or sprite.texture == null:
		return false
	var local_point := to_local(point)
	var size := sprite.texture.get_size() * sprite.scale
	var rect := Rect2(sprite.position - size * 0.5, size)
	return rect.has_point(local_point)

func set_selected(active: bool) -> void:
	if sprite == null:
		return
	sprite.modulate = Color(1.15, 1.15, 1.15, 1.0) if active else Color.WHITE

func _apply_visual() -> void:
	if sprite == null:
		return
	var color_name := get_piece_color()
	if color_name.is_empty():
		color_name = "black"
	var texture_path := STONE_TEXTURE_PATH % color_name
	if ResourceLoader.exists(texture_path):
		sprite.texture = load(texture_path)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _refresh_preview() -> void:
	if not is_node_ready():
		return
	_apply_visual()

func _get_color_for_piece(new_piece_id: String) -> String:
	return String(PIECE_COLORS.get(new_piece_id, "black"))
