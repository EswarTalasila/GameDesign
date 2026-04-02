extends PointLight2D

@export var min_energy: float = 0.3
@export var max_energy: float = 0.7
@export var min_interval: float = 0.05
@export var max_interval: float = 0.2

func _ready():
	# Connect the Timer's timeout signal to a function
	$Timer.connect("timeout", Callable(self, "_on_timer_timeout"))
	# Set initial random wait time and start the timer
	_on_timer_timeout()

func _on_timer_timeout():
	# Randomize the light's energy
	self.energy = randf_range(min_energy, max_energy)

	# Randomize the timer's wait time for the next flicker
	$Timer.wait_time = randf_range(min_interval, max_interval)
	$Timer.start()
