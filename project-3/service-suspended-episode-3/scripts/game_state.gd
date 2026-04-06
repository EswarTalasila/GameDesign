extends Node

# Singleton tracking dungeon state across the game loop:
# train cart → punch ticket → dungeon → collect tickets → exit door → next cart

signal ticket_collected(current: int, total: int)
signal all_tickets_collected
signal player_died
signal key_collected(current: int)
signal key_mode_changed(active: bool)
signal checkpoint_set(position: Vector2, section: String)
signal player_hit(current_health: int)
signal player_health_changed(current_health: int)
signal ticket_picked_up(held: int)
signal special_ticket_collected(current: int, required: int)
signal all_special_tickets_collected
signal wire_cutter_collected
signal wire_cutter_mode_changed(active: bool)
signal clock_collected
signal clock_hands_collected
signal clock_hands_added
signal clock_mode_changed(active: bool)
signal conductor_watching_changed(watching: bool)
signal lore_collected(lore_entry: Dictionary)
signal map_piece_collected(piece_id: int)
signal map_assembled_signal

var current_cart_index: int = 0
var dungeon_type: String = "standard"
var tickets_collected: int = 0
var tickets_held: int = 0
var tickets_required: int = 5
var loop_count: int = 0
var dungeon_seed: int = 0
var keys_collected: int = 0
var key_mode: bool = false
var checkpoint_position: Vector2 = Vector2.ZERO
var checkpoint_section: String = ""
var max_health: int = 3
var player_health: int = 3
var special_tickets_collected: int = 0
var special_tickets_required: int = 6  # per floor
var combat_tutorial_shown: bool = false
var hit_tip_shown: bool = false
var ticket_tip_shown: bool = false
var checkpoint_tip_shown: bool = false
var swap_tip_shown: bool = false
var key_tip_shown: bool = false
var golden_ticket_tip_shown: bool = false
var golden_punch_tip_shown: bool = false
var all_golden_tip_shown: bool = false
var golden_ticket_dry_streak: int = 0  # consecutive rotations without a golden ticket

# Dialogue replay flags — tracks whether NPC dialogue has been heard
var lady_section_1_heard: bool = false
var lady_section_2_heard: bool = false
var lady2_asked_conductor: bool = false
var lady2_asked_escape: bool = false
var lady2_asked_before: bool = false

# Wire cutter
var has_wire_cutter: bool = false
var wire_cutter_mode: bool = false

# Clock
var has_clock: bool = false
var has_clock_hands: bool = false
var clock_hands_inserted: bool = false
var clock_mode: bool = false
var current_variant: int = 1
var has_selected_variant: bool = false
var suitcase_solved: bool = false

# Map pieces
var collected_map_pieces: Array[int] = []  # total ever collected (1-4)
var board_pieces: Array[int] = []  # pieces placed on the board
var map_assembled: bool = false
var clock_on_map: bool = false
var wire_cut_order: Array = []  # determined by map path colors clockwise

# Conductor
var conductor_watching: bool = false

# Lore
var lore_open: bool = false
var collected_lore: Array[Dictionary] = []

# Audio mute (persists across resets — player preference)
var muted: bool = false

# Floor/section tracking
var current_floor: int = 1
var num_floors: int = 2
var sections_per_floor: int = 4
var variants_per_section: int = 3
# Tracks current variant index (1-based) per section per floor
# Format: { 1: { "a": 1, "b": 1, "c": 1, "d": 1 }, 2: { ... } }
var section_variants: Dictionary = {}

func _ready() -> void:
	_init_section_variants()

func _init_section_variants() -> void:
	for floor_num in range(1, num_floors + 1):
		randomize_section_variants(floor_num)

func randomize_section_variants(floor_num: int) -> void:
	section_variants[floor_num] = {}
	for section_key in ["a", "b", "c", "d"]:
		section_variants[floor_num][section_key] = randi_range(1, variants_per_section)

func get_section_variant(floor_num: int, section_key: String) -> int:
	if section_variants.has(floor_num) and section_variants[floor_num].has(section_key):
		return section_variants[floor_num][section_key]
	return 1

func advance_section_variant(floor_num: int, section_key: String) -> int:
	var current = get_section_variant(floor_num, section_key)
	var next = (current % variants_per_section) + 1
	section_variants[floor_num][section_key] = next
	return next

func start_dungeon(cart_index: int, type: String = "standard", ticket_count: int = 5) -> void:
	current_cart_index = cart_index
	dungeon_type = type
	tickets_collected = 0
	tickets_required = ticket_count
	dungeon_seed = get_effective_seed()

