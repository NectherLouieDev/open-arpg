# AGENTS.md — Slayent Technical Implementation Breakdown (v3)

This revision aligns with **GDD v5.1**. The major changes from v2 (which aligned with GDD v4):

- **Accessory slot removed.** Equipment is now **6 slots** (weapon, head, body, legs, feet, hands) — all skill-bearing. There is no passive-only accessory slot.
- **Talismans are the primary attribute progression system.** 3 Talisman slots. Crafted from **Shards** + pairing items (incl. other Talismans) + gold. Tiers T1→T2→T3 chained (T3 requires T2 of same attribute). Persistent; never dropped on death.
- **Attributes renamed and expanded.** **STR / FIN / ARK** (was STR/AGI/INT). FIN = Finesse (replaces AGI); ARK = Arkifex (replaces INT).
- **Anima replaces Stamina.** Anima is the universal combat resource — all skills, dashes, and dodges consume it. No Mana. No Stamina.
- **Two symmetric usage-based trees.** Equipment Mastery tree (per line, scales skills) **and** Attribute tree (per attribute, scales base + derived stats). Both earned by use; both persistent.
- **No character level.** Progress is expressed as **Mastery Rank** (per line) and **Attribute Rank** (per attribute). Both are earn-by-use.
- **Attribute Points removed.** Hub coins buy crafting/consumables/escape items only. Base resource bumps (HP/Anima/inventory) are governed by **Attribute Rank + Attribute tree**.
- **Death penalty clarified.** Talismans, Attribute Rank, and Attribute tree nodes persist on death. Run loot and run-earned XP do not.

Sections most affected: **0, 1.1, 1.2, 1.4, 1.5, 1.6, 1.7, 1.8, 2.1–2.3, 2.7, 2.12, 2.13, 3.1, 3.2, 3.3, 4.1–4.4, 5, 6, 7**.

---

## 0. Project Context & Constraints

**Read first before touching code:**

- **Engine:** Godot (4.x assumed). GDScript unless a justified performance case exists for C#.
- **Solo-dev friendly:** Simple, composable scenes over heavy abstractions. Every system must be buildable and testable by one person.
- **Controller-first:** All combat and UI must be fully gamepad-navigable. Mouse/keyboard is a secondary Diablo-style scheme.
- **Auto-attack is core:** Basic attacks fire automatically when an enemy is within attack radius. **No attack button.** Positioning and skill usage are the primary combat inputs.
- **No weapon swapping:** One active weapon loadout per run. Do not build weapon-swap UI or logic.
- **No Talisman swapping mid-run:** Talismans are equipped in the Hub only.
- **Art pipeline:** **2D hand-drawn cartoony character sprites composited over 3D environments** (Bastion-inspired). Characters/enemies are 2D sprite sheets; environments are 3D. Do **not** build a fully 3D character pipeline, and do **not** build a fully 2D top-down world. The hybrid is the USP.
- **Resources:** **Health** + **Anima** only. **Anima is the universal combat resource** — all skills, dashes, dodges consume it. **Do not build Mana or Stamina.**
- **Attributes:** **STR / FIN / ARK** only. No point allocation. No Attribute Points. Attributes are raised by equipped **Talismans** and by **Attribute Progress/Rank** earned through use.
- **Progression model:** Two symmetric usage-based trees — **Equipment Mastery** (per line) and **Attribute tree** (per attribute). No character level. Both persist on death.
- **Scope lock:** One island, one boss (Dragon or Kapre — TBD). No multi-island systems. Co-op is out of scope for now.
- **Save system:** Progress saves **only in the Hub**. Island runs are live sessions with no mid-run saving.
- **Target:** 60 FPS on mid-range PCs. Minimal loading between Hub and Island.
- **Composition architecture:** Root orchestrator (`player.gd`, `enemy.gd`) wires components; components communicate via injected refs and signals. No `get_node("../../")` from components. See Section 4.

---

## 1. Essential Systems for the ARPG Vertical Slice

The slice must prove: the player enters a combat area, fights enemies, earns rewards, becomes stronger, and is motivated to keep playing — **with the extraction risk/reward loop layered on top**, **equipment-granted skills** driving build variety, **Talismans + Attribute Rank** driving attribute identity, and **two usage-based trees** providing long-term progression.

### 1.1 Player Controller and Movement

**GDD references:** Sections 3.2, 6.1, 6.3.2, 9.1, 9.2, 9.3

> The game is a **3D environment with 2D sprite characters**. Player is a `CharacterBody3D` with a sprite billboard (`Sprite3D` or `AnimatedSprite3D`) that faces the camera. Movement is restricted to the XZ plane.

| Task | Implementation Notes |
|---|---|
| **3D movement on XZ plane** | `CharacterBody3D` with gravity disabled or zeroed for top-down feel. Movement restricted to XZ; Y stays at ground height. Collision via 3D physics layers. |
| **Camera: isometric/3/4 orthographic** | `Camera3D` with orthographic projection, offset from player, smooth follow. Matches Torchlight/Diablo feel. |
| **2D sprite billboard** | `Sprite3D` (or `AnimatedSprite3D`) with `billboard = BaseMaterial3D.BILLBOARD_ENABLED` so the sprite always faces the camera. **Sprite flipping is horizontal only** — 5 drawn directions (3/4 front, side, 3/4 back + 2 mirrors). |
| Gamepad movement (right stick) | Primary input. Right stick = move (world-space, camera-relative). Left stick = rotate/aim. |
| Mouse/keyboard movement | Left-click point-and-click movement via **camera raycast onto the Y=0 ground plane**. Diablo-style. Secondary scheme. |
| **Dash/dodge** | **B button** / **Space**. i-frames during dash. Cooldown-gated. **Consumes Anima** (not Stamina). |
| Aim/rotation | Left stick rotates aim pivot (and sprite facing). MKB: aim follows mouse or movement direction. |
| Collision and navigation | 3D collision layers for player/enemy/interactable/ground. `NavigationAgent3D` for enemy pathing on ProcGen terrain. |
| Animation driver | A `VisualComponent` maps movement state → 2D sprite animation (idle, move, dash, hurt). Direction selection from velocity + facing, with horizontal flip. |
| No weapon / Talisman swapping | No weapon-swap or Talisman-swap input, UI, or logic. One loadout per run. |

