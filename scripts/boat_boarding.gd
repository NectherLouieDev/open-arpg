extends Area3D
## Boarding the Hub boat starts an island run.

@export_file("*.tscn") var destination_scene := "res://scenes/island.tscn"

var _player_nearby := false
var _transition_started := false
var _prompt: Label3D

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_prompt = Label3D.new()
	_prompt.name = "BoardPrompt"
	_prompt.text = "A / F · BOARD BOAT"
	_prompt.position = Vector3(0.0, 2.0, 0.0)
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.font_size = 30
	_prompt.outline_size = 5
	_prompt.modulate = Color("fff0c9")
	_prompt.visible = false
	add_child(_prompt)

func _unhandled_input(event: InputEvent) -> void:
	if not _player_nearby or _transition_started or not event.is_action_pressed("interact"):
		return
	_transition_started = true
	get_viewport().set_input_as_handled()
	var error := get_tree().change_scene_to_file(destination_scene)
	if error != OK:
		_transition_started = false
		push_error("Could not enter island scene: %s" % destination_scene)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("players"):
		_player_nearby = true
		_prompt.visible = true

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("players"):
		_player_nearby = false
		_prompt.visible = false
