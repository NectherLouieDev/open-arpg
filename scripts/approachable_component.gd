extends Node
## Marks an entity as something the player can approach or interact with.
class_name ApproachableComponent

@export var interaction_radius := 1.5
@export var approach_offset := 0.2

func _ready() -> void:
	add_to_group("approachables")

func get_interaction_radius() -> float:
	return interaction_radius

func get_approach_position(from: Vector3) -> Vector3:
	var object_position := _get_object_position()
	var to_from := from - object_position
	to_from.y = 0.0
	if to_from.length_squared() < 0.0001:
		to_from = Vector3.FORWARD
	return object_position + to_from.normalized() * (interaction_radius + approach_offset)

func _get_object_position() -> Vector3:
	var object := get_parent() as Node3D
	return object.global_position if is_instance_valid(object) else Vector3.ZERO