**Acceptance criteria:** Player moves smoothly with both input schemes on 3D terrain, dashes with i-frames consuming **Anima**, sprite billboards correctly to the camera, and the 5-direction flip set works with no visible popping. No weapon or Talisman swapping exists.

---

### 1.2 Combat System (equipment-granted skills, 4 base animations, Anima-gated)

**GDD references:** Sections 3.1, 3.2, 3.4.1–3.4.3, 6.3.1, 9.2

> Skills are **granted by equipped gear**, not chosen from a skill tree. Max **6 active skills** (one per skill-bearing slot). Base animation set is **4 animations**, not per-skill animations. **All skills consume Anima.**

| Task | Implementation Notes |
|---|---|
| **Auto-attack** | Fires automatically when an enemy enters attack radius. Applies to **both** input schemes. No attack button. Weapon defines range/arc/damage/speed. |
| **Equipment-granted skills** | Each skill-bearing gear slot (**weapon, head, body, legs, feet, hands** — 6 slots) grants one active skill. **Cap: 6 active skills.** See 2.2. |
| **Skill slot mapping** | Gamepad: **X, Y, RB, LB, RT, LT** = 6 skill slots. MKB: **Q, W, E, R, T, Y** = 6 skill slots. Item slots: D-pad (4) / 1–4. |
| **4 base attack animations** | **Range Attack, Light Attack, Heavy Attack, Casting.** Skills reuse these; differentiation comes from VFX, timing, and hit effects. Do not build a unique animation per skill. |
| Health, damage, death | HP pools; centralized damage calc (2.4). Death handling respects GDD death penalty (1.7). |
| Hit reactions | Stagger/knockback, flash-on-hit, hit-stop. |
| **Anima cost & cooldown** | Every skill has an Anima cost and a per-slot cooldown. If Anima is insufficient, the skill fails cleanly (no cost, HUD feedback). |
| Cooldowns | Per-slot cooldowns driven by the granted skill. HUD indicator per slot. |
| Attack range & targeting | Auto-attack radius; nearest-enemy or facing-cone targeting. `TargetingComponent` handles click-to-approach; `CombatComponent.find_nearest_target` handles auto-attack targeting. |
| Feedback | Damage numbers, hit VFX, attack SFX, hit-stop. |
| **Anima** | Universal combat resource (replaces v4 Stamina). Gates dash, dodge, and all skills. Regenerates over time with a short delay after spending. Scaled by FIN (max Anima) and ARK (regen rate). |

**Acceptance criteria:** Auto-attack fires reliably under both schemes. Equipping a gear piece with a skill makes that skill available in a slot. All 6 skill buttons work. Each skill plays one of the 4 base animations with its own VFX, and **consumes Anima**. Combat feels responsive at 60 FPS.

---

### 1.3 Enemy AI (3D navigation, parameterized framework, boss reuse)

**GDD references:** Sections 5.2, 6.3.2

> Navigation is `NavigationAgent3D`. Sprite direction set for enemies can be **simpler than the player's** (e.g., 3 directions + flip). AI replaces `PlayerController` as the intent source — it's the only structural difference from the player root.

| Task | Implementation Notes |
|---|---|
| State machine | **Idle → Patrol → Chase → Attack → Dead.** One framework, parameterized per enemy. Do not write bespoke AI per type. |
| Idle/patrol | Patrol between points when player is out of aggro range. |
| Detect & approach | Aggro radius triggers chase. Path via `NavigationAgent3D` on ProcGen terrain. |
| Attack in range | Melee (or ranged) when in range; **telegraph** before attack. |
| Take damage & die | Hit reactions, death animation, removal from AI pool, drop loot. |
| **One melee enemy** | Required. Simple, readable attack. |
| **One ranged enemy** (if time) | Optional. Reuse framework + projectile. |
| **One stronger elite** | Required. Higher HP/damage, visibly distinct (VFX, size, color). |
| **Boss (Dragon or Kapre, TBD)** | Required. Reuses the same framework with tuned params + at least one telegraphed signature attack. Some bosses may require keys/crafted items to access (GDD 5.2). |
| Enemy sprite direction set | Simpler than player: 3 directions + horizontal flip. |
| **Reuse on the player architecture** | Enemy root (`enemy.gd`) wires the **same** `StatComponent`, `MovementComponent`, `CombatComponent`, `VisualComponent` as the player. `SkillComponent` is optional (only if the enemy has skills). `TargetingComponent` is optional. The AI node replaces `PlayerController` as the intent driver. See Section 4. |
| **Target filtering** | `CombatComponent.target_group` must be parameterized (e.g., player targets `&"enemies"`, enemies target `&"player"`). Do not hardcode a single `"combat_targets"` group for both sides. |

**Acceptance criteria:** Melee enemy patrols → detects → chases → attacks → takes damage → dies → drops loot. Elite and boss reuse the same framework. Player and enemies damage each other correctly (target groups are distinct). The enemy root uses the same components as the player root, proving reuse.

---

### 1.4 Loot and Item Pickup (gear = skills + rarity; Shards & Talismans feed crafting)

**GDD references:** Sections 3.1, 3.4, 3.5.3, 3.6.5–3.6.6, 8.2

> A drop is not just a stat upgrade — it may **grant a skill**, belong to an **equipment line** you've invested in, or be a **Shard / Talisman input** for crafting. Loot tables must respect rarity, equipment line, and crafting components.

| Task | Implementation Notes |
|---|---|
| Enemies drop gold / equipment / **Shards** | Loot tables (2.5) determine drops. Drops spawn as world objects. |
| Loot appears in world | Visual drop with rarity indication (color, glow). |
| Player collects it | Pickup on proximity or interact (A / F). |
| Item name & info | Tooltip/toast: name, slot, rarity, stat modifiers, **granted skill(s)**, **equipment line**, and (for Shards) **which attribute it feeds**. |
| **Gold pickup** | Required. Currency for Hub crafting/consumables/escape items. |
| **Three weapon variants** | Required. Each must feel *noticeably* different (range, speed, damage, arc) **and** grant a different weapon-line skill. |
| **Skill-bearing drops** | At least one non-weapon gear drop must grant an active skill, proving the equipment-skill system. |
| **Mastery line tagging** | Every equipment item carries an `equipment_line` ID (e.g., `"stick"`, `"bow"`, `"light_armor"`) so mastery XP routes correctly. |
| **Shard drops** | **STR Shard / FIN Shard / ARK Shard** drop from enemies and chests. Required for Talisman crafting (see 1.6, 2.3). |
| **Talisman drops** | Talismans do **not** drop. They are crafted. Only Shards and Talisman *inputs* drop. |

