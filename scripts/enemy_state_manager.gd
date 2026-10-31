extends Node
## Owns enemy state nodes and calls enter, update, and exit during transitions.
class_name EnemyStateManager

signal state_changed(previous_state: StringName, new_state: StringName)

var ai
var current_state
var _states: Dictionary = {}

func initialize(enemy_ai) -> void:
	ai = enemy_ai
	_states.clear()
	for child in get_children():
		if child.has_method("get_state_name") and child.has_method("enter") and child.has_method("update") and child.has_method("exit"):
			child.set("manager", self)
			var state_name: StringName = child.call("get_state_name")
			_states[state_name] = child
	transition_to(&"Idle")

func tick(delta: float) -> void:
	if not is_instance_valid(current_state):
		return
	var requested_state: StringName = current_state.update(delta)
	if not requested_state.is_empty():
		transition_to(requested_state)

func transition_to(state_name: StringName) -> void:
	var next_state = _states.get(state_name)
	if not is_instance_valid(next_state) or next_state == current_state:
		return
	var previous_name: StringName = current_state.get_state_name() if is_instance_valid(current_state) else &""
	if is_instance_valid(current_state):
		current_state.exit(state_name)
	current_state = next_state
	current_state.enter(previous_name)
	state_changed.emit(previous_name, state_name)

func get_current_state_name() -> StringName:
	return current_state.get_state_name() if is_instance_valid(current_state) else &""
