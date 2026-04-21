extends PanelContainer

@onready var total_label: RichTextLabel = $VBox/TotalLabel

func _ready() -> void:
	GameState.special_ticket_collected.connect(func(_c, _r): _refresh())
	_refresh()

func _refresh() -> void:
	total_label.text = "[color=#ffd700]Golden Tickets: %d / %d[/color]" % [
		GameState.special_tickets_collected,
		GameState.special_tickets_required
	]