**Acceptance criteria:** Killing an enemy drops gold, occasionally gear, and occasionally a **Shard**. Equipping a new weapon changes both combat feel **and** the weapon-line skill in the skill slot. A non-weapon gear drop grants a working active skill. Picking up an item of a line you've mastered visibly reflects mastery bonuses. Shards are collectible and persist on extraction.

---

### 1.5 Inventory and Equipment (6 slots + 3 Talisman slots + crafting inventory)

**GDD references:** Sections 3.2, 3.4.1–3.4.2, 3.6.1, 7.2

> **v5.1 change:** Equipment slots are **6 skill-bearing slots** (weapon, head, body, legs, feet, hands). The accessory slot is **removed**. **3 Talisman slots** are separate. Inventory must support **crafting materials (Shards, pairing items)**.

| Task | Implementation Notes |
|---|---|
| Small inventory grid/list | Limited slots for consumables, materials (**Shards**, pairing items), loot. Start small. |
| **6 equipment slots** | Weapon, Head, Body, Legs, Feet, Hands. All skill-bearing. |
| **3 Talisman slots** | Str/FIN/ARK Talismans (mix-and-match allowed). Equipped in Hub only. |
| **Skill preview per equipment slot** | The equipment screen shows the active skill granted by each equipped piece. |
| Equip/unequip | Per slot. No weapon swapping mid-run — equip happens in Hub or inventory. **Talismans equip in Hub only.** |
| Equipment modifies stats | Stats update on equip (damage, attack speed, range, etc.). |
| Compare current vs. new | Stat delta display + **skill granted** delta (old skill → new skill). |
| **Inventory and equipment screen** | Required. Start/Select (gamepad) and menu key (MKB). Fully gamepad-navigable. |

**Acceptance criteria:** Player opens inventory, sees 6 equipment slots + 3 Talisman slots, equips a weapon (feels different, grants a different skill), equips a head piece granting an active skill (new skill appears in slot pool), equips a STR Talisman (STR goes up), and the skill slot assignment UI allows swapping which of the granted skills occupies which of the 6 combat slots. No accessory slot exists.

---

### 1.6 Character Progression (**Two symmetric usage-based trees + Talismans**)

**GDD references:** Sections 3.5.1–3.5.4, 3.6.4–3.6.6, 8.2

> **v5.1 change:** Progression is now **two symmetric usage-based trees** plus crafted Talismans. No character level. No Attribute Points. No Hub stat purchases.

| Task | Implementation Notes |
|---|---|
| **Equipment Mastery XP** | Earned by wearing/using gear of a line (e.g., "Stick", "Bow", "Light Armor"). Persistent across runs. Rises **Mastery Rank** (per line). |
| **Equipment Mastery tree** | Per-line tree (Albion-style). Spend mastery progress on nodes that improve that line's skills/passives. Persistent. |
| **Attribute Progress XP** | Earned by **using an attribute line** (playing with STR/FIN/ARK-focused Talismans + derived stats in combat — exact XP sources TBD). Persistent across runs. Rises **Attribute Rank** (per attribute). |
| **Attribute tree** | Per-attribute tree, **structurally identical to the equipment mastery tree**. Spend Attribute Progress on nodes that improve that attribute's base + derived stats. Persistent. |
| **Talismans** | Crafted, passive, persistent. **3 slots.** Raise equipped attribute bonus. Built from **Shard + pairing items (incl. other Talismans) + gold**. Tiered T1→T2→T3 (T3 requires T2 of same attribute + rarity-gated pairing item). **Never dropped on death.** See 2.3 for data model. |
| **Attribute Rank raises base stats** | STR Rank raises base STR, etc. Stacks with Talisman bonus. |
| **Death persistence** | Mastery Rank + nodes, Attribute Rank + nodes, and Talismans all **persist on death**. Only run loot and run-earned XP are lost. |
| **Hub coins** | Buy **crafting/consumables/escape items** only. Do **not** build Hub stat purchases (HP/Anima/inventory are governed by Attribute Rank + Attribute tree). |
| **No character level** | Do not build a free-floating character level. |
| **No Attribute Points** | Do not build a spendable Attribute Points currency. |

**Acceptance criteria:** Player uses a stick weapon repeatedly → stick mastery rises → stick-granted skill visibly improves. Player uses STR Talismans in combat → STR Attribute Progress rises → STR Rank rises → base STR increases. Player crafts a T2 STR Talisman from a T1 STR Talisman + Shard + pairing item + gold → equips it → STR bonus increases and stacks with STR Rank. Player dies → loses the stick **item** and run loot but keeps stick **mastery**, **STR Rank**, **STR tree nodes**, and **STR Talismans**.

---

### 1.7 Extraction & Shroud Systems (GDD-Critical, Slice-Essential)

**GDD references:** Sections 2.1–2.2, 3.1, 3.3

> Death penalty explicitly excludes Mastery Rank, Attribute Rank, tree nodes, and Talismans.

| Task | Implementation Notes |
|---|---|
| **Shroud timer** | Visible shroud engulfs island from edges inward. 15–30 min. HUD proximity indicator/timer. |
| **Shroud damage/death** | Catching the player = death = loss of all run loot and run-earned XP. **Mastery Rank, Attribute Rank, tree nodes, and Talismans are NOT lost.** |
| **Extraction decision** | Extract early (keep loot) or push deeper (rarer rewards, boss). "Pera o Bayong" tension. |
| **Escape items** | Portal Scrolls, purchased/crafted in Hub. Mid-run escape. |
| **Extraction availability indicator** | HUD portal/scroll status. |
| **Boss hunt vs. escape** | Deeper island = boss lair clues; decide to fight or flee. |
| **Death penalty** | Dying to enemies **or** Shroud loses all run items and run-earned XP — including equipped gear brought in. **Mastery, Attribute Rank, tree nodes, and Talismans persist.** |
| **Save only in Hub** | No mid-run saves. Island runs are live sessions. |

