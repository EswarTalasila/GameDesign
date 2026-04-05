extends Node2D

var _pause_menu_scene = preload("res://scenes/ui/pause_menu.tscn")
var _game_ui_scene = preload("res://scenes/ui/game_ui.tscn")
var _pause_menu: CanvasLayer = null
var _paused: bool = false
var _game_ui: Node = null

# Item scenes — edit these in the editor to control scale, offset, etc.
var _wire_cutter_icon_scene = preload("res://scenes/items/wire_cutter_icon.tscn")
var _wire_cutter_cursor_scene = preload("res://scenes/items/wire_cutter_cursor.tscn")
var _wire_cutter_cursor_click = preload("res://assets/ui/wire_cutter/cursor_click.png")
var _wire_cutter_icon_active_tex = preload("res://assets/ui/wire_cutter/icon_active.png")
var _wire_cutter_icon_default_tex = preload("res://assets/ui/wire_cutter/icon_default.png")

var _clock_icon_scene = preload("res://scenes/items/clock_icon.tscn")
var _clock_hands_icon_scene = preload("res://scenes/items/clock_hands_icon.tscn")
var _clock_hands_cursor_scene = preload("res://scenes/items/clock_hands_cursor.tscn")
var _clock_icon_no_hands_tex = preload("res://assets/ui/clock/icon_no_hands.png")
var _clock_icon_hands_tex = preload("res://assets/ui/clock/icon_hands.png")
var _clock_hand_icon_tex = preload("res://assets/ui/clock/clock_hand_icon.png")

# Marker tile → interactable scene table.
var _interactable_table: Array = [
	{
		"atlas_min": Vector2i(42, 4),
		"atlas_max": Vector2i(44, 7),
		"source": -1,
		"scene": preload("res://scenes/interactables/electrical_panel.tscn"),
		"no_erase": true,
	},
	{
		"atlas_min": Vector2i(33, 3),
		"atlas_max": Vector2i(38, 8),
		"source": -1,
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
		"atlas_min": Vector2i(0, 0),
		"atlas_max": Vector2i(0, 0),
		"source": 0,
		"scene": preload("res://scenes/pickups/wire_cutter_pickup.tscn"),
		"no_erase": false,
		"skip_if": "has_wire_cutter",
	},
]

# ── Dynamic inventory slots ──
# Each entry: { "id", "icon_scene", "on_click", "instance" (runtime) }
var _inventory_items: Array[Dictionary] = []
var _slot_nodes: Array[Node] = []  # The Slot1-4 parent nodes
const MAX_SLOTS = 4

# Track which tool cursor is active
var _active_tool: String = ""

func _ready() -> void:
	GameState.has_wire_cutter = false
	GameState.wire_cutter_mode = false
	CustomCursor.reset_cursor()

	_scan_interactables()
	_setup_hud()
	GameState.wire_cutter_collected.connect(_on_wire_cutter_collected)
	GameState.wire_cutter_mode_changed.connect(func(_a): pass)
	GameState.clock_collected.connect(_on_clock_collected)
	GameState.clock_hands_collected.connect(_on_clock_hands_collected)
	GameState.clock_hands_added.connect(_on_clock_hands_inserted)

# ── HUD ──

func _setup_hud() -> void:
	_game_ui = _game_ui_scene.instantiate()
	add_child(_game_ui)
	for i in range(1, MAX_SLOTS + 1):
		var slot = _game_ui.get_node("UILayer/InventoryPanel/Slot%d" % i)
		_slot_nodes.append(slot)
		slot.visible = false
	# Restore inventory from GameState
	if GameState.has_wire_cutter:
		_add_inventory_item("wire_cutter", _wire_cutter_icon_scene, _on_wire_cutter_clicked)
	if GameState.has_clock:
		_add_inventory_item("clock", _clock_icon_scene, _on_clock_clicked)
	if GameState.has_clock_hands and not GameState.clock_hands_inserted:
		_add_inventory_item("clock_hands", _clock_hands_icon_scene, _on_clock_hands_clicked)

func _add_inventory_item(id: String, icon_scene: PackedScene, on_click: Callable) -> void:
	for item in _inventory_items:
		if item["id"] == id:
			return
	if _inventory_items.size() >= MAX_SLOTS:
		return
	var idx = _inventory_items.size()
	var instance = icon_scene.instantiate()
	var slot_node = _slot_nodes[idx]
	# Clear any existing children
	for child in slot_node.get_children():
		child.queue_free()
	slot_node.add_child(instance)
	slot_node.visible = true
	_inventory_items.append({"id": id, "icon_scene": icon_scene, "on_click": on_click, "instance": instance})

