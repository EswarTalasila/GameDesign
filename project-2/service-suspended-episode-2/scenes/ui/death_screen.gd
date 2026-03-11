extends CanvasLayer

signal reload_requested
signal respawn_requested

@onready var death_anim: AnimatedSprite2D = $DeathAnim
@onready var reload_btn: TextureButton = $ReloadButton
@onready var respawn_btn: TextureButton = $RespawnButton

var _reload_tex = [
	preload("res://assets/ui/buttons/reload/normal.png"),
	preload("res://assets/ui/buttons/reload/hover.png"),
	preload("res://assets/ui/buttons/reload/clicked.png"),
]
var _respawn_tex = [
	preload("res://assets/ui/buttons/respawn/normal.png"),
	preload("res://assets/ui/buttons/respawn/hover.png"),
	preload("res://assets/ui/buttons/respawn/clicked.png"),
]

var _game_over_music = preload("res://assets/sounds/game_over.mp3")
var _btn_hover_sound = preload("res://assets/sounds/button_hover.mp3")
var _btn_click_sound = preload("res://assets/sounds/button_click.mp3")

var _music_player: AudioStreamPlayer
var _hover_player: AudioStreamPlayer
var _click_player: AudioStreamPlayer

var _reload_tooltip: Label
var _respawn_tooltip: Label

func _ready() -> void:
	var viewport_size = get_viewport().get_visible_rect().size

	death_anim.position = viewport_size / 2
	death_anim.modulate = Color(1, 1, 1, 0)

	# Reload button (free restart)
	reload_btn.texture_normal = _reload_tex[0]
	reload_btn.texture_hover = _reload_tex[1]
	reload_btn.texture_pressed = _reload_tex[2]
	reload_btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# Respawn button (costs a ticket)
	respawn_btn.texture_normal = _respawn_tex[0]
	respawn_btn.texture_hover = _respawn_tex[1]
	respawn_btn.texture_pressed = _respawn_tex[2]
	respawn_btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

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

	# Hover tooltips
	_reload_tooltip = _create_tooltip("Reload the floor\nFree - resets tickets & keys", reload_btn)
	_respawn_tooltip = _create_tooltip("Respawn at checkpoint\nCosts 3 tickets", respawn_btn)

	reload_btn.mouse_entered.connect(func(): _reload_tooltip.visible = true)
	reload_btn.mouse_exited.connect(func(): _reload_tooltip.visible = false)
	respawn_btn.mouse_entered.connect(func(): _respawn_tooltip.visible = true)
	respawn_btn.mouse_exited.connect(func(): _respawn_tooltip.visible = false)

	reload_btn.pressed.connect(_on_reload_pressed)
	respawn_btn.pressed.connect(_on_respawn_pressed)

	# Button sounds
	_hover_player = AudioStreamPlayer.new()
	_hover_player.stream = _btn_hover_sound
	add_child(_hover_player)
	_click_player = AudioStreamPlayer.new()
	_click_player.stream = _btn_click_sound
	add_child(_click_player)
	reload_btn.mouse_entered.connect(func(): _hover_player.play())
	respawn_btn.mouse_entered.connect(func(): _hover_player.play())

	# Game over music
	_music_player = AudioStreamPlayer.new()
	_music_player.stream = _game_over_music
	add_child(_music_player)
	_music_player.finished.connect(_music_player.play)
	_music_player.play()

	_play_intro()

func _create_tooltip(text: String, btn: TextureButton) -> Label:
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.8))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.visible = false
	add_child(label)
	# Position below the button
	var btn_h = btn.texture_normal.get_size().y * btn.scale.y
	var btn_center_x = btn.position.x + btn.texture_normal.get_size().x * btn.scale.x / 2
	label.position = Vector2(btn_center_x - 160, btn.position.y + btn_h + 8)
	label.custom_minimum_size = Vector2(320, 0)
	return label

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
	tween.tween_property(_music_player, "volume_db", -40.0, 0.5)
	await tween.finished

func _on_reload_pressed() -> void:
	_click_player.play()
	reload_btn.disabled = true
	respawn_btn.disabled = true
	reload_requested.emit()

func _on_respawn_pressed() -> void:
	_click_player.play()
	reload_btn.disabled = true
	respawn_btn.disabled = true
	respawn_requested.emit()
