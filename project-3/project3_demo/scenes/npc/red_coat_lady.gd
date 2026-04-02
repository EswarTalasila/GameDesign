# npc.gd
extends CharacterBody2D

@export var dialogue_resource: DialogueResource  # assign your .dialogue file in the Inspector
@export var dialogue_start: String = "start"      # the title/label to start from in your dialogue file
@export var interaction_key: String = "interact"
## GameState property name that tracks whether this NPC's dialogue has been heard.
## Leave empty to disable replay gating (always starts from dialogue_start).
@export var heard_flag: String = ""
@onready var prompt_label: Node2D = $PromptSprite

var player_in_range: bool = false

func _ready():
	var area = $chat_detection
	# Disconnect first to avoid duplicates
	if area.body_entered.is_connected(_on_body_entered):
		area.body_entered.disconnect(_on_body_entered)
	if area.body_exited.is_connected(_on_body_exited):
		area.body_exited.disconnect(_on_body_exited)
	prompt_label.visible = false

	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent):
	if player_in_range and event.is_action_pressed(interaction_key):
		_start_dialogue()

func _on_body_entered(body):
	if body.is_in_group("Player"):
		player_in_range = true
		prompt_label.visible = true

func _on_body_exited(body):
	if body.is_in_group("Player"):
		player_in_range = false
		prompt_label.visible = false

func _start_dialogue():
	if dialogue_resource == null:
		push_error("No dialogue resource assigned to NPC!")
		return
	var start = dialogue_start
	if heard_flag != "" and GameState.get(heard_flag):
		start = "return"
	DialogueManager.show_dialogue_balloon(dialogue_resource, start)
	# Mark as heard after first full playthrough
	if heard_flag != "" and not GameState.get(heard_flag):
		GameState.set(heard_flag, true)
