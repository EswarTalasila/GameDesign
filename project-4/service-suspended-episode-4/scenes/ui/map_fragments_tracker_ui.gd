extends PanelContainer

const REQUIRED_PIECES := 4
const PULSE_SCALE := Vector2(1.06, 1.06)
const PULSE_TIME := 0.12

@onready var title_label: RichTextLabel = $VBox/TitleLabel
@onready var count_label: RichTextLabel = $VBox/CountLabel

var _base_scale: Vector2 = Vector2.ONE
var _pulse_tween: Tween = null

func _ready() -> void:
	_base_scale = scale
	GameState.map_piece_collected.connect(_on_map_piece_collected)
	GameState.map_assembled_signal.connect(_refresh)
	_refresh()

func _refresh() -> void:
	var count := GameState.collected_map_pieces.size()
	title_label.text = "[color=#f2e7c4]Map Fragments[/color]"
	count_label.text = "[color=#fff6da]%d / %d[/color]" % [count, REQUIRED_PIECES]
	visible = not GameState.map_assembled

func _on_map_piece_collected(_piece_id: int) -> void:
	_refresh()
	_pulse()

func _pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	scale = _base_scale
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(self, "scale", _base_scale * PULSE_SCALE, PULSE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(self, "scale", _base_scale, PULSE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
