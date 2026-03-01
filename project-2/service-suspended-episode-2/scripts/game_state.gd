extends Node

# Singleton tracking dungeon state across the game loop:
# train cart → punch ticket → dungeon → collect tickets → exit door → next cart

signal ticket_collected(current: int, total: int)
signal all_tickets_collected
signal player_died

var current_cart_index: int = 0
var dungeon_type: String = "standard"
var tickets_collected: int = 0
var tickets_required: int = 5
var loop_count: int = 0
var dungeon_seed: int = 0

func start_dungeon(cart_index: int, type: String = "standard", ticket_count: int = 5) -> void:
	current_cart_index = cart_index
	dungeon_type = type
	tickets_collected = 0
	tickets_required = ticket_count
	dungeon_seed = get_effective_seed()

func get_effective_seed() -> int:
	return current_cart_index * 10000 + loop_count

func collect_ticket() -> void:
	tickets_collected += 1
	ticket_collected.emit(tickets_collected, tickets_required)
	if tickets_collected >= tickets_required:
		all_tickets_collected.emit()

func on_player_death() -> void:
	loop_count += 1
	player_died.emit()

func complete_dungeon() -> void:
	loop_count = 0
	current_cart_index += 1

func advance_to_next_cart() -> void:
	complete_dungeon()

func reset() -> void:
	current_cart_index = 0
	tickets_collected = 0
	tickets_required = 5
	loop_count = 0
	dungeon_seed = 0
