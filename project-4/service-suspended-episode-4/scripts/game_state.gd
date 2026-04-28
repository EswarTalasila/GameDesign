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
signal ritual_focus_items_changed(items)
signal trial_started
signal trial_time_changed(remaining_seconds: float)
signal trial_time_adjusted(delta_seconds: float)
signal campfire_state_changed(lit: bool)
signal campfire_burn_changed(remaining_seconds: float, duration_seconds: float)
signal stone_puzzle_state_changed
signal jungle_route_state_changed

const ITEM_SPECIAL_TICKET := "special_ticket"
const ITEM_VOODOO_DOLL := "voodoo_doll"
const ITEM_CLOCK := "clock"
const ITEM_WOOD := "wood"
const ITEM_KEY := "key"
const ITEM_MAP := "map"
const INVENTORY_SLOT_COUNT := 4
const STATUE_SLOT_COUNT := 8
const BROKEN_STATUE_COUNT := 2
const STATUE_COLOR_ORDER: Array[String] = ["yellow", "blue", "red", "green", "purple", "white"]
const STONE_PUZZLE_OBJECTIVE_ID := "find_stone_rocks"
const STONE_PUZZLE_TOTAL := 8
const JUNGLE_HUNT_OBJECTIVE_ID := "survive_variant_5"
const JUNGLE_BOSS_OBJECTIVE_ID := "defeat_variant_6_boss"
const JUNGLE_RETURN_OBJECTIVE_ID := "return_to_variant_1"
const JUNGLE_ROUTE_FREE := "free"
const JUNGLE_ROUTE_HUNT := "hunt"
const JUNGLE_ROUTE_BOSS := "boss"
const JUNGLE_ROUTE_RETURN := "return"
const JUNGLE_CHECKPOINT_DUNGEON_START := "dungeon_start"
const JUNGLE_CHECKPOINT_VARIANT_5 := "variant_5"
const JUNGLE_CHECKPOINT_VARIANT_6 := "variant_6"
const JUNGLE_CHECKPOINT_RETURN_1 := "return_variant_1"
const STONE_PIECE_IDS: Array[String] = [
	"black_1",
	"black_2",
	"red",
	"yellow",
	"green",
	"blue",
	"purple",
	"white",
]
const STONE_PIECE_COLORS := {
	"black_1": "black",
	"black_2": "black",
	"red": "red",
	"yellow": "yellow",
	"green": "green",
	"blue": "blue",
	"purple": "purple",
	"white": "white",
}

const _JUNGLE_CHECKPOINT_SCALAR_KEYS := [
	"current_cart_index",
	"dungeon_type",
	"tickets_collected",
	"tickets_held",
	"tickets_required",
	"loop_count",
	"dungeon_seed",
	"keys_collected",
	"key_mode",
	"checkpoint_position",
	"checkpoint_section",
	"player_health",
	"special_tickets_collected",
	"special_tickets_required",
	"special_tickets_held",
	"selected_inventory_item",
	"ritual_focus_item",
	"special_ticket_supply_seeded",
	"voodoo_doll_supply_seeded",
	"wood_supply_seeded",
	"key_supply_seeded",
	"combat_tutorial_shown",
	"hit_tip_shown",
	"ticket_tip_shown",
	"checkpoint_tip_shown",
	"swap_tip_shown",
	"key_tip_shown",
	"golden_ticket_tip_shown",
	"golden_punch_tip_shown",
	"all_golden_tip_shown",
	"golden_ticket_dry_streak",
	"intro_played",
	"campfire_intro_played",
	"trial_start",
	"trial_time_remaining",
	"trial_time_limit",
	"campfire_status_active",
	"campfire_lit",
	"campfire_burn_remaining",
	"campfire_burn_duration",
	"lady_section_1_heard",
	"lady_section_2_heard",
	"lady2_asked_conductor",
	"lady2_asked_escape",
	"lady2_asked_before",
	"cat_intro_heard",
	"cat_rescued",
	"cat_at_campfire",
	"has_wire_cutter",
	"wire_cutter_mode",
	"has_clock",
	"has_clock_hands",
	"clock_hands_inserted",
	"clock_mode",
	"current_variant",
	"has_selected_variant",
	"suitcase_solved",
	"map_assembled",
	"clock_on_map",
	"map_clock_hint_shown",
	"simon_solved",
	"computer_lock_solved",
	"stone_puzzle_started",
	"stone_puzzle_solved",
	"conductor_watching",
	"lore_open",
	"current_floor",
	"jungle_route_phase",
	"jungle_hunt_total",
	"jungle_hunt_kills",
]