func _update_inventory_texture(id: String, texture: Texture2D) -> void:
	for item in _inventory_items:
		if item["id"] == id and item["instance"] is Sprite2D:
			item["instance"].texture = texture
			return

func _remove_inventory_item(id: String) -> void:
	var remove_idx = -1
	for i in range(_inventory_items.size()):
		if _inventory_items[i]["id"] == id:
			remove_idx = i
			break
	if remove_idx == -1:
		return
	# Remove instance
	var old = _inventory_items[remove_idx]["instance"]
	if old and old.get_parent():
		old.get_parent().remove_child(old)
		old.queue_free()
	_inventory_items.remove_at(remove_idx)
	# Rebuild all slots
	for i in range(MAX_SLOTS):
		var slot = _slot_nodes[i]
		# Clear slot
		for child in slot.get_children():
			child.get_parent().remove_child(child)
			child.queue_free()
		if i < _inventory_items.size():
			var item = _inventory_items[i]
			var new_instance = item["icon_scene"].instantiate()
			slot.add_child(new_instance)
			item["instance"] = new_instance
			slot.visible = true
		else:
			slot.visible = false

# ── Tool activation ──

func _activate_tool(tool_id: String) -> void:
	if _active_tool != "":
		_deactivate_tool()
	_active_tool = tool_id
	match tool_id:
		"wire_cutter":
			GameState.wire_cutter_mode = true
			_update_inventory_texture("wire_cutter", _wire_cutter_icon_active_tex)
			CustomCursor.set_cursor_scene(_wire_cutter_cursor_scene, _wire_cutter_cursor_click)
		"clock_hands":
			CustomCursor.set_cursor_scene(_clock_hands_cursor_scene)

func _deactivate_tool() -> void:
	match _active_tool:
		"wire_cutter":
			GameState.wire_cutter_mode = false
			_update_inventory_texture("wire_cutter", _wire_cutter_icon_default_tex)
		"clock_hands":
			pass
	_active_tool = ""
	CustomCursor.reset_cursor()

# ── Item callbacks ──

func _on_wire_cutter_collected() -> void:
	_add_inventory_item("wire_cutter", _wire_cutter_icon_scene, _on_wire_cutter_clicked)

func _on_wire_cutter_clicked() -> void:
	if _active_tool == "wire_cutter":
		_deactivate_tool()
	else:
		_activate_tool("wire_cutter")

func _on_clock_collected() -> void:
	_add_inventory_item("clock", _clock_icon_scene, _on_clock_clicked)

func _on_clock_clicked() -> void:
	_open_clock_ui()

func _on_clock_hands_collected() -> void:
	_add_inventory_item("clock_hands", _clock_hands_icon_scene, _on_clock_hands_clicked)

func _on_clock_hands_clicked() -> void:
	if _active_tool == "clock_hands":
		_deactivate_tool()
	else:
		_activate_tool("clock_hands")

func _on_clock_hands_inserted() -> void:
	_deactivate_tool()
	_update_inventory_texture("clock", _clock_icon_hands_tex)
	_remove_inventory_item("clock_hands")

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

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_inventory_click(get_viewport().get_mouse_position())

func _handle_inventory_click(mouse: Vector2) -> bool:
	for i in range(_inventory_items.size()):
		var slot = _slot_nodes[i]
		if slot.visible:
			var slot_pos = slot.global_position
			var half = Vector2(24, 24)
			if Rect2(slot_pos - half, half * 2).has_point(mouse):
				_inventory_items[i]["on_click"].call()
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
	get_tree().root.add_child(_clock_ui)

func _close_clock_ui() -> void:
	get_tree().paused = false
	if _clock_ui:
		_clock_ui.queue_free()
		_clock_ui = null

# ── Tile Scanner ──

func _scan_interactables() -> void:
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

	for entry in _interactable_table:
		var skip_flag = entry.get("skip_if", "")
		if skip_flag != "" and GameState.get(skip_flag):
			_erase_matching_tiles(layer, entry)
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
		add_child(instance)

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
	get_tree().reload_current_scene()

func _quit() -> void:
	get_tree().quit()