**Acceptance criteria:** Extract-or-push decision feels meaningful. Shroud advances visibly. Extracting keeps loot and run-earned XP; dying loses loot and run-earned XP but keeps mastery, attribute ranks, tree nodes, and Talismans. Save only happens in Hub.

---

### 1.8 Core Gameplay Loop Integration (Vertical Slice Proof)

**GDD references:** Sections 2.1–2.2, 3.1, 8.2

```
Hub Preparation → Island Infiltration → Explore/Fight/Loot → Extraction Decision
→ Boss Hunt or Escape → Return to Hub → Craft/Upgrade → Repeat
```

**Proof sequence (updated for v5.1):**
1. Player explores, fights enemies.
2. Player collects gold, a **skill-bearing gear drop**, **Shards**, and **mastery/attribute XP**.
3. Player equips the gear → **notices a new skill in a slot** and different combat feel.
4. Player uses the new skill to defeat a tougher enemy or the boss.
5. Player decides to extract (keeping loot + run-earned XP) or push deeper.
6. Player returns to Hub, **crafts a T1→T2 Talisman** using collected Shards + pairing items + gold, equips it, and sees STR/FIN/ARK go up — and checks the **Attribute tree** and **Mastery tree** nodes unlocked this run.

**Acceptance criteria:** A new player can complete this sequence without guidance, and both usage-based trees (mastery, attribute) plus Talismans visibly matter. The extract-or-push decision feels meaningful.

---

## 2. Supporting Systems Built Around the Core

### 2.1 Player Stats

**GDD references:** Sections 3.2, 3.6.2–3.6.3

- **Resources:** Health, Anima (universal combat resource).
- **Attributes:** STR, FIN, ARK. Derived stats per GDD 3.6.3 (STR→HP+melee dmg; FIN→Anima+atk speed+move speed+dash efficiency; ARK→skill dmg+CDR+Anima regen).
- Stats modify via **equipment** (per-drop), **Talismans** (equipped attribute bonus), and **Attribute Rank** (base attribute).
- **No Hub stat purchases.** No Attribute Points.

### 2.2 Skill System

**GDD references:** Sections 3.4.1–3.4.3, 6.3.1, 9.2

> Skills are **granted by equipment**. The system owns the mapping from gear slots → granted skills → the 6 combat skill slots. **All skills consume Anima.**

| Task | Implementation Notes |
|---|---|
| **Skill data as `Resource`** | Each skill: ID, name, animation type (Range/Light/Heavy/Cast), **Anima cost**, cooldown, damage, VFX ref, mastery scaling curve. |
| **Gear grants skills** | Each skill-bearing gear item references one or more skill Resources. **All 6 equipment slots are skill-bearing.** |
| **6-slot cap** | The player has 6 combat skill slots. Granted skills are assigned to slots by the player. Max 6 active at once. |
| **Slot mapping** | Gamepad: X, Y, RB, LB, RT, LT. MKB: Q, W, E, R, T, Y. |
| **4 base animations** | Range, Light, Heavy, Casting. Skills map to one of these; VFX differentiates. |
| **Mastery scaling** | Skill power reads from the **Mastery Rank of its equipment line** (see 1.6). |
| **Anima gating** | Each skill checks Anima before firing; on failure, emit a HUD signal (no cost, no cooldown consumed). |
| **Do not build** | A free skill tree. Per-skill unique animations. Hundreds of skills. Mana. Stamina. |

### 2.3 Item Data (equipment line + granted skills + Shards + Talismans)

**GDD references:** Sections 3.4, 3.5.3, 3.6.5–3.6.6, 8.2

- **`EquipmentData`:** ID, name, **slot type** (weapon/head/body/legs/feet/hands), **equipment_line ID**, rarity, stat modifiers, **granted skill IDs**.
- **`ShardData`:** ID, **attribute** (STR/FIN/ARK), tier, rarity. Crafting input for Talismans.
- **`TalismanData`:** ID, **attribute** (STR/FIN/ARK), tier (T1/T2/T3), attribute bonus, optional secondary effects, **crafting recipe** (Shard + pairing item IDs + optional lower-tier Talisman ID + gold).
- Data-driven via Godot `Resource` files — no code changes to add items.
- **Deep item synergies** (GDD 3.2) are a full-game goal — for the slice, prove the *data structure* supports synergies (affixes, set bonuses), implement 1–2 examples.
- **Rarity vs. mastery vs. attribute:** rarity is per-drop (raw power); mastery is per-line (persistent, scales skills); attribute rank is per-attribute (persistent, scales base stats + Talisman effectiveness). All three must be represented.
- **Talisman chain:** T2 recipes optionally consume T1; **T3 recipes require a T2 of the same attribute** plus a rarity-gated pairing item. Data model must represent the chain.

### 2.4 Damage System

**GDD references:** Sections 3.1–3.2, 3.6.2–3.6.3

- Physical damage types, damage calc, death handling.
- Centralized in a `DamageService` autoload for testability.
- Reads attacker stats + skill modifiers + **mastery scaling** for skill damage + **attribute modifiers** (STR melee bonus, ARK skill damage bonus).

### 2.5 Loot Tables

**GDD references:** Sections 3.1, 3.5.3, 3.6.5–3.6.6, 8.2

