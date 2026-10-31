extends Resource
## Data-driven enemy rewards; every entry rolls independently.
class_name LootTable

@export var entries: Array[LootTableEntry] = []

func roll() -> Array[Dictionary]:
	var drops: Array[Dictionary] = []
	for entry in entries:
		if not is_instance_valid(entry) or not is_instance_valid(entry.item):
			continue
		if randf() > clampf(entry.drop_chance, 0.0, 1.0):
			continue
		var minimum := mini(entry.minimum_quantity, entry.maximum_quantity)
		var maximum := maxi(entry.minimum_quantity, entry.maximum_quantity)
		drops.append({"item": entry.item, "quantity": randi_range(minimum, maximum)})
	return drops
