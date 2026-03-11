extends Node2D

# Conductor hub cutscene controller — self-contained cinematic sequence.
# Player walks in from the left toward controls, turns around to face the door,
# conductor follows from the left, dialogue plays, fade to black, ending text, menu.
#
# Expected scene tree:
#   ConductorHub (Node2D) [this script]
#   ├── Background (ColorRect)
#   ├── GameWorld (Node2D, y_sort_enabled)
#   │   ├── TrainSection3 (instance)
#   │   ├── Player (instance of player.tscn)
#   │   └── Conductor (instance of conductor.tscn)
#   ├── GameUI (instance of game_ui.tscn)
#   └── CutsceneUI (CanvasLayer, layer=10)
#       ├── FadeOverlay (ColorRect, anchors full rect, Color(0,0,0,0))
#       └── EndingLabel (Label, centered, white text, hidden)

# --- Tunable positions (derived from editor placement at runtime) ---
var player_start: Vector2
var player_target: Vector2
var conductor_start: Vector2
var conductor_target: Vector2

# --- Default cursor textures (same as train.gd) ---
var _cursor_default = preload("res://assets/ui/cursor/frame_1.png")
var _cursor_clicked = preload("res://assets/ui/cursor/frame_0.png")

# --- Train audio ---
var _train_sounds_stream = preload("res://assets/sounds/train_sounds.mp3")
var _train_ambience_stream = preload("res://assets/sounds/train_ambience.mp3")
var _train_ambience_stream_2 = preload("res://assets/sounds/train_ambience_2.mp3")

# --- Dialogue ---
var _conductor_dialogue = preload("res://dialogues/conductor.dialogue")

# --- Nodes ---
@onready var player: CharacterBody2D = $GameWorld/Player
@onready var conductor: CharacterBody2D = $GameWorld/Conductor
@onready var fade_overlay: ColorRect = $CutsceneUI/FadeOverlay
@onready var ending_label: Label = $CutsceneUI/EndingLabel
@onready var punch_slot: Sprite2D = $GameUI/UILayer/InventoryPanel/PunchSlot
@onready var ticket_slot: Sprite2D = $GameUI/UILayer/InventoryPanel/TicketSlot
@onready var key_slot: Sprite2D = $GameUI/UILayer/InventoryPanel/KeySlot
@onready var special_slot: Sprite2D = $GameUI/UILayer/InventoryPanel/SpecialSlot
@onready var cursor_sprite: Sprite2D = $GameUI/CursorLayer/CursorSprite

# --- State ---
var _waiting_for_click: bool = false


func _ready() -> void:
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)

	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_disable_autoload_cursor()

	cursor_sprite.texture = _cursor_default
	cursor_sprite.centered = false
	cursor_sprite.scale = Vector2(1, 1)
	cursor_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_dim_inventory_slots()
	_start_train_audio()

	fade_overlay.modulate = Color(1, 1, 1, 0)
	ending_label.visible = false

	# Save editor positions as walk-to targets, then start off-screen left
	player_target = player.global_position
	conductor_target = conductor.global_position
	player.global_position = Vector2(-20, player_target.y)
	conductor.global_position = Vector2(-40, conductor_target.y)
	conductor.visible = false

	call_deferred("_start_cutscene")


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			cursor_sprite.texture = _cursor_clicked
		else:
			cursor_sprite.texture = _cursor_default

	if _waiting_for_click and event is InputEventMouseButton and event.pressed:
		_waiting_for_click = false
	if _waiting_for_click and event is InputEventKey and event.pressed:
		_waiting_for_click = false


# ── Main cutscene sequence ──

