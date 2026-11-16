extends Resource
## Data for an attribute Talisman; recipe fields are a handoff contract for crafting.
class_name TalismanDefinition

enum Attribute { STR, FIN, ARK }
enum Tier { T1, T2, T3 }

@export var talisman_id := ""
@export var display_name := "Unnamed Talisman"
@export_enum("STR", "FIN", "ARK") var attribute: int = Attribute.STR
@export_enum("T1", "T2", "T3") var tier: int = Tier.T1
@export_range(0, 4) var rarity := 0
@export_range(0.0, 1000.0, 0.1) var attribute_bonus := 0.0
@export var secondary_effects: Dictionary = {}

@export_group("Future crafting recipe")
@export var required_shard_id := ""
@export var pairing_item_ids: PackedStringArray = PackedStringArray()
@export var required_lower_tier_talisman_id := ""
@export_range(0, 1000000, 1) var gold_cost := 0

func get_description() -> String:
	var attributes := ["STR", "FIN", "ARK"]
	var tiers := ["T1", "T2", "T3"]
	return "%s · %s · %s\n+%s %s" % [display_name, tiers[clampi(tier, 0, 2)], _rarity_name(rarity), attributes[clampi(attribute, 0, 2)], ItemDefinition.format_signed(attribute_bonus)]

func _rarity_name(value: int) -> String:
	return ["Common", "Uncommon", "Rare", "Epic", "Legendary"][clampi(value, 0, 4)]
