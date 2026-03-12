extends CanvasLayer

signal resume_requested
signal restart_requested
signal quit_requested

@onready var background: ColorRect = $Background
@onready var clipboard_sprite: Sprite2D = $ClipboardSprite
@onready var resume_btn: Sprite2D = $ResumeButton
@onready var restart_btn: Sprite2D = $RestartButton
@onready var quit_btn: Sprite2D = $QuitButton
@onready var resume_area: Area2D = $ResumeButton/ResumeArea
@onready var restart_area: Area2D = $RestartButton/RestartArea
@onready var quit_area: Area2D = $QuitButton/QuitArea
@onready var mute_btn: Sprite2D = $MuteButton
@onready var mute_area: Area2D = $MuteButton/MuteArea

var _mute_unmute_tex = preload("res://assets/ui/buttons/mute_unmute.png")
var _mute_muted_tex = preload("res://assets/ui/buttons/mute_muted.png")

# Normal / hover / clicked textures per button
var _resume_tex = [
	preload("res://assets/ui/buttons/play/normal.png"),
	preload("res://assets/ui/buttons/play/hover.png"),
	preload("res://assets/ui/buttons/play/clicked.png"),
]
var _restart_tex = [
	preload("res://assets/ui/buttons/reload/normal.png"),
	preload("res://assets/ui/buttons/reload/hover.png"),
	preload("res://assets/ui/buttons/reload/clicked.png"),
]
var _quit_tex = [
	preload("res://assets/ui/buttons/exit/normal.png"),
	preload("res://assets/ui/buttons/exit/hover.png"),
	preload("res://assets/ui/buttons/exit/clicked.png"),
]

var _resume_tooltip: Label
var _restart_tooltip: Label
var _quit_tooltip: Label
var _mute_tooltip: Label

var _btn_hover_sound = preload("res://assets/sounds/button_hover.mp3")
var _btn_click_sound = preload("res://assets/sounds/button_click.mp3")
var _hover_player: AudioStreamPlayer
var _click_player: AudioStreamPlayer

var _disabled: bool = false

func _ready() -> void:
	# Background starts transparent
	background.color = Color(0, 0, 0, 0)

	# Everything starts invisible for fade-in
	clipboard_sprite.modulate = Color(1, 1, 1, 0)
	resume_btn.modulate = Color(1, 1, 1, 0)
	restart_btn.modulate = Color(1, 1, 1, 0)
	quit_btn.modulate = Color(1, 1, 1, 0)

	# Tooltips to the right of the clipboard
	_resume_tooltip = _create_tooltip("Resume", resume_btn)
	_restart_tooltip = _create_tooltip("Restart Floor\nResets tickets & keys", restart_btn)
	_quit_tooltip = _create_tooltip("Quit Game", quit_btn)
	_mute_tooltip = _create_tooltip("Toggle Mute", mute_btn)

	# Button sounds
	_hover_player = AudioStreamPlayer.new()
	_hover_player.stream = _btn_hover_sound
	add_child(_hover_player)
	_click_player = AudioStreamPlayer.new()
	_click_player.stream = _btn_click_sound
	add_child(_click_player)

	# Mute button — sync with current state
	mute_btn.modulate = Color(1, 1, 1, 0)
	_update_mute_texture()

	_play_intro()

var _hovered: int = -1  # -1=none, 0=resume, 1=restart, 2=quit

func _process(_delta: float) -> void:
	if _disabled:
		return
	var mouse = get_viewport().get_mouse_position()
	var new_hover = -1
	if _is_in_area(mouse, resume_btn, resume_area):
		new_hover = 0
	elif _is_in_area(mouse, restart_btn, restart_area):
		new_hover = 1
	elif _is_in_area(mouse, quit_btn, quit_area):
		new_hover = 2
	elif _is_in_area(mouse, mute_btn, mute_area):
		new_hover = 3

	if new_hover != _hovered:
		# Unhover old
		_set_hover(_hovered, false)
		# Hover new
		_set_hover(new_hover, true)
		_hovered = new_hover

