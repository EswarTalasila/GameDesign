extends JungleSection

const WORLD_WEATHER_SCRIPT := preload("res://scenes/jungle/shared/world_weather.gd")

## Per-variant weather. Auto maps winter to snow, wasteland to dark red rain, and jungle/autumn to rain.
@export var rain_enabled: bool = false
@export_enum("auto", "rain", "snow", "blood_rain") var rain_type: String = "auto"

var _world_weather: Node2D = null

func _ready() -> void:
	super._ready()
	_setup_weather()

func refresh_weather() -> void:
	_setup_weather()

func _setup_weather() -> void:
	if not rain_enabled:
		_clear_weather()
		return
	if _world_weather == null:
		_world_weather = Node2D.new()
		_world_weather.name = "WorldWeather"
		_world_weather.set_script(WORLD_WEATHER_SCRIPT)
		add_child(_world_weather)
	if _world_weather.has_method("configure"):
		_world_weather.configure(_resolve_weather_mode(), _get_weather_rect())

func _clear_weather() -> void:
	if _world_weather:
		_world_weather.queue_free()
		_world_weather = null

func _resolve_weather_mode() -> String:
	if rain_type != "auto":
		return rain_type
	match season:
		"winter":
			return "snow"
		"wasteland":
			return "blood_rain"
		_:
			return "rain"

func _get_weather_rect() -> Rect2:
	var bounds := Rect2()
	var has_bounds := false
	for layer in [_floor_layer, _floor2, _bottom_walls, _top_walls, _side_walls, _furniture, _furniture2, _overhead]:
		if layer == null:
			continue
		for cell in layer.get_used_cells():
			var point := to_local(layer.to_global(layer.map_to_local(cell)))
			if not has_bounds:
				bounds = Rect2(point, Vector2.ZERO)
				has_bounds = true
			else:
				bounds = bounds.expand(point)
	if not has_bounds:
		return Rect2(Vector2(-512, -512), Vector2(1024, 1024))
	return bounds.grow(512.0)
