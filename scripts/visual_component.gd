extends Node
## Coordinates character presentation components and owns targeting/range previews.
## The player or enemy root injects gameplay references, then calls initialize/update.
class_name VisualComponent

var stats: StatComponent
var movement: MovementComponent
var combat: CombatComponent
var skill: SkillComponent
var equipment: EquipmentComponent
var body: CharacterBody3D
var body_visual: SpriteBase3D
var attack_range_visual: MeshInstance3D
var skill_range_visual: MeshInstance3D
var aim_pivot: Node3D
@onready var direction_component: DirectionComponent = $DirectionComponent
@onready var hit_component: HitComponent = $HitComponent
@onready var animation_component: AnimationComponent = $AnimationComponent

var _preview_shape_visual: MeshInstance3D
var _preview_shape_material: StandardMaterial3D
var _preview_skill: SkillDefinition

func initialize() -> void:
	## Injects the sprite and signal sources into child components, then prepares previews.
	if is_instance_valid(body_visual):
		direction_component.body_visual = body_visual
		hit_component.body_visual = body_visual
		animation_component.body_visual = body_visual
	direction_component.initialize()
	hit_component.stats = stats
	hit_component.movement = movement
	hit_component.combat = combat
	hit_component.initialize()
	animation_component.initialize()
	if is_instance_valid(attack_range_visual) and attack_range_visual.mesh is TorusMesh:
		attack_range_visual.mesh = (attack_range_visual.mesh as TorusMesh).duplicate()
	if is_instance_valid(skill_range_visual) and skill_range_visual.mesh is TorusMesh:
		skill_range_visual.mesh = (skill_range_visual.mesh as TorusMesh).duplicate()
	if is_instance_valid(skill_range_visual):
		skill_range_visual.visible = false
		var range_material := skill_range_visual.material_override as StandardMaterial3D
		if is_instance_valid(range_material):
			skill_range_visual.material_override = range_material.duplicate()
		_preview_shape_material = StandardMaterial3D.new()
		_preview_shape_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_preview_shape_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_preview_shape_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_preview_shape_material.albedo_color = Color(0.35, 0.78, 1.0, 0.28)
		_preview_shape_material.render_priority = 1
		_preview_shape_visual = MeshInstance3D.new()
		_preview_shape_visual.name = "DirectionalSkillPreview"
		_preview_shape_visual.material_override = _preview_shape_material
		_preview_shape_visual.visible = false
		add_child(_preview_shape_visual)
	if is_instance_valid(combat) and not combat.attack_animation_requested.is_connected(animation_component.play_action):
		combat.attack_animation_requested.connect(animation_component.play_action)
	if is_instance_valid(skill) and not skill.skill_action_requested.is_connected(_on_skill_action_requested):
		skill.skill_action_requested.connect(_on_skill_action_requested)
	if is_instance_valid(equipment) and not equipment.equipment_set_changed.is_connected(_update_range_sizes):
		equipment.equipment_set_changed.connect(_update_range_sizes)
	_update_range_sizes()

func update(delta: float) -> void:
	## Updates aim, targeting previews, direction, hit feedback, and animation state.
	if not is_instance_valid(movement):
		return
	var facing := movement.get_facing()
	if is_instance_valid(aim_pivot) and facing.length_squared() > 0.001:
		aim_pivot.look_at(aim_pivot.global_position + facing, Vector3.UP)
	_update_skill_preview(facing)
	if not is_instance_valid(body_visual):
		return
	var current_velocity := movement.get_velocity()
	var moving := Vector2(current_velocity.x, current_velocity.z).length_squared() > 0.25
	var dashing := movement.is_dashing()
	var current_direction := direction_component.update_direction(facing)
	hit_component.update(delta, dashing, animation_component.is_casting())
	animation_component.update(delta, current_direction, moving, dashing)

func _update_range_sizes() -> void:
	if is_instance_valid(attack_range_visual) and attack_range_visual.mesh is TorusMesh and is_instance_valid(combat):
		var attack_mesh := attack_range_visual.mesh as TorusMesh
		attack_mesh.inner_radius = maxf(0.0, combat.get_attack_range() - 0.08)
		attack_mesh.outer_radius = combat.get_attack_range()
	if is_instance_valid(skill_range_visual) and skill_range_visual.mesh is TorusMesh and is_instance_valid(skill):
		var skill_mesh := skill_range_visual.mesh as TorusMesh
		skill_mesh.inner_radius = maxf(0.0, skill.get_skill_range() - 0.08)
		skill_mesh.outer_radius = skill.get_skill_range()

