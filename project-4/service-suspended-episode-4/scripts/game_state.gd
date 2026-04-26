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
signal inventory_changed
signal inventory_selection_changed(item_id: String)
signal ritual_focus_changed(active: bool, item_id: String)
signal trial_started
signal trial_time_changed(remaining_seconds: float)
signal trial_time_adjusted(delta_seconds: float)

const ITEM_SPECIAL_TICKET := "special_ticket"
const ITEM_VOODOO_DOLL := "voodoo_doll"
const ITEM_CLOCK := "clock"
const INVENTORY_SLOT_COUNT := 4
const STATUE_SLOT_COUNT := 8
const BROKEN_STATUE_COUNT := 2
const STATUE_COLOR_ORDER: Array[String] = ["yellow", "blue", "red", "green", "purple", "white"]

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
var special_tickets_held: int = 0
var inventory_slots: Array[String] = ["", "", "", ""]
var inventory_counts: Dictionary = {}
var selected_inventory_item: String = ""
var ritual_focus_item: String = ""
var special_ticket_supply_seeded: bool = false
var voodoo_doll_supply_seeded: bool = false
var statue_colors_by_id: Dictionary = {}
var broken_statue_ids: Array[int] = []
var statue_offering_order: Array[int] = []
var statue_order_progress: int = 0
var statue_ritual_seeded: bool = false
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

# One-shot session flags
var intro_played: bool = false
var campfire_intro_played: bool = false
var trial_start: bool = false
var trial_time_remaining: float = 0.0
var trial_time_limit: float = 120.0

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
var map_clock_hint_shown: bool = false
var wire_cut_order: Array = []
var path_assignments: Array = []  # [{path: int, color: String}, ...]

# Simon says puzzle
var simon_solved: bool = false
var simon_key_sequence: Array = []

# Computer lock puzzle
var computer_lock_solved: bool = false

# Conductor
var conductor_watching: bool = false

# Lore
var lore_open: bool = false
var collected_lore: Array[Dictionary] = []

# PA announcements — one-shot, never reset on death (session-persistent)
signal pa_requested(section: String)
var pa_lore_pickup_played: bool = false
var pa_first_rotation_played: bool = false
var pa_clock_solved_played: bool = false
var pa_half_map_played: bool = false
var pa_computer_solved_played: bool = false
var pa_map_complete_played: bool = false
var pa_wire_puzzle_played: bool = false

func request_pa(section: String) -> void:
	pa_requested.emit(section)

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

func pickup_inventory_item(item_id: String, amount: int = 1) -> bool:
	return add_inventory_item(item_id, amount)

func add_inventory_item(item_id: String, amount: int = 1) -> bool:
	if amount <= 0:
		return false
	var slot_index := _find_inventory_slot(item_id)
	if slot_index == -1:
		slot_index = _find_first_empty_inventory_slot()
		if slot_index == -1:
			return false
		inventory_slots[slot_index] = item_id
	inventory_counts[item_id] = get_inventory_count(item_id) + amount
	if item_id == ITEM_SPECIAL_TICKET:
		special_tickets_held = get_inventory_count(item_id)
	inventory_changed.emit()
	return true

func consume_inventory_item(item_id: String, amount: int = 1) -> bool:
	var current := get_inventory_count(item_id)
	if amount <= 0 or current < amount:
		return false
	var remaining := current - amount
	if remaining > 0:
		inventory_counts[item_id] = remaining
	else:
		inventory_counts.erase(item_id)
		for i in range(inventory_slots.size()):
			if inventory_slots[i] == item_id:
				inventory_slots[i] = ""
	if item_id == ITEM_SPECIAL_TICKET:
		special_tickets_held = remaining
	inventory_changed.emit()
	if selected_inventory_item == item_id and remaining <= 0:
		clear_selected_inventory_item()
	return true

func has_inventory_item(item_id: String, amount: int = 1) -> bool:
	return get_inventory_count(item_id) >= amount

func get_inventory_count(item_id: String) -> int:
	return int(inventory_counts.get(item_id, 0))

func get_inventory_slot_item(index: int) -> String:
	if index < 0 or index >= inventory_slots.size():
		return ""
	return inventory_slots[index]

func ensure_starting_special_tickets(count: int = 6) -> void:
	if special_ticket_supply_seeded:
		return
	if add_inventory_item(ITEM_SPECIAL_TICKET, count):
		special_ticket_supply_seeded = true

func ensure_starting_voodoo_dolls(count: int = 1) -> void:
	if voodoo_doll_supply_seeded:
		return
	if add_inventory_item(ITEM_VOODOO_DOLL, count):
		voodoo_doll_supply_seeded = true

func ensure_starting_clock() -> void:
	has_clock = true
	has_clock_hands = true
	clock_hands_inserted = true
	if not has_inventory_item(ITEM_CLOCK):
		add_inventory_item(ITEM_CLOCK)

func start_trial(duration_seconds: float = -1.0) -> void:
	if trial_start:
		return
	trial_start = true
	trial_time_remaining = trial_time_limit if duration_seconds < 0.0 else duration_seconds
	trial_started.emit()
	trial_time_changed.emit(trial_time_remaining)

func tick_trial_time(delta: float) -> void:
	if not trial_start or trial_time_remaining <= 0.0:
		return
	trial_time_remaining = max(0.0, trial_time_remaining - delta)
	trial_time_changed.emit(trial_time_remaining)

