extends CharacterBody3D
## Player root that injects component dependencies and coordinates the main game loop.
class_name Player

signal stats_changed
signal died
signal target_reached(target: Node3D)
signal target_lost

@onready var controller: PlayerController = $PlayerController
@onready var targeting: TargetingComponent = $TargetingComponent
@onready var stats: StatComponent = $StatComponent
@onready var attributes: AttributeComponent = $AttributeComponent
@onready var equipment: EquipmentComponent = $EquipmentComponent
@onready var inventory: InventoryComponent = $InventoryComponent
@onready var talismans: TalismanComponent = $TalismanComponent
@onready var inventory_ui: InventoryUI = $InventoryUI
@onready var movement: MovementComponent = $MovementComponent
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var combat: CombatComponent = $CombatComponent
@onready var skill: SkillComponent = $SkillComponent
@onready var visual: VisualComponent = $VisualComponent
@onready var camera_rig: CameraRig = $CameraRig
@onready var body_visual: AnimatedSprite3D = $BodyVisual
@onready var aim_pivot: Node3D = $AimPivot
@onready var attack_range_visual: MeshInstance3D = $AttackRange
@onready var skill_range_visual: MeshInstance3D = $SkillRange

var is_dead := false
var _controller_enabled_before_inventory := true

func _ready() -> void:
	add_to_group("players")
	attributes.initialize(stats)
	talismans.initialize(attributes)
	equipment.initialize(stats)
	movement.stats = stats
	movement.attributes = attributes
	movement.body = self
	movement.set_navigation_agent(navigation_agent)

	skill.stats = stats
	skill.attributes = attributes
	skill.equipment = equipment
	skill.combat = combat
	skill.movement = movement
	skill.body = self

	combat.stats = stats
	combat.attributes = attributes
	combat.equipment = equipment
	combat.movement = movement
	combat.target_group = &"enemies"
	combat.body = self

	visual.stats = stats
	visual.movement = movement
	visual.combat = combat
	visual.skill = skill
	visual.equipment = equipment
	visual.body = self
	visual.body_visual = body_visual
	visual.attack_range_visual = attack_range_visual
	visual.skill_range_visual = skill_range_visual
	visual.aim_pivot = aim_pivot
	visual.initialize()

	controller.camera_rig = camera_rig
	controller.movement = movement
	controller.targeting = targeting
	controller.skill = skill
	controller.combat = combat
	targeting.movement = movement
	targeting.body = self

	stats.stats_changed.connect(_on_stats_changed)
	stats.died.connect(_on_died)
	combat.auto_attack_targeted.connect(_on_auto_attack_targeted)
	targeting.target_reached.connect(_on_target_reached)
	targeting.target_lost.connect(_on_target_lost)
	inventory_ui.opened_changed.connect(_on_inventory_opened_changed)
	inventory_ui.bind_player(self)
	camera_rig.follow(global_position)

func _process(delta: float) -> void:
	camera_rig.follow(global_position)
	visual.update(delta)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	controller.poll_input()
	for slot_index in range(InventoryComponent.QUICK_ITEM_SLOT_COUNT):
		if Input.is_action_just_pressed("item_%d" % (slot_index + 1)):
			_use_quick_item(slot_index)
	movement.tick(delta)
	skill.tick(delta)
	combat.tick(delta)
	if not skill.is_locked_out() and not skill.is_targeting():
		combat.try_auto_attack()

func _use_quick_item(slot_index: int) -> void:
	var item := inventory.get_quick_item_definition(slot_index)
	if not is_instance_valid(item):
		return
	var restores_health := item.health_restore > 0.0 and stats.health < stats.max_health
	var restores_anima := item.anima_restore > 0.0 and stats.anima < stats.max_anima
	if not restores_health and not restores_anima:
		return
	if restores_health:
		stats.heal(item.health_restore)
	if restores_anima:
		stats.restore_anima(item.anima_restore)
	inventory.remove_item(item.item_id, 1)

func take_damage(amount: float, source_position: Vector3 = Vector3.ZERO, is_skill: bool = false) -> void:
	_take_damage(amount, source_position, is_skill)

func _take_damage(amount: float, source_position: Vector3, _is_skill: bool) -> void:
	if movement.is_invulnerable():
		return
	stats.take_damage(amount)
	if not is_dead and is_instance_valid(movement):
		movement.apply_hit_reaction(source_position)
	CombatFeedback.show_damage_number(get_tree(), global_position + Vector3.UP * 1.25, amount, _is_skill)

func get_debug_stats() -> Dictionary:
	return {
		"health": stats.health,
		"max_health": stats.max_health,
		"anima": stats.anima,
		"max_anima": stats.max_anima,
		"str": attributes.strength,
		"fin": attributes.finesse,
		"ark": attributes.arkifex,
		"damage": combat.get_attack_damage(),
		"range": combat.get_attack_range(),
		"attack_cooldown": combat.get_attack_cooldown_left(),
		"target": combat.get_last_target_name(),
		"skill_cooldowns": _get_skill_cooldowns(),
		"skill_action_lockout": skill.get_action_lockout_left(),
		"dash_cooldown": movement.get_dash_cooldown_left(),
		"invulnerable": movement.is_invulnerable()
	}

func _get_skill_cooldowns() -> Array[float]:
	var values: Array[float] = []
	for slot_index in range(1, 7):
		values.append(skill.get_cooldown_left(slot_index))
	return values

func _on_stats_changed() -> void:
	stats_changed.emit()

func _on_died() -> void:
	is_dead = true
	remove_from_group("players")
	controller.set_enabled(false)
	movement.clear_move_target()
	velocity = Vector3.ZERO
	died.emit()

func _on_target_reached(target: Node3D) -> void:
	target_reached.emit(target)

func _on_target_lost() -> void:
	target_lost.emit()

func _on_inventory_opened_changed(is_open: bool) -> void:
	if is_open:
		_controller_enabled_before_inventory = controller.is_enabled()
		controller.set_enabled(false)
	else:
		controller.set_enabled(_controller_enabled_before_inventory and not is_dead)

func _on_auto_attack_targeted(_target: Node3D) -> void:
	if not targeting.is_attack_approaching() and not movement.has_move_target():
		return
	targeting.clear_target()
	movement.clear_move_target()
