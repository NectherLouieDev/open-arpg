extends Node
## Acquires targets and supplies navigation/movement intent to the state machine.
class_name EnemyAI

@export var definition: EnemyDefinition

var enemy: CharacterBody3D
var stats: StatComponent
var body_visual: SpriteBase3D
var collision_shape: CollisionShape3D
var movement: MovementComponent
var combat: CombatComponent
var navigation_agent: NavigationAgent3D
var state_manager: EnemyStateManager
var telegraph: EnemyAttackTelegraph
var current_target: Node3D
var _patrol_index := -1
var _patrol_origin_transform := Transform3D.IDENTITY
var _last_navigation_target := Vector3.ZERO
var _has_navigation_target := false

func initialize(enemy_root: CharacterBody3D) -> void:
	enemy = enemy_root
	_patrol_origin_transform = enemy.global_transform
	movement = enemy.get_node("MovementComponent") as MovementComponent
	combat = enemy.get_node("CombatComponent") as CombatComponent
	stats = enemy.get_node("StatComponent") as StatComponent
	navigation_agent = enemy.get_node("NavigationAgent3D") as NavigationAgent3D
	state_manager = get_node("EnemyStateManager") as EnemyStateManager
	telegraph = enemy.get_node("AttackTelegraph") as EnemyAttackTelegraph
	body_visual = enemy.get_node("BodyVisual") as SpriteBase3D
	collision_shape = enemy.get_node("CollisionShape3D") as CollisionShape3D
	if is_instance_valid(definition):
		enemy.name = definition.display_name.replace(" ", "")
		movement.move_speed = definition.move_speed
		combat.attack_damage = definition.attack_damage
		combat.attack_range = definition.attack_range
		combat.attack_interval = definition.attack_interval
		combat.attack_arc_degrees = definition.attack_arc_degrees
		combat.attack_animation_category = definition.attack_animation_category
		combat.target_group = &"players"
		if is_instance_valid(stats):
			stats.max_health = definition.max_health
			stats.health = definition.max_health
		if is_instance_valid(body_visual):
			body_visual.modulate = definition.visual_tint
			body_visual.scale = definition.visual_scale
		if is_instance_valid(collision_shape):
			collision_shape.scale = definition.visual_scale
	if is_instance_valid(state_manager):
		state_manager.initialize(self)

func tick(delta: float) -> void:
	if is_instance_valid(state_manager):
		state_manager.tick(delta)

func enter_dead_state() -> void:
	if is_instance_valid(state_manager):
		state_manager.transition_to(&"Dead")

func acquire_target() -> bool:
	if not is_instance_valid(enemy) or not is_instance_valid(definition):
		return false
	var nearest: Node3D
	var nearest_distance_squared := definition.aggro_range * definition.aggro_range
	for candidate in get_tree().get_nodes_in_group(&"players"):
		if not is_instance_valid(candidate) or not candidate is Node3D or candidate == enemy:
			continue
		if not candidate.is_visible_in_tree():
			continue
		var candidate_stats := candidate.get_node_or_null("StatComponent") as StatComponent
		if is_instance_valid(candidate_stats) and candidate_stats.health <= 0.0:
			continue
		var offset = candidate.global_position - enemy.global_position
		offset.y = 0.0
		if offset.length_squared() <= nearest_distance_squared:
			nearest = candidate
			nearest_distance_squared = offset.length_squared()
	current_target = nearest
	return is_instance_valid(current_target)

func refresh_target() -> bool:
	if not is_instance_valid(current_target):
		return acquire_target()
	if not current_target.is_inside_tree() or not current_target.is_visible_in_tree():
		current_target = null
		return false
	var target_stats := current_target.get_node_or_null("StatComponent") as StatComponent
	if is_instance_valid(target_stats) and target_stats.health <= 0.0:
		current_target = null
		return false
	var offset := current_target.global_position - enemy.global_position
	offset.y = 0.0
	if offset.length_squared() > definition.leash_range * definition.leash_range:
		current_target = null
		return false
	return true

func is_target_in_attack_range() -> bool:
	return is_instance_valid(current_target) and target_distance() <= combat.get_attack_range()

func target_distance() -> float:
	if not is_instance_valid(current_target) or not is_instance_valid(enemy):
		return INF
	var offset := current_target.global_position - enemy.global_position
	offset.y = 0.0
	return offset.length()

