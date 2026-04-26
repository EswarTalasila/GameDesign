extends Node2D

## Variant coordinator — manages the jungle game loop.
## Controls: clock countdown, variant loading/switching, bonfire fire-of-time,
## UI layering, pause/death, golden ticket ritual.
##
## Expected child structure:
##   GameWorld (Node2D, y_sort_enabled)
##     VariantContainer (Node2D)  — active variant scene loaded here
##     Player (CharacterBody2D)
##   GameUI (instance of game_ui.tscn)

# ── Variant scenes (loaded on demand) ──
const VARIANT_PATHS: Array[String] = [
	"res://scenes/jungle/variants/variant_1.tscn",
	"res://scenes/jungle/variants/variant_2.tscn",
	"res://scenes/jungle/variants/variant_3.tscn",
	"res://scenes/jungle/variants/variant_4.tscn",
	"res://scenes/jungle/variants/variant_5.tscn",
	"res://scenes/jungle/variants/variant_6.tscn",
	"res://scenes/jungle/variants/variant_7.tscn",
]

# ── Preloaded UI / audio ──
var _pause_menu_scene = preload("res://scenes/ui/pause_menu.tscn")
var _loading_screen_scene = preload("res://scenes/ui/loading_screen.tscn")
var _death_screen_scene = preload("res://scenes/ui/death_screen.tscn")
var _saving_icon_scene = preload("res://scenes/ui/saving_icon.tscn")

var _ambience_stream = preload("res://assets/sounds/dungeon_ambience.mp3")
var _ambience_stream_2 = preload("res://assets/sounds/dungeon_ambience_2.mp3")

# ── Config ──
@export var starting_variant: int = 0  ## 0-indexed into VARIANT_PATHS
@export var clock_duration: float = 120.0  ## seconds before fire dies
## "auto" = each variant uses its own season setting. Otherwise forces all variants to this season.
@export_enum("auto", "jungle", "autumn", "winter", "wasteland") var season: String = "auto"

# ── Nodes ──
@onready var player: CharacterBody2D = $GameWorld/Player
@onready var variant_container: Node2D = $GameWorld/VariantContainer

# ── Season ──
var _season_swapper: SeasonSwapper

# ── State ──
var current_variant: int = -1
var _active_section: Node2D = null
var _clock_remaining: float = 0.0
var _clock_running: bool = false
var _paused: bool = false
var _pause_menu: CanvasLayer = null
var _death_screen: CanvasLayer = null
var _clock_ui: CanvasLayer = null

# ── Signals ──
signal variant_changed(variant_index: int)
signal clock_tick(remaining: float)
signal fire_died

func _ready() -> void:
	# Reset cursor to default (project-3 scene-based cursor handles itself)
	CustomCursor.reset_cursor()
	GameState.ensure_starting_special_tickets(6)
	GameState.ensure_starting_voodoo_dolls(1)
	GameState.ensure_statue_ritual_seeded()
	GameState.ensure_starting_clock()
	_season_swapper = SeasonSwapper.new()
	add_child(_season_swapper)
	_clock_remaining = clock_duration
	_load_variant(starting_variant)
	_setup_pause()
	_connect_signals()

