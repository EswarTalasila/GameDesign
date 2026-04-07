extends Node2D

var _pause_menu_scene = preload("res://scenes/ui/pause_menu.tscn")
var _game_ui_scene = preload("res://scenes/ui/game_ui.tscn")
var _loading_screen_scene = preload("res://scenes/ui/loading_screen.tscn")
var _death_screen_scene = preload("res://scenes/ui/death_screen.tscn")
var _saving_icon_scene = preload("res://scenes/ui/saving_icon.tscn")
var _pause_menu: CanvasLayer = null
var _death_screen: CanvasLayer = null
var _paused: bool = false
var _game_ui: Node = null

# Item scenes — the source of truth for how things look.
# Edit these in the Godot editor to change scale, offset, textures.
var _wire_cutter_icon_scene = preload("res://scenes/items/icons/wire_cutter_icon.tscn")
var _wire_cutter_cursor_scene = preload("res://scenes/items/cursors/wire_cutter_cursor.tscn")
var _clock_icon_scene = preload("res://scenes/items/icons/clock_icon.tscn")
var _clock_hands_icon_scene = preload("res://scenes/items/icons/clock_hands_icon.tscn")
var _clock_hands_cursor_scene = preload("res://scenes/items/cursors/clock_hands_cursor.tscn")
var _map_icon_scene = preload("res://scenes/items/icons/map_icon.tscn")

# Marker tile → interactable scene table.
var _interactable_table: Array = [
	{
		"atlas_min": Vector2i(43, 6),
		"atlas_max": Vector2i(43, 6),
		"source": 0,
		"scene": preload("res://scenes/interactables/electrical_panel.tscn"),
		"no_erase": true,
	},
	{
		"atlas_min": Vector2i(33, 3),
		"atlas_max": Vector2i(38, 8),
		"source": 0,
		"scene": preload("res://scenes/interactables/locked_door.tscn"),
		"no_erase": true,
	},
	{
		"atlas_min": Vector2i(31, 37),
		"atlas_max": Vector2i(31, 37),
		"source": 1,
		"scene": preload("res://scenes/interactables/desk_clock.tscn"),
		"no_erase": true,
		"skip_if": "has_clock",
	},
	{
		"atlas_min": Vector2i(3, 19),
		"atlas_max": Vector2i(5, 20),
		"source": 1,
		"scene": preload("res://scenes/interactables/suitcase.tscn"),
		"no_erase": true,
	},
	{
		"atlas_min": Vector2i(43, 27),
		"atlas_max": Vector2i(46, 29),
		"source": 1,
		"scene": preload("res://scenes/interactables/map_board.tscn"),
		"no_erase": true,
	},
	{
		"atlas_min": Vector2i(43, 10),
		"atlas_max": Vector2i(43, 10),
		"source": 0,
		"scene": preload("res://scenes/interactables/simon_says_panel.tscn"),
		"no_erase": true,
	},
	{
		"atlas_min": Vector2i(1, 31),
		"atlas_max": Vector2i(1, 31),
		"source": 1,
		"scene": preload("res://scenes/interactables/computer_lock.tscn"),
		"no_erase": true,
	},
	{
		"atlas_min": Vector2i(0, 0),
		"atlas_max": Vector2i(0, 0),
		"source": 0,
		"scene": preload("res://scenes/pickups/wire_cutter_pickup.tscn"),
		"no_erase": false,
		"skip_if": "has_wire_cutter",
	},
	{
		"atlas_min": Vector2i(0, 0),
		"atlas_max": Vector2i(0, 0),
		"source": 1,
		"scene": preload("res://scenes/pickups/map_piece_pickup.tscn"),
		"no_erase": false,
		"props": {"piece_id": 1},
	},
	{
		"atlas_min": Vector2i(0, 0),
		"atlas_max": Vector2i(0, 0),
		"source": 2,
		"scene": preload("res://scenes/pickups/map_piece_pickup.tscn"),
		"no_erase": false,
		"props": {"piece_id": 2},
	},
	{
		"atlas_min": Vector2i(0, 0),
		"atlas_max": Vector2i(0, 0),
		"source": 3,
		"scene": preload("res://scenes/pickups/map_piece_pickup.tscn"),
		"no_erase": false,
		"props": {"piece_id": 3},
	},
	{
		"atlas_min": Vector2i(0, 0),
		"atlas_max": Vector2i(0, 0),
		"source": 4,
		"scene": preload("res://scenes/pickups/map_piece_pickup.tscn"),
		"no_erase": false,
		"props": {"piece_id": 4},
	},
]

