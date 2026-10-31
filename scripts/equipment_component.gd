extends Node
## Owns the six gear slots and reports equipment changes to dependent systems.
class_name EquipmentComponent

signal equipment_changed(gear_slot: int, equipment: EquipmentDefinition)
signal equipment_set_changed

const SLOT_COUNT := 6

@export var starting_equipment: Array[EquipmentDefinition] = []

var stats: StatComponent
var _equipped: Array[EquipmentDefinition] = []

func initialize(stat_component: StatComponent) -> void:
	stats = stat_component
	_equipped.resize(SLOT_COUNT)
	for equipment in starting_equipment:
		if is_instance_valid(equipment):
			_equip_into_slot(equipment.gear_slot, equipment, false)
	_apply_stat_modifiers()

func equip(equipment: EquipmentDefinition) -> bool:
	if not is_instance_valid(equipment) or equipment.gear_slot < 0 or equipment.gear_slot >= SLOT_COUNT:
		return false
	_equip_into_slot(equipment.gear_slot, equipment, true)
	return true

func unequip(gear_slot: int) -> EquipmentDefinition:
	if gear_slot < 0 or gear_slot >= _equipped.size():
		return null
	var previous := _equipped[gear_slot]
	_equipped[gear_slot] = null
	_apply_stat_modifiers()
	equipment_changed.emit(gear_slot, null)
	equipment_set_changed.emit()
	return previous

func get_equipped(gear_slot: int) -> EquipmentDefinition:
	if gear_slot < 0 or gear_slot >= _equipped.size():
		return null
	return _equipped[gear_slot]

func get_equipped_for_skill_slot(skill_slot: int) -> EquipmentDefinition:
	if skill_slot < 1 or skill_slot > SLOT_COUNT:
		return null
	return get_equipped(skill_slot - 1)

func get_skill_for_slot(skill_slot: int) -> SkillDefinition:
	var equipment := get_equipped_for_skill_slot(skill_slot)
	return equipment.granted_skill if is_instance_valid(equipment) else null

func get_weapon() -> WeaponDefinition:
	var equipment := get_equipped(EquipmentDefinition.GearSlot.WEAPON)
	return equipment as WeaponDefinition

func _equip_into_slot(gear_slot: int, equipment: EquipmentDefinition, emit_signals: bool) -> void:
	if gear_slot < 0 or gear_slot >= SLOT_COUNT:
		return
	_equipped[gear_slot] = equipment
	_apply_stat_modifiers()
	if emit_signals:
		equipment_changed.emit(gear_slot, equipment)
		equipment_set_changed.emit()

func _apply_stat_modifiers() -> void:
	if not is_instance_valid(stats):
		return
	var health_bonus := 0.0
	var anima_bonus := 0.0
	var damage_bonus := 0.0
	var range_bonus := 0.0
	var speed_bonus := 0.0
	for equipment in _equipped:
		if not is_instance_valid(equipment):
			continue
		health_bonus += equipment.max_health_bonus
		anima_bonus += equipment.max_anima_bonus
		damage_bonus += equipment.attack_damage_bonus
		range_bonus += equipment.attack_range_bonus
		speed_bonus += equipment.attack_speed_bonus
	stats.apply_equipment_modifiers(health_bonus, anima_bonus, damage_bonus, range_bonus, speed_bonus)