func get_effective_seed() -> int:
	return current_cart_index * 10000 + loop_count

func pickup_ticket() -> void:
	if tickets_held >= 9:
		return
	tickets_held += 1
	ticket_picked_up.emit(tickets_held)

func collect_ticket() -> void:
	tickets_collected += 1
	ticket_collected.emit(tickets_collected, tickets_required)
	if tickets_collected >= tickets_required:
		all_tickets_collected.emit()

func collect_special_ticket() -> void:
	special_tickets_collected += 1
	special_ticket_collected.emit(special_tickets_collected, special_tickets_required)
	if special_tickets_collected >= special_tickets_required:
		all_special_tickets_collected.emit()

func collect_key() -> void:
	if keys_collected >= 9:
		return
	keys_collected += 1
	key_collected.emit(keys_collected)

func use_key() -> bool:
	if keys_collected > 0:
		keys_collected -= 1
		key_collected.emit(keys_collected)
		return true
	return false

func set_key_mode(active: bool) -> void:
	key_mode = active
	key_mode_changed.emit(active)

func collect_wire_cutter() -> void:
	has_wire_cutter = true
	wire_cutter_collected.emit()

func set_wire_cutter_mode(active: bool) -> void:
	wire_cutter_mode = active
	wire_cutter_mode_changed.emit(active)

func collect_clock() -> void:
	has_clock = true
	clock_collected.emit()

func collect_clock_hands() -> void:
	has_clock_hands = true
	clock_hands_collected.emit()

func insert_clock_hands() -> void:
	clock_hands_inserted = true
	has_clock_hands = false
	clock_hands_added.emit()

func set_clock_mode(active: bool) -> void:
	clock_mode = active
	clock_mode_changed.emit(active)

func collect_map_piece(piece_id: int) -> void:
	if piece_id in collected_map_pieces:
		return
	collected_map_pieces.append(piece_id)
	map_piece_collected.emit(piece_id)

func has_map_piece(piece_id: int) -> bool:
	return piece_id in collected_map_pieces

func set_conductor_watching(watching: bool) -> void:
	conductor_watching = watching
	conductor_watching_changed.emit(watching)

func collect_lore(id: String, title: String, body: String, icon: Texture2D = null) -> void:
	for entry in collected_lore:
		if entry["id"] == id:
			return
	var entry = {"id": id, "title": title, "body": body, "icon": icon}
	collected_lore.append(entry)
	lore_collected.emit(entry)

func has_lore(id: String) -> bool:
	for entry in collected_lore:
		if entry["id"] == id:
			return true
	return false

func set_checkpoint(pos: Vector2, section: String = "") -> void:
	checkpoint_position = pos
	checkpoint_section = section
	checkpoint_set.emit(pos, section)

func damage_player(amount: int = 1) -> void:
	player_health = maxi(player_health - amount, 0)
	player_hit.emit(player_health)
	player_health_changed.emit(player_health)
	if player_health <= 0:
		on_player_death()

func heal_player(amount: int = 1) -> void:
	player_health = mini(player_health + amount, max_health)
	player_health_changed.emit(player_health)

func reset_health() -> void:
	player_health = max_health
	player_health_changed.emit(player_health)

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
	tickets_held = 0
	keys_collected = 0
	key_mode = false
	tickets_required = 5
	loop_count = 0
	dungeon_seed = 0
	current_floor = 1
	special_tickets_collected = 0
	checkpoint_position = Vector2.ZERO
	checkpoint_section = ""
	combat_tutorial_shown = false
	hit_tip_shown = false
	ticket_tip_shown = false
	checkpoint_tip_shown = false
	swap_tip_shown = false
	key_tip_shown = false
	golden_ticket_tip_shown = false
	golden_punch_tip_shown = false
	all_golden_tip_shown = false
	golden_ticket_dry_streak = 0
	lady_section_1_heard = false
	lady_section_2_heard = false
	lady2_asked_conductor = false
	lady2_asked_escape = false
	lady2_asked_before = false
	has_wire_cutter = false
	wire_cutter_mode = false
	has_clock = false
	has_clock_hands = false
	clock_hands_inserted = false
	clock_mode = false
	current_variant = 1
	has_selected_variant = false
	suitcase_solved = false
	conductor_watching = false
	lore_open = false
	collected_map_pieces.clear()
	board_pieces.clear()
	map_assembled = false
	clock_on_map = false
	wire_cut_order.clear()
	collected_lore.clear()
	_init_section_variants()

func toggle_mute() -> void:
	muted = not muted
	AudioServer.set_bus_mute(0, muted)
