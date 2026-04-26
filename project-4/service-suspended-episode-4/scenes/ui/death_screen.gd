extends CanvasLayer

signal reload_requested
signal exit_requested

const BOON_BUTTON_SCENE := preload("res://scenes/ui/boon_choice_button.tscn")
const BUTTON_FONT := preload("res://assets/fonts/DotGothic16-Regular.ttf")

const BUTTON_WIDTH := 248.0
const BUTTON_HEIGHT := 108.0
const BUTTON_GAP := 50.0
const BUTTON_SCALE := Vector2.ONE
const BUTTON_ROW_Y_RATIO := 0.65
const TOOLTIP_WIDTH := 360.0
const TOOLTIP_OFFSET_Y := 18.0

@onready var death_anim: AnimatedSprite2D = $DeathAnim

var _game_over_music = preload("res://assets/sounds/game_over.mp3")
var _btn_hover_sound = preload("res://assets/sounds/button_hover.mp3")
var _btn_click_sound = preload("res://assets/sounds/button_click.mp3")

var _music_player: AudioStreamPlayer
var _hover_player: AudioStreamPlayer
var _click_player: AudioStreamPlayer

var _reload_btn: TextureButton
var _exit_btn: TextureButton
var _reload_tooltip: Label
var _exit_tooltip: Label

func _ready() -> void:
	var viewport_size = get_viewport().get_visible_rect().size

	death_anim.position = viewport_size / 2
	death_anim.modulate = Color(1, 1, 1, 0)

	_hover_player = AudioStreamPlayer.new()
	_hover_player.stream = _btn_hover_sound
	add_child(_hover_player)

	_click_player = AudioStreamPlayer.new()
	_click_player.stream = _btn_click_sound
	add_child(_click_player)

	_music_player = AudioStreamPlayer.new()
	_music_player.stream = _game_over_music
	add_child(_music_player)
	_music_player.play()

	_build_buttons(viewport_size)
	_play_intro()

func _build_buttons(viewport_size: Vector2) -> void:
	var total_w := BUTTON_WIDTH * 2.0 + BUTTON_GAP
	var start_x := (viewport_size.x - total_w) / 2.0
	var btn_y := viewport_size.y * BUTTON_ROW_Y_RATIO

	_reload_btn = _create_boon_button("Reload")
	_reload_btn.position = Vector2(start_x, btn_y)
	add_child(_reload_btn)

	_exit_btn = _create_boon_button("Exit")
	_exit_btn.position = Vector2(start_x + BUTTON_WIDTH + BUTTON_GAP, btn_y)
	add_child(_exit_btn)

	_reload_tooltip = _create_tooltip(
		"Restart the run from the beginning.\nNo checkpoints.",
		_reload_btn
	)
	_exit_tooltip = _create_tooltip(
		"Return to the main menu.",
		_exit_btn
	)

	_reload_btn.mouse_entered.connect(func():
		_reload_tooltip.visible = true
		_hover_player.play()
	)
	_reload_btn.mouse_exited.connect(func(): _reload_tooltip.visible = false)
	_exit_btn.mouse_entered.connect(func():
		_exit_tooltip.visible = true
		_hover_player.play()
	)
	_exit_btn.mouse_exited.connect(func(): _exit_tooltip.visible = false)

	_reload_btn.pressed.connect(_on_reload_pressed)
	_exit_btn.pressed.connect(_on_exit_pressed)

func _create_boon_button(text: String) -> TextureButton:
	var button := BOON_BUTTON_SCENE.instantiate() as TextureButton
	button.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	button.scale = BUTTON_SCALE
	button.pressed_text_offset = Vector2.ZERO
	button.modulate = Color(1, 1, 1, 0)
	button.visible = false
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var label := button.get_node("TextRoot/Label") as Label
	label.text = text
	label.add_theme_font_override("font", BUTTON_FONT)
	label.add_theme_font_size_override("font_size", 30)
	return button

func _create_tooltip(text: String, btn: TextureButton) -> Label:
	var label := Label.new()
	label.text = text
	label.visible = false
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(TOOLTIP_WIDTH, 0)
	label.position = Vector2(
		btn.position.x + (BUTTON_WIDTH - TOOLTIP_WIDTH) / 2.0,
		btn.position.y + BUTTON_HEIGHT + TOOLTIP_OFFSET_Y
	)
	label.add_theme_font_override("font", BUTTON_FONT)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.8))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(label)
	return label

func _play_intro() -> void:
	death_anim.play("death")

	var tween := create_tween()
	tween.tween_property(death_anim, "modulate:a", 1.0, 1.0)
	tween.tween_interval(0.5)
	tween.tween_callback(func():
		_reload_btn.visible = true
		_exit_btn.visible = true
		var btn_tween := create_tween().set_parallel(true)
		btn_tween.tween_property(_reload_btn, "modulate:a", 1.0, 0.5)
		btn_tween.tween_property(_exit_btn, "modulate:a", 1.0, 0.5)
	)

func _on_reload_pressed() -> void:
	_click_player.play()
	_set_buttons_disabled(true)
	reload_requested.emit()

func _on_exit_pressed() -> void:
	_click_player.play()
	_set_buttons_disabled(true)
	exit_requested.emit()

func _set_buttons_disabled(disabled: bool) -> void:
	if _reload_btn:
		_reload_btn.disabled = disabled
	if _exit_btn:
		_exit_btn.disabled = disabled
