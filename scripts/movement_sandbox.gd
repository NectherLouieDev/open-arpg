extends Node3D
## Builds the movement and combat sandbox used to exercise the current game systems.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const DUMMY_SCENE := preload("res://scenes/training_dummy.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const ELITE_ENEMY_DEFINITION := preload("res://resources/enemies/elite_enemy.tres")
const BOSS_ENEMY_DEFINITION := preload("res://resources/enemies/boss_enemy.tres")
const CHEST_SCENE := preload("res://scenes/chest.tscn")
const INTERACTABLE_SCENE := preload("res://scenes/interactable.tscn")
const DEBUG_HUD_SCENE := preload("res://scenes/debug_hud.tscn")
const COMBAT_HUD_SCENE := preload("res://scenes/combat_hud.tscn")
const ARENA_HALF_SIZE := Vector2(24.0, 18.0)
var _material_cache: Dictionary = {}
var _terrain_collision: StaticBody3D
var _terrain_mesh: BoxMesh

func _ready() -> void:
	_build_arena()
	_build_navigation_region()
	var player := PLAYER_SCENE.instantiate() as Player
	player.position = Vector3(0.0, 0.0, 0.0)
	add_child(player)
	var dummy := DUMMY_SCENE.instantiate()
	dummy.position = Vector3(0.0, 0.0, -3.5)
	add_child(dummy)
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.position = Vector3(0.0, 0.0, -10.0)
	add_child(enemy)
	_spawn_enemy(ELITE_ENEMY_DEFINITION, Vector3(11.0, 0.0, -8.0))
	_spawn_enemy(BOSS_ENEMY_DEFINITION, Vector3(-16.0, 0.0, -12.0))
	var chest := CHEST_SCENE.instantiate() as Node3D
	chest.position = Vector3(9.0, 0.0, 2.0)
	add_child(chest)
	var interactable := INTERACTABLE_SCENE.instantiate() as Node3D
	interactable.position = Vector3(-9.0, 0.0, 3.0)
	add_child(interactable)
	var debug_hud := DEBUG_HUD_SCENE.instantiate() as DebugHUD
	add_child(debug_hud)
	debug_hud.bind_player(player)
	var combat_hud := COMBAT_HUD_SCENE.instantiate() as CombatHUD
	add_child(combat_hud)
	combat_hud.bind_player(player)

func _spawn_enemy(definition: EnemyDefinition, at: Vector3) -> void:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.enemy_definition = definition
	enemy.position = at
	add_child(enemy)

func _build_arena() -> void:
	var environment := WorldEnvironment.new()
	var world := Environment.new()
	world.background_mode = Environment.BG_COLOR
	world.background_color = Color("72c7c6")
	world.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.ambient_light_color = Color(0.72, 0.79, 0.84)
	world.ambient_light_energy = 0.8
	environment.environment = world
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	light.light_energy = 1.1
	add_child(light)
	_terrain_collision = StaticBody3D.new()
	_terrain_collision.name = "IslandTerrainCollision"
	add_child(_terrain_collision)
	_terrain_mesh = BoxMesh.new()
	_terrain_mesh.size = Vector3(2.02, 0.3, 2.02)
	for x in range(-22, 23, 2):
		for z in range(-16, 17, 2):
			if not _is_land_cell(x, z):
				continue
			var center := Vector3(x, 0.0, z)
			var is_path := _is_path_cell(x, z)
			var grass_colors: Array[Color] = [Color("83a84f"), Color("8eaf57"), Color("779b49"), Color("98b75d"), Color("82a24d")]
			var tile_color := Color("b9914e") if is_path else grass_colors[posmod(x * 7 + z * 11, grass_colors.size())]
			_add_terrain_tile(center, tile_color)
			_add_box("IslandRock_%d_%d" % [x, z], center + Vector3(0, -1.25, 0), Vector3(2.04, 2.1, 2.04), Color("665640"), false)
			if _is_edge_cell(x, z):
				_add_box("CliffLedge_%d_%d" % [x, z], center + Vector3(0, -2.25, 0), Vector3(1.85, 1.5, 1.85), Color("514632"), false)
	_add_box("RockOutcropA", Vector3(5, 0.42, 2), Vector3(2.5, 0.85, 2.5), Color("8b7952"), true)
	_add_box("RockOutcropB", Vector3(-7, 0.38, -4), Vector3(3.2, 0.75, 2.3), Color("88764f"), true)
	_add_box("RockOutcropC", Vector3(11, 0.5, -9), Vector3(2.0, 1.0, 2.0), Color("907d52"), true)
	for tree_position in [Vector2(-18, -12), Vector2(-12, -14), Vector2(16, -13), Vector2(20, -5), Vector2(-20, 5), Vector2(20, 9), Vector2(14, 14), Vector2(-10, 14), Vector2(4, -14)]:
		_add_tree(Vector3(tree_position.x, 0.0, tree_position.y))
	_add_hut(Vector3(0.0, 0.0, 13.0))

func _is_land_cell(x: int, z: int) -> bool:
	var ax := absf(float(x))
	var az := absf(float(z))
	if ax > ARENA_HALF_SIZE.x - 2.0 or az > ARENA_HALF_SIZE.y - 2.0:
		return false
	if ax > ARENA_HALF_SIZE.x - 7.0 and az > ARENA_HALF_SIZE.y - 7.0:
		var corner_delta := Vector2(ax - (ARENA_HALF_SIZE.x - 7.0), az - (ARENA_HALF_SIZE.y - 7.0))
		if corner_delta.length() > 5.0:
			return false
	return true

