extends Node
## Owns health and Anima values, applies damage, and emits stat and death signals.
class_name StatComponent

signal stats_changed
signal damaged(amount: float)
signal died

@export var max_health := 100.0
@export var max_anima := 100.0
@export var anima_regen_per_second := 18.0
@export var anima_regen_delay := 0.8

var health := 100.0
var anima := 100.0
var attack_damage_bonus := 0.0
var attack_range_bonus := 0.0
var attack_speed_bonus := 0.0
var attributes: AttributeComponent
var _regen_delay_left := 0.0
var _is_dead := false
var _base_max_health := 100.0
var _base_max_anima := 100.0
var _equipment_health_bonus := 0.0
var _equipment_anima_bonus := 0.0

func _ready() -> void:
	_base_max_health = max_health
	_base_max_anima = max_anima
	health = max_health
	anima = max_anima

func apply_equipment_modifiers(health_bonus: float, anima_bonus: float, damage_bonus: float, range_bonus: float, speed_bonus: float) -> void:
	_equipment_health_bonus = health_bonus
	_equipment_anima_bonus = anima_bonus
	attack_damage_bonus = damage_bonus
	attack_range_bonus = range_bonus
	attack_speed_bonus = speed_bonus
	_refresh_maximums()

func refresh_attribute_modifiers() -> void:
	_refresh_maximums()

func _refresh_maximums() -> void:
	var health_ratio := health / max_health if max_health > 0.0 else 1.0
	var anima_ratio := anima / max_anima if max_anima > 0.0 else 1.0
	var attribute_health := attributes.get_health_bonus() if is_instance_valid(attributes) else 0.0
	var attribute_anima := attributes.get_max_anima_bonus() if is_instance_valid(attributes) else 0.0
	max_health = maxf(1.0, _base_max_health + _equipment_health_bonus + attribute_health)
	max_anima = maxf(0.0, _base_max_anima + _equipment_anima_bonus + attribute_anima)
	health = clampf(health_ratio * max_health, 0.0, max_health)
	anima = clampf(anima_ratio * max_anima, 0.0, max_anima)
	stats_changed.emit()

func _process(delta: float) -> void:
	if _is_dead or anima >= max_anima:
		return
	if _regen_delay_left > 0.0:
		_regen_delay_left = maxf(0.0, _regen_delay_left - delta)
		if _regen_delay_left > 0.0:
			return
	var regen_multiplier := attributes.get_anima_regen_multiplier() if is_instance_valid(attributes) else 1.0
	var previous_anima := anima
	anima = minf(max_anima, anima + anima_regen_per_second * regen_multiplier * delta)
	if not is_equal_approx(previous_anima, anima):
		stats_changed.emit()

func take_damage(amount: float) -> void:
	if _is_dead or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	damaged.emit(amount)
	stats_changed.emit()
	if health <= 0.0:
		_is_dead = true
		died.emit()

func spend_anima(amount: float) -> bool:
	if _is_dead or amount < 0.0 or anima < amount:
		return false
	if amount <= 0.0:
		return true
	anima = maxf(0.0, anima - amount)
	_regen_delay_left = anima_regen_delay
	stats_changed.emit()
	return true

func heal(amount: float) -> void:
	if _is_dead or amount <= 0.0:
		return
	var previous_health := health
	health = minf(max_health, health + amount)
	if not is_equal_approx(previous_health, health):
		stats_changed.emit()

func restore_anima(amount: float) -> void:
	if _is_dead or amount <= 0.0:
		return
	var previous_anima := anima
	anima = minf(max_anima, anima + amount)
	if not is_equal_approx(previous_anima, anima):
		stats_changed.emit()

func is_dead() -> bool:
	return _is_dead