const _JUNGLE_CHECKPOINT_ARRAY_KEYS := [
	"inventory_slots",
	"ritual_focus_items",
	"broken_statue_ids",
	"statue_offering_order",
	"completed_statue_ids",
	"collected_map_pieces",
	"board_pieces",
	"wire_cut_order",
	"path_assignments",
	"simon_key_sequence",
	"collected_stone_piece_ids",
	"carried_stone_piece_ids",
	"deposited_stone_piece_ids",
	"defeated_jungle_enemy_ids",
	"jungle_persistent_enemy_drops",
	"collected_lore",
]

const _JUNGLE_CHECKPOINT_DICT_KEYS := [
	"inventory_counts",
	"statue_colors_by_id",
	"section_variants",
]

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
var ritual_focus_items: Array[String] = []
var special_ticket_supply_seeded: bool = false
var voodoo_doll_supply_seeded: bool = false
var wood_supply_seeded: bool = false
var key_supply_seeded: bool = false
var statue_colors_by_id: Dictionary = {}
var broken_statue_ids: Array[int] = []
var statue_offering_order: Array[int] = []
var statue_order_progress: int = 0
var completed_statue_ids: Array[int] = []
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
var campfire_status_active: bool = false
var campfire_lit: bool = false
var campfire_burn_remaining: float = 0.0
var campfire_burn_duration: float = 60.0

# Dialogue replay flags — tracks whether NPC dialogue has been heard
var lady_section_1_heard: bool = false
var lady_section_2_heard: bool = false
var lady2_asked_conductor: bool = false
var lady2_asked_escape: bool = false
var lady2_asked_before: bool = false
var cat_intro_heard: bool = false
var cat_rescued: bool = false
var cat_at_campfire: bool = false

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
var stone_puzzle_started: bool = false
var stone_puzzle_solved: bool = false
var collected_stone_piece_ids: Array[String] = []
var carried_stone_piece_ids: Array[String] = []
var deposited_stone_piece_ids: Array[String] = []
var jungle_route_phase: String = JUNGLE_ROUTE_FREE
var jungle_hunt_total: int = 0
var jungle_hunt_kills: int = 0
var jungle_checkpoint_variant: int = 1
var jungle_checkpoint_stage: String = ""
var jungle_checkpoint_snapshot: Dictionary = {}

# Jungle enemy persistence
var defeated_jungle_enemy_ids: Array[String] = []
var jungle_persistent_enemy_drops: Array[Dictionary] = []
var _jungle_drop_serial: int = 0

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
	if item_id == ITEM_KEY:
		amount = mini(amount, 9 - get_inventory_count(item_id))
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
	elif item_id == ITEM_KEY:
		_sync_key_count_from_inventory()
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
	elif item_id == ITEM_KEY:
		_sync_key_count_from_inventory()
	inventory_changed.emit()
	if selected_inventory_item == item_id and remaining <= 0:
		clear_selected_inventory_item()
	return true

func has_inventory_item(item_id: String, amount: int = 1) -> bool:
	return get_inventory_count(item_id) >= amount

func get_inventory_count(item_id: String) -> int:
	return int(inventory_counts.get(item_id, 0))

func make_jungle_enemy_id(section_path: String, position: Vector2) -> String:
	if section_path.is_empty():
		return ""
	return "%s|%d|%d" % [section_path, roundi(position.x), roundi(position.y)]

