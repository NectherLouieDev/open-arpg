extends EnemyState
## Walks between configured patrol points until a player enters aggro range.
class_name EnemyPatrolState

func enter(_previous_state: StringName) -> void:
	manager.ai.select_next_patrol_point()

func update(_delta: float) -> StringName:
	if manager.ai.acquire_target():
		return &"Chase"
	manager.ai.navigate_to_patrol_point()
	if manager.ai.is_at_navigation_target():
		manager.ai.stop_moving()
		return &"Idle"
	return &""

func exit(_next_state: StringName) -> void:
	manager.ai.stop_moving()
