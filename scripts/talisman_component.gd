extends Node
## Owns the three persistent attribute Talisman slots.
class_name TalismanComponent

signal talismans_changed

const SLOT_COUNT := 3
var attributes: AttributeComponent
var _equipped: Array[TalismanDefinition] = []

func initialize(attribute_component: AttributeComponent) -> void:
	attributes = attribute_component
	_equipped.resize(SLOT_COUNT)
	_refresh_attribute_bonuses()

func equip(slot_index: int, talisman: TalismanDefinition) -> bool:
	if slot_index < 0 or slot_index >= SLOT_COUNT or not is_instance_valid(talisman):
		return false
	_equipped[slot_index] = talisman
	_refresh_attribute_bonuses()
	talismans_changed.emit()
	return true

func unequip(slot_index: int) -> TalismanDefinition:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return null
	var previous := _equipped[slot_index]
	_equipped[slot_index] = null
	_refresh_attribute_bonuses()
	talismans_changed.emit()
	return previous

func get_equipped(slot_index: int) -> TalismanDefinition:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return null
	return _equipped[slot_index]

func _refresh_attribute_bonuses() -> void:
	if not is_instance_valid(attributes):
		return
	var totals := PackedFloat32Array([0.0, 0.0, 0.0])
	for talisman in _equipped:
		if is_instance_valid(talisman):
			totals[talisman.attribute] += talisman.attribute_bonus
	attributes.set_talisman_bonuses(totals)
