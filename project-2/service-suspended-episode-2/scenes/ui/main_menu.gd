extends Control

@onready var _bg: TextureRect = $Background
@onready var _exit_region: Control = $ExitRegion
@onready var _play_region: Control = $PlayRegion
@onready var _music: AudioStreamPlayer = $Music
@onready var _hover_sound: AudioStreamPlayer = $HoverSound
@onready var _click_sound: AudioStreamPlayer = $ClickSound

var _base_tex := preload("res://assets/ui/screens/main_menu_base.png")
var _hover_exit_tex := preload("res://assets/ui/screens/main_menu_hover_exit.png")
var _clicked_exit_tex := preload("res://assets/ui/screens/main_menu_clicked_exit.png")
var _hover_play_tex := preload("res://assets/ui/screens/main_menu_hover_play.png")
var _clicked_play_tex := preload("res://assets/ui/screens/main_menu_clicked_play.png")

var _hovered: String = ""
var _hold_tween: Tween = null


func _ready() -> void:
	_bg.texture = _base_tex
	_music.finished.connect(_music.play)
	_exit_region.mouse_entered.connect(_on_exit_hover)
	_exit_region.mouse_exited.connect(_on_exit_unhover)
	_exit_region.gui_input.connect(_on_exit_input)
	_play_region.mouse_entered.connect(_on_play_hover)
	_play_region.mouse_exited.connect(_on_play_unhover)
	_play_region.gui_input.connect(_on_play_input)


func _on_exit_hover() -> void:
	_cancel_hold()
	_hovered = "exit"
	_bg.texture = _hover_exit_tex
	_hover_sound.play()


func _on_exit_unhover() -> void:
	_hovered = ""
	_hover_sound.stop()
	_hold_then_base()


func _on_exit_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_bg.texture = _clicked_exit_tex
		_click_sound.play()
		await get_tree().create_timer(0.15).timeout
		get_tree().quit()


func _on_play_hover() -> void:
	_cancel_hold()
	_hovered = "play"
	_bg.texture = _hover_play_tex
	_hover_sound.play()


func _on_play_unhover() -> void:
	_hovered = ""
	_hover_sound.stop()
	_hold_then_base()


func _on_play_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_bg.texture = _clicked_play_tex
		_click_sound.play()
		GameState.reset()
		await get_tree().create_timer(0.15).timeout
		get_tree().change_scene_to_file("res://scenes/train/train.tscn")


func _hold_then_base() -> void:
	_cancel_hold()
	_hold_tween = create_tween()
	_hold_tween.tween_callback(func(): _bg.texture = _base_tex).set_delay(0.15)


func _cancel_hold() -> void:
	if _hold_tween and _hold_tween.is_valid():
		_hold_tween.kill()
	_hold_tween = null
