extends Node
## Handles auto-attacks, target selection, attack timing, and attack feedback signals.
class_name CombatComponent

signal attack_performed(target: Node3D, amount: float)
signal attack_animation_requested(animation_category: int)
signal auto_attack_targeted(target: Node3D)

@export var attack_damage := 12.0
@export var attack_range := 3.0
@export var attack_interval := 0.65
@export_range(0.0, 360.0, 1.0) var attack_arc_degrees := 120.0
@export_range(0, 3, 1) var attack_animation_category := 1
@export var target_group: StringName = &"enemies"

var stats: StatComponent
var attributes: AttributeComponent
var equipment: EquipmentComponent
var movement: MovementComponent
var body: CharacterBody3D
var _attack_audio: AudioStreamPlayer

var _attack_timer := 0.0
var _last_target_name := "None"

func _ready() -> void:
	_attack_audio = AudioStreamPlayer.new()
	_attack_audio.name = "AttackSFX"
	_attack_audio.volume_db = -8.0
	_attack_audio.stream = _make_attack_sound()
	add_child(_attack_audio)

func tick(delta: float) -> void:
	_attack_timer = maxf(0.0, _attack_timer - delta)

func find_nearest_target(max_range: float) -> Node3D:
	if not is_instance_valid(body):
		return null
	var nearest: Node3D = null
	var nearest_distance_squared := max_range * max_range
	for candidate in get_tree().get_nodes_in_group(target_group):
		if not is_instance_valid(candidate) or not candidate is Node3D or candidate == body:
			continue
		var candidate_3d := candidate as Node3D
		if not candidate_3d.is_visible_in_tree():
			continue
		var offset := candidate_3d.global_position - body.global_position
		offset.y = 0.0
		var distance_squared := offset.length_squared()
		if distance_squared <= nearest_distance_squared:
			nearest = candidate_3d
			nearest_distance_squared = distance_squared
	return nearest

func find_nearest_target_for_skill(definition: SkillDefinition, facing: Vector3) -> Node3D:
	if not is_instance_valid(body) or not is_instance_valid(definition):
		return null
	var direction := Vector3(facing.x, 0.0, facing.z).normalized()
	if direction.length_squared() < 0.001:
		direction = Vector3.FORWARD
	var nearest: Node3D = null
	var nearest_distance_squared := definition.skill_range * definition.skill_range
	for candidate in get_tree().get_nodes_in_group(target_group):
		if not is_instance_valid(candidate) or not candidate is Node3D or candidate == body:
			continue
		var target := candidate as Node3D
		if not target.is_visible_in_tree():
			continue
		var offset := target.global_position - body.global_position
		offset.y = 0.0
		var distance_squared := offset.length_squared()
		if distance_squared > nearest_distance_squared:
			continue
		var in_shape := false
		match definition.targeting_shape:
			SkillDefinition.TargetingShape.RADIUS:
				in_shape = true
			SkillDefinition.TargetingShape.CONE:
				if distance_squared > 0.0001:
					var half_angle := deg_to_rad(definition.cone_angle_degrees * 0.5)
					in_shape = direction.dot(offset.normalized()) >= cos(half_angle)
			SkillDefinition.TargetingShape.LINE:
				var forward_distance := offset.dot(direction)
				var lateral_distance := (offset - direction * forward_distance).length()
				in_shape = forward_distance >= 0.0 and lateral_distance <= definition.line_width * 0.5
		if in_shape:
			nearest = target
			nearest_distance_squared = distance_squared
	return nearest

func get_attack_damage() -> float:
	return DamageService.calculate_damage(_get_base_attack_damage(), stats, attributes, _get_attack_damage_type())

func get_attack_range() -> float:
	var weapon: WeaponDefinition = equipment.get_weapon() if is_instance_valid(equipment) else null
	var base_range := weapon.attack_range if is_instance_valid(weapon) else attack_range
	return maxf(0.0, base_range + (stats.attack_range_bonus if is_instance_valid(stats) else 0.0))

func get_attack_interval() -> float:
	var weapon: WeaponDefinition = equipment.get_weapon() if is_instance_valid(equipment) else null
	var base_interval := weapon.attack_interval if is_instance_valid(weapon) else attack_interval
	var speed_bonus := stats.attack_speed_bonus if is_instance_valid(stats) else 0.0
	var attribute_speed := attributes.get_attack_speed_multiplier() if is_instance_valid(attributes) else 1.0
	return maxf(0.05, base_interval / (maxf(0.1, 1.0 + speed_bonus) * attribute_speed))

