extends CanvasLayer

## Simon says puzzle UI. Phase 1: enter key sequence. Phase 2: simon says.

signal puzzle_closed
signal puzzle_solved

const COLORS = ["red", "blue", "green", "black"]

var _btn_off_textures: Dictionary = {}
var _btn_on_textures: Dictionary = {}
var _panel_closed_tex = preload("res://assets/ui/simon_says/panel_closed.png")
var _panel_open_tex = preload("res://assets/ui/simon_says/panel_open.png")

var _btn_sprites: Dictionary = {}  # color -> Sprite2D
var _is_open: bool = false
var _playing_sequence: bool = false

# Phase 1: key sequence (generated at room start, shown by door lights)
var _key_sequence: Array = []  # e.g. ["red", "green", "blue", "black"]
var _key_input: Array = []
var _key_complete: bool = false

# Phase 2: simon says
var _simon_sequence: Array = []
var _simon_round: int = 0
var _simon_input: Array = []
var _max_rounds: int = 4

@onready var _panel_sprite: Sprite2D = $PanelSprite

func _ready() -> void:
	layer = 8
	_panel_sprite.texture = _panel_closed_tex
	for c in COLORS:
		_btn_off_textures[c] = load("res://assets/ui/simon_says/btn_%s_off.png" % c)
		_btn_on_textures[c] = load("res://assets/ui/simon_says/btn_%s_on.png" % c)
	# Generate key sequence if not already set
	if not GameState.get("simon_key_sequence"):
		var key = COLORS.duplicate()
		key.shuffle()
		GameState.set("simon_key_sequence", key)
	_key_sequence = GameState.get("simon_key_sequence")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		puzzle_closed.emit()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse = event.position
		# Inventory clicks
		var coordinator = get_tree().root.find_child("Node2D", true, false)
		if coordinator and coordinator.has_method("_handle_inventory_click"):
			if coordinator._handle_inventory_click(mouse):
				return

		if not _is_open:
			# Click to open panel
			var center = _panel_sprite.position
			var half = Vector2(64, 64) * _panel_sprite.scale
			if Rect2(center - half, half * 2).has_point(mouse):
				_open_panel()
				get_viewport().set_input_as_handled()
			return

		if _playing_sequence:
			return  # Don't accept input during playback

		# Check button clicks
		for color in COLORS:
			if _hit_test_button(mouse, color):
				_on_button_pressed(color)
				get_viewport().set_input_as_handled()
				return

func _open_panel() -> void:
	_is_open = true
	_panel_sprite.texture = _panel_open_tex
	_create_buttons()

func _create_buttons() -> void:
	for color in COLORS:
		var sprite = Sprite2D.new()
		sprite.texture = _btn_off_textures[color]
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = Vector2.ZERO  # Same canvas, overlays perfectly
		_panel_sprite.add_child(sprite)
		_btn_sprites[color] = sprite

func _hit_test_button(mouse: Vector2, color: String) -> bool:
	var sprite = _btn_sprites.get(color)
	if sprite == null:
		return false
	var tex = sprite.texture
	var local = (mouse - _panel_sprite.position) / _panel_sprite.scale
	var sprite_local = local - sprite.position
	var tex_size = Vector2(tex.get_width(), tex.get_height())
	var tex_coord = sprite_local + tex_size / 2.0
	if tex_coord.x < 0 or tex_coord.y < 0 or tex_coord.x >= tex_size.x or tex_coord.y >= tex_size.y:
		return false
	var img = tex.get_image()
	var px = img.get_pixel(int(tex_coord.x), int(tex_coord.y))
	return px.a > 0.1

func _on_button_pressed(color: String) -> void:
	_flash_button(color)
	if not _key_complete:
		_handle_key_input(color)
	else:
		_handle_simon_input(color)

func _flash_button(color: String) -> void:
	var sprite = _btn_sprites[color]
	sprite.texture = _btn_on_textures[color]
	get_tree().create_timer(0.3).timeout.connect(func():
		if is_instance_valid(sprite):
			sprite.texture = _btn_off_textures[color]
	)

# Phase 1: Key sequence
func _handle_key_input(color: String) -> void:
	_key_input.append(color)
	var idx = _key_input.size() - 1
	if _key_input[idx] != _key_sequence[idx]:
		# Wrong - reset
		_key_input.clear()
		return
	if _key_input.size() == _key_sequence.size():
		_key_complete = true
		_key_input.clear()
		# Start simon says after brief pause
		get_tree().create_timer(0.5).timeout.connect(_start_simon_round)

# Phase 2: Simon says
func _start_simon_round() -> void:
	_simon_round += 1
	if _simon_round > _max_rounds:
		puzzle_solved.emit()
		return
	# Add random color to sequence
	_simon_sequence.append(COLORS[randi() % COLORS.size()])
	_simon_input.clear()
	# Play the sequence
	_play_sequence()

func _play_sequence() -> void:
	_playing_sequence = true
	await get_tree().create_timer(0.3).timeout
	for i in range(_simon_sequence.size()):
		var color = _simon_sequence[i]
		var sprite = _btn_sprites[color]
		sprite.texture = _btn_on_textures[color]
		await get_tree().create_timer(0.4).timeout
		sprite.texture = _btn_off_textures[color]
		await get_tree().create_timer(0.2).timeout
	_playing_sequence = false

func _handle_simon_input(color: String) -> void:
	_simon_input.append(color)
	var idx = _simon_input.size() - 1
	if _simon_input[idx] != _simon_sequence[idx]:
		# Wrong - restart
		_simon_input.clear()
		_simon_sequence.clear()
		_simon_round = 0
		get_tree().create_timer(0.5).timeout.connect(_start_simon_round)
		return
	if _simon_input.size() == _simon_sequence.size():
		# Correct round
		_simon_input.clear()
		get_tree().create_timer(0.5).timeout.connect(_start_simon_round)