func is_jungle_enemy_defeated(enemy_id: String) -> bool:
	return not enemy_id.is_empty() and defeated_jungle_enemy_ids.has(enemy_id)

func mark_jungle_enemy_defeated(enemy_id: String) -> void:
	if enemy_id.is_empty() or defeated_jungle_enemy_ids.has(enemy_id):
		return
	defeated_jungle_enemy_ids.append(enemy_id)

func add_jungle_persistent_enemy_drop(section_path: String, scene_path: String, position: Vector2) -> String:
	if section_path.is_empty() or scene_path.is_empty():
		return ""
	_jungle_drop_serial += 1
	var drop_id := "jungle_drop_%d" % _jungle_drop_serial
	jungle_persistent_enemy_drops.append({
		"id": drop_id,
		"section_path": section_path,
		"scene_path": scene_path,
		"x": position.x,
		"y": position.y,
	})
	return drop_id

func remove_jungle_persistent_enemy_drop(drop_id: String) -> void:
	if drop_id.is_empty():
		return
	for i in range(jungle_persistent_enemy_drops.size() - 1, -1, -1):
		if String(jungle_persistent_enemy_drops[i].get("id", "")) == drop_id:
			jungle_persistent_enemy_drops.remove_at(i)
			return

func get_jungle_persistent_enemy_drops(section_path: String) -> Array[Dictionary]:
	var drops: Array[Dictionary] = []
	if section_path.is_empty():
		return drops
	for drop: Dictionary in jungle_persistent_enemy_drops:
		if String(drop.get("section_path", "")) == section_path:
			drops.append(drop.duplicate(true))
	return drops

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

func ensure_starting_wood(count: int = 5) -> void:
	if wood_supply_seeded:
		return
	if add_inventory_item(ITEM_WOOD, count):
		wood_supply_seeded = true

func ensure_starting_clock() -> void:
	has_clock = true
	has_clock_hands = true
	clock_hands_inserted = true
	if not has_inventory_item(ITEM_CLOCK):
		add_inventory_item(ITEM_CLOCK)

func ensure_starting_keys(count: int = 1) -> void:
	if key_supply_seeded:
		return
	if add_inventory_item(ITEM_KEY, count):
		key_supply_seeded = true

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

func configure_campfire(duration_seconds: float) -> void:
	if duration_seconds > 0.0:
		campfire_burn_duration = duration_seconds
		if campfire_burn_remaining > campfire_burn_duration:
			campfire_burn_remaining = campfire_burn_duration
	campfire_burn_changed.emit(campfire_burn_remaining, campfire_burn_duration)

func ignite_campfire(duration_seconds: float = -1.0) -> void:
	if duration_seconds > 0.0:
		campfire_burn_duration = duration_seconds
	var refill_to := campfire_burn_duration if duration_seconds <= 0.0 else duration_seconds
	campfire_burn_remaining = max(0.0, refill_to)
	campfire_status_active = true
	var changed := not campfire_lit
	campfire_lit = true
	if changed:
		campfire_state_changed.emit(true)
	campfire_burn_changed.emit(campfire_burn_remaining, campfire_burn_duration)

func extinguish_campfire() -> void:
	campfire_burn_remaining = 0.0
	var changed := campfire_lit
	campfire_lit = false
	if changed:
		campfire_state_changed.emit(false)
	campfire_burn_changed.emit(campfire_burn_remaining, campfire_burn_duration)

func tick_campfire(delta: float) -> void:
	if not campfire_lit or campfire_burn_remaining <= 0.0:
		return
	campfire_burn_remaining = max(0.0, campfire_burn_remaining - delta)
	if campfire_burn_remaining <= 0.0:
		extinguish_campfire()
	else:
		campfire_burn_changed.emit(campfire_burn_remaining, campfire_burn_duration)

func set_selected_inventory_item(item_id: String) -> void:
	if item_id.is_empty():
		clear_selected_inventory_item()
		return
	if not has_inventory_item(item_id):
		return
	selected_inventory_item = item_id
	set_key_mode(item_id == ITEM_KEY)
	_apply_inventory_cursor()
	inventory_selection_changed.emit(selected_inventory_item)

