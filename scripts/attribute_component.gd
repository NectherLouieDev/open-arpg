extends Node
## Tracks STR, FIN, and ARK values and derives attribute-based combat stats.
class_name AttributeComponent

signal attributes_changed

enum Attribute { STR, FIN, ARK }

@export var scaling: StatScaling
@export var strength := 0.0
@export var finesse := 0.0
@export var arkifex := 0.0

var stats: StatComponent
var talisman_bonuses := PackedFloat32Array([0.0, 0.0, 0.0])

func initialize(stat_component: StatComponent) -> void:
	stats = stat_component
	if is_instance_valid(stats):
		stats.attributes = self
		stats.refresh_attribute_modifiers()

func get_attribute(attribute: int) -> float:
	match attribute:
		Attribute.STR:
			return strength + talisman_bonuses[Attribute.STR]
		Attribute.FIN:
			return finesse + talisman_bonuses[Attribute.FIN]
		Attribute.ARK:
			return arkifex + talisman_bonuses[Attribute.ARK]
	return 0.0

func set_talisman_bonuses(bonuses: PackedFloat32Array) -> void:
	talisman_bonuses = PackedFloat32Array([0.0, 0.0, 0.0])
	for index in range(mini(3, bonuses.size())):
		talisman_bonuses[index] = bonuses[index]
	if is_instance_valid(stats):
		stats.refresh_attribute_modifiers()
	attributes_changed.emit()

func set_attribute(attribute: int, value: float) -> void:
	var clamped_value := maxf(0.0, value)
	match attribute:
		Attribute.STR:
			strength = clamped_value
		Attribute.FIN:
			finesse = clamped_value
		Attribute.ARK:
			arkifex = clamped_value
	if is_instance_valid(stats):
		stats.refresh_attribute_modifiers()
	attributes_changed.emit()

func get_health_bonus() -> float:
	return get_attribute(Attribute.STR) * _coefficient("strength_health_per_point", 10.0)

func get_max_anima_bonus() -> float:
	return get_attribute(Attribute.FIN) * _coefficient("finesse_max_anima_per_point", 8.0)

func get_melee_damage_multiplier() -> float:
	return 1.0 + get_attribute(Attribute.STR) * _coefficient("strength_melee_damage_per_point", 0.015)

func get_skill_damage_multiplier() -> float:
	return 1.0 + get_attribute(Attribute.ARK) * _coefficient("arkifex_skill_damage_per_point", 0.015)

func get_attack_speed_multiplier() -> float:
	return 1.0 + get_attribute(Attribute.FIN) * _coefficient("finesse_attack_speed_per_point", 0.01)

func get_move_speed_multiplier() -> float:
	return 1.0 + get_attribute(Attribute.FIN) * _coefficient("finesse_move_speed_per_point", 0.005)

func get_dash_cost_multiplier() -> float:
	var reduction := get_attribute(Attribute.FIN) * _coefficient("finesse_dash_cost_reduction_per_point", 0.005)
	var cap := _coefficient("dash_cost_reduction_cap", 0.75)
	return 1.0 - clampf(reduction, 0.0, cap)

func get_cooldown_multiplier() -> float:
	var reduction := get_attribute(Attribute.ARK) * _coefficient("arkifex_cooldown_reduction_per_point", 0.0075)
	var cap := _coefficient("cooldown_reduction_cap", 0.75)
	return 1.0 - clampf(reduction, 0.0, cap)

func get_anima_regen_multiplier() -> float:
	return 1.0 + get_attribute(Attribute.ARK) * _coefficient("arkifex_anima_regen_per_point", 0.01)

func _coefficient(property_name: StringName, fallback: float) -> float:
	if is_instance_valid(scaling):
		return float(scaling.get(property_name))
	return fallback
