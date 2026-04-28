extends PanelContainer

const OBJECTIVE_ROW_SCENE := preload("res://scenes/ui/objective_row.tscn")

@onready var objective_list: VBoxContainer = $VBox/ObjectiveList

var _rows_by_id: Dictionary = {}

func _ready() -> void:
	visible = false
	if not QuestManager.objectives_changed.is_connected(_rebuild):
		QuestManager.objectives_changed.connect(_rebuild)
	if not QuestManager.objective_completed.is_connected(_on_objective_completed):
		QuestManager.objective_completed.connect(_on_objective_completed)
	_rebuild()

func _rebuild() -> void:
	for child in objective_list.get_children():
		child.queue_free()
	_rows_by_id.clear()
	var objectives: Array = QuestManager.get_visible_objectives()
	visible = not objectives.is_empty()
	for data in objectives:
		var row = OBJECTIVE_ROW_SCENE.instantiate()
		objective_list.add_child(row)
		row.configure(data)
		_rows_by_id[String(data.get("id", ""))] = row

func _on_objective_completed(id: String) -> void:
	var row = _rows_by_id.get(id)
	if row != null and row.has_method("play_completion"):
		row.play_completion()
