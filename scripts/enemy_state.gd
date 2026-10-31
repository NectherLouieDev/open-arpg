extends Node
## Base API for state nodes managed by EnemyStateManager.
class_name EnemyState

var manager

func get_state_name() -> StringName:
	return StringName(name)

func enter(_previous_state: StringName) -> void:
	pass

func update(_delta: float) -> StringName:
	return &""

func exit(_next_state: StringName) -> void:
	pass