func _set_hover(idx: int, hovered: bool) -> void:
	if idx == 3:
		_mute_tooltip.visible = hovered
		if hovered and _hover_player:
			_hover_player.play()
		return
	var btn: Sprite2D
	var tex: Array
	var tooltip: Label
	match idx:
		0: btn = resume_btn; tex = _resume_tex; tooltip = _resume_tooltip
		1: btn = restart_btn; tex = _restart_tex; tooltip = _restart_tooltip
		2: btn = quit_btn; tex = _quit_tex; tooltip = _quit_tooltip
		_: return
	btn.texture = tex[1] if hovered else tex[0]
	tooltip.visible = hovered
	if hovered and _hover_player:
		_hover_player.play()

func _create_tooltip(text: String, btn: Sprite2D) -> Label:
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.8))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.visible = false
	add_child(label)
	var clipboard_right = clipboard_sprite.position.x + clipboard_sprite.texture.get_size().x * clipboard_sprite.scale.x / 2
	label.position = Vector2(clipboard_right + 20, btn.position.y - 16)
	label.custom_minimum_size = Vector2(320, 0)
	return label

func _play_intro() -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(background, "color:a", 0.6, 0.3)
	tween.tween_property(clipboard_sprite, "modulate:a", 1.0, 0.3)
	tween.tween_property(resume_btn, "modulate:a", 1.0, 0.3)
	tween.tween_property(restart_btn, "modulate:a", 1.0, 0.3)
	tween.tween_property(quit_btn, "modulate:a", 1.0, 0.3)
	tween.tween_property(mute_btn, "modulate:a", 1.0, 0.3)

func _fade_out() -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(background, "color:a", 0.0, 0.3)
	tween.tween_property(clipboard_sprite, "modulate:a", 0.0, 0.3)
	tween.tween_property(resume_btn, "modulate:a", 0.0, 0.3)
	tween.tween_property(restart_btn, "modulate:a", 0.0, 0.3)
	tween.tween_property(quit_btn, "modulate:a", 0.0, 0.3)
	tween.tween_property(mute_btn, "modulate:a", 0.0, 0.3)
	await tween.finished

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_resume_pressed()

	# Click detection via mouse position vs Area2D
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not _disabled:
		var click = get_viewport().get_mouse_position()
		if _is_in_area(click, resume_btn, resume_area):
			_click_player.play()
			resume_btn.texture = _resume_tex[2]
			_on_resume_pressed()
		elif _is_in_area(click, restart_btn, restart_area):
			_click_player.play()
			restart_btn.texture = _restart_tex[2]
			_on_restart_pressed()
		elif _is_in_area(click, quit_btn, quit_area):
			_click_player.play()
			quit_btn.texture = _quit_tex[2]
			_on_quit_pressed()
		elif _is_in_area(click, mute_btn, mute_area):
			_click_player.play()
			_on_mute_pressed()

func _is_in_area(click: Vector2, btn: Sprite2D, area: Area2D) -> bool:
	var col = area.get_child(0) as CollisionShape2D
	var shape = col.shape as RectangleShape2D
	var center = btn.global_position
	var half = shape.size * btn.scale / 2
	return Rect2(center - half, shape.size * btn.scale).has_point(click)

func _on_resume_pressed() -> void:
	_disabled = true
	await _fade_out()
	resume_requested.emit()

func _on_restart_pressed() -> void:
	_disabled = true
	await _fade_out()
	restart_requested.emit()

func _on_quit_pressed() -> void:
	_disabled = true
	await _fade_out()
	quit_requested.emit()

func _on_mute_pressed() -> void:
	GameState.toggle_mute()
	_update_mute_texture()

func _update_mute_texture() -> void:
	mute_btn.texture = _mute_muted_tex if GameState.muted else _mute_unmute_tex
