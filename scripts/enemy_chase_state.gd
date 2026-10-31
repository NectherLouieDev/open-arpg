extends EnemyState
## Follows the current target through the navigation agent until attack range.
class_name EnemyChaseState

func update(_delta: float) -> StringName:
	if not manager.ai.refresh_target():
		return &"Idle"
	if manager.ai.is_target_in_attack_range():
		return &"Attack"
	manager.ai.navigate_to_target()
	return &""

func exit(_next_state: StringName) -> void:
	manager.ai.stop_moving()
