extends MeshInstance3D
## Draws the configured melee attack arc on the ground during an enemy wind-up.
class_name EnemyAttackTelegraph

var _material: StandardMaterial3D
var _time_left := 0.0

func _ready() -> void:
	visible = false
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.albedo_color = Color(1.0, 0.12, 0.08, 0.35)
	_material.emission_enabled = true
	_material.emission = Color(1.0, 0.04, 0.02)
	material_override = _material

func show_attack(radius: float, arc_degrees: float, duration: float, color: Color, facing: Vector3) -> void:
	mesh = _build_arc_mesh(radius, arc_degrees)
	_material.albedo_color = Color(color.r, color.g, color.b, 0.35)
	_material.emission = color
	_time_left = duration
	if facing.length_squared() > 0.001:
		look_at(global_position + Vector3(facing.x, 0.0, facing.z).normalized(), Vector3.UP)
	visible = true

func hide_attack() -> void:
	visible = false
	_time_left = 0.0

func _process(delta: float) -> void:
	if not visible:
		return
	_time_left = maxf(0.0, _time_left - delta)
	if _time_left <= 0.0:
		hide_attack()

func _build_arc_mesh(radius: float, arc_degrees: float) -> ImmediateMesh:
	var result := ImmediateMesh.new()
	result.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 24
	var half_angle := deg_to_rad(clampf(arc_degrees, 0.0, 360.0) * 0.5)
	for index in range(segments):
		var angle_a := lerpf(-half_angle, half_angle, float(index) / float(segments))
		var angle_b := lerpf(-half_angle, half_angle, float(index + 1) / float(segments))
		result.surface_add_vertex(Vector3.ZERO)
		result.surface_add_vertex(Vector3(sin(angle_a) * radius, 0.0, -cos(angle_a) * radius))
		result.surface_add_vertex(Vector3(sin(angle_b) * radius, 0.0, -cos(angle_b) * radius))
	result.surface_end()
	return result
