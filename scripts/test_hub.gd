extends Node3D
## Interactive test wrapper: environment visuals and geometry live in hub-environment.tscn.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const PANDAY_SCENE := preload("res://scenes/panday.tscn")
const BABAYLAN_SCENE := preload("res://scenes/babaylan.tscn")
const ELDER_SCENE := preload("res://scenes/elder.tscn")
const DIALOGUE_SCENE := preload("res://scenes/hub_dialogue.tscn")
const DEBUG_HUD_SCENE := preload("res://scenes/debug_hud.tscn")
const COMBAT_HUD_SCENE := preload("res://scenes/combat_hud.tscn")
const HUB_ENVIRONMENT_SCENE: PackedScene = preload("res://scenes/hub-environment.tscn")

const TILE_SIZE := 2.0
const ROOF_COLLISION_LAYER := 2
const NAV_AGENT_RADIUS := 0.4
@onready var move_click_target: Node3D = $MoveClickTarget
@onready var move_stick_target: Node3D = $MoveStickTarget
var _roof_entries: Array[Dictionary] = []
var _hub_player: Player

func _ready() -> void:
	_build_lighting()
	var environment := HUB_ENVIRONMENT_SCENE.instantiate() as Node3D
	environment.name = "HubEnvironment"
	add_child(environment)
	_build_navigation_region(environment)
	_add_boundary_blockers(environment)
	_connect_environment_roofs(environment)
	_add_player_and_npcs()
	add_child(DIALOGUE_SCENE.instantiate())
	var debug_hud := DEBUG_HUD_SCENE.instantiate() as DebugHUD
	add_child(debug_hud)
	debug_hud.bind_player(_hub_player)
	var combat_hud := COMBAT_HUD_SCENE.instantiate() as CombatHUD
	add_child(combat_hud)
	combat_hud.bind_player(_hub_player)
	_add_hub_hint()

func _process(delta: float) -> void:
	if not is_instance_valid(_hub_player) or not is_instance_valid(_hub_player.camera_rig.camera):
		return
	for entry in _roof_entries:
		entry.occluded = false
	var camera := _hub_player.camera_rig.camera
	var ray_start := camera.global_position
	var ray_end := _hub_player.global_position + Vector3.UP * 0.9
	var excluded: Array[RID] = [_hub_player.get_rid()]
	for _hit_index in range(_roof_entries.size()):
		var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end, ROOF_COLLISION_LAYER)
		query.exclude = excluded
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			break
		var collider := hit.collider as Node3D
		if not is_instance_valid(collider):
			break
		excluded.append(collider.get_rid())
		for entry in _roof_entries:
			if entry.body == collider:
				entry.occluded = true
	for entry in _roof_entries:
		var target_alpha := 0.16 if entry.inside or entry.occluded else 1.0
		entry.alpha = move_toward(float(entry.alpha), target_alpha, delta * 3.0)
		for roof_material in entry.materials:
			var color: Color = roof_material.albedo_color
			color.a = entry.alpha
			roof_material.albedo_color = color

func _build_lighting() -> void:
	var environment := WorldEnvironment.new()
	var world := Environment.new()
	world.background_mode = Environment.BG_COLOR
	world.background_color = Color("84cbd0")
	world.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.ambient_light_color = Color(0.82, 0.88, 0.86)
	world.ambient_light_energy = 0.8
	environment.environment = world
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_energy = 1.15
	add_child(sun)

func _connect_environment_roofs(environment: Node3D) -> void:
	for roof_node in environment.get_tree().get_nodes_in_group("hub_roofs"):
		if not environment.is_ancestor_of(roof_node):
			continue
		var roof_body := roof_node as StaticBody3D
		if not is_instance_valid(roof_body):
			continue
		var materials: Array[StandardMaterial3D] = []
		for child in roof_body.get_children():
			if child is MeshInstance3D and child.material_override is StandardMaterial3D:
				var material := child.material_override as StandardMaterial3D
				if not materials.has(material):
					materials.append(material)
		var roof_entry := {"body": roof_body, "materials": materials, "inside": false, "occluded": false, "alpha": 1.0}
		_roof_entries.append(roof_entry)
	for trigger_node in environment.get_tree().get_nodes_in_group("hub_house_triggers"):
		if not environment.is_ancestor_of(trigger_node):
			continue
		var trigger := trigger_node as Area3D
		if not is_instance_valid(trigger):
			continue
		var roof_name := String(trigger.get_meta("roof_name", ""))
		for entry in _roof_entries:
			if (entry.body as Node).name == roof_name:
				trigger.body_entered.connect(_on_house_entered.bind(entry))
				trigger.body_exited.connect(_on_house_exited.bind(entry))
				break

func _on_house_entered(body: Node3D, roof_entry: Dictionary) -> void:
	if body.is_in_group("players"):
		roof_entry.inside = true

