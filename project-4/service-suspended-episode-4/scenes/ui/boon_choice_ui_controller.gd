@tool
extends CanvasLayer

@export var time_boon_seconds: float = 60.0
@export_range(0.0, 1.0) var dim_alpha: float = 0.42
@export_range(0, 160, 1) var button_gap: int = 24:
	set(value):
		button_gap = value
		_apply_button_gap()

@onready var dimmer: ColorRect = $Dimmer
@onready var panel: Control = $Panel
@onready var time_choice: TextureButton = $Panel/Choices/TimeChoice
@onready var ticket_choice: TextureButton = $Panel/Choices/TicketChoice

var _open: bool = false
@export var allow_cancel: bool = false

func _ready() -> void:
	_apply_button_gap()
	if Engine.is_editor_hint():
		return
	add_to_group("boon_ui_overlay")
	process_mode = Node.PROCESS_MODE_ALWAYS
	dimmer.modulate.a = 0.0
	panel.modulate.a = 0.0
	visible = false
	time_choice.pressed.connect(_choose_time)
	ticket_choice.pressed.connect(_choose_ticket)

func _apply_button_gap() -> void:
	var choice_container: HBoxContainer = get_node_or_null("Panel/Choices") as HBoxContainer
	if choice_container == null:
		return
	choice_container.add_theme_constant_override("separation", button_gap)

func is_blocking_pause() -> bool:
	return _open or visible

func open() -> void:
	_open = true
	visible = true
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(dimmer, "modulate:a", dim_alpha, 0.16)
	tween.tween_property(panel, "modulate:a", 1.0, 0.16)

func close() -> void:
	if not _open:
		return
	_open = false
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(dimmer, "modulate:a", 0.0, 0.14)
	tween.tween_property(panel, "modulate:a", 0.0, 0.14)
	await tween.finished
	queue_free()

func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if allow_cancel:
			close()
		return

func _choose_time() -> void:
	if not _open:
		return
	GameState.adjust_trial_time(time_boon_seconds)
	close()

func _choose_ticket() -> void:
	if not _open:
		return
	GameState.add_inventory_item(GameState.ITEM_SPECIAL_TICKET, 1)
	close()