# ── Inventory System ──
# Each item: { id, icon_scene, cursor_scene (or null), on_click, instance }
var _inventory: Array[Dictionary] = []
var _slots: Array[Node2D] = []
const MAX_SLOTS = 4
var _active_tool: String = ""

func _ready() -> void:
	# Detect variant from scene filename so direct-run works correctly
	var scene_file = get_tree().current_scene.scene_file_path.get_file()
	var regex = RegEx.new()
	regex.compile("escape_room_(\\d+)")
	var result = regex.search(scene_file)
	if result:
		GameState.current_variant = int(result.get_string(1))

	GameState.wire_cutter_mode = false
	GameState.conductor_watching = false
	GameState.lore_open = false
	CustomCursor.reset_cursor()

	# Clear any stale dialogue state from previous scene/reload
	DialogueManager.dialogue_ended.emit(null)

	_scan_interactables()
	_setup_hud()
	_show_saving_icon()
	GameState.wire_cutter_collected.connect(_on_wire_cutter_collected)
	GameState.clock_collected.connect(_on_clock_collected)
	GameState.clock_hands_collected.connect(_on_clock_hands_collected)
	GameState.clock_hands_added.connect(_on_clock_hands_inserted)
	GameState.map_piece_collected.connect(_on_map_piece_collected)
	GameState.player_died.connect(_on_player_died)

	_setup_controls_hint()

	# Variant 3 first-entry dialogue
	if GameState.current_variant == 3 and not GameState.get("variant3_dialogue_shown"):
		GameState.set("variant3_dialogue_shown", true)
		_play_variant3_dialogue()

# ── HUD Setup ──

func _setup_hud() -> void:
	_game_ui = _game_ui_scene.instantiate()
	add_child(_game_ui)
	for i in range(1, MAX_SLOTS + 1):
		_slots.append(_game_ui.get_node("UILayer/InventoryPanel/Slot%d" % i))
	# Restore from GameState
	if GameState.has_wire_cutter:
		add_item("wire_cutter", _wire_cutter_icon_scene, _wire_cutter_cursor_scene, _on_wire_cutter_clicked)
	if GameState.has_clock:
		add_item("clock", _clock_icon_scene, null, _on_clock_clicked)
		if GameState.clock_hands_inserted:
			set_item_active("clock")
	if GameState.has_clock_hands and not GameState.clock_hands_inserted:
		add_item("clock_hands", _clock_hands_icon_scene, _clock_hands_cursor_scene, _on_clock_hands_clicked)
	var _pieces_in_hand = 0
	for p in GameState.collected_map_pieces:
		if p not in GameState.board_pieces:
			_pieces_in_hand += 1
	if _pieces_in_hand > 0 and not GameState.map_assembled:
		add_item("map", _map_icon_scene, null, func(): pass)
		_update_map_count()

# ── Inventory API ──

func add_item(id: String, icon_scene: PackedScene, cursor_scene, on_click: Callable) -> void:
	for item in _inventory:
		if item["id"] == id:
			return
	if _inventory.size() >= MAX_SLOTS:
		return
	var idx = _inventory.size()
	var slot = _slots[idx]
	var instance = icon_scene.instantiate()
	slot.add_child(instance)
	slot.visible = true
	_inventory.append({
		"id": id,
		"icon_scene": icon_scene,
		"cursor_scene": cursor_scene,
		"on_click": on_click,
		"instance": instance,
	})

func remove_item(id: String) -> void:
	var idx = -1
	for i in range(_inventory.size()):
		if _inventory[i]["id"] == id:
			idx = i
			break
	if idx == -1:
		return
	_inventory[idx]["instance"].queue_free()
	_inventory.remove_at(idx)
	_rebuild_slots()

