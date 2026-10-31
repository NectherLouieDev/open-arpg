extends Node
## Small inventory receiver contract for pickups; future UI can consume these entries/signals.
class_name InventoryComponent

signal item_added(item: ItemDefinition, quantity: int, total_quantity: int)
signal item_rejected(item: ItemDefinition, quantity: int)
signal inventory_changed

@export_range(1, 200, 1) var slot_capacity := 16
@export var known_item_definitions: Array[ItemDefinition] = []
@export var starting_items: Array[ItemDefinition] = []
@export var starting_quantities: PackedInt32Array = PackedInt32Array()

const QUICK_ITEM_SLOT_COUNT := 4
var quick_item_slots := PackedStringArray(["", "", "", ""])

## Entries are dictionaries with stable ItemDefinition references and quantities.
var entries: Array[Dictionary] = []

func _ready() -> void:
	for item in known_item_definitions:
		_register_item_definition(item)
	for index in range(starting_items.size()):
		var quantity := starting_quantities[index] if index < starting_quantities.size() else 1
		try_add_item(starting_items[index], quantity)

func try_add_item(item: ItemDefinition, quantity: int = 1) -> int:
	if not is_instance_valid(item) or quantity <= 0:
		return 0
	_register_item_definition(item)
	var remaining := quantity
	if item.stackable:
		for entry in entries:
			if entry.item.item_id != item.item_id:
				continue
			var room: int = item.max_stack - int(entry.quantity)
			var accepted := mini(room, remaining)
			entry.quantity = int(entry.quantity) + accepted
			remaining -= accepted
			if remaining <= 0:
				break
	while remaining > 0 and _used_slots() < slot_capacity:
		var stack_size := mini(item.max_stack, remaining) if item.stackable else 1
		entries.append({"item": item, "quantity": stack_size})
		remaining -= stack_size
	var accepted_total := quantity - remaining
	if accepted_total > 0:
		item_added.emit(item, accepted_total, get_item_quantity(item.item_id))
		inventory_changed.emit()
	if remaining > 0:
		item_rejected.emit(item, remaining)
	return accepted_total

func remove_item(item_id: String, quantity: int = 1) -> bool:
	if item_id.is_empty() or quantity <= 0 or get_item_quantity(item_id) < quantity:
		return false
	var remaining := quantity
	for index in range(entries.size() - 1, -1, -1):
		var entry := entries[index]
		if entry.item.item_id != item_id:
			continue
		var removed := mini(int(entry.quantity), remaining)
		entry.quantity = int(entry.quantity) - removed
		remaining -= removed
		if int(entry.quantity) <= 0:
			entries.remove_at(index)
		if remaining <= 0:
			break
	if get_item_quantity(item_id) <= 0:
		_clear_quick_item_bindings(item_id)
	inventory_changed.emit()
	return true

func bind_quick_item(item_id: String, slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= QUICK_ITEM_SLOT_COUNT or get_item_quantity(item_id) <= 0:
		return false
	var item := _find_item_definition(item_id)
	if not is_instance_valid(item) or item.item_kind != ItemDefinition.ItemKind.CONSUMABLE:
		return false
	for index in range(QUICK_ITEM_SLOT_COUNT):
		if quick_item_slots[index] == item_id:
			quick_item_slots[index] = ""
	quick_item_slots[slot_index] = item_id
	inventory_changed.emit()
	return true

func get_quick_item_id(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= QUICK_ITEM_SLOT_COUNT:
		return ""
	return quick_item_slots[slot_index]

func get_quick_item_definition(slot_index: int) -> ItemDefinition:
	var item_id := get_quick_item_id(slot_index)
	if item_id.is_empty() or get_item_quantity(item_id) <= 0:
		return null
	return _find_item_definition(item_id)

func get_quick_item_slot(item_id: String) -> int:
	for index in range(mini(QUICK_ITEM_SLOT_COUNT, quick_item_slots.size())):
		if quick_item_slots[index] == item_id:
			return index
	return -1

func get_item_definition_for_equipment(equipment: EquipmentDefinition) -> ItemDefinition:
	if not is_instance_valid(equipment):
		return null
	for item in known_item_definitions:
		if is_instance_valid(item) and item.item_kind == ItemDefinition.ItemKind.EQUIPMENT and item.equipment == equipment:
			return item
	return null

func get_item_quantity(item_id: String) -> int:
	var total := 0
	for entry in entries:
		if entry.item.item_id == item_id:
			total += int(entry.quantity)
	return total

func _used_slots() -> int:
	return entries.size()

func _register_item_definition(item: ItemDefinition) -> void:
	if not is_instance_valid(item):
		return
	for known_item in known_item_definitions:
		if known_item == item:
			return
	known_item_definitions.append(item)

func _find_item_definition(item_id: String) -> ItemDefinition:
	for entry in entries:
		var item: ItemDefinition = entry.item
		if item.item_id == item_id:
			return item
	for item in known_item_definitions:
		if is_instance_valid(item) and item.item_id == item_id:
			return item
	return null

func _clear_quick_item_bindings(item_id: String) -> void:
	for index in range(mini(QUICK_ITEM_SLOT_COUNT, quick_item_slots.size())):
		if quick_item_slots[index] == item_id:
			quick_item_slots[index] = ""