- Data-driven per enemy type.
- Configure items / gold / **Shard** drops.
- **Skill-bearing drops** must be represented in tables (so 1.4's acceptance test can be met).
- **Shard drop rates** tuned so Talisman crafting is achievable within a few runs.
- Boss table with guaranteed meaningful drop (materials + a high-rarity item of a mastery-relevant line + a **T2-recipe Shard**).

### 2.6 Camera

**GDD references:** Sections 6.1, 9.1–9.2

- **3D orthographic camera, isometric/3/4 perspective.**
- Smooth follow with wall obstruction handling (3D raycast).
- `project_click_to_ground(screen_pos)` helper for MKB click-to-move and `TargetingComponent`.
- Controller-first: no mouse-driven camera rotation required.

### 2.7 UI/HUD (Health + Anima, 6 skills, Talismans, both trees)

**GDD references:** Sections 7.1–7.2, 3.6.4

**In-game HUD (7.1):**
- **Health and Anima bars.**
- **6 skill slots** with cooldown indicators + 4 item slots.
- Shroud proximity indicator/timer.
- Minimal compass.
- Current objectives/clues.
- Extraction availability indicator (portal/scroll status).

**Menus (7.2):**
- Inventory management screen (**6 equipment slots + skill preview + 3 Talisman slots + Shard/material inventory**).
- **Equipment Mastery tree interface** (per line).
- **Attribute tree interface** (per attribute: STR/FIN/ARK).
- **Attribute Rank display.**
- **Talisman crafting interface** (Shard + pairing items + optional lower-tier Talisman + gold → Talisman).
- Crafting interface (other recipes: Portal Scrolls, keys, gear upgrades).
- Hub vendor shops (coins for crafting/consumables/escape items).
- Run statistics and achievements.

**Controller-first mandate:** Every HUD element and menu fully gamepad-navigable.

### 2.8 Level Design (3D environments, 2D character compositing)

**GDD references:** Sections 5.1–5.2, 6.1, 6.3.2

| Area | Minimum Viable Implementation |
|---|---|
| **Hub** | 3D safe zone with blacksmith, alchemist, **craftsman (incl. Talisman crafting)**, elder, portal keeper. Visual changes reflect story progress. All progression/crafting/prep here. |
| **Island (ProcGen, 3D)** | One island per run, procedurally generated **in 3D**. Biomes: forest, ruins, caves, mountain paths. **Verticality** (multi-level 3D). Secrets: hidden paths, optional challenge areas. |
| **Boss encounter** | Single randomized deep-island encounter in 3D space (Dragon or Kapre). May require keys/crafted items. |
| **Shroud integration** | Shroud advances from edges inward in 3D; level design accounts for escape routes and extraction points. |
| **Sprite compositing** | 3D terrain, props, and environment VFX; **2D hand-drawn sprites** for characters/enemies (billboarded). Ensure depth sorting, shadows, and readability work in the hybrid. |
| **Shard placement** | Shards spawn in chests, from enemies, and in optional challenge areas. Tune density so T1 and T2 Talisman crafting are achievable. |

**Scope note:** One island, one boss at launch. No multi-island systems.

### 2.9 Encounter Spawning

**GDD references:** Sections 5.2, 8.2

- Place enemies manually (slice) or spawn in small groups (ProcGen).
- Escalate density toward the boss lair.
- Elite spawns in optional challenge areas.

### 2.10 Game Flow

**GDD references:** Sections 2.1–2.2, 3.3, 8.1–8.2

- Hub → island → combat/loot → extraction decision → boss or escape → Hub → craft/upgrade (Talismans + tree nodes) → repeat.
- Victory/defeat states.
- Defeat = loss of run loot and run-earned XP; **Mastery, Attribute Rank, tree nodes, and Talismans persist**.
- Failing to slay the boss reduces village population (visible in Hub).

### 2.11 Audio and VFX

**GDD references:** Sections 6.2–6.3.1

- Atmospheric music that intensifies as the Shroud approaches.
- Impactful combat sounds.
- Distinct audio cues for secrets/dangers.
- **Boss roars that echo through the island.**
- Attack SFX, hit impacts, **skill VFX (heavy lifting for visual variety since only 4 base anims)**, loot pickup sounds, **Talisman craft SFX**.
- Day/night cycle with dramatic shroud effects.

### 2.12 Crafting (Slice scope)

**GDD references:** Sections 3.1, 3.6.5–3.6.6

- Craft keys, escape items (Portal Scrolls), gear upgrades, consumables, **Talismans**.
- **Talisman recipe (slice scope):** Prove the full chain with one attribute end-to-end:
  - **T1 STR Talisman** = STR Shard + small gold.
  - **T2 STR Talisman** = STR Shard + pairing item (gear) + T1 STR Talisman (optional but recommended for the slice) + moderate gold.
  - **T3 STR Talisman** = STR Shard + rarity-gated pairing item + **T2 STR Talisman** + high gold.
- Crafting is **deterministic** (no RNG on craft).
- Ensure item data supports deep synergies; don't build deep synergy crafting yet.

### 2.13 Save System (two-tree + Talisman persistence)

**GDD references:** Sections 3.3, 3.5.4, 3.6.4, 3.6.6

- Progress saves **only in the Hub**.
- Island runs are live sessions — no mid-run saving.
- **Persist:**
  - **Equipment Mastery XP, Mastery Rank, and mastery tree nodes (per line).**
  - **Attribute Progress, Attribute Rank, and attribute tree nodes (per attribute: STR/FIN/ARK).**
  - **Crafted Talismans and their equipped slots (3).**
  - Extracted materials (incl. **Shards**), currency, and crafting components.
  - Village state (population, repairs).
- **Do not persist:**
  - Run inventory, run loot, run-earned XP (unless extracted).
  - Equipped gear brought into a failed run (lost on death).
  - Per-item stats/rarity (lost with the item).
- **No attribute points, no character level** in the save schema.

---

## 3. The Core Gameplay Loop (Build Order)

### 3.1 Loop Stages

1. Explore the 3D combat area.
2. Fight enemies (auto-attack, equipment-granted skills, dash/positioning — **all consuming Anima**).
3. Collect rewards (gold, gear, **Shards**, mastery XP, attribute XP).
4. Improve character (equip skill-bearing gear, **craft and equip Talismans**, allocate mastery/attribute tree nodes).
5. Extraction decision (extract or push deeper).
6. Defeat a tougher enemy or boss (prove new power).
7. Return to Hub (craft/upgrade).
8. Repeat.

### 3.2 Suggested Development Order (Mapped to GDD 5-Month Timeline)

| Order | Task | GDD Month |
|---|---|---|
| 1 | **3D movement + orthographic camera + 2D sprite billboard** — the hybrid foundation. | Month 1 |
| 2 | **Combat foundation** — auto-attack, damage, health, **Anima**, death, one melee enemy (3D nav). | Month 1 |
| 3 | **Equipment-granted skills** — skill Resources, gear→skill mapping, 6-slot assignment, 4 base anims, Anima gating. | Month 2–3 |
| 4 | **Rewards** — XP (feeds mastery + attributes), gold, gear drops (incl. skill-bearing), **Shard drops**, 3 weapon variants. | Month 2 |
| 5 | **Progression (two trees)** — **Equipment Mastery tree** (per line) + **Attribute tree** (per attribute) + **Attribute Rank**. | Month 3 |
| 6 | **Talismans** — Shard data, Talisman data, crafting chain (T1→T2→T3), 3 slots, persistence. | Month 3 |
| 7 | **Shroud & extraction** — timer, escape items, death penalty (mastery/attributes/Talismans persist). | Month 2 |
| 8 | **Hub loop** — blacksmith, alchemist, **craftsman (Talismans)**, portal keeper; save-on-Hub. | Month 1, 3 |
| 9 | **ProcGen 3D island** — biomes, verticality, secrets, boss lair placement, Shard placement. | Month 1–3 |
| 10 | **Boss prototype** — Dragon or Kapre, distinct telegraphed attack. | Month 3 |
| 11 | **Complete the slice** — HUD (Health/Anima, 6 skills, Talismans, both trees), audio, VFX, encounter pacing, clear ending. | Month 4 |
| 12 | **Launch prep** — bug fixing, optimization, Steam page, marketing assets, final balance. | Month 5 |

### 3.3 Vertical Slice Checklist (v5.1)

```
[ ] Player
    [ ] 3D movement on XZ + orthographic camera (gamepad + MKB)
    [ ] 2D sprite billboard with 5-direction flip
    [ ] Auto-attack (no attack button)
    [ ] 6 equipment-granted skill slots with cooldowns + Anima cost
    [ ] 4 base attack animations (Range, Light, Heavy, Casting)
    [ ] Health + Anima (no Stamina, no Mana)
    [ ] Dash/dodge with i-frames (consumes Anima)

[ ] Enemies
    [ ] One melee enemy (3D NavigationAgent3D: patrol → detect → chase → attack → die → drop)
    [ ] One stronger elite enemy    [ ] One boss with a distinct telegraphed attack (Dragon or Kapre)
    [ ] Enemy drops gold, gear, mastery XP, attribute XP, Shards
    [ ] Enemy root reuses player components (proves composition)
    [ ] Target groups distinct (player vs enemies)

[ ] Equipment & Skills
    [ ] 6 equipment slots (weapon/head/body/legs/feet/hands) — all skill-bearing
    [ ] Gear grants skills; 6 active skill cap enforced
    [ ] Skill slot assignment UI (which granted skill → which of 6 slots)
    [ ] NO accessory slot

[ ] Attributes & Talismans
    [ ] STR / FIN / ARK attributes exist and affect derived stats
    [ ] 3 Talisman slots
    [ ] STR Shard / FIN Shard / ARK Shard drop and are collectible
    [ ] T1 Talisman craftable from Shard + gold
    [ ] T2 Talisman craftable from Shard + pairing item + T1 + gold
    [ ] T3 Talisman craftable from Shard + rarity-gated pairing item + T2 + gold
    [ ] Talismans persist on death (verify)

[ ] Progression (two trees, no character level)
    [ ] Equipment Mastery XP earned by use, persists across runs
    [ ] Mastery Rank rises and scales granted skill power
    [ ] Mastery tree node purchased (per line)
    [ ] Attribute Progress earned by use, persists across runs
    [ ] Attribute Rank rises and raises base attribute
    [ ] Attribute tree node purchased (per attribute)
    [ ] NO character level
    [ ] NO attribute points

[ ] Items
    [ ] Gold pickup
    [ ] Three weapon variants (different feel + different granted skill)
    [ ] At least one non-weapon skill-bearing drop works
    [ ] Inventory + 6-slot equipment screen + 3-slot Talisman screen
    [ ] Item tooltip shows granted skill + equipment line
    [ ] Shard tooltip shows which attribute it feeds

[ ] Extraction & Shroud (Slayent-critical)
    [ ] Shroud timer advances from island edges inward
    [ ] HUD shroud proximity indicator
    [ ] Portal Scroll escape item (craftable/purchasable)
    [ ] Extract-or-push decision is meaningful
    [ ] Death by enemy or Shroud loses run loot + run-earned XP
    [ ] Mastery, Attribute Rank, tree nodes, and Talismans persist
    [ ] Save only in Hub

[ ] Presentation
    [ ] Health + Anima bars, 6-skill, 4-item HUD
    [ ] Damage and hit feedback
    [ ] Loot and pickup feedback
    [ ] Skill VFX differentiation (since only 4 base anims)
    [ ] Victory and defeat states
    [ ] Shroud visual/audio intensity ramp
    [ ] Boss roar audio
    [ ] Talisman craft SFX
```

---

## 4. Technical Architecture Notes (Godot-Specific, v5.1)

### 4.1 Composition Architecture

- **Root orchestrators:** `player.gd` and `enemy.gd` are `CharacterBody3D`. They wire components in `_ready()` and expose a public API (`player.stats`, `player.combat`, `player.controller` / `enemy.ai`, `player.movement`, `player.skill`, `player.visual`, `player.talismans`).
- **Communication rules:**
  - Parent → child: direct method calls.
  - Child → parent: signals.
  - Child ↔ child: references injected by the root in `_ready()`. **No `get_node("../../")` from components.**
- **Reusable components (shared by player and enemies):**
  - `StatComponent` — Health, **Anima**, regen, `take_damage`, `spend_anima`, `died`. **No stamina. No mana.**
  - `AttributeComponent` — STR/FIN/ARK base values, Attribute Rank, derived-stat calc (reads `StatScaling`). Provides `get_attribute(attr) -> float`.
  - `MovementComponent` — velocity, dash, i-frames, `move_and_slide()`. **Takes world-space intent** (no camera dependency). Dash consumes Anima via `StatComponent.spend_anima`.
  - `CombatComponent` — auto-attack timer, `find_nearest_target(range)`, `apply_damage_to`, **parameterized `target_group`**.
  - `SkillComponent` — skill slots, cooldowns, `try_use_skill(slot)` (checks **Anima**), **reads skills from equipped gear**.
  - `VisualComponent` — sprite billboard direction selection, hit flash, range torus visibility. Null-checks optional child nodes so enemies can omit `AimPivot`/`SkillRange`.
  - `TargetingComponent` — click-to-approach with interaction radius, reusable for enemies and interactables. Uses `ApproachableComponent` on targets.
  - `ApproachableComponent` — attached to enemies/chests/interactables; exposes `get_interaction_radius()` and `get_approach_position(from)`.
  - `TalismanComponent` — 3 Talisman slots, applies attribute bonuses to `AttributeComponent`, persists equipped Talismans, handles equip/unequip (Hub only).
- **What differs between player and enemy:**
  - **Input driver:** `PlayerController` (reads `Input`) vs `EnemyAI` (reads world state). Both emit the **same intent calls** to components.
  - **Death consequence:** `player.gd` on `stats.died` → defeat screen, run loot/XP loss. `enemy.gd` on `stats.died` → loot drop, mastery/attribute XP grant, death anim, `queue_free()`.
  - **Component set:** enemies omit `SkillComponent`, `TargetingComponent`, and `TalismanComponent` unless needed.
- **Camera dependency:** only `PlayerController` calls `CameraRig.project_click_to_ground`. `MovementComponent` is camera-free.

### 4.2 Autoloads (singletons)

- `GameManager` (flow/state)
- `SaveManager` (**Hub-only saves**, persists mastery + attributes + Talismans + village)
- `DamageService` (centralized calc, reads mastery scaling + attribute modifiers)
- `LootService` (tables, skill-bearing drops, **Shard drops**)
- `MasteryService` (per-line XP, tree nodes, skill scaling lookup)
- `AttributeService` (per-attribute XP, tree nodes, derived-stat lookup, `StatScaling` resource)
- `TalismanService` (recipe lookup, craft validation, T1→T2→T3 chain enforcement)
- `AudioManager`
- `InputRouter` (gamepad/MKB scheme switching)

### 4.3 Data-Driven Content (`Resource` files)

- `EquipmentData` — ID, name, slot type, **equipment_line**, rarity, stat mods, **granted_skill_ids**.
- `SkillData` — ID, name, animation type (Range/Light/Heavy/Cast), **Anima cost**, cooldown, damage, VFX, mastery scaling.
- `ShardData` — ID, **attribute** (STR/FIN/ARK), tier, rarity.
- `TalismanData` — ID, **attribute**, tier, attribute bonus, secondary effects, **crafting recipe** (Shard + pairing item IDs + optional lower-tier Talisman ID + gold).
- `LootTable` — per enemy type, gold range, item entries (weighted), **Shard entries**, skill-bearing chance.
- `MasteryTreeData` — per line: nodes, costs, effects.
- `AttributeTreeData` — per attribute: nodes, costs, effects (mirrors `MasteryTreeData`).
- `StatScaling` — attribute → derived-stat coefficients (tunable).
- `EnemyData` — stats, AI params, sprite set.
- No hardcoded content in scripts.

### 4.4 Input

- Godot Input Map with separate action sets for gamepad and MKB; `InputRouter` selects the active scheme.
- **Skill actions:** `skill_1`..`skill_6` mapped to X/Y/RB/LB/RT/LT (gamepad) and Q/W/E/R/T/Y (MKB).
- **Item actions:** `item_1`..`item_4` mapped to D-pad (gamepad) and 1–4 (MKB).
- **Click actions:** `move_click` (LMB), `interact` (A / F / RMB).
- Never hardcode raw button checks in gameplay code.

### 4.5 3D + 2D Hybrid Rendering

- **Environment:** 3D meshes, materials, lights, and VFX. **Orthographic Camera3D.**
- **Characters/enemies:** `Sprite3D` or `AnimatedSprite3D` with `BILLBOARD_ENABLED`. Sprite sheets authored per animation type (4 base anims) and per direction (5 drawn + flip).
- **Direction selection:** `VisualComponent` picks the nearest of 5 drawn directions from velocity/facing relative to camera, applies horizontal flip for the mirrored pair.
- **Depth sorting:** use `Sprite3D`'s `alpha_cut` + render priority; ensure sprites correctly occlude/are occluded by 3D props. Test early — this is a known hybrid pain point.
- **Shadows:** decide whether sprites cast 3D shadows (a simple blob/quad) or rely on VFX; lock this early since it affects art pipeline.

### 4.6 ProcGen

- Room/tile-based generator in **3D** with biome rules. Seed per run. Debuggable (seed display, regeneration hotkey).
- Output must feed `NavigationAgent3D` baking for enemies.
- **Shard placement** integrated into loot/chest placement rules.

### 4.7 Performance

- Target 60 FPS mid-range PC.
- **Profile early:** Shroud VFX (full-screen effect over 3D), ProcGen generation, **sprite billboard depth sorting with many enemies** (likely hotspot in the hybrid), and the mastery/attribute/talisman lookup path.
- Object pooling: projectiles, loot drops, damage numbers.

### 4.8 Art Pipeline

- **Sprite sheets** for characters/enemies: 4 base animations × 5 drawn directions (mirror for the other 3) = **20 drawn frames minimum per character** (plus idle/move/hurt/dash).
- **3D environment** modular kit: terrain tiles, ruins, props, biome-specific assets. 3D art can be simpler/clean (Bastion-style) since character sprites carry the visual identity.
- **VFX** is a first-class deliverable since skills reuse 4 base anims — budget VFX time accordingly.
- **Talisman / Shard icons** — small 2D icons for inventory, crafting UI, and Talisman slots.

---

## 5. What to Postpone (Do Not Build Yet)

- Multiple playable classes.
- **A free-floating skill tree** (skills come from gear).
- **Character level** (removed in v5.1 — use Mastery Rank + Attribute Rank).
- **Attribute Points** (removed in v5.1).
- **Mana** and **Stamina** resources (replaced by Anima).
- **Accessory slot** (removed in v5.1).
- **Hub stat purchases** (HP/Anima/inventory are governed by Attribute Rank + Attribute tree).
- **Talisman swapping mid-run** (Hub only).
- **Deep** procedural generation (build a simple 3D ProcGen island; not Diablo-scale).
- Multiplayer and trading.
- **Co-op** (out of current scope).
- **Additional islands and bosses** (post-launch).
- Advanced crafting, enchanting, item rerolling (Talisman chain + one other recipe only).
- Dozens of item rarities and affixes.
- **Per-skill unique animations** (4 base anims + VFX only).
- **8-direction sprite sets** (5 drawn + flip only).
- Pet companions, mounts, complex NPC systems.
- Endgame activities, seasons, extensive questlines.
- Cosmetic armor variations (post-launch).
- Speedrun timers, challenge modes (post-launch).
- **Weapon swapping** (excluded by GDD 3.2/9.2).
- **Tier 4+ Talismans** (post-launch; cap at T3 for launch).

---

## 6. Open Questions (Resolve Before Implementation)

From GDD v5.1 Section 13:

- **Boss identity:** Dragon or Kapre. **Blocks 1.3 boss prototype and 2.8 boss encounter.**
- **Story details:** Only the precolonial Spanish-era Philippine setting is fixed. Narrative delivery can proceed with placeholders.
- **Equipment mastery curve:** Exact XP thresholds and skill power scaling per Mastery Rank. **Blocks 1.6 and 2.2 mastery scaling implementation.** Pick placeholder values for the slice (e.g., 5 ranks, +5% skill damage per rank) and mark as tunable.
- **Attribute Progress curve:** Exact XP thresholds and base-stat gains per Attribute Rank. **Blocks 1.6 and 3.6.4 implementation.** Pick placeholder values (e.g., 5 ranks, +2 attribute points per rank) and mark as tunable.
- **Attribute tree shape:** Node count, costs, effects per attribute. Start by mirroring the equipment mastery tree structure.
- **Attribute coefficients:** Final STR/FIN/ARK derived-stat coefficients (GDD 3.6.3). Start with the proposed values in a `StatScaling` resource.
- **Talisman tier cap at launch:** Tier 3 (recommended) vs. Tier 4+. **Blocks 2.12 and 3.6.5 implementation scope.**
- **Skill pool per item:** How many skills each item carries (1 vs. multiple). For the slice: 1 skill per skill-bearing slot.
- **Co-op:** Nice-to-have; not in current scope. Keep player state in components (not hardcoded singletons) so co-op remains possible later.
- **Additional islands:** Post-launch; each with its own boss.

**Resolved by v5.1 (no longer open):**
- ~~XP persistence model~~ → two symmetric usage-based trees (Mastery + Attribute). Run-earned XP lost on death; ranks and nodes persist. See 1.6, 2.13.
- ~~Skill tree unlock via XP~~ → skills come from equipment. See 2.2.
- ~~Art style (2D vs. 3D)~~ → **2D hand-drawn characters over 3D environments.** See 0, 1.1, 4.5.
- ~~Mana resource~~ → replaced by **Anima**.
- ~~AGI / INT naming~~ → renamed to **FIN (Finesse)** and **ARK (Arkifex)**.
- ~~Accessory slot~~ → removed; replaced by **3 Talisman slots**.
- ~~Leveling / character level~~ → replaced by **Mastery Rank + Attribute Rank** (earn-by-use).
- ~~Attribute Points~~ → removed. Attributes governed by **Attribute Progress / Rank / Tree**.
- ~~Hub stat purchases with coins~~ → coins buy crafting/consumables/escape items only.
- ~~Talisman persistence~~ → explicitly persistent, never lost on death.

---

## 7. Definition of Done (Vertical Slice, v5.1)

The slice is done when a new player, without developer guidance, can:

1. Start in the Hub, buy/craft an escape item, select a 6-slot equipment loadout + 3 Talisman slots, and confirm each equipped skill-bearing piece grants an active skill in a 6-slot assignment.
2. Travel to the **3D ProcGen island** and fight enemies with auto-attack and equipment-granted skills using a gamepad, with 2D sprite billboards rendering correctly against 3D terrain, **all skills and dashes consuming Anima**.
3. Collect gold, a **skill-bearing gear drop**, **Shards**, and mastery + attribute XP; equip the gear and notice **both** a combat feel change **and** a new skill in their slot assignment.
4. See the Shroud advancing, feel time pressure, and make a deliberate extract-or-push decision.
5. Use their new power to defeat an elite or the boss (or escape via Portal Scroll).
6. Return to the Hub, **craft a T1→T2 Talisman** using collected Shards + pairing items + gold, equip it, and see STR/FIN/ARK rise — and confirm **both** the Equipment Mastery tree and the Attribute tree show nodes unlocked this run.
7. Die to an enemy or the Shroud — lose run loot and run-earned XP, **keep Mastery Rank, Attribute Rank, tree nodes, and Talismans** — and understand exactly why.

If that sequence is satisfying and runs at 60 FPS on mid-range hardware, Slayent has a strong foundation to expand into the full GDD v5.1 scope.

---

**Sources of change from v2 → v3 (for reviewers):**

- Resources: Stamina/Mana → **Anima** (universal combat resource).
- Attributes: STR/AGI/INT → **STR/FIN/ARK**; coefficients added (GDD 3.6.3).
- Equipment: 7 slots (incl. accessory) → **6 skill-bearing slots** (accessory removed).
- Talismans: **new system** — 3 slots, Shard-based crafting, T1→T2→T3 chain, persistent.
- Progression: two tracks (Hub stats + mastery) → **two symmetric usage-based trees** (Mastery + Attribute); no character level; no Attribute Points.
- Hub coins: buy stat upgrades → buy **crafting/consumables/escape items** only.
- Save model: persist mastery + village → persist **mastery + attributes + tree nodes + Talismans** + village.
- Death penalty: mastery persists → **mastery + attribute rank + tree nodes + Talismans persist**.
- HUD: Health/Stamina → **Health/Anima**; add **Talisman slots** and **Attribute Rank display**.
- Data model: `ItemData` → split into **`EquipmentData` / `ShardData` / `TalismanData`**; add **`AttributeTreeData`** and **`StatScaling`**.
- Autoloads: add **`AttributeService`** and **`TalismanService`**.
- Architecture: add **`AttributeComponent`** and **`TalismanComponent`** to the reusable component set.
- Slice checklist, build order, and Definition of Done updated to prove **Talisman crafting chain**, **both trees**, and **Anima economy**.