func _update_skill_preview(facing: Vector3) -> void:
	if not is_instance_valid(skill_range_visual):
		return
	var definition: SkillDefinition = skill.get_targeting_skill() if is_instance_valid(skill) and skill.is_targeting() else null
	if not is_instance_valid(definition):
		skill_range_visual.visible = false
		if is_instance_valid(_preview_shape_visual):
			_preview_shape_visual.visible = false
		_preview_skill = null
		return
	var is_radius := definition.targeting_shape == SkillDefinition.TargetingShape.RADIUS
	skill_range_visual.visible = is_radius
	if is_radius and skill_range_visual.mesh is TorusMesh:
		var range_mesh := skill_range_visual.mesh as TorusMesh
		range_mesh.inner_radius = maxf(0.0, definition.skill_range - 0.08)
		range_mesh.outer_radius = definition.skill_range
		var range_material := skill_range_visual.material_override as StandardMaterial3D
		if is_instance_valid(range_material):
			range_material.albedo_color = Color(definition.effect_color.r, definition.effect_color.g, definition.effect_color.b, 0.55)
	if not is_instance_valid(_preview_shape_visual):
		return
	_preview_shape_visual.visible = not is_radius
	if is_radius:
		_preview_skill = definition
		return
	if _preview_skill != definition:
		_preview_shape_visual.mesh = _make_directional_preview_mesh(definition)
		_preview_skill = definition
	var direction := Vector3(facing.x, 0.0, facing.z).normalized()
	if direction.length_squared() < 0.001:
		direction = Vector3.FORWARD
	if not is_instance_valid(body):
		return
	var preview_position := body.global_position
	preview_position.y += 0.06
	_preview_shape_visual.global_position = preview_position
	_preview_shape_visual.look_at(preview_position + direction, Vector3.UP)
	_preview_shape_material.albedo_color = Color(definition.effect_color.r, definition.effect_color.g, definition.effect_color.b, 0.28)

func _make_directional_preview_mesh(definition: SkillDefinition) -> ImmediateMesh:
	var preview_mesh := ImmediateMesh.new()
	preview_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _preview_shape_material)
	if definition.targeting_shape == SkillDefinition.TargetingShape.CONE:
		var segment_count := 24
		var half_angle := deg_to_rad(definition.cone_angle_degrees * 0.5)
		for segment in range(segment_count):
			var angle_a := lerpf(-half_angle, half_angle, float(segment) / float(segment_count))
			var angle_b := lerpf(-half_angle, half_angle, float(segment + 1) / float(segment_count))
			preview_mesh.surface_add_vertex(Vector3.ZERO)
			preview_mesh.surface_add_vertex(Vector3(sin(angle_a) * definition.skill_range, 0.0, -cos(angle_a) * definition.skill_range))
			preview_mesh.surface_add_vertex(Vector3(sin(angle_b) * definition.skill_range, 0.0, -cos(angle_b) * definition.skill_range))
	else:
		var half_width := definition.line_width * 0.5
		var left_near := Vector3(-half_width, 0.0, 0.0)
		var right_near := Vector3(half_width, 0.0, 0.0)
		var left_far := Vector3(-half_width, 0.0, -definition.skill_range)
		var right_far := Vector3(half_width, 0.0, -definition.skill_range)
		preview_mesh.surface_add_vertex(left_near)
		preview_mesh.surface_add_vertex(left_far)
		preview_mesh.surface_add_vertex(right_far)
		preview_mesh.surface_add_vertex(left_near)
		preview_mesh.surface_add_vertex(right_far)
		preview_mesh.surface_add_vertex(right_near)
	preview_mesh.surface_end()
	return preview_mesh

func _on_skill_action_requested(_slot_index: int, skill_definition: SkillDefinition) -> void:
	if is_instance_valid(skill_definition):
		animation_component.play_action(skill_definition.animation_category)