func clear_selected_inventory_item() -> void:
	if selected_inventory_item.is_empty():
		if key_mode:
			set_key_mode(false)
		_apply_inventory_cursor()
		return
	selected_inventory_item = ""
	if key_mode:
		set_key_mode(false)
	_apply_inventory_cursor()
	inventory_selection_changed.emit("")

func toggle_selected_inventory_item(item_id: String) -> void:
	if selected_inventory_item == item_id:
		clear_selected_inventory_item()
	else:
		set_selected_inventory_item(item_id)

func set_ritual_focus_item(item_id: String) -> void:
	set_ritual_focus_items([item_id])

func clear_ritual_focus_item() -> void:
	clear_ritual_focus_items()

func set_ritual_focus_items(item_ids: Array[String]) -> void:
	var filtered: Array[String] = []
	for item_id: String in item_ids:
		if item_id.is_empty() or filtered.has(item_id):
			continue
		filtered.append(item_id)
	ritual_focus_items = filtered
	ritual_focus_item = ritual_focus_items[0] if not ritual_focus_items.is_empty() else ""
	ritual_focus_changed.emit(not ritual_focus_item.is_empty(), ritual_focus_item)
	ritual_focus_items_changed.emit(ritual_focus_items.duplicate())

func clear_ritual_focus_items() -> void:
	if ritual_focus_items.is_empty() and ritual_focus_item.is_empty():
		return
	ritual_focus_item = ""
	ritual_focus_items.clear()
	ritual_focus_changed.emit(false, "")
	ritual_focus_items_changed.emit([])

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

func has_completed_statue_offering(statue_id: int) -> bool:
	ensure_statue_ritual_seeded()
	return completed_statue_ids.has(statue_id)

func mark_statue_offering_completed(statue_id: int) -> void:
	ensure_statue_ritual_seeded()
	if is_statue_broken(statue_id) or completed_statue_ids.has(statue_id):
		return
	completed_statue_ids.append(statue_id)
	completed_statue_ids.sort()

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
	if has_inventory_item(ITEM_KEY) or _find_inventory_slot(ITEM_KEY) != -1 or _find_first_empty_inventory_slot() != -1:
		add_inventory_item(ITEM_KEY, 1)
		return
	if keys_collected >= 9:
		return
	keys_collected += 1
	key_collected.emit(keys_collected)

func use_key() -> bool:
	if has_inventory_item(ITEM_KEY):
		if consume_inventory_item(ITEM_KEY, 1):
			return true
	if keys_collected > 0:
		keys_collected -= 1
		key_collected.emit(keys_collected)
		if keys_collected <= 0 and key_mode:
			set_key_mode(false)
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

func has_all_map_pieces() -> bool:
	return collected_map_pieces.size() >= 4

func assemble_map() -> bool:
	if map_assembled:
		return has_inventory_item(ITEM_MAP)
	if not has_all_map_pieces():
		return false
	if not add_inventory_item(ITEM_MAP, 1):
		return false
	map_assembled = true
	map_assembled_signal.emit()
	return true

func get_map_tree_reveal_order() -> Array[Dictionary]:
	var reveal_order: Array[Dictionary] = []
	for index in range(STATUE_COLOR_ORDER.size()):
		reveal_order.append({
			"position": index + 1,
			"color": STATUE_COLOR_ORDER[index],
		})
	return reveal_order

func get_stone_piece_ids() -> Array[String]:
	return STONE_PIECE_IDS.duplicate()

func get_stone_piece_color(piece_id: String) -> String:
	return String(STONE_PIECE_COLORS.get(piece_id, ""))

func get_collected_stone_piece_ids() -> Array[String]:
	return collected_stone_piece_ids.duplicate()

func get_carried_stone_piece_ids() -> Array[String]:
	return carried_stone_piece_ids.duplicate()

func get_deposited_stone_piece_ids() -> Array[String]:
	return deposited_stone_piece_ids.duplicate()

