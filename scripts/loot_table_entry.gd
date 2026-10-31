extends Resource
## One independently rolled item entry in a LootTable.
class_name LootTableEntry

@export var item: ItemDefinition
@export_range(0.0, 1.0, 0.01) var drop_chance := 1.0
@export_range(1, 999, 1) var minimum_quantity := 1
@export_range(1, 999, 1) var maximum_quantity := 1
