extends PanelContainer

@onready var hint_label: RichTextLabel = $VBox/HintLabel
@onready var total_label: RichTextLabel = $VBox/TotalLabel
@onready var floor_label: RichTextLabel = $VBox/FloorLabel

func _ready() -> void:
	GameState.objective_updated.connect(_refresh)
	GameState.special_ticket_collected.connect(func(_c, _r): _refresh())
	_refresh()

func _refresh() -> void:
	total_label.text = "[color=#ffd700]Golden Tickets: %d / %d[/color]" % [
		GameState.special_tickets_collected,
		GameState.special_tickets_required
	]
	floor_label.text = "[color=#c0c0c0]This Floor: %d / %d[/color]" % [
		GameState.special_tickets_collected_this_floor,
		GameState.special_tickets_spawned_this_floor
	]
