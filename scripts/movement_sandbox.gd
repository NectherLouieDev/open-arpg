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
	world.background_color = Color("182522")
	world.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.ambient_light_color = Color(0.72, 0.79, 0.84)
	world.ambient_light_energy = 0.65
	environment.environment = world
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	light.light_energy = 1.1
	add_child(light)
	_add_box("PlaceholderFloor", Vector3(0, -0.3, 0), Vector3(ARENA_HALF_SIZE.x * 2.0, 0.6, ARENA_HALF_SIZE.y * 2.0), Color("263c3a"), false)
	for x in range(-22, 23, 2):
		_add_line(Vector3(x, 0.01, -ARENA_HALF_SIZE.y), Vector3(x, 0.01, ARENA_HALF_SIZE.y))
	for z in range(-16, 17, 2):
		_add_line(Vector3(-ARENA_HALF_SIZE.x, 0.01, z), Vector3(ARENA_HALF_SIZE.x, 0.01, z))
	_add_box("NorthBoundary", Vector3(0, 0.8, -ARENA_HALF_SIZE.y), Vector3(ARENA_HALF_SIZE.x * 2.0, 1.6, 0.6), Color("596c62"), true)
	_add_box("SouthBoundary", Vector3(0, 0.8, ARENA_HALF_SIZE.y), Vector3(ARENA_HALF_SIZE.x * 2.0, 1.6, 0.6), Color("596c62"), true)
	_add_box("WestBoundary", Vector3(-ARENA_HALF_SIZE.x, 0.8, 0), Vector3(0.6, 1.6, ARENA_HALF_SIZE.y * 2.0), Color("596c62"), true)
	_add_box("EastBoundary", Vector3(ARENA_HALF_SIZE.x, 0.8, 0), Vector3(0.6, 1.6, ARENA_HALF_SIZE.y * 2.0), Color("596c62"), true)
	_add_box("ObstacleA", Vector3(5, 0.7, 2), Vector3(2.5, 1.4, 5.5), Color("718477"), true)
	_add_box("ObstacleB", Vector3(-7, 0.6, -4), Vector3(5, 1.2, 1.8), Color("718477"), true)
	_add_box("ObstacleC", Vector3(11, 0.9, -9), Vector3(1.8, 1.8, 4.5), Color("718477"), true)

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
		Rect2(Vector2(3.15, -1.35), Vector2(3.7, 6.7)),
		Rect2(Vector2(-10.1, -5.5), Vector2(6.2, 3.0)),
		Rect2(Vector2(9.75, -11.85), Vector2(2.5, 5.7))
	]
	for x in range(-23, 23):
		for z in range(-17, 17):
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
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	if collidable:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
	add_child(body)

func _add_line(from: Vector3, to: Vector3) -> void:
	var mesh_instance := MeshInstance3D.new()
	var immediate := ImmediateMesh.new()
	immediate.surface_begin(Mesh.PRIMITIVE_LINES)
	immediate.surface_add_vertex(from)
	immediate.surface_add_vertex(to)
	immediate.surface_end()
	mesh_instance.mesh = immediate
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.35, 0.48, 0.44, 0.38)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_instance.material_override = material
	add_child(mesh_instance)
