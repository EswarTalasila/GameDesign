extends Node2D

# Train coordinator — lighter version of floor.gd for the train hub scenes.
# Manages section spawning by cart_index, NPC visibility, connector interactions,
# dimmed inventory UI, train audio, pause menu, and cursor management.
# Attach to the root Node2D of train.tscn.
# Expected child structure:
#   GameWorld (Node2D, y_sort_enabled)
#     Sections/Section1, Section2 (each with a train_section instance)
#     Player
#   Connectors (Node2D)
#     DungeonConnector (Area2D, meta "target" = "dungeon")
#     ConductorConnector (Area2D, meta "target" = "conductor")
#   GameUI (instance of game_ui.tscn — UILayer + CursorLayer)

# --- Spawn positions (set per-scene in inspector) ---
@export var section_1_spawn: Vector2 = Vector2(71, 56)
@export var section_2_spawn: Vector2 = Vector2(1018, 56)

# --- Default cursor textures ---
var _cursor_default = preload("res://assets/ui/cursor/frame_1.png")
var _cursor_clicked = preload("res://assets/ui/cursor/frame_0.png")

# --- Play/pause HUD textures ---
var _pause_normal = preload("res://assets/ui/buttons/play_pause/pause_normal.png")
var _pause_pressed = preload("res://assets/ui/buttons/play_pause/pause_pressed.png")
var _play_normal = preload("res://assets/ui/buttons/play_pause/play_normal.png")

# --- Train audio ---
var _train_sounds_stream = preload("res://assets/sounds/train_sounds.mp3")
var _train_ambience_stream = preload("res://assets/sounds/train_ambience.mp3")
var _train_ambience_stream_2 = preload("res://assets/sounds/train_ambience_2.mp3")
var _door_transition_stream = preload("res://assets/sounds/train_door_transition.mp3")

# --- Nodes ---
@onready var player: CharacterBody2D = $GameWorld/Player
@onready var punch_slot: Sprite2D = $GameUI/UILayer/InventoryPanel/PunchSlot
@onready var ticket_slot: Sprite2D = $GameUI/UILayer/InventoryPanel/TicketSlot
@onready var key_slot: Sprite2D = $GameUI/UILayer/InventoryPanel/KeySlot
@onready var special_slot: Sprite2D = $GameUI/UILayer/InventoryPanel/SpecialSlot
@onready var pause_slot: Sprite2D = $GameUI/UILayer/InventoryPanel/PauseSlot
@onready var cursor_sprite: Sprite2D = $GameUI/CursorLayer/CursorSprite

# --- State ---
var _paused: bool = false
var _transitioning: bool = false

# --- Connector tracking ---
var _active_connector: Area2D = null  # connector the player is currently inside
var _connector_prompts: Dictionary = {}  # Area2D -> PressEPrompt node


func _ready() -> void:
	_disable_autoload_cursor()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	# Hide objective panel (only shown in dungeon)
	var obj_panel = $GameUI/UILayer.get_node_or_null("ObjectivePanel")
	if obj_panel:
		obj_panel.visible = false

	# Cursor setup
	cursor_sprite.texture = _cursor_default
	cursor_sprite.centered = false
	cursor_sprite.scale = Vector2(1, 1)
	cursor_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# Determine spawn section from GameState.current_cart_index
	var cart_index = GameState.current_cart_index
	var sections_node = $GameWorld/Sections

	if cart_index == 0:
		# Spawn in Section 1
		player.global_position = section_1_spawn
		_remove_npcs_from_section(sections_node.get_node_or_null("Section2"))
	else:
		# Spawn in Section 2
		player.global_position = section_2_spawn
		_remove_npcs_from_section(sections_node.get_node_or_null("Section1"))

	# Set checkpoint at spawn position
	GameState.set_checkpoint(player.global_position, "train")

	# Dim inventory slots (visible but non-interactive, 0.4 alpha)
	_dim_inventory_slots()

	# Setup connectors (Area2D children under Connectors node)
	_setup_connectors()

	# Train audio: subtle mechanical sounds (looping, -18dB)
	var train_sfx = AudioStreamPlayer.new()
	train_sfx.stream = _train_sounds_stream
	train_sfx.volume_db = -18.0
	train_sfx.name = "TrainSounds"
	add_child(train_sfx)
	train_sfx.finished.connect(train_sfx.play)
	train_sfx.play()

	# Train ambience (looping, randomly pick track, ~15% quieter)
	var ambience = AudioStreamPlayer.new()
	ambience.stream = [_train_ambience_stream, _train_ambience_stream_2].pick_random()
	ambience.name = "TrainAmbience"
	ambience.volume_db = -8.0
	add_child(ambience)
	ambience.finished.connect(ambience.play)
	ambience.play()


func _input(event: InputEvent) -> void:
	if _paused:
		return

	# Cursor click feedback (default cursor only — no punch/key modes on train)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			cursor_sprite.texture = _cursor_clicked
		else:
			cursor_sprite.texture = _cursor_default

	# Left-click on pause slot
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var click = get_viewport().get_mouse_position()
		if _is_click_on_slot(click, pause_slot):
			_on_pause_slot_pressed()

	# Interact key (E) for connectors
	if event.is_action_pressed("interact"):
		if _active_connector:
			_use_connector(_active_connector)

	# Escape opens pause menu
	if event.is_action_pressed("ui_cancel"):
		_open_pause_menu()


# ── NPC management ──