func get_collected_stone_count() -> int:
	return collected_stone_piece_ids.size()

func get_stone_puzzle_available_count() -> int:
	return carried_stone_piece_ids.size() + deposited_stone_piece_ids.size()

func has_collected_stone_piece(piece_id: String) -> bool:
	return collected_stone_piece_ids.has(piece_id)

func is_stone_piece_carried(piece_id: String) -> bool:
	return carried_stone_piece_ids.has(piece_id)

func is_stone_piece_deposited(piece_id: String) -> bool:
	return deposited_stone_piece_ids.has(piece_id)

func start_stone_puzzle() -> bool:
	if stone_puzzle_started:
		return false
	stone_puzzle_started = true
	_sync_stone_puzzle_objective()
	stone_puzzle_state_changed.emit()
	return true

func collect_stone_piece(piece_id: String) -> bool:
	if stone_puzzle_solved or not STONE_PIECE_COLORS.has(piece_id) or collected_stone_piece_ids.has(piece_id):
		return false
	collected_stone_piece_ids.append(piece_id)
	carried_stone_piece_ids.append(piece_id)
	_sort_stone_piece_ids(collected_stone_piece_ids)
	_sort_stone_piece_ids(carried_stone_piece_ids)
	_sync_stone_puzzle_objective()
	stone_puzzle_state_changed.emit()
	return true

func deposit_carried_stone_pieces() -> Array[String]:
	if carried_stone_piece_ids.is_empty():
		return []
	var moved := carried_stone_piece_ids.duplicate()
	for piece_id in moved:
		if not deposited_stone_piece_ids.has(piece_id):
			deposited_stone_piece_ids.append(piece_id)
	carried_stone_piece_ids.clear()
	_sort_stone_piece_ids(deposited_stone_piece_ids)
	stone_puzzle_state_changed.emit()
	return moved

func can_attempt_stone_puzzle() -> bool:
	return not stone_puzzle_solved and get_stone_puzzle_available_count() >= STONE_PUZZLE_TOTAL

func get_stone_solution_colors() -> Array[String]:
	ensure_statue_ritual_seeded()
	var solution: Array[String] = []
	for statue_id in range(1, STATUE_SLOT_COUNT + 1):
		solution.append("black" if is_statue_broken(statue_id) else get_statue_fire_color(statue_id))
	return solution

func solve_stone_puzzle() -> void:
	if stone_puzzle_solved:
		return
	stone_puzzle_solved = true
	_sync_stone_puzzle_objective()
	stone_puzzle_state_changed.emit()

func has_jungle_checkpoint() -> bool:
	return not jungle_checkpoint_stage.is_empty() and not jungle_checkpoint_snapshot.is_empty()

func capture_jungle_checkpoint(variant: int, stage: String) -> void:
	if variant <= 0 or stage.is_empty():
		return
	jungle_checkpoint_variant = variant
	jungle_checkpoint_stage = stage
	jungle_checkpoint_snapshot = _build_jungle_checkpoint_snapshot()
	jungle_route_state_changed.emit()

func restore_jungle_checkpoint() -> int:
	if not has_jungle_checkpoint():
		return 1
	_apply_jungle_checkpoint_snapshot(jungle_checkpoint_snapshot)
	jungle_route_state_changed.emit()
	return jungle_checkpoint_variant

func begin_jungle_hunt(total: int) -> void:
	jungle_route_phase = JUNGLE_ROUTE_HUNT
	jungle_hunt_total = maxi(total, 0)
	jungle_hunt_kills = 0
	capture_jungle_checkpoint(5, JUNGLE_CHECKPOINT_VARIANT_5)
	_sync_jungle_route_objectives()

func record_jungle_hunt_kill() -> bool:
	if jungle_route_phase != JUNGLE_ROUTE_HUNT or jungle_hunt_total <= 0:
		return false
	if jungle_hunt_kills >= jungle_hunt_total:
		return true
	jungle_hunt_kills += 1
	_sync_jungle_route_objectives()
	return jungle_hunt_kills >= jungle_hunt_total

