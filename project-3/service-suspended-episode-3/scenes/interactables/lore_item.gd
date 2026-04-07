extends Node2D

## In-world lore pickup. Player walks up, presses E, item is collected
## into GameState.collected_lore and disappears. Re-read from inventory.

@export var lore_title: String = "Document"
@export_multiline var lore_body: String = ""
@export var lore_id: String = ""

@onready var _prompt: AnimatedSprite2D = $Area2D/PressEPrompt

var _player_nearby: bool = false

func _ready() -> void:
	if lore_id != "" and GameState.has_lore(lore_id):
		queue_free()
		return
	$Area2D.body_entered.connect(_on_zone_entered)
	$Area2D.body_exited.connect(_on_zone_exited)
	_prompt.visible = false

func _on_zone_entered(body: Node2D) -> void:
	if body.name == "Player":
		_player_nearby = true
		_prompt.visible = true

func _on_zone_exited(body: Node2D) -> void:
	if body.name == "Player":
		_player_nearby = false
		_prompt.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not _player_nearby:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_collect()

func _collect() -> void:
	var anim = $AnimatedSprite2D
	var icon_tex: Texture2D = anim.sprite_frames.get_frame_texture("default", 0) if anim.sprite_frames else null
	GameState.collect_lore(lore_id, lore_title, lore_body, icon_tex)

	# Open the inventory overlay to show what was just picked up
	GameState.lore_open = true
	var overlay = preload("res://scenes/ui/lore_overlay.tscn").instantiate()
	get_tree().root.add_child(overlay)
	overlay.open(lore_title, lore_body)
	overlay.closed.connect(func(): GameState.lore_open = false)

	queue_free()
