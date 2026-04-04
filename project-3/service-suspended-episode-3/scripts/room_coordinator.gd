extends Node2D

var _pause_menu_scene = preload("res://scenes/ui/pause_menu.tscn")
var _game_ui_scene = preload("res://scenes/ui/game_ui.tscn")
var _pause_menu: CanvasLayer = null
var _paused: bool = false
var _game_ui: Node = null

# Wire cutter cursor textures
var _wire_cutter_icon_default = preload("res://assets/ui/wire_cutter/icon_default.png")
var _wire_cutter_icon_active = preload("res://assets/ui/wire_cutter/icon_active.png")
var _wire_cutter_cursor_tex = preload("res://assets/ui/wire_cutter/cursor_default.png")
var _wire_cutter_cursor_click = preload("res://assets/ui/wire_cutter/cursor_click.png")

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
		"atlas_min": Vector2i(0, 0),
		"atlas_max": Vector2i(0, 0),
		"source": 4,
		"scene": preload("res://scenes/pickups/wire_cutter_pickup.tscn"),
		"no_erase": false,
	},
]

func _ready() -> void:
	_scan_interactables()
	_setup_hud()
	GameState.wire_cutter_collected.connect(_on_wire_cutter_collected)
	GameState.wire_cutter_mode_changed.connect(_on_wire_cutter_mode_changed)

# ── HUD ──

func _setup_hud() -> void:
	_game_ui = _game_ui_scene.instantiate()
	add_child(_game_ui)
	# Swap the PunchSlot to show wire cutter icon (hidden until collected)
	var punch_slot = _game_ui.get_node("UILayer/InventoryPanel/PunchSlot")
	if punch_slot:
		punch_slot.texture = _wire_cutter_icon_default
		punch_slot.visible = false

func _on_wire_cutter_collected() -> void:
	var punch_slot = _game_ui.get_node("UILayer/InventoryPanel/PunchSlot")
	if punch_slot:
		punch_slot.texture = _wire_cutter_icon_default
		punch_slot.visible = true

func _on_wire_cutter_mode_changed(active: bool) -> void:
	var punch_slot = _game_ui.get_node("UILayer/InventoryPanel/PunchSlot")
	if punch_slot:
		punch_slot.texture = _wire_cutter_icon_active if active else _wire_cutter_icon_default
	if active:
		CustomCursor.set_cursor(_wire_cutter_cursor_tex, _wire_cutter_cursor_click)
	else:
		CustomCursor.reset_cursor()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _paused:
			_resume()
		else:
			_pause()
		return

	# Click on wire cutter slot to toggle mode
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if GameState.has_wire_cutter:
			var punch_slot = _game_ui.get_node("UILayer/InventoryPanel/PunchSlot")
			if punch_slot and punch_slot.visible:
				var mouse = get_viewport().get_mouse_position()
				var slot_pos = punch_slot.global_position
				var half = Vector2(24, 24)
				if Rect2(slot_pos - half, half * 2).has_point(mouse):
					GameState.set_wire_cutter_mode(not GameState.wire_cutter_mode)
					get_viewport().set_input_as_handled()

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
