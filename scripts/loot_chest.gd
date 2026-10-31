extends StaticBody3D
## Small sandbox chest that emits the same world pickups as enemy loot.
class_name LootChest

@export var loot_table: LootTable
@export var pickup_scene: PackedScene = preload("res://scenes/loot_pickup.tscn")

@onready var visual: MeshInstance3D = $Visual
@onready var prompt: Label3D = $Prompt
var _player_in_range := false
var _opened := false

func _ready() -> void:
	$InteractArea.body_entered.connect(_on_body_entered)
	$InteractArea.body_exited.connect(_on_body_exited)
	if visual.material_override is StandardMaterial3D:
		visual.material_override = (visual.material_override as StandardMaterial3D).duplicate()
	prompt.visible = false

func _process(_delta: float) -> void:
	if _player_in_range and not _opened and Input.is_action_just_pressed("interact"):
		_open()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("players") and not _opened:
		_player_in_range = true
		prompt.visible = true

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("players"):
		_player_in_range = false
		prompt.visible = false

func _open() -> void:
	if _opened or not is_instance_valid(loot_table):
		return
	_opened = true
	_player_in_range = false
	prompt.visible = false
	if visual.material_override is StandardMaterial3D:
		(visual.material_override as StandardMaterial3D).albedo_color = Color("b9a271")
	var index := 0
	for drop in loot_table.roll():
		var pickup := pickup_scene.instantiate() as LootPickup
		if not is_instance_valid(pickup):
			continue
		get_parent().add_child(pickup)
		pickup.configure(drop.item, drop.quantity)
		pickup.global_position = global_position + Vector3(float(index % 3 - 1) * 0.55, 0.25, 1.1 + float(index / 3) * 0.45)
		index += 1
