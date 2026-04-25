extends CanvasLayer

const DIGIT_PATH := "res://assets/sprites/ui/timer/digit_%d.png"
const ADJUST_PLUS_PATH := "res://assets/sprites/ui/timer/adjust_plus_%d.png"
const ADJUST_MINUS_PATH := "res://assets/sprites/ui/timer/adjust_minus_%d.png"

@export var top_offset: float = 28.0

@onready var timer_anchor: Node2D = $TimerAnchor
@onready var base: Sprite2D = $TimerAnchor/Base
@onready var digits: Array[Sprite2D] = [
	$TimerAnchor/Digits/MinuteTens,
	$TimerAnchor/Digits/MinuteOnes,
	$TimerAnchor/Digits/SecondTens,
	$TimerAnchor/Digits/SecondOnes,
]
@onready var popup: Sprite2D = $TimerAnchor/Popup

var _digit_textures: Array[Texture2D] = []
var _adjust_plus: Array[Texture2D] = []
var _adjust_minus: Array[Texture2D] = []

func _ready() -> void:
	_load_textures()
	_configure_sprites()
	_reposition()
	popup.modulate.a = 0.0
	_set_visible_state(GameState.trial_start)
	_update_timer(GameState.trial_time_remaining)
	GameState.trial_started.connect(_on_trial_started)
	GameState.trial_time_changed.connect(_update_timer)
	GameState.trial_time_adjusted.connect(_show_adjustment)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_reposition()

func _on_trial_started() -> void:
	_set_visible_state(true)
	_update_timer(GameState.trial_time_remaining)

func _set_visible_state(active: bool) -> void:
	timer_anchor.visible = active

func _update_timer(remaining_seconds: float) -> void:
	var total: int = maxi(0, int(ceil(remaining_seconds)))
	var minutes: int = floori(float(total) / 60.0)
	var seconds: int = total % 60
	var text: String = "%02d%02d" % [minutes, seconds]
	for i in range(digits.size()):
		var value: int = int(text[i])
		digits[i].texture = _digit_textures[value]

func _show_adjustment(delta_seconds: float) -> void:
	var minutes: int = int(round(abs(delta_seconds) / 60.0))
	minutes = clampi(minutes, 1, 9)
	if delta_seconds >= 0.0:
		popup.texture = _adjust_plus[minutes - 1]
	else:
		popup.texture = _adjust_minus[minutes - 1]
	popup.visible = true
	popup.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(popup, "modulate:a", 1.0, 0.16)
	tween.tween_interval(1.0)
	tween.tween_property(popup, "modulate:a", 0.0, 0.22)

func _load_textures() -> void:
	for i in range(10):
		var digit_texture: Texture2D = load(DIGIT_PATH % i) as Texture2D
		_digit_textures.append(digit_texture)
	for i in range(1, 10):
		var plus_texture: Texture2D = load(ADJUST_PLUS_PATH % i) as Texture2D
		var minus_texture: Texture2D = load(ADJUST_MINUS_PATH % i) as Texture2D
		_adjust_plus.append(plus_texture)
		_adjust_minus.append(minus_texture)

func _configure_sprites() -> void:
	base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	popup.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for i in range(digits.size()):
		digits[i].texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _reposition() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	timer_anchor.position = Vector2(viewport_size.x * 0.5, top_offset)
