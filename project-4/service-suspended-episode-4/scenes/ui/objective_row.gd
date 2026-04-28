extends HBoxContainer

const INDENT_SIZE := 12.0
const FADE_DELAY := 0.12
const FADE_TIME := 0.88
const TEXT_COLOR := "#fff6da"
const MUTED_COLOR := "#d6d0bf"

@onready var indent: Control = $Indent
@onready var state_label: RichTextLabel = $StateLabel
@onready var text_label: RichTextLabel = $TextLabel
@onready var progress_label: RichTextLabel = $ProgressLabel

var _text: String = ""
var _progress_current: int = -1
var _progress_required: int = -1
var _completion_tween: Tween = null

func configure(data: Dictionary) -> void:
	_text = String(data.get("text", ""))
	_progress_current = int(data.get("progress_current", -1))
	_progress_required = int(data.get("progress_required", -1))
	indent.custom_minimum_size.x = INDENT_SIZE * int(data.get("depth", 0))
	_apply_state(bool(data.get("completed", false)))

func play_completion() -> void:
	_apply_state(true)
	if _completion_tween and _completion_tween.is_valid():
		return
	_completion_tween = create_tween()
	_completion_tween.tween_interval(FADE_DELAY)
	_completion_tween.tween_property(self, "modulate:a", 0.0, FADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _apply_state(completed: bool) -> void:
	state_label.text = _state_markup(completed)
	text_label.text = _text_markup(completed)
	progress_label.visible = _has_progress()
	if progress_label.visible:
		progress_label.text = _progress_markup(completed)

func _has_progress() -> bool:
	return _progress_required > 0

func _state_markup(completed: bool) -> String:
	return "[color=%s]%s[/color]" % [MUTED_COLOR if completed else TEXT_COLOR, "[x]" if completed else "[ ]"]

func _text_markup(completed: bool) -> String:
	var content := _text
	if completed:
		content = "[s]%s[/s]" % content
	return "[color=%s]%s[/color]" % [MUTED_COLOR if completed else TEXT_COLOR, content]

func _progress_markup(completed: bool) -> String:
	var content := "%d / %d" % [_progress_current, _progress_required]
	if completed:
		content = "[s]%s[/s]" % content
	return "[color=%s]%s[/color]" % [MUTED_COLOR if completed else TEXT_COLOR, content]