func _process(delta: float) -> void:
	if _paused:
		return
	if _clock_running:
		_clock_remaining -= delta
		clock_tick.emit(_clock_remaining)
		if _clock_remaining <= 0.0:
			_clock_remaining = 0.0
			_clock_running = false
			fire_died.emit()
			_on_fire_died()
	GameState.tick_trial_time(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _clock_ui:
			_close_clock()
			get_viewport().set_input_as_handled()
			return
		if _has_blocking_ui_overlay():
			get_viewport().set_input_as_handled()
			return
		_toggle_pause()
	if event.is_action_pressed("toggle_inventory") and GameState.has_clock:
		if _clock_ui:
			_close_clock()
		else:
			_open_clock()
		get_viewport().set_input_as_handled()

# ── Variant loading ──

func _load_variant(index: int) -> void:
	if index < 0 or index >= VARIANT_PATHS.size():
		push_error("Invalid variant index: ", index)
		return

	_detach_player_from_active_section()

	# Free current variant
	if _active_section:
		_active_section.queue_free()
		_active_section = null

	var scene = load(VARIANT_PATHS[index])
	if scene == null:
		push_error("Failed to load variant: ", VARIANT_PATHS[index])
		return

	_active_section = scene.instantiate()
	# If coordinator has a forced season, override the variant's setting before _ready
	if season != "auto" and "season" in _active_section:
		_active_section.season = season
	# Otherwise the variant keeps whatever season was set in its own inspector
	variant_container.add_child(_active_section)
	current_variant = index

	# Teleport player to this variant's spawn point
	var spawn = _active_section.get_node_or_null("PlayerSpawn")
	if spawn and player:
		player.global_position = spawn.global_position

	_attach_player_to_active_section()

	variant_changed.emit(index)
	GameState.current_variant = index + 1

func _detach_player_from_active_section() -> void:
	if not player:
		return
	if not _active_section:
		return
	if player.get_parent() != _active_section:
		return
	var global_pos := player.global_position
	_active_section.remove_child(player)
	$GameWorld.add_child(player)
	player.global_position = global_pos

func _attach_player_to_active_section() -> void:
	if not player:
		return
	if not _active_section:
		return
	if player.get_parent() == _active_section:
		return
	var global_pos := player.global_position
	var parent := player.get_parent()
	if parent:
		parent.remove_child(player)
	_active_section.add_child(player)
	player.global_position = global_pos

func switch_variant(index: int) -> void:
	## Call this to change the active map variant (e.g., from clock interaction).
	_load_variant(index)

func advance_variant() -> void:
	## Move to next variant (wraps around).
	var next = (current_variant + 1) % VARIANT_PATHS.size()
	switch_variant(next)

# ── Season switching ──

func set_season(new_season: String) -> void:
	## Change the season. Repaints all tiles on the current variant immediately.
	season = new_season
	if _active_section and _season_swapper:
		var effective = new_season if new_season != "auto" else "jungle"
		_active_section.season = effective
		_season_swapper.swap_season(effective, _active_section)
		if _active_section.has_method("refresh_weather"):
			_active_section.refresh_weather()

# ── Clock / fire of time ──

func start_clock() -> void:
	_clock_running = true

func stop_clock() -> void:
	_clock_running = false

func feed_fire(seconds: float) -> void:
	## Add time back to the clock (bonfire interaction).
	_clock_remaining = min(_clock_remaining + seconds, clock_duration)

func _on_fire_died() -> void:
	# Fire ran out — player loses. Show death screen or trigger consequence.
	if GameState.has_method("damage_player"):
		GameState.damage_player(GameState.player_health)

# ── Pause ──

func _setup_pause() -> void:
	var inventory_panel: Node = get_node_or_null("GameUI/UILayer/InventoryPanel")
	if inventory_panel and inventory_panel.has_signal("pause_requested"):
		inventory_panel.pause_requested.connect(_on_hud_pause_requested)

func _has_blocking_ui_overlay() -> bool:
	if _clock_ui:
		return true
	for group in ["statue_ui_overlay", "campfire_ui_overlay", "boon_ui_overlay"]:
		for node in get_tree().get_nodes_in_group(group):
			if node.has_method("is_blocking_pause") and node.is_blocking_pause():
				return true
			if node is CanvasItem and node.visible:
				return true
	return false

func _toggle_pause() -> void:
	if _paused:
		_resume()
	else:
		_pause()

func _on_hud_pause_requested() -> void:
	if _has_blocking_ui_overlay():
		return
	if not _paused:
		_pause()

func _pause() -> void:
	_paused = true
	_set_hud_pause_state(true)
	get_tree().paused = true
	_pause_menu = _pause_menu_scene.instantiate()
	add_child(_pause_menu)
	_pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	if _pause_menu.has_signal("resume_requested"):
		_pause_menu.resume_requested.connect(_resume)
	if _pause_menu.has_signal("restart_requested"):
		_pause_menu.restart_requested.connect(_restart)
	if _pause_menu.has_signal("quit_requested"):
		_pause_menu.quit_requested.connect(_quit)

func _resume() -> void:
	_paused = false
	get_tree().paused = false
	_set_hud_pause_state(false)
	if _pause_menu:
		_pause_menu.queue_free()
		_pause_menu = null

func _restart() -> void:
	_paused = false
	get_tree().paused = false
	_set_hud_pause_state(false)
	get_tree().reload_current_scene()

func _quit() -> void:
	get_tree().quit()

func _set_hud_pause_state(paused: bool) -> void:
	var inventory_panel: Node = get_node_or_null("GameUI/UILayer/InventoryPanel")
	if inventory_panel and inventory_panel.has_method("set_paused"):
		inventory_panel.set_paused(paused)

# ── GameState signals ──

func _connect_signals() -> void:
	if not GameState.player_died.is_connected(_on_player_died):
		GameState.player_died.connect(_on_player_died)
	if not GameState.inventory_selection_changed.is_connected(_on_inventory_selection_changed):
		GameState.inventory_selection_changed.connect(_on_inventory_selection_changed)

func _on_inventory_selection_changed(item_id: String) -> void:
	if item_id != GameState.ITEM_CLOCK:
		return
	GameState.clear_selected_inventory_item()
	_open_clock()

func _open_clock() -> void:
	if _clock_ui or _paused:
		return
	var scene: PackedScene = load("res://scenes/ui/clock_ui.tscn")
	_clock_ui = scene.instantiate()
	_clock_ui.clock_closed.connect(_on_clock_closed)
	_clock_ui.variant_selected.connect(_on_clock_variant_selected)
	add_child(_clock_ui)

func _close_clock() -> void:
	if _clock_ui:
		if _clock_ui.has_method("close"):
			_clock_ui.close()
		else:
			_on_clock_closed()

func _on_clock_closed() -> void:
	if _clock_ui:
		_clock_ui.queue_free()
	_clock_ui = null

func _on_clock_variant_selected(variant: int) -> void:
	switch_variant(variant - 1)
	_on_clock_closed()

func _on_player_died() -> void:
	_clock_running = false
	_death_screen = _death_screen_scene.instantiate()
	add_child(_death_screen)
