extends Node2D

const MODE_RAIN := "rain"
const MODE_SNOW := "snow"
const MODE_BLOOD_RAIN := "blood_rain"

var precipitation_mode := MODE_RAIN:
	set(value):
		precipitation_mode = value
		_apply_mode_settings()
		_reset_particles()

var weather_rect := Rect2(Vector2.ZERO, Vector2(1024, 768)):
	set(value):
		weather_rect = value
		_reset_particles()

var _particle_count := 260
var _particles: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _color := Color(0.65, 0.78, 0.9, 0.5)
var _speed_range := Vector2(850.0, 1120.0)
var _slant := 0.28
var _length_range := Vector2(22.0, 34.0)
var _thickness := 1.0
var _snow_radius_range := Vector2(1.0, 2.4)
var _snow_drift := 22.0

func _ready() -> void:
	z_index = 100
	_rng.randomize()
	_apply_mode_settings()
	_reset_particles()
	set_process(true)

func configure(mode: String, bounds: Rect2) -> void:
	weather_rect = bounds
	precipitation_mode = mode

func _process(delta: float) -> void:
	for i in range(_particles.size()):
		var particle := _particles[i]
		var particle_position: Vector2 = particle["position"]
		var speed: float = particle["speed"]
		if precipitation_mode == MODE_SNOW:
			var drift_phase: float = particle["drift_phase"] + delta * particle["drift_speed"]
			particle["drift_phase"] = drift_phase
			particle_position.x += sin(drift_phase) * _snow_drift * delta
			particle_position.y += speed * delta
		else:
			particle_position.x += speed * _slant * delta
			particle_position.y += speed * delta

		particle["position"] = particle_position
		if _is_outside_weather_rect(particle_position):
			particle = _make_particle(true)
		_particles[i] = particle
	queue_redraw()

func _draw() -> void:
	if precipitation_mode == MODE_SNOW:
		_draw_snow()
	else:
		_draw_rain()

func _draw_rain() -> void:
	for particle in _particles:
		var particle_position: Vector2 = particle["position"]
		var length: float = particle["length"]
		draw_line(particle_position, particle_position + Vector2(length * _slant, length), _color, _thickness, false)

func _draw_snow() -> void:
	for particle in _particles:
		draw_circle(particle["position"], particle["radius"], _color)

func _reset_particles() -> void:
	if not is_inside_tree():
		return
	_particles.clear()
	for i in range(_particle_count):
		_particles.append(_make_particle(false))
	queue_redraw()

func _make_particle(from_top: bool) -> Dictionary:
	var x := _rng.randf_range(weather_rect.position.x, weather_rect.end.x)
	var y := _rng.randf_range(weather_rect.position.y - 80.0, weather_rect.position.y - 8.0)
	if not from_top:
		y = _rng.randf_range(weather_rect.position.y, weather_rect.end.y)
	return {
		"position": Vector2(x, y),
		"speed": _rng.randf_range(_speed_range.x, _speed_range.y),
		"length": _rng.randf_range(_length_range.x, _length_range.y),
		"radius": _rng.randf_range(_snow_radius_range.x, _snow_radius_range.y),
		"drift_phase": _rng.randf_range(0.0, TAU),
		"drift_speed": _rng.randf_range(1.1, 2.4),
	}

func _is_outside_weather_rect(particle_position: Vector2) -> bool:
	return particle_position.y > weather_rect.end.y + 80.0 or particle_position.x > weather_rect.end.x + 96.0 or particle_position.x < weather_rect.position.x - 96.0

func _apply_mode_settings() -> void:
	match precipitation_mode:
		MODE_SNOW:
			_particle_count = 180
			_color = Color(0.92, 0.97, 1.0, 0.78)
			_speed_range = Vector2(58.0, 128.0)
			_slant = 0.08
			_snow_radius_range = Vector2(1.0, 2.5)
			_snow_drift = 24.0
		MODE_BLOOD_RAIN:
			_particle_count = 320
			_color = Color(0.46, 0.02, 0.025, 0.68)
			_speed_range = Vector2(900.0, 1240.0)
			_slant = 0.25
			_length_range = Vector2(24.0, 38.0)
			_thickness = 1.25
		_:
			_particle_count = 300
			_color = Color(0.62, 0.74, 0.86, 0.52)
			_speed_range = Vector2(820.0, 1100.0)
			_slant = 0.28
			_length_range = Vector2(20.0, 34.0)
			_thickness = 1.0