func set_item_active(id: String) -> void:
	for item in _inventory:
		if item["id"] == id and item["instance"] is Sprite2D:
			if item["instance"].has_meta("active_texture"):
				item["instance"].texture = item["instance"].get_meta("active_texture")
			return

func set_item_default(id: String) -> void:
	for item in _inventory:
		if item["id"] == id and item["instance"] is Sprite2D:
			if item["instance"].has_meta("default_texture"):
				item["instance"].texture = item["instance"].get_meta("default_texture")
			return

func _rebuild_slots() -> void:
	for i in range(MAX_SLOTS):
		var slot = _slots[i]
		for child in slot.get_children():
			child.queue_free()
		if i < _inventory.size():
			var item = _inventory[i]
			var instance = item["icon_scene"].instantiate()
			slot.add_child(instance)
			item["instance"] = instance
			slot.visible = true
		else:
			slot.visible = false

# ── Tool Activation ──

func _activate_tool(id: String) -> void:
	if _active_tool != "":
		_deactivate_tool()
	_active_tool = id
	set_item_active(id)
	# Find the cursor scene for this item
	for item in _inventory:
		if item["id"] == id and item["cursor_scene"] != null:
			CustomCursor.set_cursor_scene(item["cursor_scene"])
			break
	if id == "wire_cutter":
		GameState.wire_cutter_mode = true

func _deactivate_tool() -> void:
	if _active_tool == "wire_cutter":
		GameState.wire_cutter_mode = false
	set_item_default(_active_tool)
	_active_tool = ""
	CustomCursor.reset_cursor()

# ── Item Callbacks ──

func _on_wire_cutter_collected() -> void:
	add_item("wire_cutter", _wire_cutter_icon_scene, _wire_cutter_cursor_scene, _on_wire_cutter_clicked)

func _on_wire_cutter_clicked() -> void:
	if _active_tool == "wire_cutter":
		_deactivate_tool()
	else:
		_activate_tool("wire_cutter")

func _on_clock_collected() -> void:
	add_item("clock", _clock_icon_scene, null, _on_clock_clicked)

func _on_clock_clicked() -> void:
	if get_tree().paused:
		# If board UI is open and map assembled, place clock on map
		var board_ui = get_tree().root.find_child("MapBoardUI", true, false)
		if board_ui and GameState.map_assembled and GameState.clock_hands_inserted and not GameState.clock_on_map:
			board_ui.place_clock_from_inventory()
		return
	_open_clock_ui()

func _on_clock_hands_collected() -> void:
	add_item("clock_hands", _clock_hands_icon_scene, _clock_hands_cursor_scene, _on_clock_hands_clicked)

func _on_clock_hands_clicked() -> void:
	if _active_tool == "clock_hands":
		_deactivate_tool()
	else:
		_activate_tool("clock_hands")

func _on_map_piece_collected(_piece_id: int) -> void:
	# Add map icon (add_item ignores if already exists)
	add_item("map", _map_icon_scene, null, func(): pass)
	_update_map_count()

func _update_map_count() -> void:
	for item in _inventory:
		if item["id"] == "map" and item["instance"]:
			var number_sprite = item["instance"].get_node_or_null("Number")
			if number_sprite:
				var in_hand = 0
				for p in GameState.collected_map_pieces:
					if p not in GameState.board_pieces:
						in_hand += 1
				number_sprite.texture = load("res://assets/ui/numbers/%d.png" % clampi(in_hand, 0, 9))

func _on_clock_hands_inserted() -> void:
	_deactivate_tool()
	set_item_active("clock")
	remove_item("clock_hands")
	_update_map_count()

