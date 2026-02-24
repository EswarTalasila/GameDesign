extends PanelContainer

signal finished

@export var chars_per_second: float = 30.0

@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var text_label: RichTextLabel = $MarginContainer/VBoxContainer/RichTextLabel

var _typing: bool = false
var _char_timer: float = 0.0

func _ready() -> void:
	visible = false

func show_text(text: String, speaker: String = "") -> void:
	if speaker != "":
		name_label.text = speaker
		name_label.visible = true
	else:
		name_label.visible = false

	text_label.text = text
	text_label.visible_characters = 0
	_char_timer = 0.0
	_typing = true
	visible = true

func _process(delta: float) -> void:
	if not _typing:
		return
	_char_timer += delta * chars_per_second
	while _char_timer >= 1.0 and text_label.visible_characters < text_label.get_total_character_count():
		text_label.visible_characters += 1
		_char_timer -= 1.0
	if text_label.visible_characters >= text_label.get_total_character_count():
		_typing = false
		finished.emit()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept"):
		if _typing:
			text_label.visible_characters = -1
			_typing = false
			finished.emit()
		else:
			visible = false
