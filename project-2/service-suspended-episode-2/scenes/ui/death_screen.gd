extends CanvasLayer

@onready var death_anim: AnimatedSprite2D = $DeathAnim
@onready var reload_btn: TextureButton = $ReloadButton

var tex_normal: Texture2D = preload("res://assets/ui/reload_button/frame_0.png")
var tex_hovered: Texture2D = preload("res://assets/ui/reload_button/frame_1.png")
var tex_clicked: Texture2D = preload("res://assets/ui/reload_button/frame_2.png")

var _reload_scene_path: String = ""

func _ready() -> void:
	var viewport_size = get_viewport().get_visible_rect().size

	# Center death animation
	death_anim.position = viewport_size / 2
	death_anim.modulate = Color(1, 1, 1, 0)

	# Set up reload button textures
	reload_btn.texture_normal = tex_normal
	reload_btn.texture_hover = tex_hovered
	reload_btn.texture_pressed = tex_clicked

	# Position button: center horizontally, below death text
	var scale_factor = 4.0
	var tex_size = tex_normal.get_size()
	reload_btn.scale = Vector2(scale_factor, scale_factor)
	reload_btn.position = Vector2(
		(viewport_size.x - tex_size.x * scale_factor) / 2,
		viewport_size.y * 0.65
	)
	reload_btn.modulate = Color(1, 1, 1, 0)

	# Connect button
	reload_btn.pressed.connect(_on_reload_pressed)

	# Play the intro
	_play_intro()

func show_death(reload_scene: String) -> void:
	_reload_scene_path = reload_scene

func _play_intro() -> void:
	death_anim.play("death")

	# Fade in death text
	var tween = create_tween()
	tween.tween_property(death_anim, "modulate:a", 1.0, 1.0)
	tween.tween_interval(0.5)

	# Fade in button - force it visible even in standalone
	tween.tween_callback(func(): reload_btn.visible = true)
	tween.tween_property(reload_btn, "modulate:a", 1.0, 0.5)

func _on_reload_pressed() -> void:
	# Disable button so it can't be clicked again
	reload_btn.disabled = true

	var tween = create_tween().set_parallel(true)
	tween.tween_property(death_anim, "modulate:a", 0.0, 0.5)
	tween.tween_property(reload_btn, "modulate:a", 0.0, 0.5)
	await tween.finished

	# Show loading screen and transition
	var scene_path = _reload_scene_path
	if scene_path == "":
		# Fallback: reload current scene, or just show loading screen
		if get_tree().current_scene:
			scene_path = get_tree().current_scene.scene_file_path
		else:
			# Standalone test - load test cart
			scene_path = "res://scenes/rooms/test_cart.tscn"

	var loading = preload("res://scenes/ui/loading_screen.tscn").instantiate()
	get_tree().root.add_child(loading)
	loading.transition_to(scene_path)
	queue_free()
