extends CharacterBody3D
## Enemy root that wires shared gameplay components and handles damage and death.
class_name Enemy

@export var enemy_definition: EnemyDefinition

@onready var ai: EnemyAI = $EnemyAI
@onready var movement: MovementComponent = $MovementComponent
@onready var stats: StatComponent = $StatComponent
@onready var attributes: AttributeComponent = get_node_or_null("AttributeComponent") as AttributeComponent
@onready var combat: CombatComponent = $CombatComponent
@onready var visual: VisualComponent = $VisualComponent
@onready var body_visual: Sprite3D = $BodyVisual
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var aim_pivot: Node3D = $AimPivot
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var state_manager: EnemyStateManager = $EnemyAI/EnemyStateManager
@onready var attack_telegraph: EnemyAttackTelegraph = $AttackTelegraph
@onready var skill_hit_particles: CPUParticles3D = $SkillHitParticles

var is_dead := false

func _ready() -> void:
	add_to_group("enemies")
	if is_instance_valid(enemy_definition):
		ai.definition = enemy_definition
	movement.stats = stats
	movement.attributes = attributes
	movement.body = self
	if is_instance_valid(attributes):
		attributes.initialize(stats)
	combat.stats = stats
	combat.attributes = attributes
	combat.target_group = &"players"
	combat.movement = movement
	combat.body = self
	visual.stats = stats
	visual.movement = movement
	visual.combat = combat
	visual.body_visual = body_visual
	visual.aim_pivot = aim_pivot
	visual.initialize()
	ai.initialize(self)
	stats.died.connect(_on_died)

func _process(delta: float) -> void:
	visual.update(delta)

func _physics_process(delta: float) -> void:
	ai.tick(delta)
	movement.tick(delta)
	combat.tick(delta)

func take_damage(amount: float, source_position: Vector3 = Vector3.ZERO, _is_skill: bool = false) -> void:
	stats.take_damage(amount)
	if not is_dead:
		movement.apply_hit_reaction(source_position)
	CombatFeedback.show_damage_number(get_tree(), global_position + Vector3.UP * 1.25, amount, _is_skill)

func play_skill_hit_vfx(effect_color: Color, effect_radius: float) -> void:
	skill_hit_particles.color = effect_color
	skill_hit_particles.scale_amount_min = effect_radius * 0.1
	skill_hit_particles.scale_amount_max = effect_radius * 0.2
	skill_hit_particles.emitting = true
	skill_hit_particles.restart()

func _on_died() -> void:
	is_dead = true
	remove_from_group("enemies")
	ai.enter_dead_state()
