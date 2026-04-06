extends CanvasLayer

# Lore inventory overlay.
# Left side: scrollable grid of collected lore item icons (clickable).
# Right side: document reader showing title + body of selected item.
# Opened via GameState lore data. Closes on Escape.

signal closed

var _root: Control
var _title_label: Label
var _body_label: RichTextLabel
var _grid: GridContainer
var _inv_vbox: VBoxContainer
var _no_selection_label: Label
var _reader_panel: PanelContainer

# Track which item is selected
var _selected_index: int = -1

func _ready() -> void:
	layer = 20
	set_process_unhandled_input(false)

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.modulate = Color(1, 1, 1, 0)
	add_child(_root)

	_build_ui()

func _build_ui() -> void:
	var vp_size = get_viewport().get_visible_rect().size
	var cinzel = load("res://assets/fonts/Cinzel-Variable.ttf")
	var dot_gothic = load("res://assets/fonts/DotGothic16-Regular.ttf")

	# Dark backdrop
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.8)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(bg)

	# Main panel
	var panel_w: float = minf(1300.0, vp_size.x - 40.0)
	var panel_h: float = minf(820.0, vp_size.y - 40.0)
	var outer = PanelContainer.new()
	outer.position = (vp_size - Vector2(panel_w, panel_h)) / 2.0
	outer.custom_minimum_size = Vector2(panel_w, panel_h)
	var outer_style = StyleBoxFlat.new()
	outer_style.bg_color = Color(0.06, 0.05, 0.03, 0.97)
	outer_style.border_color = Color(0.65, 0.55, 0.35)
	outer_style.set_border_width_all(2)
	outer_style.set_corner_radius_all(4)
	outer.add_theme_stylebox_override("panel", outer_style)
	_root.add_child(outer)

	var outer_margin = MarginContainer.new()
	outer_margin.add_theme_constant_override("margin_top", 14)
	outer_margin.add_theme_constant_override("margin_bottom", 14)
	outer_margin.add_theme_constant_override("margin_left", 14)
	outer_margin.add_theme_constant_override("margin_right", 14)
	outer.add_child(outer_margin)

	# Vertical: header + content
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	outer_margin.add_child(main_vbox)

	# Header
	var header = Label.new()
	header.text = "COLLECTED DOCUMENTS"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_override("font", dot_gothic)
	header.add_theme_font_size_override("font_size", 32)
	header.add_theme_color_override("font_color", Color(0.95, 0.88, 0.65))
	main_vbox.add_child(header)

	var sep = HSeparator.new()
	var sep_style = StyleBoxFlat.new()
	sep_style.bg_color = Color(0.65, 0.55, 0.35, 0.5)
	sep_style.content_margin_top = 1.0
	sep_style.content_margin_bottom = 1.0
	sep.add_theme_stylebox_override("separator", sep_style)
	main_vbox.add_child(sep)

	# Content: inventory grid (left) | reader (right)
	var hbox = HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 14)
	main_vbox.add_child(hbox)

	# ── Left: scrollable inventory grid ──
	var inv_panel = PanelContainer.new()
	inv_panel.custom_minimum_size = Vector2(240, 0)
	inv_panel.size_flags_horizontal = Control.SIZE_FILL
	inv_panel.size_flags_stretch_ratio = 0.35
	var inv_style = StyleBoxFlat.new()
	inv_style.bg_color = Color(0.1, 0.08, 0.06, 0.9)
	inv_style.border_color = Color(0.45, 0.38, 0.25, 0.6)
	inv_style.set_border_width_all(1)
	inv_style.set_corner_radius_all(3)
	inv_panel.add_theme_stylebox_override("panel", inv_style)
	hbox.add_child(inv_panel)

	var inv_margin = MarginContainer.new()
	inv_margin.add_theme_constant_override("margin_top", 8)
	inv_margin.add_theme_constant_override("margin_bottom", 8)
	inv_margin.add_theme_constant_override("margin_left", 8)
	inv_margin.add_theme_constant_override("margin_right", 8)
	inv_panel.add_child(inv_margin)

	var inv_scroll = ScrollContainer.new()
	inv_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inv_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inv_margin.add_child(inv_scroll)

	# Wrapper vbox — empty-state label goes here (full width), grid goes below it
	var inv_vbox = VBoxContainer.new()
	inv_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_vbox.add_theme_constant_override("separation", 8)
	inv_scroll.add_child(inv_vbox)

	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inv_vbox = inv_vbox
	inv_vbox.add_child(_grid)

	# ── Right: document reader ──
	_reader_panel = PanelContainer.new()
	_reader_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reader_panel.size_flags_stretch_ratio = 0.65
	var reader_style = StyleBoxFlat.new()
	reader_style.bg_color = Color(0.08, 0.06, 0.04, 0.95)
	reader_style.border_color = Color(0.45, 0.38, 0.25, 0.6)
	reader_style.set_border_width_all(1)
	reader_style.set_corner_radius_all(3)
	_reader_panel.add_theme_stylebox_override("panel", reader_style)
	hbox.add_child(_reader_panel)

	var reader_margin = MarginContainer.new()
	reader_margin.add_theme_constant_override("margin_top", 16)
	reader_margin.add_theme_constant_override("margin_bottom", 14)
	reader_margin.add_theme_constant_override("margin_left", 20)
	reader_margin.add_theme_constant_override("margin_right", 20)
	_reader_panel.add_child(reader_margin)

	var reader_vbox = VBoxContainer.new()
	reader_vbox.add_theme_constant_override("separation", 8)
	reader_margin.add_child(reader_vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_override("font", dot_gothic)
	_title_label.add_theme_font_size_override("font_size", 36)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.65))
	_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_title_label.add_theme_constant_override("shadow_offset_x", 1)
	_title_label.add_theme_constant_override("shadow_offset_y", 1)
	_title_label.visible = false
	reader_vbox.add_child(_title_label)

	var reader_sep = HSeparator.new()
	reader_sep.add_theme_stylebox_override("separator", sep_style)
	reader_sep.visible = false
	reader_vbox.add_child(reader_sep)

	var reader_scroll = ScrollContainer.new()
	reader_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	reader_vbox.add_child(reader_scroll)

	_body_label = RichTextLabel.new()
	_body_label.bbcode_enabled = true
	_body_label.fit_content = true
	_body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_label.add_theme_font_override("normal_font", dot_gothic)
	_body_label.add_theme_font_size_override("normal_font_size", 22)
	_body_label.add_theme_color_override("default_color", Color(0.84, 0.80, 0.68))
	reader_scroll.add_child(_body_label)

	# No-selection placeholder
	_no_selection_label = Label.new()
	_no_selection_label.text = "Select a document to read"
	_no_selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_no_selection_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_no_selection_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_no_selection_label.add_theme_font_override("font", dot_gothic)
	_no_selection_label.add_theme_font_size_override("font_size", 32)
	_no_selection_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.45))
	reader_vbox.add_child(_no_selection_label)

	# Close hint at bottom
	var hint = Label.new()
	hint.text = "[ Press Escape to close ]  |  [ Tab ] to reopen later"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", dot_gothic)
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.45))
	main_vbox.add_child(hint)

