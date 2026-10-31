extends Node3D
## Stationary practice target that records incoming damage and plays hit effects.

@export var max_health := 100000.0
@onready var visual: Sprite3D = $Visual
@onready var damage_label: Label3D = $DamageLabel
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var skill_hit_particles: CPUParticles3D = $SkillHitParticles

var health := 100.0
var _hit_flash_left := 0.0
var _resetting := false
var _damage_tween: Tween
var _visual_time := 0.0
var _base_tint := Color.WHITE

func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	visual.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_base_tint = visual.modulate
	damage_label.visible = false

func _process(delta: float) -> void:
	_visual_time += delta
	if not _resetting and _hit_flash_left <= 0.0:
		visual.position.y = 1.0 + sin(_visual_time * 2.8) * 0.015
	if _hit_flash_left > 0.0:
		_hit_flash_left = maxf(0.0, _hit_flash_left - delta)
		if _hit_flash_left <= 0.0:
			visual.modulate = _base_tint

func take_damage(amount: float, _source_position: Vector3 = Vector3.ZERO, is_skill: bool = false) -> void:
	if _resetting or health <= 0.0:
		return
	health = maxf(0.0, health - amount)
	_hit_flash_left = 0.18
	visual.modulate = Color.WHITE
	visual.scale = Vector3(1.18, 0.88, 1.18)
	var squash := create_tween()
	squash.tween_property(visual, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_skill:
		skill_hit_particles.emitting = true
		skill_hit_particles.restart()
	_show_damage_number(amount)
	_log_debug("Dummy took %.0f damage · HP %.0f/%.0f" % [amount, health, max_health])
	if health <= 0.0:
		_reset_dummy()

func play_skill_hit_vfx(effect_color: Color, effect_radius: float) -> void:
	skill_hit_particles.color = effect_color
	skill_hit_particles.scale_amount_min = effect_radius * 0.1
	skill_hit_particles.scale_amount_max = effect_radius * 0.2
	skill_hit_particles.emitting = true
	skill_hit_particles.restart()

func _show_damage_number(amount: float) -> void:
	if _damage_tween and _damage_tween.is_running():
		_damage_tween.kill()
	damage_label.text = "-%.0f" % amount
	damage_label.position = Vector3(0.0, 2.0, 0.0)
	damage_label.modulate = Color.WHITE
	damage_label.visible = true
	_damage_tween = create_tween()
	_damage_tween.set_parallel(true)
	_damage_tween.tween_property(damage_label, "position:y", 2.8, 0.55)
	_damage_tween.tween_property(damage_label, "modulate:a", 0.0, 0.55)
	_damage_tween.chain().tween_callback(func(): damage_label.visible = false)

func _reset_dummy() -> void:
	_resetting = true
	visible = false
	collision_shape.set_deferred("disabled", true)
	_log_debug("Training dummy down · resetting")
	await get_tree().create_timer(1.5).timeout
	health = max_health
	visible = true
	collision_shape.set_deferred("disabled", false)
	_resetting = false
	_log_debug("Training dummy restored · HP %.0f" % max_health)

func _log_debug(message: String) -> void:
	var hud := get_tree().get_first_node_in_group("debug_hud")
	if hud and hud.has_method("log_event"):
		hud.call("log_event", message)
