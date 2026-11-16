extends Area3D
## A nearby Hub NPC that opens one short line of dialogue when interacted with.
class_name HubNPC

@export var npc_title := "Villager"
@export_multiline var dialogue_message := "Welcome."

var _player_nearby := false
var _prompt: Label3D

func _ready() -> void:
	add_to_group("hub_npcs")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_prompt = Label3D.new()
	_prompt.text = "A / F · TALK"
	_prompt.position = Vector3(0.0, 2.35, 0.0)
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.font_size = 28
	_prompt.outline_size = 5
	_prompt.modulate = Color("fff0c9")
	_prompt.visible = false
	add_child(_prompt)

func _unhandled_input(event: InputEvent) -> void:
	if not _player_nearby or not event.is_action_pressed("interact"):
		return
	var dialogue := get_tree().get_first_node_in_group("hub_dialogue")
	if not is_instance_valid(dialogue) or not dialogue.has_method("show_dialog"):
		return
	dialogue.show_dialog(npc_title, dialogue_message)
	get_viewport().set_input_as_handled()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("players"):
		_player_nearby = true
		_prompt.visible = true

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("players"):
		_player_nearby = false
		_prompt.visible = false