func _start_cutscene() -> void:
	await get_tree().create_timer(0.5).timeout

	# --- Player walks in from the left toward controls (east) ---
	var player_sprite: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
	player_sprite.play("walk_east")

	var player_tween = create_tween()
	player_tween.tween_property(player, "global_position", player_target, 1.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await player_tween.finished

	# Player stops, turns around to face back toward the door (west)
	player_sprite.play("idle_west")

	await get_tree().create_timer(0.5).timeout

	# --- Intercom plays before conductor appears ---
	DialogueManager.show_dialogue_balloon(_conductor_dialogue, "intercom")
	await DialogueManager.dialogue_ended

	await get_tree().create_timer(0.8).timeout

	# --- Conductor appears and follows from the left, walking east ---
	conductor.visible = true
	var conductor_sprite: AnimatedSprite2D = conductor.get_node("AnimatedSprite2D")
	conductor_sprite.play("walk_east")

	# Camera shake while conductor walks
	var cam: Camera2D = player.get_node("Camera2D")
	var shake_timer := Timer.new()
	shake_timer.wait_time = 0.05
	shake_timer.autostart = true
	add_child(shake_timer)
	shake_timer.timeout.connect(func():
		cam.offset = Vector2(randf_range(-1.5, 1.5), randf_range(-1.0, 1.0))
	)

	var conductor_tween = create_tween()
	conductor_tween.tween_property(conductor, "global_position", conductor_target, 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await conductor_tween.finished

	# Stop shake and reset camera
	shake_timer.stop()
	shake_timer.queue_free()
	cam.offset = Vector2.ZERO

	# Conductor stops facing east (toward player)
	conductor_sprite.play("idle_east")

	await get_tree().create_timer(0.3).timeout

	# --- Trigger conductor dialogue ---
	DialogueManager.show_dialogue_balloon(_conductor_dialogue, "start")
	await DialogueManager.dialogue_ended

	await get_tree().create_timer(0.5).timeout

	# --- Fade to black ---
	var fade_tween = create_tween()
	fade_tween.tween_property(fade_overlay, "modulate", Color(1, 1, 1, 1), 1.5)
	await fade_tween.finished

	await get_tree().create_timer(0.5).timeout

	# --- Ending text 1 ---
	ending_label.text = "The conductor locks you in a cart with no windows and seemingly no escape. Your service has been suspended."
	ending_label.visible = true
	await _wait_for_click()

	# --- Ending text 2 ---
	ending_label.text = "See you in Episode 3."
	await get_tree().create_timer(4.0).timeout

	await get_tree().create_timer(0.3).timeout

	# --- Return to main menu ---
	GameState.reset()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


# ── Wait for any click or key press ──

func _wait_for_click() -> void:
	_waiting_for_click = true
	while _waiting_for_click:
		await get_tree().process_frame


# ── Dimmed inventory (same as train.gd) ──

func _dim_inventory_slots() -> void:
	var dimmed_alpha = Color(1.0, 1.0, 1.0, 0.4)
	punch_slot.modulate = dimmed_alpha
	ticket_slot.modulate = dimmed_alpha
	key_slot.modulate = dimmed_alpha
	special_slot.modulate = dimmed_alpha


# ── Train audio (same as train.gd) ──

func _start_train_audio() -> void:
	var train_sfx = AudioStreamPlayer.new()
	train_sfx.stream = _train_sounds_stream
	train_sfx.volume_db = -18.0
	train_sfx.name = "TrainSounds"
	add_child(train_sfx)
	train_sfx.finished.connect(train_sfx.play)
	train_sfx.play()

	var ambience = AudioStreamPlayer.new()
	ambience.stream = [_train_ambience_stream, _train_ambience_stream_2].pick_random()
	ambience.name = "TrainAmbience"
	ambience.volume_db = -8.0
	add_child(ambience)
	ambience.finished.connect(ambience.play)
	ambience.play()


# ── Cursor management (same as train.gd) ──

func _disable_autoload_cursor() -> void:
	if has_node("/root/CustomCursor"):
		var cc = get_node("/root/CustomCursor")
		cc.set_process(false)
		cc.set_process_input(false)
		for child in cc.get_children():
			if child is CanvasLayer:
				for grandchild in child.get_children():
					if grandchild is Sprite2D:
						grandchild.visible = false


func _exit_tree() -> void:
	if has_node("/root/CustomCursor"):
		var cc = get_node("/root/CustomCursor")
		cc.set_process(true)
		cc.set_process_input(true)
		for child in cc.get_children():
			if child is CanvasLayer:
				for grandchild in child.get_children():
					if grandchild is Sprite2D:
						grandchild.visible = true
