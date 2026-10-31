extends EnemyState
## Telegraphs and performs a melee attack, then waits through its recovery phase.
class_name EnemyAttackState

enum Phase { WINDUP, RECOVERY }
var _phase := Phase.WINDUP
var _phase_left := 0.0
var _telegraph_started := false

func enter(_previous_state: StringName) -> void:
	manager.ai.stop_moving()
	manager.ai.face_target()
	_begin_windup()

func update(delta: float) -> StringName:
	if not manager.ai.refresh_target():
		manager.ai.hide_attack_telegraph()
		return &"Idle"
	manager.ai.face_target()
	if _phase == Phase.WINDUP:
		var cooldown_left = manager.ai.combat.get_attack_cooldown_left()
		if cooldown_left > 0.0:
			manager.ai.hide_attack_telegraph()
			return &""
		if not _telegraph_started:
			_phase_left = manager.ai.definition.attack_telegraph_duration
			manager.ai.show_attack_telegraph()
			_telegraph_started = true
		_phase_left = maxf(0.0, _phase_left - delta)
		if _phase_left > 0.0:
			return &""
		manager.ai.hide_attack_telegraph()
		if not manager.ai.is_target_in_attack_range():
			return &"Chase"
		manager.ai.perform_attack()
		_phase = Phase.RECOVERY
		_phase_left = manager.ai.get_attack_recovery()
		_telegraph_started = false
		return &""
	_phase_left = maxf(0.0, _phase_left - delta)
	if _phase_left > 0.0:
		return &""
	if manager.ai.is_target_in_attack_range():
		_begin_windup()
		return &""
	return &"Chase"

func exit(_next_state: StringName) -> void:
	manager.ai.hide_attack_telegraph()

func _begin_windup() -> void:
	_phase = Phase.WINDUP
	_telegraph_started = manager.ai.combat.get_attack_cooldown_left() <= 0.0
	_phase_left = manager.ai.definition.attack_telegraph_duration if _telegraph_started else 0.0
	if _telegraph_started:
		manager.ai.show_attack_telegraph()
