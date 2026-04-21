extends AnimatedSprite2D

# Health bar UI — plays drain animations between states.
# States: full (3hp), two_thirds (2hp), one_third (1hp), empty (0hp)

var _state_map = { 3: "full", 2: "two_thirds", 1: "one_third", 0: "empty" }
var _transition_map = {
	"full_to_two_thirds": "two_thirds",
	"two_thirds_to_one_third": "one_third",
	"one_third_to_empty": "empty",
}
var _drain_map = {
	3: { 2: "full_to_two_thirds" },
	2: { 1: "two_thirds_to_one_third" },
	1: { 0: "one_third_to_empty" },
}

var _current_hp: int = 3

func _ready() -> void:
	_current_hp = GameState.player_health
	play(_state_map.get(_current_hp, "full"))
	animation_finished.connect(_on_animation_finished)
	GameState.player_health_changed.connect(_on_health_changed)

func _on_health_changed(new_hp: int) -> void:
	if new_hp == _current_hp:
		return
	if new_hp < _current_hp and _drain_map.has(_current_hp) and _drain_map[_current_hp].has(new_hp):
		play(_drain_map[_current_hp][new_hp])
	else:
		play(_state_map.get(new_hp, "full"))
	_current_hp = new_hp

func _on_animation_finished() -> void:
	if _transition_map.has(animation):
		play(_transition_map[animation])