func enter_jungle_boss_room() -> void:
	jungle_route_phase = JUNGLE_ROUTE_BOSS
	capture_jungle_checkpoint(6, JUNGLE_CHECKPOINT_VARIANT_6)
	_sync_jungle_route_objectives()

func mark_jungle_boss_defeated() -> void:
	if jungle_route_phase == JUNGLE_ROUTE_RETURN:
		return
	jungle_route_phase = JUNGLE_ROUTE_RETURN
	_sync_jungle_route_objectives()

func complete_jungle_route_return() -> void:
	if jungle_route_phase != JUNGLE_ROUTE_RETURN:
		return
	jungle_route_phase = JUNGLE_ROUTE_FREE
	capture_jungle_checkpoint(1, JUNGLE_CHECKPOINT_RETURN_1)
	_sync_jungle_route_objectives()

func get_jungle_clock_warning(target_variant: int) -> String:
	if target_variant <= 0:
		return ""
	if not trial_start and target_variant != current_variant:
		return "Start the campfire trial first."
	if jungle_checkpoint_stage == JUNGLE_CHECKPOINT_RETURN_1 and (target_variant == 5 or target_variant == 6) and target_variant != current_variant:
		return "The hands of time resist. That path has already closed."
	if target_variant == 6 and jungle_route_phase == JUNGLE_ROUTE_FREE and jungle_checkpoint_stage != JUNGLE_CHECKPOINT_RETURN_1:
		return "The hands of time resist. Reach Variant 6 through Variant 5."
	if current_variant == 5 and jungle_route_phase == JUNGLE_ROUTE_HUNT and target_variant != 5:
		return "The hands of time resist. Finish the hunt first."
	if current_variant == 6 and jungle_route_phase == JUNGLE_ROUTE_BOSS and target_variant != 6:
		return "The hands of time resist. Defeat the boss first."
	if current_variant == 6 and jungle_route_phase == JUNGLE_ROUTE_RETURN and target_variant != 1 and target_variant != 6:
		return "The hands of time resist. Only Variant 1 will answer."
	return ""

func can_use_jungle_clock_variant(target_variant: int) -> bool:
	return get_jungle_clock_warning(target_variant).is_empty()

func get_jungle_reload_tooltip() -> String:
	match jungle_checkpoint_stage:
		JUNGLE_CHECKPOINT_VARIANT_5:
			return "Reload at the Variant 5 checkpoint.\nRefight the hunt."
		JUNGLE_CHECKPOINT_VARIANT_6:
			return "Reload at the Variant 6 checkpoint.\nRefight the boss."
		JUNGLE_CHECKPOINT_RETURN_1:
			return "Reload at the Variant 1 checkpoint.\nReturn to the post-boss dungeon state."
		_:
			return "Reload at the Variant 1 checkpoint.\nReturn to the dungeon start."

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
	cat_intro_heard = false
	cat_rescued = false
	cat_at_campfire = false
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
	stone_puzzle_started = false
	stone_puzzle_solved = false
	collected_stone_piece_ids.clear()
	carried_stone_piece_ids.clear()
	deposited_stone_piece_ids.clear()
	jungle_route_phase = JUNGLE_ROUTE_FREE
	jungle_hunt_total = 0
	jungle_hunt_kills = 0
	jungle_checkpoint_variant = 1
	jungle_checkpoint_stage = ""
	jungle_checkpoint_snapshot.clear()
	defeated_jungle_enemy_ids.clear()
	jungle_persistent_enemy_drops.clear()
	_jungle_drop_serial = 0
	collected_lore.clear()
	inventory_slots = ["", "", "", ""]
	inventory_counts.clear()
	selected_inventory_item = ""
	ritual_focus_item = ""
	ritual_focus_items.clear()
	special_ticket_supply_seeded = false
	voodoo_doll_supply_seeded = false
	wood_supply_seeded = false
	key_supply_seeded = false
	intro_played = false
	campfire_intro_played = false
	trial_start = false
	trial_time_remaining = 0.0
	campfire_status_active = false
	campfire_lit = false
	campfire_burn_remaining = 0.0
	campfire_burn_duration = 60.0
	statue_colors_by_id.clear()
	broken_statue_ids.clear()
	statue_offering_order.clear()
	statue_order_progress = 0
	completed_statue_ids.clear()
	statue_ritual_seeded = false
	_quest_manager_reset()
	reset_health()
	campfire_state_changed.emit(campfire_lit)
	campfire_burn_changed.emit(campfire_burn_remaining, campfire_burn_duration)
	stone_puzzle_state_changed.emit()
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
	elif selected_inventory_item == ITEM_KEY:
		CustomCursor.set_cursor_scene(preload("res://scenes/items/cursors/key_cursor.tscn"))
	elif selected_inventory_item == ITEM_WOOD:
		CustomCursor.set_cursor_scene(preload("res://scenes/items/cursors/wood_cursor.tscn"))
	else:
		CustomCursor.reset_cursor()

