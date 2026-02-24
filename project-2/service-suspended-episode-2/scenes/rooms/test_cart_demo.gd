extends Node2D

@onready var bubble: PanelContainer = $CanvasLayer/DialogBubble

var lines: Array[Dictionary] = [
	{"text": "The train hasn't moved in hours...", "speaker": "You"},
	{"text": "Your ticket, please.", "speaker": "Conductor"},
	{"text": "I... I don't have one.", "speaker": "You"},
	{"text": "Then how did you get on this train?", "speaker": "Conductor"},
]
var current_line: int = 0

func _ready() -> void:
	bubble.finished.connect(_on_bubble_finished)
	await get_tree().create_timer(0.5).timeout
	_show_next_line()

func _show_next_line() -> void:
	if current_line >= lines.size():
		return
	var line = lines[current_line]
	bubble.show_text(line["text"], line["speaker"])

func _on_bubble_finished() -> void:
	current_line += 1

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and not bubble.visible and current_line < lines.size():
		_show_next_line()