func _on_house_exited(body: Node3D, roof_entry: Dictionary) -> void:
	if body.is_in_group("players"):
		roof_entry.inside = false

func _add_player_and_npcs() -> void:
	var player := PLAYER_SCENE.instantiate() as Player
	player.position = Vector3(0.0, 0.0, 3.5)
	add_child(player)
	_hub_player = player
	player.controller.move_click_target = move_click_target
	player.controller.move_stick_target = move_stick_target
	move_click_target.global_position = player.global_position
	move_stick_target.global_position = player.global_position
	var panday := PANDAY_SCENE.instantiate() as HubNPC
	panday.position = Vector3(-6.0, 0.0, 0.0)
	add_child(panday)
	var babaylan := BABAYLAN_SCENE.instantiate() as HubNPC
	babaylan.position = Vector3(6.0, 0.0, 0.0)
	add_child(babaylan)
	var elder := ELDER_SCENE.instantiate() as HubNPC
	elder.position = Vector3(0.0, 0.0, -8.0)
	add_child(elder)

func _build_navigation_region(parent: Node3D) -> void:
	var region := NavigationRegion3D.new()
	region.name = "HubNavigationRegion"
	var nav_mesh := NavigationMesh.new()
	nav_mesh.agent_radius = NAV_AGENT_RADIUS
	nav_mesh.agent_height = 1.8
	var vertices: Array[Vector3] = []
	var polygons: Array[PackedInt32Array] = []
	var vertex_lookup: Dictionary = {}
	var cells: Array[Vector2i] = []
	for x in range(-10, 11, 2):
		for z in range(-10, 11, 2):
			if _is_land_tile(x, z):
				cells.append(Vector2i(x, z))
	for x in range(-2, 3, 2):
		for z in range(10, 15, 2):
			var cell := Vector2i(x, z)
			if not cells.has(cell):
				cells.append(cell)
	for cell in cells:
		polygons.append(PackedInt32Array([
			_get_nav_vertex(cell.x - 1, cell.y - 1, vertices, vertex_lookup),
			_get_nav_vertex(cell.x - 1, cell.y + 1, vertices, vertex_lookup),
			_get_nav_vertex(cell.x + 1, cell.y + 1, vertices, vertex_lookup),
			_get_nav_vertex(cell.x + 1, cell.y - 1, vertices, vertex_lookup)
		]))
	nav_mesh.vertices = PackedVector3Array(vertices)
	for polygon in polygons:
		nav_mesh.add_polygon(polygon)
	region.navigation_mesh = nav_mesh
	parent.add_child(region)

func _get_nav_vertex(x: int, z: int, vertices: Array[Vector3], lookup: Dictionary) -> int:
	var key := Vector2i(x, z)
	if lookup.has(key):
		return lookup[key]
	var index := vertices.size()
	vertices.append(Vector3(float(x), 0.0, float(z)))
	lookup[key] = index
	return index

func _add_boundary_blockers(parent: Node3D) -> void:
	var cells: Array[Vector2i] = []
	for x in range(-10, 11, 2):
		for z in range(-10, 11, 2):
			if _is_land_tile(x, z):
				cells.append(Vector2i(x, z))
	for x in range(-2, 3, 2):
		for z in range(10, 15, 2):
			var cell := Vector2i(x, z)
			if not cells.has(cell):
				cells.append(cell)
	var cell_lookup: Dictionary = {}
	for cell in cells:
		cell_lookup[cell] = true
	var boundary := StaticBody3D.new()
	boundary.name = "HubBoundaryBlockers"
	parent.add_child(boundary)
	for cell in cells:
		var sides := [Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -2), Vector2i(0, 2)]
		for side in sides:
			if cell_lookup.has(cell + side):
				continue
			var wall := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			var along_z = side.x != 0
			shape.size = Vector3(0.2, 3.0, 2.0) if along_z else Vector3(2.0, 3.0, 0.2)
			wall.shape = shape
			wall.position = Vector3(cell.x + side.x * 0.5, 1.5, cell.y + side.y * 0.5)
			boundary.add_child(wall)

func _is_land_tile(x: int, z: int) -> bool:
	var ax := absf(float(x))
	var az := absf(float(z))
	if ax > 10.0 or az > 10.0:
		return false
	if ax >= 8.0 and az >= 8.0 and Vector2(ax - 8.0, az - 8.0).length() > 2.5:
		return false
	return true

func _add_hub_hint() -> void:
	var hint := Label3D.new()
	hint.text = "ELDER'S HOUSE · TALK TO THE ELDER"
	hint.position = Vector3(0.0, 2.4, -8.0)
	hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hint.font_size = 32
	hint.outline_size = 6
	hint.modulate = Color("fff0c9")
	add_child(hint)
