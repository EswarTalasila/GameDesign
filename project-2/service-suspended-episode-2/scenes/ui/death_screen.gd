extends CanvasLayer

signal reload_requested
signal respawn_requested

@onready var death_anim: AnimatedSprite2D = $DeathAnim
@onready var reload_btn: TextureButton = $ReloadButton
@onready var respawn_btn: TextureButton = $RespawnButton

var _reload_tex = [
	preload("res://assets/ui/reload_button/frame_0.png"),
	preload("res://assets/ui/reload_button/frame_1.png"),
	preload("res://assets/ui/reload_button/frame_2.png"),
]
var _respawn_tex = [
	preload("res://assets/ui/respawn_button/frame_0.png"),
	preload("res://assets/ui/respawn_button/frame_1.png"),
	preload("res://assets/ui/respawn_button/frame_2.png"),
]

func _ready() -> void:
	var viewport_size = get_viewport().get_visible_rect().size

	death_anim.position = viewport_size / 2
	death_anim.modulate = Color(1, 1, 1, 0)

	# Reload button (free restart)
	reload_btn.texture_normal = _reload_tex[0]
	reload_btn.texture_hover = _reload_tex[1]
	reload_btn.texture_pressed = _reload_tex[2]

	# Respawn button (costs a ticket)
	respawn_btn.texture_normal = _respawn_tex[0]
	respawn_btn.texture_hover = _respawn_tex[1]
	respawn_btn.texture_pressed = _respawn_tex[2]

	# Position both buttons side by side, centered
	var scale_factor = 4.0
	var reload_w = _reload_tex[0].get_size().x * scale_factor
	var respawn_w = _respawn_tex[0].get_size().x * scale_factor
	var gap = 24.0
	var total_w = reload_w + gap + respawn_w
	var start_x = (viewport_size.x - total_w) / 2
	var btn_y = viewport_size.y * 0.65

	reload_btn.scale = Vector2(scale_factor, scale_factor)
	reload_btn.position = Vector2(start_x, btn_y)
	reload_btn.modulate = Color(1, 1, 1, 0)

	respawn_btn.scale = Vector2(scale_factor, scale_factor)
	respawn_btn.position = Vector2(start_x + reload_w + gap, btn_y)
	respawn_btn.modulate = Color(1, 1, 1, 0)

	reload_btn.pressed.connect(_on_reload_pressed)
	respawn_btn.pressed.connect(_on_respawn_pressed)

	_play_intro()

func _play_intro() -> void:
	death_anim.play("death")

	var tween = create_tween()
	tween.tween_property(death_anim, "modulate:a", 1.0, 1.0)
	tween.tween_interval(0.5)
	tween.tween_callback(func():
		reload_btn.visible = true
		respawn_btn.visible = true
		var btn_tween = create_tween().set_parallel(true)
		btn_tween.tween_property(reload_btn, "modulate:a", 1.0, 0.5)
		btn_tween.tween_property(respawn_btn, "modulate:a", 1.0, 0.5)
	)

func _fade_out() -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(death_anim, "modulate:a", 0.0, 0.5)
	tween.tween_property(reload_btn, "modulate:a", 0.0, 0.5)
	tween.tween_property(respawn_btn, "modulate:a", 0.0, 0.5)
	tween.tween_property($Background, "color:a", 0.0, 0.5)
	await tween.finished

func _on_reload_pressed() -> void:
	reload_btn.disabled = true
	respawn_btn.disabled = true
	await _fade_out()
	reload_requested.emit()

func _on_respawn_pressed() -> void:
	reload_btn.disabled = true
	respawn_btn.disabled = true
	await _fade_out()
	respawn_requested.emit()
