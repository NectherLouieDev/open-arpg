extends RefCounted
## Shared presentation helpers for combat events such as damage numbers and hit-stop.
class_name CombatFeedback

static func show_damage_number(tree: SceneTree, world_position: Vector3, amount: float, is_skill: bool) -> void:
	if not is_instance_valid(tree) or not is_instance_valid(tree.current_scene):
		return
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.01
	label.font_size = 48
	label.outline_size = 8
	label.text = "-%.0f" % amount
	label.modulate = Color(0.55, 0.82, 1.0) if is_skill else Color(1.0, 0.9, 0.75)
	tree.current_scene.add_child(label)
	label.global_position = world_position
	var tween := label.create_tween()
	tween.tween_property(label, "global_position", world_position + Vector3.UP * 0.85, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.55)
	tween.tween_callback(label.queue_free)
