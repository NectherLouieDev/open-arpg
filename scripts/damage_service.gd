extends Node
## Centralizes damage calculation and shared combat hit-stop behavior.

enum DamageType { GENERIC, MELEE, HEAVY, SKILL }

var _hit_stop_active := false

func calculate_damage(base_damage: float, attacker_stats: StatComponent, attributes: AttributeComponent = null, damage_type: DamageType = DamageType.GENERIC) -> float:
	if base_damage <= 0.0:
		return 0.0
	var flat_bonus := attacker_stats.attack_damage_bonus if is_instance_valid(attacker_stats) else 0.0
	var multiplier := 1.0
	if is_instance_valid(attributes):
		if damage_type == DamageType.SKILL:
			multiplier = attributes.get_skill_damage_multiplier()
		elif damage_type == DamageType.MELEE or damage_type == DamageType.HEAVY:
			multiplier = attributes.get_melee_damage_multiplier()
	return maxf(0.0, (base_damage + flat_bonus) * multiplier)

func request_hit_stop(duration_seconds: float = 0.045, slow_scale: float = 0.08) -> void:
	if _hit_stop_active or duration_seconds <= 0.0:
		return
	_hit_stop_active = true
	Engine.time_scale = clampf(slow_scale, 0.01, 1.0)
	await get_tree().create_timer(duration_seconds, true, false, true).timeout
	Engine.time_scale = 1.0
	_hit_stop_active = false
