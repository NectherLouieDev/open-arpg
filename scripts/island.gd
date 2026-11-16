extends Node3D
## First playable landing area on the single cursed island.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const COMMON_ENEMY_DEFINITION := preload("res://resources/enemies/melee_enemy.tres")
const ELITE_ENEMY_DEFINITION := preload("res://resources/enemies/elite_enemy.tres")
const DEBUG_HUD_SCENE := preload("res://scenes/debug_hud.tscn")
const COMBAT_HUD_SCENE := preload("res://scenes/combat_hud.tscn")
const NAV_AGENT_RADIUS := 0.4
const ISLAND_Z_MIN := -36
const ISLAND_Z_MAX := 12
const ISLAND_X_MAX := 20

@onready var island_environment: Node3D = $IslandEnvironment

var _player: Player

func _ready() -> void:
	_build_lighting()
	_add_boundary_marker_visuals()
	_build_navigation_region()
	_add_landing_dock_collisions()
	# NavigationServer synchronizes newly added regions on physics frames.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_add_player()
	_spawn_enemies()
	_add_landing_label()

func _add_boundary_marker_visuals() -> void:
	var blockers := island_environment.get_node_or_null("IslandBoundaryBlockers")
	if not is_instance_valid(blockers):
		return
	var visuals := Node3D.new()
	visuals.name = "IslandBoundaryBlockerVisuals"
	add_child(visuals)
	var marker_material := StandardMaterial3D.new()
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker_material.albedo_color = Color(1.0, 0.12, 0.04, 0.42)
	marker_material.emission_enabled = true
	marker_material.emission = Color(1.0, 0.08, 0.02, 1.0)
	for child in blockers.get_children():
		if not child is CollisionShape3D:
			continue
		var boundary_shape := child as CollisionShape3D
		if not boundary_shape.shape is BoxShape3D:
			continue
		var marker := MeshInstance3D.new()
		marker.name = boundary_shape.name.replace("BoundaryCollision", "BoundaryMarker")
		var marker_mesh := BoxMesh.new()
		marker_mesh.size = (boundary_shape.shape as BoxShape3D).size
		marker.mesh = marker_mesh
		marker.material_override = marker_material
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visuals.add_child(marker)
		marker.global_transform = boundary_shape.global_transform

func _build_lighting() -> void:
	var environment := WorldEnvironment.new()
	var world := Environment.new()
	world.background_mode = Environment.BG_COLOR
	world.background_color = Color("397f91")
	world.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.ambient_light_color = Color(0.76, 0.84, 0.79)
	world.ambient_light_energy = 0.9
	environment.environment = world
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_energy = 1.2
	add_child(sun)

func _build_navigation_region() -> void:
	var region := NavigationRegion3D.new()
	region.name = "IslandNavigationRegion"
	var nav_mesh := NavigationMesh.new()
	nav_mesh.agent_radius = NAV_AGENT_RADIUS
	nav_mesh.agent_height = 1.8
	var vertices: Array[Vector3] = []
	var lookup: Dictionary = {}
	var polygons: Array[PackedInt32Array] = []
	for cell in _get_walkable_cells():
		polygons.append(PackedInt32Array([
			_get_nav_vertex(cell.x - 1, cell.y - 1, vertices, lookup),
			_get_nav_vertex(cell.x - 1, cell.y + 1, vertices, lookup),
			_get_nav_vertex(cell.x + 1, cell.y + 1, vertices, lookup),
			_get_nav_vertex(cell.x + 1, cell.y - 1, vertices, lookup)
		]))
	nav_mesh.vertices = PackedVector3Array(vertices)
	for polygon in polygons:
		nav_mesh.add_polygon(polygon)
	region.navigation_mesh = nav_mesh
	add_child(region)

func _get_walkable_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(-ISLAND_X_MAX, ISLAND_X_MAX + 1, 2):
		for z in range(ISLAND_Z_MIN, ISLAND_Z_MAX + 1, 2):
			if _is_island_cell(x, z):
				cells.append(Vector2i(x, z))
	for x in range(-2, 3, 2):
		for z in [12, 14]:
			var cell := Vector2i(x, z)
			if not cells.has(cell):
				cells.append(cell)
	return cells

func _is_island_cell(x: int, z: int) -> bool:
	var ax := absf(float(x))
	var az := absf(float(z))
	if ax > ISLAND_X_MAX or z < ISLAND_Z_MIN or z > ISLAND_Z_MAX:
		return false
	if ax >= 16.0 and az >= 30.0 and (ax - 16.0) + (az - 30.0) > 4.0:
		return false
	return true

func _get_nav_vertex(x: int, z: int, vertices: Array[Vector3], lookup: Dictionary) -> int:
	var key := Vector2i(x, z)
	if lookup.has(key):
		return int(lookup[key])
	var index := vertices.size()
	vertices.append(Vector3(float(x), 0.0, float(z)))
	lookup[key] = index
	return index

func _add_landing_dock_collisions() -> void:
	var dock_floor := StaticBody3D.new()
	dock_floor.name = "LandingDockCollision"
	add_child(dock_floor)
	for x in [-2, 0, 2]:
		for z in [12, 14]:
			var collision := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(1.9, 0.16, 1.9)
			collision.shape = shape
			collision.position = Vector3(x, 0.08, z)
			dock_floor.add_child(collision)

func _add_player() -> void:
	var click_target := Node3D.new()
	click_target.name = "MoveClickTarget"
	add_child(click_target)
	var stick_target := Node3D.new()
	stick_target.name = "MoveStickTarget"
	add_child(stick_target)
	_player = PLAYER_SCENE.instantiate() as Player
	_player.position = Vector3(0.0, 0.0, 10.0)
	add_child(_player)
	click_target.global_position = _player.global_position
	stick_target.global_position = _player.global_position
	_player.controller.move_click_target = click_target
	_player.controller.move_stick_target = stick_target
	var debug_hud := DEBUG_HUD_SCENE.instantiate() as DebugHUD
	add_child(debug_hud)
	debug_hud.bind_player(_player)
	var combat_hud := COMBAT_HUD_SCENE.instantiate() as CombatHUD
	add_child(combat_hud)
	combat_hud.bind_player(_player)

func _spawn_enemies() -> void:
	for at in [
		Vector3(-12.0, 0.0, 0.0),
		Vector3(14.0, 0.0, -8.0),
		Vector3(0.0, 0.0, -16.0),
		Vector3(-6.0, 0.0, -24.0),
		Vector3(8.0, 0.0, -32.0)
	]:
		_spawn_enemy(COMMON_ENEMY_DEFINITION, at)
	for at in [Vector3(14.0, 0.0, -22.0), Vector3(-14.0, 0.0, -18.0)]:
		_spawn_enemy(ELITE_ENEMY_DEFINITION, at)

func _spawn_enemy(definition: EnemyDefinition, at: Vector3) -> void:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.enemy_definition = definition
	enemy.position = at
	add_child(enemy)

func _add_landing_label() -> void:
	var label := Label3D.new()
	label.name = "LandingAreaLabel"
	label.text = "CURSED ISLAND · LANDING BEACH"
	label.position = Vector3(0.0, 2.8, 7.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 34
	label.outline_size = 6
	label.modulate = Color("fff0c9")
	add_child(label)
