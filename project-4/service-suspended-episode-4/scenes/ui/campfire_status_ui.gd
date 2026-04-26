extends Node2D

const STATUS_STEP_COUNT := 10
const EMPTY_FRAME := 10

@export_range(0.05, 1.0, 0.01) var min_flame_scale_ratio: float = 0.22

@onready var status_sprite: Sprite2D = $StatusSprite as Sprite2D
@onready var fire: Node2D = $Fire as Node2D
@onready var fire_sprite: AnimatedSprite2D = $Fire/AnimatedSprite2D as AnimatedSprite2D

var _base_fire_scale: Vector2 = Vector2.ONE
var _started: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	process_mode = Node.PROCESS_MODE_ALWAYS

	if fire != null:
		fire.process_mode = Node.PROCESS_MODE_ALWAYS
		_base_fire_scale = fire.scale

	if fire_sprite != null:
		fire_sprite.process_mode = Node.PROCESS_MODE_ALWAYS

	if not GameState.campfire_state_changed.is_connected(_on_campfire_state_changed):
		GameState.campfire_state_changed.connect(_on_campfire_state_changed)
	if not GameState.campfire_burn_changed.is_connected(_on_campfire_burn_changed):
		GameState.campfire_burn_changed.connect(_on_campfire_burn_changed)

	_started = GameState.campfire_lit and GameState.campfire_burn_remaining > 0.0
	visible = _started
	_sync_from_state()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return

	visible = _started
	if not visible:
		return
	_sync_from_state()

func _on_campfire_state_changed(is_lit: bool) -> void:
	if is_lit:
		_started = true
		visible = true
	_sync_from_state()

func _on_campfire_burn_changed(_remaining_seconds: float, _duration_seconds: float) -> void:
	_sync_from_state()

func _sync_from_state() -> void:
	_apply_status_frame(GameState.campfire_burn_remaining, GameState.campfire_burn_duration)
	_apply_fire_state(GameState.campfire_lit)

func _apply_status_frame(remaining_seconds: float, duration_seconds: float) -> void:
	if status_sprite == null:
		return
	if duration_seconds <= 0.0 or remaining_seconds <= 0.0:
		status_sprite.frame = EMPTY_FRAME
		return

	var step_duration: float = duration_seconds / float(STATUS_STEP_COUNT)
	if step_duration <= 0.0:
		status_sprite.frame = EMPTY_FRAME
		return

	var displayed_seconds: int = maxi(0, int(ceil(remaining_seconds)))
	var elapsed: float = max(0.0, duration_seconds - float(displayed_seconds))
	var consumed_steps: int = int(floor(elapsed / step_duration))
	status_sprite.frame = clampi(consumed_steps, 0, EMPTY_FRAME)

func _apply_fire_state(is_lit: bool) -> void:
	if fire == null:
		return

	var burn_ratio: float = 0.0
	if GameState.campfire_burn_duration > 0.0:
		burn_ratio = clampf(
			GameState.campfire_burn_remaining / GameState.campfire_burn_duration,
			0.0,
			1.0
		)

	var scale_ratio: float = lerpf(min_flame_scale_ratio, 1.0, burn_ratio)
	fire.scale = _base_fire_scale * scale_ratio
	fire.visible = is_lit and burn_ratio > 0.0

	if fire.visible:
		if fire.has_method("play_fire"):
			fire.play_fire()
		if fire_sprite != null:
			fire_sprite.play("burn")
	else:
		if fire.has_method("stop"):
			fire.stop()
		if fire_sprite != null:
			fire_sprite.stop()
			fire_sprite.frame = 0
