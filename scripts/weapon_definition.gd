extends EquipmentDefinition
## Weapon-specific equipment data for attack damage, range, speed, and arc.
class_name WeaponDefinition

@export var attack_damage := 12.0
@export var attack_range := 3.0
@export var attack_interval := 0.65
@export_range(0.0, 360.0, 1.0) var attack_arc_degrees := 120.0
@export_enum("Range Attack", "Light Attack", "Heavy Attack", "Casting") var attack_animation_category := 1
