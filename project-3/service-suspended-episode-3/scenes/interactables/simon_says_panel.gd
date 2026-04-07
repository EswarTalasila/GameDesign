extends Area2D

## Simon says panel. Press E to open. Two phases:
## Phase 1: Enter the key sequence (shown by door lights on room entry)
## Phase 2: Standard simon says with random sequences

@onready var _prompt: AnimatedSprite2D = $PressEPrompt

var _player_in_range: bool = false
var _ui_open: bool = false
var _simon_ui_scene = preload("res://scenes/ui/simon_says_ui.tscn")
var _simon_ui: CanvasLayer = null

const COLOR_TINTS = {
	"red": Vector3(0.8, 0.1, 0.1),
	"blue": Vector3(0.1, 0.1, 0.8),
	"green": Vector3(0.1, 0.8, 0.1),
	"black": Vector3(0.0, 0.0, 0.0),
}
const SIMON_VARIANT = 2

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if GameState.simon_solved:
		_prompt.visible = false
	if GameState.simon_key_sequence.size() == 0:
		var key = ["red", "blue", "green", "black"]
		key.shuffle()
		GameState.simon_key_sequence = key
	if not GameState.simon_solved and GameState.current_variant == SIMON_VARIANT:
		_start_light_loop()

func _start_light_loop() -> void:
	await get_tree().create_timer(5.0).timeout
	while is_inside_tree() and not GameState.simon_solved and GameState.current_variant == SIMON_VARIANT:
		if GameState.conductor_watching or _ui_open:
			await get_tree().create_timer(1.0).timeout
			continue
		await _flash_key_sequence()
		await get_tree().create_timer(8.0).timeout

func _flash_key_sequence() -> void:
	if GameState.current_variant != SIMON_VARIANT:
		return
	var player = get_tree().root.find_child("Player", true, false)
	if player == null:
		return
	var mat = player._vision_material
	if mat == null:
		return
	for color_name in GameState.simon_key_sequence:
		if not is_inside_tree() or GameState.current_variant != SIMON_VARIANT:
			_clear_light_tint(player, mat)
			return
		if color_name == "black":
			# Black = turn off the door light entirely
			player.lights_disabled = true
		else:
			var tint = COLOR_TINTS.get(color_name, Vector3.ZERO)
			mat.set_shader_parameter("light_tint", tint)
			mat.set_shader_parameter("light_tint_strength", 0.6)
		await get_tree().create_timer(0.6).timeout
		if not is_inside_tree() or GameState.current_variant != SIMON_VARIANT:
			_clear_light_tint(player, mat)
			return
		player.lights_disabled = false
		mat.set_shader_parameter("light_tint", Vector3.ZERO)
		mat.set_shader_parameter("light_tint_strength", 0.0)
		await get_tree().create_timer(0.3).timeout
	_clear_light_tint(player, mat)

func _clear_light_tint(player: Node, mat: ShaderMaterial) -> void:
	player.lights_disabled = false
	mat.set_shader_parameter("light_tint", Vector3.ZERO)
	mat.set_shader_parameter("light_tint_strength", 0.0)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" and not GameState.simon_solved:
		_player_in_range = true
		_prompt.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		_player_in_range = false
		_prompt.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and not _ui_open and not GameState.simon_solved and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_open_ui()

func _open_ui() -> void:
	_ui_open = true
	_prompt.visible = false
	get_tree().paused = true
	_simon_ui = _simon_ui_scene.instantiate()
	_simon_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	_simon_ui.puzzle_closed.connect(_close_ui)
	_simon_ui.puzzle_solved.connect(_on_solved)
	get_tree().root.add_child(_simon_ui)

func _close_ui() -> void:
	_ui_open = false
	get_tree().paused = false
	if _simon_ui:
		_simon_ui.queue_free()
		_simon_ui = null
	if _player_in_range and not GameState.simon_solved:
		_prompt.visible = true

var _map_pickup_scene = preload("res://scenes/pickups/map_piece_pickup.tscn")
var _lore_item_scene = preload("res://scenes/interactables/lore_item.tscn")

func _on_solved() -> void:
	GameState.simon_solved = true
	_close_ui()
	# Drop map piece 2 at the RewardSpawn marker position
	if not GameState.has_map_piece(2):
		var pickup = _map_pickup_scene.instantiate()
		pickup.piece_id = 2
		pickup.global_position = $RewardSpawn.global_position
		get_parent().add_child(pickup)
	if not GameState.has_lore("stamped_tickets"):
		var lore = _lore_item_scene.instantiate()
		lore.lore_id = "stamped_tickets"
		lore.lore_title = "Stamped Tickets (Impossible Dates)"
		lore.lore_body = "Three tickets, bundled together with a rusted clip. Each is stamped with the same route and passenger number. The dates are what stop you cold.\n\nRoute 4-7-2 | Passenger #0041 | March 14, 2007\nRoute 4-7-2 | Passenger #0041 | March 14, 1925\nRoute 4-7-2 | Passenger #0041 | March 14, 1853\n\nThe handwriting on each ticket is different. The stamp is identical. Same ink, same pressure. Like the machine never aged. Like it was used yesterday on all three.\n\nScrawled on the back of the oldest ticket in pencil: \"Same seat. Every time. I've started leaving this here so the next one knows.\""
		lore.global_position = $RewardSpawn.global_position + Vector2(32, 0)
		get_parent().add_child(lore)
