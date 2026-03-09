extends Node2D

# Dungeon coordinator — runs at level start, delegates to sub-systems.
# Currently unused (main_demo.tscn is the active scene).
# Kept as a skeleton for future dungeon scenes that need the same pattern.

@onready var enemy_markers: TileMapLayer = $EnemyMarkers
@onready var player: CharacterBody2D = $Entities/Player
@onready var enemies_container: Node2D = $Entities/Enemies
@onready var exit_door: Area2D = $Entities/ExitDoor
@onready var ticket_label: Label = $CanvasLayer/TicketCounter
@onready var dialog: PanelContainer = $CanvasLayer/DialogBubble

var _enemy_scene = preload("res://scenes/enemies/sword_enemy.tscn")

func _ready() -> void:
	_spawn_enemies_from_markers()

	GameState.all_tickets_collected.connect(_on_all_tickets_collected)
	GameState.ticket_collected.connect(_on_ticket_collected)
	GameState.player_died.connect(_on_player_died)

	_update_ticket_label()

# --- Enemy spawn markers ---

func _spawn_enemies_from_markers() -> void:
	for cell in enemy_markers.get_used_cells():
		var enemy = _enemy_scene.instantiate()
		enemy.position = enemy_markers.map_to_local(cell)
		enemy_markers.erase_cell(cell)
		enemies_container.add_child(enemy)

# --- HUD & signals ---

func _update_ticket_label() -> void:
	ticket_label.text = "Tickets: %d / %d" % [GameState.tickets_collected, GameState.tickets_required]

func _on_ticket_collected(_current: int, _total: int) -> void:
	_update_ticket_label()

func _on_all_tickets_collected() -> void:
	exit_door.appear()

func _on_player_died() -> void:
	player.set_physics_process(false)
	var death_screen = preload("res://scenes/ui/death_screen.tscn").instantiate()
	death_screen.show_death("res://scenes/dungeon/dungeon.tscn")
	get_tree().root.add_child(death_screen)

func _exit_tree() -> void:
	if GameState.all_tickets_collected.is_connected(_on_all_tickets_collected):
		GameState.all_tickets_collected.disconnect(_on_all_tickets_collected)
	if GameState.ticket_collected.is_connected(_on_ticket_collected):
		GameState.ticket_collected.disconnect(_on_ticket_collected)
	if GameState.player_died.is_connected(_on_player_died):
		GameState.player_died.disconnect(_on_player_died)