func adjust_trial_time(delta_seconds: float) -> void:
	if not trial_start:
		return
	trial_time_remaining = max(0.0, trial_time_remaining + delta_seconds)
	trial_time_adjusted.emit(delta_seconds)
	trial_time_changed.emit(trial_time_remaining)

func set_selected_inventory_item(item_id: String) -> void:
	if item_id.is_empty():
		clear_selected_inventory_item()
		return
	if not has_inventory_item(item_id):
		return
	selected_inventory_item = item_id
	_apply_inventory_cursor()
	inventory_selection_changed.emit(selected_inventory_item)

func clear_selected_inventory_item() -> void:
	if selected_inventory_item.is_empty():
		_apply_inventory_cursor()
		return
	selected_inventory_item = ""
	_apply_inventory_cursor()
	inventory_selection_changed.emit("")

func toggle_selected_inventory_item(item_id: String) -> void:
	if selected_inventory_item == item_id:
		clear_selected_inventory_item()
	else:
		set_selected_inventory_item(item_id)

func set_ritual_focus_item(item_id: String) -> void:
	ritual_focus_item = item_id
	ritual_focus_changed.emit(not item_id.is_empty(), item_id)

func clear_ritual_focus_item() -> void:
	if ritual_focus_item.is_empty():
		return
	ritual_focus_item = ""
	ritual_focus_changed.emit(false, "")

func ensure_statue_ritual_seeded() -> void:
	if statue_ritual_seeded:
		return
	var statue_ids: Array[int] = []
	for statue_id in range(1, STATUE_SLOT_COUNT + 1):
		statue_ids.append(statue_id)
	statue_ids.shuffle()
	broken_statue_ids.clear()
	for i in range(min(BROKEN_STATUE_COUNT, statue_ids.size())):
		broken_statue_ids.append(statue_ids[i])
	broken_statue_ids.sort()
	var shuffled_colors := STATUE_COLOR_ORDER.duplicate()
	shuffled_colors.shuffle()
	statue_colors_by_id.clear()
	var active_statue_ids: Array[int] = []
	for statue_id in statue_ids:
		if not broken_statue_ids.has(statue_id):
			active_statue_ids.append(statue_id)
	for i in range(min(active_statue_ids.size(), shuffled_colors.size())):
		statue_colors_by_id[active_statue_ids[i]] = shuffled_colors[i]
	statue_offering_order.clear()
	for color in STATUE_COLOR_ORDER:
		for statue_id in active_statue_ids:
			if statue_colors_by_id.get(statue_id, "") == color:
				statue_offering_order.append(statue_id)
				break
	statue_order_progress = 0
	statue_ritual_seeded = true

func is_statue_broken(statue_id: int) -> bool:
	ensure_statue_ritual_seeded()
	return broken_statue_ids.has(statue_id)

func get_broken_statue_ids() -> Array[int]:
	ensure_statue_ritual_seeded()
	return broken_statue_ids.duplicate()

func get_statue_fire_color(statue_id: int) -> String:
	ensure_statue_ritual_seeded()
	if is_statue_broken(statue_id):
		return ""
	return String(statue_colors_by_id.get(statue_id, STATUE_COLOR_ORDER[0]))

func get_expected_statue_id() -> int:
	ensure_statue_ritual_seeded()
	if statue_order_progress >= statue_offering_order.size():
		return -1
	return statue_offering_order[statue_order_progress]

func resolve_statue_offering(statue_id: int) -> bool:
	ensure_statue_ritual_seeded()
	if is_statue_broken(statue_id):
		return false
	var accepted := statue_id == get_expected_statue_id()
	if accepted:
		statue_order_progress += 1
	return accepted

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
	var first_pickup := not has_clock
	has_clock = true
	if not has_inventory_item(ITEM_CLOCK):
		add_inventory_item(ITEM_CLOCK)
	if first_pickup:
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
	special_tickets_held = 0
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
	map_clock_hint_shown = false
	wire_cut_order.clear()
	path_assignments.clear()
	simon_solved = false
	simon_key_sequence.clear()
	computer_lock_solved = false
	collected_lore.clear()
	inventory_slots = ["", "", "", ""]
	inventory_counts.clear()
	selected_inventory_item = ""
	ritual_focus_item = ""
	special_ticket_supply_seeded = false
	voodoo_doll_supply_seeded = false
	campfire_intro_played = false
	trial_start = false
	trial_time_remaining = 0.0
	statue_colors_by_id.clear()
	broken_statue_ids.clear()
	statue_offering_order.clear()
	statue_order_progress = 0
	statue_ritual_seeded = false
	_apply_inventory_cursor()
	_init_section_variants()

func toggle_mute() -> void:
	muted = not muted
	AudioServer.set_bus_mute(0, muted)

func _find_inventory_slot(item_id: String) -> int:
	for i in range(inventory_slots.size()):
		if inventory_slots[i] == item_id:
			return i
	return -1

func _find_first_empty_inventory_slot() -> int:
	for i in range(inventory_slots.size()):
		if inventory_slots[i].is_empty():
			return i
	return -1

func _apply_inventory_cursor() -> void:
	if not has_node("/root/CustomCursor"):
		return
	if selected_inventory_item == ITEM_SPECIAL_TICKET:
		CustomCursor.set_cursor_scene(preload("res://scenes/items/cursors/special_ticket_cursor.tscn"))
	elif selected_inventory_item == ITEM_VOODOO_DOLL:
		CustomCursor.set_cursor_scene(preload("res://scenes/items/cursors/voodoo_doll_cursor.tscn"))
	else:
		CustomCursor.reset_cursor()
