extends Node
## Applies short-lived visual feedback for damage, attacks, dashes, and casting.
## Gameplay effects such as damage and invulnerability remain owned by other components.
class_name HitComponent

var body_visual: SpriteBase3D
var movement: MovementComponent
var combat: CombatComponent
var stats: StatComponent
var base_tint := Color.WHITE
var hit_flash_left := 0.0
var action_flash_left := 0.0

func initialize() -> void:
	if is_instance_valid(body_visual):
		base_tint = body_visual.modulate
	if is_instance_valid(stats) and not stats.damaged.is_connected(_on_damaged):
		stats.damaged.connect(_on_damaged)
	if is_instance_valid(movement) and not movement.dash_started.is_connected(_on_dash_started):
		movement.dash_started.connect(_on_dash_started)
	if is_instance_valid(combat) and not combat.attack_performed.is_connected(_on_attack_performed):
		combat.attack_performed.connect(_on_attack_performed)

func update(delta: float, dashing: bool, casting: bool) -> void:
	## Advances feedback timers and applies the highest-priority tint to the sprite.
	hit_flash_left = maxf(0.0, hit_flash_left - delta)
	action_flash_left = maxf(0.0, action_flash_left - delta)
	if not is_instance_valid(body_visual):
		return
	var tint := base_tint
	if hit_flash_left > 0.0:
		tint = Color.WHITE
	elif action_flash_left > 0.0:
		tint = base_tint.lightened(0.35)
	elif dashing:
		tint = base_tint.lerp(Color(0.35, 0.9, 0.95), 0.55)
	elif casting:
		tint = base_tint.lerp(Color(0.5, 0.75, 1.0), 0.25)
	body_visual.modulate = tint

func _on_damaged(_amount: float) -> void:
	hit_flash_left = 0.16

func _on_dash_started() -> void:
	action_flash_left = 0.12

func _on_attack_performed(_target: Node3D, _amount: float) -> void:
	action_flash_left = 0.1