func open(title: String = "", body: String = "") -> void:
	_populate_grid()
	set_process_unhandled_input(true)

	# If opened with a specific item (just picked up), select it
	if title != "" and body != "":
		for i in range(GameState.collected_lore.size()):
			if GameState.collected_lore[i]["title"] == title:
				_select_item(i)
				break

	var tween = create_tween()
	tween.tween_property(_root, "modulate:a", 1.0, 0.3)

func _populate_grid() -> void:
	# Clear previous empty-state label if any (first child before the grid)
	for child in _inv_vbox.get_children():
		if child != _grid:
			child.queue_free()
	for child in _grid.get_children():
		child.queue_free()

	var dot_gothic = load("res://assets/fonts/DotGothic16-Regular.ttf")

	if GameState.collected_lore.is_empty():
		_grid.visible = false
		var empty_label = Label.new()
		empty_label.text = "No documents found yet.\n\nFind documents in the room\nand they will appear here."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty_label.add_theme_font_override("font", dot_gothic)
		empty_label.add_theme_font_size_override("font_size", 24)
		empty_label.add_theme_color_override("font_color", Color(0.55, 0.52, 0.45))
		_inv_vbox.add_child(empty_label)
		return

	_grid.visible = true
	for i in range(GameState.collected_lore.size()):
		var entry = GameState.collected_lore[i]
		var slot = _create_slot(i, entry, dot_gothic)
		_grid.add_child(slot)

func _create_slot(index: int, entry: Dictionary, font: Font) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(120, 140)
	btn.clip_text = true
	btn.tooltip_text = entry["title"]

	# Style
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.14, 0.12, 0.1)
	normal_style.border_color = Color(0.4, 0.35, 0.25)
	normal_style.set_border_width_all(1)
	normal_style.set_corner_radius_all(2)
	btn.add_theme_stylebox_override("normal", normal_style)

	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.2, 0.17, 0.12)
	hover_style.border_color = Color(0.7, 0.6, 0.4)
	hover_style.set_border_width_all(1)
	hover_style.set_corner_radius_all(2)
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.25, 0.2, 0.14)
	pressed_style.border_color = Color(0.85, 0.75, 0.5)
	pressed_style.set_border_width_all(2)
	pressed_style.set_corner_radius_all(2)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_stylebox_override("focus", pressed_style)

	# Layout inside button — icon + short label
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vbox)

	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(96, 96)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if entry.get("icon"):
		icon_rect.texture = entry["icon"]
	vbox.add_child(icon_rect)

	# Clipping container so the label can scroll horizontally on hover
	var clip_box = Control.new()
	clip_box.clip_contents = true
	clip_box.custom_minimum_size = Vector2(110, 22)
	clip_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(clip_box)

	var label = Label.new()
	label.text = entry["title"]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.75, 0.7, 0.6))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	clip_box.add_child(label)

	# Scroll label on hover, reset on exit
	var tween_state = {"t": null}
	btn.mouse_entered.connect(func():
		var overflow = label.get_minimum_size().x - 110.0
		if overflow <= 0:
			return
		if tween_state.t:
			tween_state.t.kill()
		tween_state.t = create_tween()
		tween_state.t.tween_property(label, "position:x", -overflow, overflow * 0.04)
	)
	btn.mouse_exited.connect(func():
		if tween_state.t:
			tween_state.t.kill()
		tween_state.t = create_tween()
		tween_state.t.tween_property(label, "position:x", 0.0, 0.3)
	)

	btn.pressed.connect(_select_item.bind(index))
	return btn

func _select_item(index: int) -> void:
	if index < 0 or index >= GameState.collected_lore.size():
		return
	_selected_index = index
	var entry = GameState.collected_lore[index]
	_title_label.text = entry["title"]
	_title_label.visible = true
	# Show the separator (child 1 of reader_vbox)
	var reader_vbox = _title_label.get_parent()
	if reader_vbox.get_child_count() > 1:
		reader_vbox.get_child(1).visible = true
	_body_label.text = entry["body"]
	_no_selection_label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	set_process_unhandled_input(false)
	var tween = create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, 0.2)
	await tween.finished
	closed.emit()
	queue_free()
