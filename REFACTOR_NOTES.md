# Player Component Refactor Notes

## Public Player API

`Player` (`CharacterBody3D`) is the public entry point. External gameplay code should use its exposed typed components and methods rather than reaching into the scene tree:

- `player.stats`: health, Anima, `take_damage()`, `spend_anima()`, `heal()`.
- `player.attributes`: STR/FIN/ARK values and derived stat multipliers, configured through `StatScaling`.
- `player.controller`: input enable/disable and `is_controller_input()`.
- `player.movement`: movement intent/target, dash request, facing, velocity, dash and invulnerability state.
- `player.combat`: target lookup, auto-attack, damage application, attack stats.
- `player.skill`: skill use, cooldown, range, and lockout queries.
- `player.visual`: visual update component.
- `player.camera_rig`: camera follow and click-to-ground projection.
- `player.take_damage(amount)`, `player.is_dead`, `player.get_debug_stats()`.

## Component Signals

- `StatComponent`: `stats_changed`, `damaged(amount)`, `died`.
- `MovementComponent`: `dash_started`, `dash_finished`.
- `CombatComponent`: `attack_performed(target, amount)`.
- `AttributeComponent`: `attributes_changed`.
- `SkillComponent`: `skill_used(slot_index)`, `skill_failed(slot_index, reason)`.
- `Player`: forwards `stats_changed` and `died`.
- `PlayerController`, `VisualComponent`, `CameraRig`: no public signals.

## External Callers Updated

- `movement_sandbox.gd` now instantiates the orchestrated `Player` scene and passes it to both HUDs.
- `debug_hud.gd` and `combat_hud.gd` bind to the public `Player` API and `get_debug_stats()`.
- Damage callers should call `player.take_damage(amount)`; the root forwards to `player.stats` and handles death/velocity shutdown.
- Player combat searches the `enemies` group; enemy combat is configured to search `players`. The training dummy is in `enemies`. `CombatComponent.target_group` is configurable.
- `DamageService` centralizes damage scaling and hit-stop. `CombatFeedback` supplies shared damage numbers.

## Scope Notes

- Input action names remain `move_stick_left/right/up/down`, `aim_left/right/up/down`, `move_click`, `dash`, and `skill_1..skill_6`.
- Slot 1 is the implemented burst skill; slots 2–6 report as empty until abilities are assigned.
- Git commits were not created: this workspace does not contain a `.git` repository, and no baseline history was available to commit against.
