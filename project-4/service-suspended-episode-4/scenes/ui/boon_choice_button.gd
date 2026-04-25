@tool
extends TextureButton

@export_enum("Runtime", "Normal", "Hover", "Pressed") var editor_preview_state: String = "Runtime":
	set(value):
		editor_preview_state = value
		_update_button_state()

@export var normal_text_offset: Vector2 = Vector2(0, -2):
	set(value):
		normal_text_offset = value
		_update_button_state()

@export var hover_text_offset: Vector2 = Vector2(0, -2):
	set(value):
		hover_text_offset = value
		_update_button_state()

@export var pressed_text_offset: Vector2 = Vector2(0, 2):
	set(value):
		pressed_text_offset = value
		_update_button_state()

@onready var state_preview: TextureRect = get_node_or_null("StatePreview") as TextureRect
@onready var text_root: Control = get_node_or_null("TextRoot") as Control

func _ready() -> void:
	if not Engine.is_editor_hint():
		editor_preview_state = "Runtime"
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_entered.connect(_update_button_state)
	mouse_exited.connect(_update_button_state)
	button_down.connect(_update_button_state)
	button_up.connect(_update_button_state)
	focus_entered.connect(_update_button_state)
	focus_exited.connect(_update_button_state)
	_update_button_state()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_button_state()

func _update_button_state() -> void:
	if text_root == null:
		text_root = get_node_or_null("TextRoot") as Control
	if text_root == null:
		return
	var previewing: bool = editor_preview_state != "Runtime"
	var state: String = _get_visual_state(previewing)
	var offset: Vector2 = _get_state_offset(state)
	text_root.offset_left = offset.x
	text_root.offset_top = offset.y
	text_root.offset_right = offset.x
	text_root.offset_bottom = offset.y
	_update_state_preview(previewing, state)

func _get_visual_state(previewing: bool) -> String:
	if previewing:
		return editor_preview_state
	if button_pressed:
		return "Pressed"
	if hover_text_offset != normal_text_offset and (is_hovered() or has_focus()):
		return "Hover"
	return "Normal"

func _get_state_offset(state: String) -> Vector2:
	if state == "Pressed":
		return pressed_text_offset
	elif state == "Hover":
		return hover_text_offset
	return normal_text_offset

func _update_state_preview(previewing: bool, state: String) -> void:
	if state_preview == null:
		state_preview = get_node_or_null("StatePreview") as TextureRect
	if state_preview == null:
		return
	state_preview.visible = previewing
	if not previewing:
		return
	if state == "Pressed":
		state_preview.texture = texture_pressed
	elif state == "Hover":
		state_preview.texture = texture_hover
	else:
		state_preview.texture = texture_normal
