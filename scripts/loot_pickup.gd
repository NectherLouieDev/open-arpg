extends Area3D
## World pickup that hands an item to an inventory receiver and remains if rejected.
class_name LootPickup

signal picked_up(item: ItemDefinition, quantity: int)

@export var item: ItemDefinition
@export_range(1, 999, 1) var quantity := 1
@export var bob_height := 0.12
@export var bob_speed := 2.2

@onready var visual: MeshInstance3D = $Visual
@onready var label: Label3D = $Label3D
var _origin_y := 0.0
var _time := 0.0
var _attempting := false
var _inventory: InventoryComponent

func _ready() -> void:
	_origin_y = position.y
	body_entered.connect(_on_body_entered)
	_refresh_visual()

func configure(item_definition: ItemDefinition, item_quantity: int = 1) -> void:
	item = item_definition
	quantity = maxi(1, item_quantity)
	if is_node_ready():
		_refresh_visual()

func _process(delta: float) -> void:
	_time += delta
	position.y = _origin_y + sin(_time * bob_speed) * bob_height
	rotate_y(delta * 0.8)

func _on_body_entered(body: Node3D) -> void:
	if _attempting or not is_instance_valid(item):
		return
	var inventory := body.get_node_or_null("InventoryComponent") as InventoryComponent
	if not is_instance_valid(inventory):
		return
	_inventory = inventory
	if not inventory.inventory_changed.is_connected(_retry_pickup):
		inventory.inventory_changed.connect(_retry_pickup)
	_try_collect()

func _retry_pickup() -> void:
	_try_collect()

func _try_collect() -> void:
	if _attempting or not is_instance_valid(item) or not is_instance_valid(_inventory):
		return
	_attempting = true
	var requested := quantity
	var accepted := _inventory.try_add_item(item, requested)
	if accepted > 0:
		picked_up.emit(item, accepted)
		for hud in get_tree().get_nodes_in_group("combat_hud"):
			if hud.has_method("show_pickup"):
				hud.show_pickup(item, accepted)
		quantity -= accepted
		if quantity <= 0:
			queue_free()
		else:
			_refresh_visual()
	if accepted < requested:
		for hud in get_tree().get_nodes_in_group("combat_hud"):
			if hud.has_method("show_pickup_rejected"):
				hud.show_pickup_rejected(item)
	_attempting = false

func _refresh_visual() -> void:
	if not is_instance_valid(item):
		return
	label.text = "%s%s" % [item.display_name, " x%d" % quantity if quantity > 1 else ""]
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	match item.item_kind:
		ItemDefinition.ItemKind.CURRENCY:
			material.albedo_color = Color("f5c84b")
		ItemDefinition.ItemKind.SHARD:
			material.albedo_color = [Color("e36c55"), Color("55d8a5"), Color("8f75f5")][item.attribute]
		ItemDefinition.ItemKind.EQUIPMENT:
			material.albedo_color = [Color("d5d9d8"), Color("55c879"), Color("4c91e8"), Color("b55de8"), Color("edb54a")][clampi(item.rarity, 0, 4)]
		ItemDefinition.ItemKind.CONSUMABLE:
			material.albedo_color = Color("61d0c4")
	material.emission = material.albedo_color * 0.7
	visual.material_override = material
