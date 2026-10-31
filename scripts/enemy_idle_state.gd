extends EnemyState
## Waits in place, acquires nearby players, and starts patrol when configured.
class_name EnemyIdleState

var _wait_left := 0.0

func enter(_previous_state: StringName) -> void:
	_wait_left = manager.ai.definition.patrol_wait
	manager.ai.stop_moving()

func update(delta: float) -> StringName:
	if manager.ai.acquire_target():
		return &"Chase"
	if manager.ai.definition.patrol_points.is_empty():
		return &""
	_wait_left = maxf(0.0, _wait_left - delta)
	return &"Patrol" if _wait_left <= 0.0 else &""