func navigate_to_target() -> void:
	if is_instance_valid(current_target):
		navigate_to(current_target.global_position)

func select_next_patrol_point() -> void:
	if definition.patrol_points.is_empty() or not is_instance_valid(enemy):
		stop_moving()
		return
	_patrol_index = (_patrol_index + 1) % definition.patrol_points.size()
	navigate_to(_patrol_origin_transform * definition.patrol_points[_patrol_index])

func navigate_to_patrol_point() -> void:
	if _patrol_index >= 0 and _patrol_index < definition.patrol_points.size():
		navigate_to(_patrol_origin_transform * definition.patrol_points[_patrol_index])

func navigate_to(destination: Vector3) -> void:
	if not is_instance_valid(enemy) or not is_instance_valid(movement):
		return
	destination.y = enemy.global_position.y
	if not is_instance_valid(navigation_agent):
		movement.set_move_intent(destination - enemy.global_position)
		return
	if not _has_navigation_target or _last_navigation_target.distance_squared_to(destination) > 0.25:
		navigation_agent.target_position = destination
		_last_navigation_target = destination
		_has_navigation_target = true
	var next_position := destination
	var map := navigation_agent.get_navigation_map()
	if map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0 and not NavigationServer3D.map_get_regions(map).is_empty():
		var path_position := navigation_agent.get_next_path_position()
		if not navigation_agent.is_navigation_finished():
			if path_position.distance_squared_to(enemy.global_position) > 0.0001:
				next_position = path_position
	var direction := next_position - enemy.global_position
	direction.y = 0.0
	if direction.length_squared() > 0.01:
		movement.set_move_intent(direction.normalized())
	else:
		stop_moving()

func is_at_navigation_target() -> bool:
	if not is_instance_valid(enemy) or _patrol_index < 0 or _patrol_index >= definition.patrol_points.size():
		return true
	var point := _patrol_origin_transform * definition.patrol_points[_patrol_index]
	return Vector2(enemy.global_position.x - point.x, enemy.global_position.z - point.z).length() <= 0.55

func stop_moving() -> void:
	if is_instance_valid(movement):
		movement.set_move_intent(Vector3.ZERO)

func face_target() -> void:
	if is_instance_valid(current_target) and is_instance_valid(movement):
		movement.set_facing_direction(current_target.global_position - enemy.global_position)

func show_attack_telegraph() -> void:
	if is_instance_valid(telegraph):
		var facing := current_target.global_position - enemy.global_position if is_instance_valid(current_target) else Vector3.FORWARD
		facing.y = 0.0
		telegraph.global_position = enemy.global_position + Vector3.UP * 0.04
		telegraph.show_attack(combat.get_attack_range(), definition.attack_arc_degrees, definition.attack_telegraph_duration, definition.telegraph_color, facing)

func hide_attack_telegraph() -> void:
	if is_instance_valid(telegraph):
		telegraph.hide_attack()

func is_telegraph_visible() -> bool:
	return is_instance_valid(telegraph) and telegraph.visible

func perform_attack() -> void:
	if is_instance_valid(combat):
		combat.try_auto_attack()

func get_attack_recovery() -> float:
	return maxf(definition.attack_recovery_duration, combat.get_attack_interval())

func drop_loot() -> void:
	if not is_instance_valid(definition) or not is_instance_valid(enemy):
		return
	if not is_instance_valid(definition.loot_table):
		push_warning("Enemy '%s' has no loot table assigned." % definition.display_name)
		return
	var scene_parent := enemy.get_parent()
	if not is_instance_valid(scene_parent):
		return
	var pickup_scene := definition.loot_pickup_scene
	if not is_instance_valid(pickup_scene):
		pickup_scene = preload("res://scenes/loot_pickup.tscn")
	var drop_index := 0
	var drops := definition.loot_table.roll()
	if drops.is_empty():
		return
	for drop in drops:
		var loot := pickup_scene.instantiate() as LootPickup
		if not is_instance_valid(loot):
			continue
		scene_parent.add_child(loot)
		loot.configure(drop.item, drop.quantity)
		var offset := Vector3(float(drop_index % 3 - 1) * 0.55, 0.25, float(drop_index / 3) * 0.45)
		loot.global_position = enemy.global_position + offset
		drop_index += 1
