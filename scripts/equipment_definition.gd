extends Resource
## Data resource describing a gear piece, its slot, stats, line, and granted skills.
class_name EquipmentDefinition

enum GearSlot { HEAD, BODY, LEGS, FEET, HANDS, WEAPON }

@export var equipment_name := "Unnamed Equipment"
@export var item_id := ""
@export_enum("Common", "Uncommon", "Rare", "Epic", "Legendary") var rarity := 0
@export var equipment_line := ""
@export_enum("Head", "Body", "Legs", "Feet", "Hands", "Weapon") var gear_slot: int = GearSlot.HEAD
@export var granted_skill: SkillDefinition
@export var max_health_bonus := 0.0
@export var max_anima_bonus := 0.0
@export var attack_damage_bonus := 0.0
@export var attack_range_bonus := 0.0
@export var attack_speed_bonus := 0.0