func _get_base_attack_damage() -> float:
	var weapon: WeaponDefinition = equipment.get_weapon() if is_instance_valid(equipment) else null
	return weapon.attack_damage if is_instance_valid(weapon) else attack_damage

func try_auto_attack() -> void:
	if not is_instance_valid(body) or not is_instance_valid(stats) or stats.health <= 0.0:
		return
	var effective_range := get_attack_range()
	var target := find_nearest_attack_target(effective_range)
	_last_target_name = target.name if is_instance_valid(target) else "None"
	if target != null:
		auto_attack_targeted.emit(target)
	if target == null or _attack_timer > 0.0:
		return
	_attack_timer = get_attack_interval()
	apply_damage_to(target, _get_base_attack_damage(), false)
	_log_debug("Auto attack → %s for %.0f" % [target.name, get_attack_damage()])

func find_nearest_attack_target(max_range: float) -> Node3D:
	if not is_instance_valid(body):
		return null
	var facing := movement.get_facing() if is_instance_valid(movement) else -body.global_basis.z
	facing.y = 0.0
	if facing.length_squared() < 0.001:
		facing = Vector3.FORWARD
	facing = facing.normalized()
	var weapon: WeaponDefinition = equipment.get_weapon() if is_instance_valid(equipment) else null
	var arc := weapon.attack_arc_degrees if is_instance_valid(weapon) else attack_arc_degrees
	var min_dot := cos(deg_to_rad(clampf(arc, 0.0, 360.0) * 0.5))
	var nearest: Node3D = null
	var nearest_distance_squared := max_range * max_range
	for candidate in get_tree().get_nodes_in_group(target_group):
		if not is_instance_valid(candidate) or not candidate is Node3D or candidate == body:
			continue
		var target := candidate as Node3D
		if not target.is_visible_in_tree():
			continue
		var offset := target.global_position - body.global_position
		offset.y = 0.0
		var distance_squared := offset.length_squared()
		if distance_squared > nearest_distance_squared:
			continue
		if arc < 360.0 and distance_squared > 0.0001 and facing.dot(offset.normalized()) < min_dot:
			continue
		nearest = target
		nearest_distance_squared = distance_squared
	return nearest

func apply_damage_to(target: Node3D, amount: float, is_skill: bool, effect_color: Color = Color(0.2, 0.85, 1.0, 1.0), effect_radius: float = 0.7) -> void:
	if not is_instance_valid(target) or not target.has_method("take_damage"):
		return
	if not is_instance_valid(body):
		return
	var damage_type: int = DamageService.DamageType.SKILL if is_skill else _get_attack_damage_type()
	var final_damage := DamageService.calculate_damage(amount, stats, attributes, damage_type)
	target.call("take_damage", final_damage, body.global_position, is_skill)
	if is_skill and target.has_method("play_skill_hit_vfx"):
		target.call("play_skill_hit_vfx", effect_color, effect_radius)
	attack_performed.emit(target, final_damage)
	if is_instance_valid(_attack_audio):
		_attack_audio.play()
	DamageService.request_hit_stop()
	if not is_skill:
		attack_animation_requested.emit(_get_attack_animation_category())

func get_attack_cooldown_left() -> float:
	return _attack_timer

func get_last_target_name() -> String:
	return _last_target_name

func _get_attack_damage_type() -> int:
	var category := _get_attack_animation_category()
	if category == 2:
		return DamageService.DamageType.HEAVY
	if category == 1:
		return DamageService.DamageType.MELEE
	return DamageService.DamageType.GENERIC

func _get_attack_animation_category() -> int:
	var weapon: WeaponDefinition = equipment.get_weapon() if is_instance_valid(equipment) else null
	return weapon.attack_animation_category if is_instance_valid(weapon) else attack_animation_category

func _make_attack_sound() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	var sample_count := 3308
	var samples := PackedByteArray()
	samples.resize(sample_count * 2)
	for index in range(sample_count):
		var time := float(index) / float(stream.mix_rate)
		var envelope := exp(-time * 48.0)
		var tone := sin(TAU * (150.0 + 110.0 * time) * time)
		samples.encode_s16(index * 2, int(tone * envelope * 15000.0))
	stream.data = samples
	return stream

func _log_debug(message: String) -> void:
	var hud := get_tree().get_first_node_in_group("debug_hud")
	if hud and hud.has_method("log_event"):
		hud.call("log_event", message)
