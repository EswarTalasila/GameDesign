extends Area2D

## Computer lock terminal. Press E to open. Type the code, hit Enter.

@export var code: String = "free"
@export var reward_piece_id: int = 3

@onready var _prompt: AnimatedSprite2D = $PressEPrompt

var _player_in_range: bool = false
var _ui_open: bool = false
var _ui_scene = preload("res://scenes/ui/computer_lock_ui.tscn")
var _ui: CanvasLayer = null
var _map_pickup_scene = preload("res://scenes/pickups/map_piece_pickup.tscn")
var _lore_item_scene = preload("res://scenes/interactables/lore_item.tscn")

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if GameState.computer_lock_solved:
		_prompt.visible = false

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" and not GameState.computer_lock_solved:
		_player_in_range = true
		_prompt.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		_player_in_range = false
		_prompt.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and not _ui_open and not GameState.computer_lock_solved and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_open_ui()

func _open_ui() -> void:
	_ui_open = true
	_prompt.visible = false
	get_tree().paused = true
	_ui = _ui_scene.instantiate()
	_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	_ui.code = code
	_ui.puzzle_closed.connect(_close_ui)
	_ui.puzzle_solved.connect(_on_solved)
	get_tree().root.add_child(_ui)

func _close_ui() -> void:
	_ui_open = false
	get_tree().paused = false
	if _ui:
		_ui.queue_free()
		_ui = null
	if _player_in_range and not GameState.computer_lock_solved:
		_prompt.visible = true

func _on_solved() -> void:
	GameState.computer_lock_solved = true
	_close_ui()
	if not GameState.has_map_piece(reward_piece_id):
		var pickup = _map_pickup_scene.instantiate()
		pickup.piece_id = reward_piece_id
		pickup.global_position = $RewardSpawn.global_position
		get_parent().add_child(pickup)
	if not GameState.has_lore("logbook_pages_4_6"):
		var lore = _lore_item_scene.instantiate()
		lore.lore_id = "logbook_pages_4_6"
		lore.lore_title = "Passenger Logbook (Pages 4–6)"
		lore.lore_body = "Page 4:\nThe transit authority attempted a formal audit in 1971. Three inspectors were sent to the sub-platform level. Two returned. The third was located six months later, working as a conductor on a line that doesn't appear on any official map. When they showed him his own name, he didn't recognize it.\n\nPage 5:\nI've been interviewing long-term passengers. All of them mention a woman. Red coat. She appears when you're lost. Gives advice. Tells you to hold onto something, something small, something specific. I asked each of them when they first saw her. Their answers span forty years. The description never changes. Not similar. Identical. Word for word, in some cases.\n\nPage 6:\nI found a photograph from the 1940s in the station archive. A crowded platform. In the background, at the very edge of the frame, a red coat. Same face. I am certain of it.\nThe photograph is over eighty years old.\nI showed it to one of the conductors. He went pale. He said: \"She was here before I was. She'll be here after.\" Then he walked away and wouldn't speak to me again.\nMy watch says March 14th. It has said March 14th for a very long time. I'm trying not to think about what that means."
		lore.global_position = $RewardSpawn.global_position + Vector2(32, 0)
		get_parent().add_child(lore)
	if not GameState.pa_computer_solved_played:
		GameState.pa_computer_solved_played = true
		GameState.request_pa("pa_computer_lock")
