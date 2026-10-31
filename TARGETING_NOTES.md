# Click-to-Approach Notes

## API and Wiring

`ApproachableComponent` is added as a child to any clickable object. It exposes:

- `interaction_radius` and `approach_offset` exports.
- `get_interaction_radius() -> float`.
- `get_approach_position(from: Vector3) -> Vector3`.

`TargetingComponent` is reusable on any moving `CharacterBody3D` actor. Inject its `movement: MovementComponent` and `body: CharacterBody3D`, then call:

- `resolve_click(click_hit: Variant, fallback_ground_point: Vector3)` to approach a supplied approachable target or move to the ground fallback.
- `clear_target()` to abandon the current target.
- Read `current_target` to inspect the current approach target.

It emits `target_reached(target: Node3D)` once when the actor arrives and `target_lost` when the active target is explicitly cleared or becomes invalid. A freed target also cancels the active move target.

## Group and Raycast

Each `ApproachableComponent` adds its node to the `approachables` group. `TargetingComponent.approach_group` defaults to `&"approachables"` and is used as a fallback lookup.

`PlayerController.clickable_layer_mask` defaults to physics layer 1. The click query includes both bodies and areas, excludes the controlled body, and projects through the player camera. A hit without an approachable component falls back to the ground point beneath the cursor.

## Scene Coverage

- `Player.tscn` injects the player body and movement into its TargetingComponent and forwards reached/lost signals.
- `Enemy.tscn` uses the same TargetingComponent and an EnemyAI helper for manual approach requests.
- The training dummy, chest, and interactable scenes each include ApproachableComponent with object-appropriate interaction radii.
- The movement sandbox spawns all four example targets for manual interaction testing.
