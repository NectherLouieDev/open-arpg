extends Node
## Builds and selects the sprite's idle, movement, and shared attack animations.
## Attack categories map to the project's four base animation types.
class_name AnimationComponent

var body_visual: SpriteBase3D
var action_left := 0.0
var action_duration := 0.3
var action_category := 1

func initialize() -> void:
	if body_visual is AnimatedSprite3D:
		_initialize_rogue_animations(body_visual as AnimatedSprite3D)

func update(delta: float, direction: String, moving: bool, dashing: bool) -> void:
	## Advances action timing and selects the animation for the current visual state.
	action_left = maxf(0.0, action_left - delta)
	if body_visual is AnimatedSprite3D:
		_update_animated_sprite(body_visual as AnimatedSprite3D, direction, moving, dashing)

func play_action(animation_category: int) -> void:
	## Plays one of the four base actions for its configured duration.
	action_category = clampi(animation_category, 0, 3)
	match action_category:
		0: action_duration = 0.25
		1: action_duration = 0.3
		2: action_duration = 0.43
		3: action_duration = 0.38
	action_left = action_duration

func is_casting() -> bool:
	return action_left > 0.0 and action_category == 3

func _initialize_rogue_animations(sprite: AnimatedSprite3D) -> void:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	_add_sprite_animation(frames, "idle_down", ["res://assets/characters/player/rogue_idle_0.png", "res://assets/characters/player/rogue_idle_1.png"], 2.0, true)
	for direction in ["up", "left", "right"]:
		_add_sprite_animation(frames, "idle_%s" % direction, ["res://assets/characters/player/rogue_walk_%s_0.png" % direction], 1.0, true)
	for direction in ["up", "down", "left", "right"]:
		var walk_paths: Array[String] = []
		for index in range(4):
			walk_paths.append("res://assets/characters/player/rogue_walk_%s_%d.png" % [direction, index])
		_add_sprite_animation(frames, "walk_%s" % direction, walk_paths, 8.0, true)
		var action_paths: Array[String] = []
		for index in range(3):
			action_paths.append("res://assets/characters/player/rogue_act_%s_%d.png" % [direction, index])
		var speeds: Dictionary = {"range": 12.0, "light": 10.0, "heavy": 7.0, "casting": 8.0}
		for action_name in ["range", "light", "heavy", "casting"]:
			_add_sprite_animation(frames, "%s_%s" % [action_name, direction], action_paths, speeds[action_name], false)
	sprite.sprite_frames = frames
	sprite.animation = "idle_down"
	sprite.play()

func _add_sprite_animation(frames: SpriteFrames, animation_name: String, paths: Array[String], fps: float, loops: bool) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, fps)
	frames.set_animation_loop(animation_name, loops)
	for path in paths:
		var texture := load(path) as Texture2D
		if is_instance_valid(texture):
			frames.add_frame(animation_name, texture)

func _update_animated_sprite(sprite: AnimatedSprite3D, direction: String, moving: bool, dashing: bool) -> void:
	var prefix := "idle"
	if action_left > 0.0:
		match action_category:
			0: prefix = "range"
			1: prefix = "light"
			2: prefix = "heavy"
			3: prefix = "casting"
	elif moving or dashing:
		prefix = "walk"
	var animation_name := "%s_%s" % [prefix, direction]
	if not sprite.sprite_frames.has_animation(animation_name):
		animation_name = "idle_down"
	if sprite.animation != animation_name:
		sprite.play(animation_name)
	sprite.speed_scale = 1.5 if dashing else 1.0