func pulse_inventory_item(id: String) -> void:
	for item in _inventory:
		if item["id"] == id and item["instance"]:
			var node = item["instance"]
			# Find the actual Sprite2D to pulse
			var target = node
			if not node is Sprite2D:
				for child in node.get_children():
					if child is Sprite2D:
						target = child
						break
			var base_scale = target.scale
			# Stop any existing pulse
			if target.has_meta("pulse_tween"):
				var old: Tween = target.get_meta("pulse_tween")
				if old and old.is_valid():
					old.kill()
				target.scale = base_scale
			var tween = create_tween().set_loops(0)  # infinite
			tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tween.tween_property(target, "scale", base_scale * 1.1, 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
			tween.tween_property(target, "scale", base_scale, 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
			target.set_meta("pulse_tween", tween)

func stop_pulse(id: String) -> void:
	for item in _inventory:
		if item["id"] == id and item["instance"]:
			var node = item["instance"]
			var target = node
			if not node is Sprite2D:
				for child in node.get_children():
					if child is Sprite2D:
						target = child
						break
			if target.has_meta("pulse_tween"):
				var tween: Tween = target.get_meta("pulse_tween")
				if tween and tween.is_valid():
					tween.kill()
				target.remove_meta("pulse_tween")

# ── Input ──

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _active_tool != "":
			_deactivate_tool()
			return
		if _paused:
			_resume()
		else:
			_pause()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse = get_viewport().get_mouse_position()
		if event.pressed:
			if _check_pause_button(mouse):
				get_viewport().set_input_as_handled()
				return
			_handle_inventory_click(mouse)
		else:
			_release_pause_button()

var _pause_normal_tex = preload("res://assets/ui/buttons/play_pause/pause_normal.png")
var _pause_pressed_tex = preload("res://assets/ui/buttons/play_pause/pause_pressed.png")
var _pause_btn_held: bool = false

func _release_pause_button() -> void:
	if not _pause_btn_held:
		return
	_pause_btn_held = false
	var pause_slot = _game_ui.get_node_or_null("UILayer/InventoryPanel/PauseSlot")
	if pause_slot:
		pause_slot.texture = _pause_normal_tex
	if not _paused:
		_pause()

func _check_pause_button(mouse: Vector2) -> bool:
	var pause_slot = _game_ui.get_node_or_null("UILayer/InventoryPanel/PauseSlot")
	if pause_slot == null or not pause_slot.texture:
		return false
	var pos = pause_slot.global_position
	var tex_size = Vector2(pause_slot.texture.get_width(), pause_slot.texture.get_height()) * pause_slot.global_scale
	var half = tex_size / 2.0
	if Rect2(pos - half, tex_size).has_point(mouse):
		if not _paused:
			pause_slot.texture = _pause_pressed_tex
			_pause_btn_held = true
		return true
	return false

func _handle_inventory_click(mouse: Vector2) -> bool:
	for i in range(_inventory.size()):
		var slot = _slots[i]
		if slot.visible:
			var slot_pos = slot.global_position
			var half = Vector2(48, 48)
			if Rect2(slot_pos - half, half * 2).has_point(mouse):
				_inventory[i]["on_click"].call()
				get_viewport().set_input_as_handled()
				return true
	return false

# ── Clock UI ──

var _clock_ui_scene = preload("res://scenes/ui/clock_ui.tscn")
var _clock_ui: CanvasLayer = null

func _open_clock_ui() -> void:
	if _clock_ui != null:
		return
	get_tree().paused = true
	_clock_ui = _clock_ui_scene.instantiate()
	_clock_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	_clock_ui.clock_closed.connect(_close_clock_ui)
	_clock_ui.hands_inserted.connect(_on_clock_hands_inserted)
	_clock_ui.variant_selected.connect(_on_variant_selected)
	get_tree().root.add_child(_clock_ui)
	# Pulse clock hands if player has them to insert
	if GameState.has_clock_hands and not GameState.clock_hands_inserted:
		pulse_inventory_item("clock_hands")

func _close_clock_ui() -> void:
	get_tree().paused = false
	stop_pulse("clock_hands")
	if _clock_ui:
		_clock_ui.queue_free()
		_clock_ui = null

func _on_variant_selected(variant: int) -> void:
	_close_clock_ui()
	_show_saving_icon()
	GameState.current_variant = variant
	var scene_path = "res://escape_room_%d.tscn" % variant
	var loading = _loading_screen_scene.instantiate()
	loading.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(loading)
	loading.transition_to(scene_path)

# ── Tile Scanner ──

var _spawned_entries: Array[int] = []  # indices of already-spawned entries

func _scan_interactables() -> void:
	_spawned_entries.clear()
	_scan_node_recursive(self)

func _scan_node_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is TileMapLayer:
			_scan_layer(child)
		else:
			_scan_node_recursive(child)

func _scan_layer(layer: TileMapLayer) -> void:
	var ts = layer.tile_set
	if ts == null:
		return
	var tile_size = Vector2(ts.tile_size)

	for entry_idx in range(_interactable_table.size()):
		var entry = _interactable_table[entry_idx]
		var skip_flag = entry.get("skip_if", "")
		if skip_flag != "" and GameState.get(skip_flag):
			_erase_matching_tiles(layer, entry)
			continue
		if entry_idx in _spawned_entries:
			continue

		var atlas_min: Vector2i = entry["atlas_min"]
		var atlas_max: Vector2i = entry["atlas_max"]
		var source_id: int = entry["source"]
		var matched_cells: Array[Vector2i] = []

		for cell in layer.get_used_cells():
			var cell_source = layer.get_cell_source_id(cell)
			var cell_atlas = layer.get_cell_atlas_coords(cell)
			if source_id >= 0 and cell_source != source_id:
				continue
			if cell_atlas.x >= atlas_min.x and cell_atlas.x <= atlas_max.x \
			   and cell_atlas.y >= atlas_min.y and cell_atlas.y <= atlas_max.y:
				matched_cells.append(cell)

		if matched_cells.is_empty():
			continue

		var min_cell = matched_cells[0]
		var max_cell = matched_cells[0]
		for cell in matched_cells:
			min_cell = Vector2i(mini(min_cell.x, cell.x), mini(min_cell.y, cell.y))
			max_cell = Vector2i(maxi(max_cell.x, cell.x), maxi(max_cell.y, cell.y))

		var top_left_px = Vector2(min_cell) * tile_size
		var bottom_right_px = Vector2(max_cell + Vector2i.ONE) * tile_size
		var center_px = (top_left_px + bottom_right_px) / 2.0

		var instance = entry["scene"].instantiate()
		instance.position = center_px
		# Apply props (e.g. piece_id) to the spawned instance
		var props = entry.get("props", {})
		for key in props:
			if key in instance:
				instance.set(key, props[key])
		add_child(instance)
		_spawned_entries.append(entry_idx)

		if not entry.get("no_erase", false):
			for cell in matched_cells:
				layer.erase_cell(cell)

func _erase_matching_tiles(layer: TileMapLayer, entry: Dictionary) -> void:
	var atlas_min: Vector2i = entry["atlas_min"]
	var atlas_max: Vector2i = entry["atlas_max"]
	var source_id: int = entry["source"]
	for cell in layer.get_used_cells():
		var cell_source = layer.get_cell_source_id(cell)
		var cell_atlas = layer.get_cell_atlas_coords(cell)
		if source_id >= 0 and cell_source != source_id:
			continue
		if cell_atlas.x >= atlas_min.x and cell_atlas.x <= atlas_max.x \
		   and cell_atlas.y >= atlas_min.y and cell_atlas.y <= atlas_max.y:
			layer.erase_cell(cell)

# ── Pause Menu ──

func _pause() -> void:
	_paused = true
	get_tree().paused = true
	_pause_menu = _pause_menu_scene.instantiate()
	_pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_menu)
	_pause_menu.resume_requested.connect(_resume)
	_pause_menu.restart_requested.connect(_restart)
	_pause_menu.quit_requested.connect(_quit)

func _resume() -> void:
	_paused = false
	get_tree().paused = false
	if _pause_menu:
		_pause_menu.queue_free()
		_pause_menu = null

func _restart() -> void:
	_paused = false
	get_tree().paused = false
	var scene_path = "res://escape_room_%d.tscn" % GameState.current_variant
	var loading = _loading_screen_scene.instantiate()
	loading.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(loading)
	loading.transition_to(scene_path)

func _quit() -> void:
	get_tree().quit()

# ── Death Screen ──

func _on_player_died() -> void:
	get_tree().paused = true
	_death_screen = _death_screen_scene.instantiate()
	_death_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	_death_screen.reload_requested.connect(_on_death_reload)
	get_tree().root.add_child(_death_screen)

func _on_death_reload() -> void:
	get_tree().paused = false
	if _death_screen:
		_death_screen.queue_free()
		_death_screen = null
	GameState.reset_health()
	var scene_path = "res://escape_room_%d.tscn" % GameState.current_variant
	var loading = _loading_screen_scene.instantiate()
	loading.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(loading)
	loading.transition_to(scene_path)

# ── Controls Hint ──

var _controls_open: bool = false
var _controls_body: VBoxContainer = null
var _controls_chevron: Label = null
var _controls_layer: CanvasLayer = null

func _setup_controls_hint() -> void:
	_controls_layer = CanvasLayer.new()
	_controls_layer.layer = 12
	add_child(_controls_layer)

	var dot_gothic = load("res://assets/fonts/DotGothic16-Regular.ttf")

	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(12, 12)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.45)
	style.border_color = Color(0.5, 0.45, 0.35, 0.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.content_margin_left = 14
	style.content_margin_right = 14
	panel.add_theme_stylebox_override("panel", style)
	_controls_layer.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# Clickable header row
	var header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 6)
	vbox.add_child(header_row)

	var header = Label.new()
	header.text = "CONTROLS"
	header.add_theme_font_override("font", dot_gothic)
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.75, 0.7, 0.55))
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.add_child(header)

	_controls_chevron = Label.new()
	_controls_chevron.text = "▼"
	_controls_chevron.add_theme_font_override("font", dot_gothic)
	_controls_chevron.add_theme_font_size_override("font_size", 18)
	_controls_chevron.add_theme_color_override("font_color", Color(0.75, 0.7, 0.55))
	_controls_chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.add_child(_controls_chevron)

	# Body (hidden by default)
	_controls_body = VBoxContainer.new()
	_controls_body.add_theme_constant_override("separation", 6)
	_controls_body.visible = false
	vbox.add_child(_controls_body)

	var sep = HSeparator.new()
	var sep_style = StyleBoxFlat.new()
	sep_style.bg_color = Color(0.5, 0.45, 0.3, 0.4)
	sep_style.content_margin_top = 1.0
	sep_style.content_margin_bottom = 1.0
	sep.add_theme_stylebox_override("separator", sep_style)
	_controls_body.add_child(sep)

	var lines = [
		["[E]", "Interact"],
		["[Esc]", "Pause / Close"],
		["[Space]", "Attack"],
		["[WASD]", "Move"],
		["[Backspace]", "Delete input"],
		["[Enter]", "Confirm"],
	]
	for pair in lines:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_controls_body.add_child(row)
		var key_label = Label.new()
		key_label.text = pair[0]
		key_label.add_theme_font_override("font", dot_gothic)
		key_label.add_theme_font_size_override("font_size", 18)
		key_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
		key_label.custom_minimum_size = Vector2(100, 0)
		key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(key_label)
		var action_label = Label.new()
		action_label.text = pair[1]
		action_label.add_theme_font_override("font", dot_gothic)
		action_label.add_theme_font_size_override("font_size", 18)
		action_label.add_theme_color_override("font_color", Color(0.7, 0.68, 0.6))
		action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(action_label)

	# Make the panel clickable
	panel.gui_input.connect(_on_controls_panel_clicked)

func _on_controls_panel_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_controls_open = not _controls_open
		_controls_body.visible = _controls_open
		_controls_chevron.text = "▲" if _controls_open else "▼"

# ── Variant Dialogues ──

func _play_variant3_dialogue() -> void:
	await get_tree().create_timer(1.5).timeout
	if not is_inside_tree() or get_tree().paused:
		return
	var reactions = load("res://dialogues/player_reactions.dialogue")
	DialogueManager.show_dialogue_balloon(reactions, "enter_variant_3")
	await DialogueManager.dialogue_ended

# ── Saving Icon ──

func _show_saving_icon() -> void:
	var layer = CanvasLayer.new()
	layer.layer = 11  # above HUD (10)
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var icon = _saving_icon_scene.instantiate()
	icon.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(icon)
	get_tree().root.add_child(layer)
	# Clean up the CanvasLayer when the icon frees itself
	icon.tree_exited.connect(layer.queue_free)
