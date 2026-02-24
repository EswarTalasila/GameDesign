extends Node2D

@onready var puncher: TextureButton = $CanvasLayer/Puncher
@onready var ticket: Sprite2D = $CanvasLayer/Ticket

var tex_open: Texture2D = preload("res://assets/ui/Hole_Punch_UI_Opened.png")
var tex_closed: Texture2D = preload("res://assets/ui/Hole_Punch_UI_Closed.png")
var is_busy: bool = false

func _ready() -> void:
	ticket.visible = false
	puncher.texture_normal = tex_open
	puncher.pressed.connect(_on_puncher_pressed)

func _on_puncher_pressed() -> void:
	if is_busy:
		return
	is_busy = true

	# Punch animation - close the puncher
	puncher.texture_normal = tex_closed
	await get_tree().create_timer(0.3).timeout

	# Open the puncher back up
	puncher.texture_normal = tex_open

	# Show the ticket in the center
	ticket.visible = true
	ticket.modulate = Color.WHITE
	ticket.material.set_shader_parameter("radius", 0.0)
	ticket.material.set_shader_parameter("position", Vector2(0.5, 0.5))

	# Brief pause to see the ticket
	await get_tree().create_timer(0.8).timeout

	# Burn it away from center
	var tween = create_tween()
	tween.tween_method(_set_burn_radius, 0.0, 2.0, 1.5)
	await tween.finished

	ticket.visible = false
	is_busy = false

func _set_burn_radius(value: float) -> void:
	ticket.material.set_shader_parameter("radius", value)
