extends Resource
## Data resource defining a skill's cost, timing, damage, targeting, and visual effects.
class_name SkillDefinition

enum TargetingShape { RADIUS, CONE, LINE }

@export var skill_name := "Unnamed Skill"
@export_multiline var description := ""
@export var anima_cost := 20.0
@export var cooldown := 4.0
@export var skill_range := 4.0
@export var damage := 25.0
@export var action_lockout := 0.35
@export_enum("Range Attack", "Light Attack", "Heavy Attack", "Casting") var animation_category := 3
@export_enum("Radius", "Cone", "Line") var targeting_shape: int = TargetingShape.RADIUS
@export_range(1.0, 180.0, 1.0) var cone_angle_degrees := 90.0
@export_range(0.1, 5.0, 0.1) var line_width := 1.2
@export var effect_color := Color(0.2, 0.85, 1.0, 1.0)
@export var effect_radius := 0.7