func _sync_key_count_from_inventory() -> void:
	keys_collected = get_inventory_count(ITEM_KEY)
	key_collected.emit(keys_collected)
	if keys_collected <= 0 and key_mode:
		set_key_mode(false)

func _sort_stone_piece_ids(piece_ids: Array[String]) -> void:
	piece_ids.sort_custom(func(a: String, b: String) -> bool:
		return STONE_PIECE_IDS.find(a) < STONE_PIECE_IDS.find(b)
	)

func _sync_stone_puzzle_objective() -> void:
	if not stone_puzzle_started:
		return
	var current_count := get_collected_stone_count()
	if stone_puzzle_solved:
		if _quest_manager_has_objective(STONE_PUZZLE_OBJECTIVE_ID):
			_quest_manager_complete(STONE_PUZZLE_OBJECTIVE_ID)
		return
	var parent_id := "escape"
	if not _quest_manager_has_objective(parent_id):
		var primary_snapshot := _quest_manager_get_primary_snapshot()
		parent_id = String(primary_snapshot.get("id", ""))
		if parent_id.is_empty():
			_quest_manager_set_primary("escape", "Find a way to escape the dungeon")
			parent_id = "escape"
	if not _quest_manager_has_objective(STONE_PUZZLE_OBJECTIVE_ID):
		_quest_manager_add_sub(
			STONE_PUZZLE_OBJECTIVE_ID,
			"Find the colored rocks",
			parent_id,
			{"progress_required": STONE_PUZZLE_TOTAL, "progress_current": current_count}
		)
	else:
		_quest_manager_set_progress(STONE_PUZZLE_OBJECTIVE_ID, current_count, STONE_PUZZLE_TOTAL)

func _sync_jungle_route_objectives() -> void:
	_quest_manager_remove(JUNGLE_HUNT_OBJECTIVE_ID)
	_quest_manager_remove(JUNGLE_BOSS_OBJECTIVE_ID)
	_quest_manager_remove(JUNGLE_RETURN_OBJECTIVE_ID)
	var parent_id := "escape"
	if not _quest_manager_has_objective(parent_id):
		var primary_snapshot := _quest_manager_get_primary_snapshot()
		parent_id = String(primary_snapshot.get("id", ""))
		if parent_id.is_empty():
			_quest_manager_set_primary("escape", "Find a way to escape the dungeon")
			parent_id = "escape"
	match jungle_route_phase:
		JUNGLE_ROUTE_HUNT:
			if jungle_hunt_total > 0:
				_quest_manager_add_sub(
					JUNGLE_HUNT_OBJECTIVE_ID,
					"Survive and kill enemies",
					parent_id,
					{"progress_required": jungle_hunt_total, "progress_current": jungle_hunt_kills}
				)
		JUNGLE_ROUTE_BOSS:
			_quest_manager_add_sub(JUNGLE_BOSS_OBJECTIVE_ID, "Defeat the boss", parent_id)
		JUNGLE_ROUTE_RETURN:
			_quest_manager_add_sub(JUNGLE_RETURN_OBJECTIVE_ID, "Use the clock to return to Variant 1", parent_id)

