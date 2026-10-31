extends Node3D
## Legacy visual marker retained for the editor's saved dummy_loot.tscn tab.
## Enemy drops now use LootPickup and data-driven LootTable resources.
class_name DummyLoot

@export var bob_height := 0.12
@export var bob_speed := 2.2
var _origin_y := 0.0
var _time := 0.0

func _ready() -> void:
	_origin_y = position.y

func _process(delta: float) -> void:
	_time += delta
	position.y = _origin_y + sin(_time * bob_speed) * bob_height
	rotate_y(delta * 0.8)
