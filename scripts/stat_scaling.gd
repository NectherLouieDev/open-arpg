extends Resource
## Tunable conversion rates from STR, FIN, and ARK into derived character stats.
class_name StatScaling

@export var strength_health_per_point := 10.0
@export var strength_melee_damage_per_point := 0.015
@export var finesse_max_anima_per_point := 8.0
@export var finesse_attack_speed_per_point := 0.01
@export var finesse_move_speed_per_point := 0.005
@export var finesse_dash_cost_reduction_per_point := 0.005
@export var dash_cost_reduction_cap := 0.75
@export var arkifex_skill_damage_per_point := 0.015
@export var arkifex_cooldown_reduction_per_point := 0.0075
@export var cooldown_reduction_cap := 0.75
@export var arkifex_anima_regen_per_point := 0.01