func _is_path_cell(x: int, z: int) -> bool:
	if x <= -10:
		return absf(float(z - 6)) <= 1.0
	if x <= -4:
		return absf(float(z + x + 4)) <= 1.0
	if x <= 14:
		return absf(float(z)) <= 1.0
	return absf(float(z) + (float(x) - 14.0) * 0.8) <= 1.0

func _is_edge_cell(x: int, z: int) -> bool:
	return not _is_land_cell(x + 2, z) or not _is_land_cell(x - 2, z) or not _is_land_cell(x, z + 2) or not _is_land_cell(x, z - 2)

func _add_terrain_tile(center: Vector3, color: Color) -> void:
	var tile_position := center + Vector3(0, -0.15, 0)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = _terrain_mesh
	mesh_instance.position = tile_position
	mesh_instance.material_override = _get_material(color)
	add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = _terrain_mesh.size
	collision.shape = shape
	collision.position = tile_position
	_terrain_collision.add_child(collision)

func _add_tree(at: Vector3) -> void:
	_add_box("TreeTrunk", at + Vector3(0, 0.8, 0), Vector3(0.65, 1.6, 0.65), Color("805a35"), true)
	_add_box("TreeCanopyLower", at + Vector3(0, 2.0, 0), Vector3(2.0, 1.1, 2.0), Color("4f7d43"), false)
	_add_box("TreeCanopyUpper", at + Vector3(0, 2.85, 0), Vector3(1.45, 1.0, 1.45), Color("65924b"), false)
	_add_box("TreeCanopyTop", at + Vector3(0, 3.55, 0), Vector3(0.85, 0.65, 0.85), Color("82a856"), false)

func _add_hut(at: Vector3) -> void:
	_add_box("IslandHutBody", at + Vector3(0, 0.8, 0), Vector3(4.0, 1.6, 3.2), Color("b9965c"), true)
	_add_box("IslandHutRoofLower", at + Vector3(0, 1.85, 0), Vector3(4.8, 0.65, 3.8), Color("9b653e"), false)
	_add_box("IslandHutRoofCap", at + Vector3(0, 2.35, 0), Vector3(3.5, 0.45, 2.8), Color("b57b45"), false)

func _build_navigation_region() -> void:
	var navigation_region := NavigationRegion3D.new()
	navigation_region.name = "ArenaNavigationRegion"
	var nav_mesh := NavigationMesh.new()
	nav_mesh.agent_radius = 0.4
	nav_mesh.agent_height = 1.8
	var vertices: Array[Vector3] = []
	var polygons: Array[PackedInt32Array] = []
	var vertex_lookup: Dictionary = {}
	var blocked_areas: Array[Rect2] = [
		Rect2(Vector2(3.5, 0.5), Vector2(3.0, 3.0)),
		Rect2(Vector2(-8.5, -5.0), Vector2(3.2, 2.6)),
		Rect2(Vector2(10.0, -10.0), Vector2(2.5, 2.5)),
		Rect2(Vector2(-19.0, -13.0), Vector2(2.0, 2.0)),
		Rect2(Vector2(-13.0, -15.0), Vector2(2.0, 2.0)),
		Rect2(Vector2(15.0, -14.0), Vector2(2.0, 2.0)),
		Rect2(Vector2(19.0, -6.0), Vector2(2.0, 2.0)),
		Rect2(Vector2(-21.0, 4.0), Vector2(2.0, 2.0)),
		Rect2(Vector2(19.0, 8.0), Vector2(2.0, 2.0)),
		Rect2(Vector2(13.0, 13.0), Vector2(2.0, 2.0)),
		Rect2(Vector2(-11.0, 13.0), Vector2(2.0, 2.0)),
		Rect2(Vector2(3.0, -15.0), Vector2(2.0, 2.0)),
		Rect2(Vector2(-2.5, 10.5), Vector2(5.0, 5.0))
	]
	for x in range(-23, 23):
		for z in range(-17, 17):
			if not _is_land_cell(x, z):
				continue
			var cell := Rect2(Vector2(x, z), Vector2.ONE)
			var blocked := false
			for blocked_area in blocked_areas:
				if cell.intersects(blocked_area):
					blocked = true
					break
			if blocked:
				continue
			polygons.append(PackedInt32Array([
				_get_nav_vertex(x, z, vertices, vertex_lookup),
				_get_nav_vertex(x, z + 1, vertices, vertex_lookup),
				_get_nav_vertex(x + 1, z + 1, vertices, vertex_lookup),
				_get_nav_vertex(x + 1, z, vertices, vertex_lookup)
			]))
	nav_mesh.vertices = PackedVector3Array(vertices)
	for polygon in polygons:
		nav_mesh.add_polygon(polygon)
	navigation_region.navigation_mesh = nav_mesh
	add_child(navigation_region)

func _get_nav_vertex(x: int, z: int, vertices: Array[Vector3], lookup: Dictionary) -> int:
	var key := Vector2i(x, z)
	if lookup.has(key):
		return lookup[key]
	var index := vertices.size()
	vertices.append(Vector3(float(x), 0.0, float(z)))
	lookup[key] = index
	return index

func _add_box(label: String, at: Vector3, size: Vector3, color: Color, collidable: bool) -> void:
	var body: Node3D = StaticBody3D.new() if collidable else Node3D.new()
	body.name = label
	body.position = at
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = _get_material(color)
	body.add_child(mesh_instance)
	if collidable:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
	add_child(body)

func _get_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html(false)
	if _material_cache.has(key):
		return _material_cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	_material_cache[key] = material
	return material
