extends Node
## Runs equipment-granted skills, including cooldowns, Anima costs, and targeting.
class_name SkillComponent

signal skill_used(slot_index: int)
signal skill_failed(slot_index: int, reason: String)
signal skill_action_requested(slot_index: int, skill_definition: SkillDefinition)
signal targeting_started(slot_index: int, skill_definition: SkillDefinition)
signal targeting_cancelled(slot_index: int)

var stats: StatComponent
var attributes: AttributeComponent
var equipment: EquipmentComponent
var combat: CombatComponent
var movement: MovementComponent
var body: CharacterBody3D

var _skill_cooldowns: Array[float] = []
var _skill_action_lockout_left := 0.0
var _targeting_slot := 0
var _targeting_definition: SkillDefinition

func _ready() -> void:
	_skill_cooldowns.resize(6)
	_skill_cooldowns.fill(0.0)

func tick(delta: float) -> void:
	for index in range(_skill_cooldowns.size()):
		_skill_cooldowns[index] = maxf(0.0, _skill_cooldowns[index] - delta)
	_skill_action_lockout_left = maxf(0.0, _skill_action_lockout_left - delta)

func try_use_skill(slot_index: int) -> bool:
	if not begin_targeting(slot_index):
		return false
	var facing := movement.get_facing() if is_instance_valid(movement) else Vector3.FORWARD
	return confirm_targeting(facing)

func begin_targeting(slot_index: int) -> bool:
	if _targeting_slot != 0:
		return false
	var failure_reason := _get_failure_reason(slot_index)
	if not failure_reason.is_empty():
		_fail_skill(slot_index, failure_reason)
		return false
	_targeting_slot = slot_index
	_targeting_definition = equipment.get_skill_for_slot(slot_index)
	targeting_started.emit(slot_index, _targeting_definition)
	return true

func confirm_targeting(facing: Vector3) -> bool:
	if _targeting_slot == 0:
		return false
	var slot_index := _targeting_slot
	var definition := _targeting_definition
	var failure_reason := _get_failure_reason(slot_index)
	if not failure_reason.is_empty():
		_clear_targeting()
		targeting_cancelled.emit(slot_index)
		_fail_skill(slot_index, failure_reason)
		return false
	if not stats.spend_anima(definition.anima_cost):
		_clear_targeting()
		targeting_cancelled.emit(slot_index)
		_fail_skill(slot_index, "not enough Anima")
		return false
	_clear_targeting()
	var cooldown_multiplier := attributes.get_cooldown_multiplier() if is_instance_valid(attributes) else 1.0
	_skill_cooldowns[slot_index - 1] = definition.cooldown * cooldown_multiplier
	_skill_action_lockout_left = definition.action_lockout
	var target := combat.find_nearest_target_for_skill(definition, facing)
	if is_instance_valid(target):
		combat.apply_damage_to(target, definition.damage, true, definition.effect_color, definition.effect_radius)
		_log_debug("%s hit %s for %.0f" % [definition.skill_name, target.name, DamageService.calculate_damage(definition.damage, stats, attributes, DamageService.DamageType.SKILL)])
	else:
		_log_debug("%s used (no target in shape/range %.1fm)" % [definition.skill_name, definition.skill_range])
	skill_action_requested.emit(slot_index, definition)
	skill_used.emit(slot_index)
	return true

func cancel_targeting() -> void:
	if _targeting_slot == 0:
		return
	var slot_index := _targeting_slot
	_clear_targeting()
	targeting_cancelled.emit(slot_index)

func is_targeting() -> bool:
	return _targeting_slot != 0

func get_targeting_slot() -> int:
	return _targeting_slot

func get_targeting_skill() -> SkillDefinition:
	return _targeting_definition

func is_locked_out() -> bool:
	return _skill_action_lockout_left > 0.0

func get_cooldown_left(slot_index: int) -> float:
	if slot_index < 1 or slot_index > _skill_cooldowns.size():
		return 0.0
	return _skill_cooldowns[slot_index - 1]

func get_skill_range(slot_index: int = 1) -> float:
	var definition: SkillDefinition = equipment.get_skill_for_slot(slot_index) if is_instance_valid(equipment) else null
	return definition.skill_range if is_instance_valid(definition) else 0.0

func get_skill_cooldown(slot_index: int = 1) -> float:
	var definition: SkillDefinition = equipment.get_skill_for_slot(slot_index) if is_instance_valid(equipment) else null
	if not is_instance_valid(definition):
		return 0.0
	var cooldown_multiplier := attributes.get_cooldown_multiplier() if is_instance_valid(attributes) else 1.0
	return definition.cooldown * cooldown_multiplier

func get_skill_name(slot_index: int) -> String:
	var definition: SkillDefinition = equipment.get_skill_for_slot(slot_index) if is_instance_valid(equipment) else null
	return definition.skill_name if is_instance_valid(definition) else "EMPTY"

func get_action_lockout_left() -> float:
	return _skill_action_lockout_left

func _get_failure_reason(slot_index: int) -> String:
	if slot_index < 1 or slot_index > 6:
		return "invalid slot"
	if not is_instance_valid(equipment):
		return "equipment unavailable"
	var definition: SkillDefinition = equipment.get_skill_for_slot(slot_index)
	if not is_instance_valid(definition):
		return "empty slot"
	if not is_instance_valid(stats) or not is_instance_valid(combat) or not is_instance_valid(body):
		return "component unavailable"
	if stats.health <= 0.0:
		return "player defeated"
	if _skill_cooldowns.size() < 6 or _skill_cooldowns[slot_index - 1] > 0.0:
		return "cooldown"
	if _skill_action_lockout_left > 0.0:
		return "action lockout"
	if stats.anima < definition.anima_cost:
		return "not enough Anima"
	return ""

func _fail_skill(slot_index: int, reason: String) -> void:
	skill_failed.emit(slot_index, reason)
	if reason == "empty slot":
		_log_debug("Skill slot %d is empty" % slot_index)

func _clear_targeting() -> void:
	_targeting_slot = 0
	_targeting_definition = null

func _log_debug(message: String) -> void:
	var hud := get_tree().get_first_node_in_group("debug_hud")
	if hud and hud.has_method("log_event"):
		hud.call("log_event", message)
