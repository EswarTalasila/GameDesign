@tool
extends CanvasLayer

const BUTTON_FONT := preload("res://assets/fonts/DotGothic16-Regular.ttf")
const HOVER_SOUND := preload("res://assets/sounds/button_hover.mp3")
const CLICK_SOUND := preload("res://assets/sounds/button_click.mp3")

@export_range(0.0, 1.0) var dim_alpha: float = 0.42
@export_range(0, 160, 1) var button_gap: int = 50:
	set(value):
		button_gap = value
		_apply_button_gap()

@onready var dimmer: ColorRect = $Dimmer
@onready var panel: Control = $Panel
@onready var yes_choice: TextureButton = $Panel/Choices/YesChoice
@onready var no_choice: TextureButton = $Panel/Choices/NoChoice
@onready var cost_tooltip: Label = $Panel/CostTooltip

var _open: bool = false
var _campfire: Node = null
var _hover_player: AudioStreamPlayer
var _click_player: AudioStreamPlayer

func _ready() -> void:
	_apply_button_gap()
	if Engine.is_editor_hint():
		return
	add_to_group("campfire_ui_overlay")
	add_to_group("campfire_relight_ui_overlay")
	process_mode = Node.PROCESS_MODE_ALWAYS
	dimmer.modulate.a = 0.0
	panel.modulate.a = 0.0
	visible = false

	_hover_player = AudioStreamPlayer.new()
	_hover_player.stream = HOVER_SOUND
	add_child(_hover_player)

	_click_player = AudioStreamPlayer.new()
	_click_player.stream = CLICK_SOUND
	add_child(_click_player)

	yes_choice.pressed.connect(_on_yes_pressed)
	no_choice.pressed.connect(_on_no_pressed)
	yes_choice.mouse_entered.connect(_on_yes_hovered)
	yes_choice.mouse_exited.connect(func(): cost_tooltip.visible = false)
	no_choice.mouse_entered.connect(func(): _hover_player.play())

func _apply_button_gap() -> void:
	var choice_container: HBoxContainer = get_node_or_null("Panel/Choices") as HBoxContainer
	if choice_container == null:
		return
	choice_container.add_theme_constant_override("separation", button_gap)

func is_blocking_pause() -> bool:
	return _open or visible

func open(campfire: Node = null) -> void:
	if _open:
		return
	_campfire = campfire
	_refresh_cost_tooltip()
	_open = true
	visible = true
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(dimmer, "modulate:a", dim_alpha, 0.16)
	tween.tween_property(panel, "modulate:a", 1.0, 0.16)

func close() -> void:
	if not _open:
		return
	_open = false
	cost_tooltip.visible = false
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(dimmer, "modulate:a", 0.0, 0.14)
	tween.tween_property(panel, "modulate:a", 0.0, 0.14)
	await tween.finished
	visible = false

func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

func _on_yes_hovered() -> void:
	_refresh_cost_tooltip()
	cost_tooltip.visible = true
	_hover_player.play()

func _on_yes_pressed() -> void:
	if not _open:
		return
	_click_player.play()
	if _campfire and is_instance_valid(_campfire) and _campfire.has_method("relight_fire") and _campfire.relight_fire():
		close()

func _on_no_pressed() -> void:
	if not _open:
		return
	_click_player.play()
	close()

func _refresh_cost_tooltip() -> void:
	var wood_cost := 3
	var ticket_cost := 1
	if _campfire and is_instance_valid(_campfire):
		if _campfire.has_method("get_relight_wood_cost"):
			wood_cost = int(_campfire.get_relight_wood_cost())
		if _campfire.has_method("get_relight_ticket_cost"):
			ticket_cost = int(_campfire.get_relight_ticket_cost())
	cost_tooltip.text = "-%d wood  -%d golden ticket%s" % [
		wood_cost,
		ticket_cost,
		"" if ticket_cost == 1 else "s"
	]
	cost_tooltip.add_theme_font_override("font", BUTTON_FONT)
	cost_tooltip.add_theme_font_size_override("font_size", 24)
	cost_tooltip.add_theme_color_override("font_color", Color(0.9, 0.9, 0.8))
	cost_tooltip.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	cost_tooltip.add_theme_constant_override("shadow_offset_x", 1)
	cost_tooltip.add_theme_constant_override("shadow_offset_y", 1)
