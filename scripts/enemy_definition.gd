extends Resource
## Tuning data for a reusable enemy archetype: stats, AI, attacks, visuals, and drops.
class_name EnemyDefinition

@export var display_name := "Melee Enemy"
@export var max_health := 80.0
@export var move_speed := 4.0
@export var aggro_range := 9.0
@export var leash_range := 16.0
@export var patrol_points: PackedVector3Array = PackedVector3Array()
@export var patrol_wait := 1.2
@export var attack_damage := 8.0
@export var attack_range := 1.8
@export var attack_interval := 1.6
@export_range(0.0, 360.0, 1.0) var attack_arc_degrees := 110.0
@export var attack_telegraph_duration := 0.65
@export var attack_recovery_duration := 0.45
@export var attack_animation_category := 1
@export var death_cleanup_delay := 0.65
@export var loot_table: LootTable
@export var loot_pickup_scene: PackedScene
@export var telegraph_color := Color(1.0, 0.12, 0.08, 1.0)
@export var visual_tint := Color(1.0, 0.55, 0.45, 1.0)
@export var visual_scale := Vector3.ONE