func _build_jungle_checkpoint_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for key in _JUNGLE_CHECKPOINT_SCALAR_KEYS:
		snapshot[key] = get(key)
	for key in _JUNGLE_CHECKPOINT_ARRAY_KEYS:
		var value: Array = get(key)
		snapshot[key] = value.duplicate(true)
	for key in _JUNGLE_CHECKPOINT_DICT_KEYS:
		var value: Dictionary = get(key)
		snapshot[key] = value.duplicate(true)
	snapshot["_jungle_drop_serial"] = _jungle_drop_serial
	snapshot["quest_manager"] = _quest_manager_get_snapshot()
	return snapshot

func _apply_jungle_checkpoint_snapshot(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	for key in _JUNGLE_CHECKPOINT_SCALAR_KEYS:
		if snapshot.has(key):
			set(key, snapshot[key])
	for key in _JUNGLE_CHECKPOINT_ARRAY_KEYS:
		if snapshot.has(key):
			var value: Array = snapshot[key]
			set(key, value.duplicate(true))
	for key in _JUNGLE_CHECKPOINT_DICT_KEYS:
		if snapshot.has(key):
			var value: Dictionary = snapshot[key]
			set(key, value.duplicate(true))
	_jungle_drop_serial = int(snapshot.get("_jungle_drop_serial", 0))
	player_health = max_health
	_quest_manager_restore_snapshot(snapshot.get("quest_manager", {}))
	_apply_inventory_cursor()

func _get_quest_manager():
	return get_node_or_null("/root/QuestManager")

func _quest_manager_reset() -> void:
	var quest_manager = _get_quest_manager()
	if quest_manager != null and quest_manager.has_method("reset"):
		quest_manager.call("reset")

func _quest_manager_has_objective(id: String) -> bool:
	var quest_manager = _get_quest_manager()
	return (
		quest_manager != null
		and quest_manager.has_method("has_objective")
		and bool(quest_manager.call("has_objective", id))
	)

func _quest_manager_get_primary_snapshot() -> Dictionary:
	var quest_manager = _get_quest_manager()
	if quest_manager == null or not quest_manager.has_method("get_primary_snapshot"):
		return {}
	return quest_manager.call("get_primary_snapshot")

func _quest_manager_get_snapshot() -> Dictionary:
	var quest_manager = _get_quest_manager()
	if quest_manager == null or not quest_manager.has_method("get_snapshot"):
		return {}
	return quest_manager.call("get_snapshot")

func _quest_manager_restore_snapshot(snapshot: Dictionary) -> void:
	var quest_manager = _get_quest_manager()
	if quest_manager != null and quest_manager.has_method("restore_snapshot"):
		quest_manager.call("restore_snapshot", snapshot)

func _quest_manager_set_primary(id: String, text: String, options: Dictionary = {}) -> void:
	var quest_manager = _get_quest_manager()
	if quest_manager != null and quest_manager.has_method("set_primary"):
		quest_manager.call("set_primary", id, text, options)

func _quest_manager_add_sub(id: String, text: String, parent_id: String, options: Dictionary = {}) -> void:
	var quest_manager = _get_quest_manager()
	if quest_manager != null and quest_manager.has_method("add_sub"):
		quest_manager.call("add_sub", id, text, parent_id, options)

func _quest_manager_set_progress(id: String, current: int, required: int = -1) -> void:
	var quest_manager = _get_quest_manager()
	if quest_manager != null and quest_manager.has_method("set_progress"):
		quest_manager.call("set_progress", id, current, required)

func _quest_manager_complete(id: String) -> void:
	var quest_manager = _get_quest_manager()
	if quest_manager != null and quest_manager.has_method("complete"):
		quest_manager.call("complete", id)

func _quest_manager_remove(id: String) -> void:
	var quest_manager = _get_quest_manager()
	if quest_manager != null and quest_manager.has_method("remove"):
		quest_manager.call("remove", id)