func _remove_npcs_from_section(section_container: Node) -> void:
	# Remove Lady in Red (or any NPC with _start_dialogue) from a section container.
	# The section container holds the section instance as a child.
	if not section_container:
		return
	var npcs_to_remove: Array[Node] = []
	_find_dialogue_npcs(section_container, npcs_to_remove)
	for npc in npcs_to_remove:
		npc.queue_free()


func _find_dialogue_npcs(node: Node, results: Array[Node]) -> void:
	# Recursively find CharacterBody2D children that have the _start_dialogue method.
	if node is CharacterBody2D and node.has_method("_start_dialogue"):
		results.append(node)
	for child in node.get_children():
		_find_dialogue_npcs(child, results)


# ── Dimmed inventory ──

func _dim_inventory_slots() -> void:
	# Make punch/ticket/key/special slots visible but grayed out and unclickable.
	# Pause slot remains fully visible and interactive.
	var dimmed_alpha = Color(1.0, 1.0, 1.0, 0.4)
	punch_slot.modulate = dimmed_alpha
	ticket_slot.modulate = dimmed_alpha
	key_slot.modulate = dimmed_alpha
	special_slot.modulate = dimmed_alpha


# ── Connector interactions ──

func _setup_connectors() -> void:
	var connectors_node = get_node_or_null("Connectors")
	if not connectors_node:
		return
	for child in connectors_node.get_children():
		if child is Area2D:
			# Find the PressEPrompt child (could be named PressEPrompt or similar)
			var prompt = _find_press_e_prompt(child)
			if prompt:
				prompt.visible = false
				_connector_prompts[child] = prompt
			child.body_entered.connect(_on_connector_body_entered.bind(child))
			child.body_exited.connect(_on_connector_body_exited.bind(child))


func _find_press_e_prompt(connector: Area2D) -> Node:
	# Look for a child named "PressEPrompt" (Sprite2D or Label)
	for child in connector.get_children():
		if child.name == "PressEPrompt":
			return child
	return null


func _on_connector_body_entered(body: Node2D, connector: Area2D) -> void:
	if body == player:
		_active_connector = connector
		var prompt = _connector_prompts.get(connector)
		if prompt:
			prompt.visible = true


func _on_connector_body_exited(body: Node2D, connector: Area2D) -> void:
	if body == player and _active_connector == connector:
		_active_connector = null
		var prompt = _connector_prompts.get(connector)
		if prompt:
			prompt.visible = false


func _use_connector(connector: Area2D) -> void:
	if _transitioning:
		return
	_transitioning = true
	var target = connector.get_meta("target", "dungeon")

	# Play door transition sound
	var sfx = AudioStreamPlayer.new()
	sfx.stream = _door_transition_stream
	add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)

	# Disable player immediately
	player.set_physics_process(false)
	player.visible = false
	player.collision_layer = 0
	player.collision_mask = 0

	# Hide the prompt
	var prompt = _connector_prompts.get(connector)
	if prompt:
		prompt.visible = false

	var loading_screen = preload("res://scenes/ui/loading_screen.tscn").instantiate()
	get_tree().root.add_child(loading_screen)

	match target:
		"dungeon":
			# Start a dungeon run: cart_index 0, standard, 5 tickets
			GameState.start_dungeon(0, "standard", 5)
			loading_screen.transition_to("res://scenes/floors/floor_1/floor_1.tscn")
		"conductor":
			loading_screen.transition_to("res://scenes/train/conductor hub.tscn")
		_:
			push_warning("Unknown connector target: " + str(target))
			loading_screen.transition_to("res://scenes/train/conductor hub.tscn")


# ── Inventory slot click detection ──

func _is_click_on_slot(click_pos: Vector2, slot: Sprite2D) -> bool:
	var slot_screen = slot.get_global_transform_with_canvas().origin
	return click_pos.distance_to(slot_screen) < 40.0


# ── Pause menu ──

func _on_pause_slot_pressed() -> void:
	pause_slot.texture = _pause_pressed
	await get_tree().create_timer(0.1).timeout
	_open_pause_menu()


func _open_pause_menu() -> void:
	_paused = true
	pause_slot.texture = _play_normal
	get_tree().paused = true
	var menu = preload("res://scenes/ui/pause_menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	menu.resume_requested.connect(_on_pause_resume.bind(menu))
	menu.restart_requested.connect(_on_pause_restart.bind(menu))
	menu.quit_requested.connect(_on_pause_quit.bind(menu))


func _on_pause_resume(menu: CanvasLayer) -> void:
	menu.queue_free()
	get_tree().paused = false
	_paused = false
	pause_slot.texture = _pause_normal


func _on_pause_restart(menu: CanvasLayer) -> void:
	# Restart reloads the train scene (free, no ticket cost)
	menu.queue_free()
	get_tree().paused = false
	_paused = false
	var loading_screen = preload("res://scenes/ui/loading_screen.tscn").instantiate()
	get_tree().root.add_child(loading_screen)
	loading_screen.transition_to("res://scenes/train/train.tscn")


func _on_pause_quit(menu: CanvasLayer) -> void:
	menu.queue_free()
	get_tree().paused = false
	get_tree().quit()


# ── Cursor management ──

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
	# Restore autoload cursor when leaving this scene
	if has_node("/root/CustomCursor"):
		var cc = get_node("/root/CustomCursor")
		cc.set_process(true)
		cc.set_process_input(true)
		for child in cc.get_children():
			if child is CanvasLayer:
				for grandchild in child.get_children():
					if grandchild is Sprite2D:
						grandchild.visible = true
