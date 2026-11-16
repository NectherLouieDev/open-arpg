extends Resource
## Shared item identity used by world pickups, inventory, and future UI.
class_name ItemDefinition

enum ItemKind { CURRENCY, EQUIPMENT, SHARD, CONSUMABLE, TALISMAN }
enum Attribute { STR, FIN, ARK }

@export var item_id := ""
@export var display_name := "Unnamed Item"
@export_enum("Currency", "Equipment", "Shard", "Consumable", "Talisman") var item_kind: int = ItemKind.CURRENCY
@export_enum("Common", "Uncommon", "Rare", "Epic", "Legendary") var rarity := 0
@export var stackable := true
@export_range(1, 999, 1) var max_stack := 99
@export var equipment: EquipmentDefinition
@export var talisman: TalismanDefinition
@export_enum("STR", "FIN", "ARK") var attribute: int = Attribute.STR
@export_range(0.0, 1000.0, 1.0) var health_restore := 0.0
@export_range(0.0, 1000.0, 1.0) var anima_restore := 0.0

func get_pickup_description(quantity: int = 1) -> String:
	var quantity_text := " x%d" % quantity if quantity > 1 else ""
	var details := ""
	match item_kind:
		ItemKind.EQUIPMENT:
			if is_instance_valid(equipment):
				var slot_names := ["Head", "Body", "Legs", "Feet", "Hands", "Weapon"]
				var modifiers: Array[String] = []
				if equipment.max_health_bonus != 0.0:
					modifiers.append("HP %s" % format_signed(equipment.max_health_bonus))
				if equipment.max_anima_bonus != 0.0:
					modifiers.append("Anima %s" % format_signed(equipment.max_anima_bonus))
				if equipment.attack_damage_bonus != 0.0:
					modifiers.append("Damage %s" % format_signed(equipment.attack_damage_bonus))
				if equipment.attack_speed_bonus != 0.0:
					modifiers.append("Speed %s" % format_signed(equipment.attack_speed_bonus))
				if equipment is WeaponDefinition:
					modifiers.append("Attack %.0f dmg · %.1fm · %.2fs · %d°" % [equipment.attack_damage, equipment.attack_range, equipment.attack_interval, roundi(equipment.attack_arc_degrees)])
				var modifier_text := ", ".join(modifiers) if not modifiers.is_empty() else "No stat modifiers"
				details = "%s · %s · %s\n%s · Skill: %s" % [slot_names[equipment.gear_slot], _rarity_name(equipment.rarity), equipment.equipment_line, modifier_text, equipment.granted_skill.skill_name if is_instance_valid(equipment.granted_skill) else "None"]
		ItemKind.SHARD:
			var attributes := ["STR", "FIN", "ARK"]
			details = "%s crafting material" % attributes[attribute]
		ItemKind.CURRENCY:
			details = "Currency"
		ItemKind.CONSUMABLE:
			var effects: Array[String] = []
			if health_restore > 0.0:
				effects.append("Restores %.0f Health" % health_restore)
			if anima_restore > 0.0:
				effects.append("Restores %.0f Anima" % anima_restore)
			details = ", ".join(effects) if not effects.is_empty() else "Consumable"
		ItemKind.TALISMAN:
			details = talisman.get_description() if is_instance_valid(talisman) else "Talisman"
	return "%s%s\n%s" % [display_name, quantity_text, details]

func _rarity_name(value: int) -> String:
	var names := ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
	return names[clampi(value, 0, names.size() - 1)]

static func format_signed(value: float) -> String:
	var sign := "+" if value >= 0.0 else ""
	return sign + ("%.1f" % value)
