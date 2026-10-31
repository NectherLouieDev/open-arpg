# Slayent — Game Design Document (Revised v5.1)

---

## 1. Game Overview

**Title:** Slayent
**Genre:** Roguelite Extraction Action-RPG
**Platform:** PC (Steam)
**Engine:** Godot
**Target Audience:** 18–40 years old; gamers in their thirties with limited playtime; fans of Torchlight, Diablo, and extraction games; controller-first players

**Core Concept:** A time-limited, session-based extraction action-RPG where a lone player explores a procedurally generated island, fights creatures, collects loot, and crafts upgrades—all while racing against a deadly "night shroud." Loot is only kept if the player successfully extracts; death means losing everything from that run. The ultimate goal is to find and slay the island's boss (a Dragon or Kapre) lurking in the island's depths.

**USP:** The fusion of extraction risk/reward with ARPG loot/grind/crafting (Torchlight/Diablo-style), presented in a **2D hand-drawn cartoony character art style over 3D environments** (Bastion-inspired), set in a **precolonial Spanish-era Philippines** setting, with **controller-first combat**.

**Scope Note:** The game currently focuses on **one island** with one boss. Additional islands (each with their own boss, Mega Man-style) are planned as **post-launch / extra content**.

---

## 2. Core Game Loop

### 2.1 The Loop

1. **Hub Preparation** → 2. **Island Infiltration** → 3. **Exploration, Combat & Loot Collection** → 4. **Extraction Decision** (extract early or push deeper) → 5. **Boss Hunt or Escape** → 6. **Return to Hub** → 7. **Upgrade & Repeat**

### 2.2 Session Flow

- Start in the safe Hub (upgrade gear, craft items, plan loadout, purchase escape items)
- Travel to the island with limited daylight remaining
- Explore, fight creatures, solve environmental puzzles, and collect loot
- Find clues pointing to the boss's lair (deeper in the island)
- **Choose:** Extract early via portal/scroll to secure loot, OR risk pushing deeper for rarer rewards and the boss encounter
- If the Shroud catches you or you die, you lose all loot and experience from that run
- Return to Hub with extracted resources to upgrade, craft, and prepare for the next run

---

## 3. Gameplay Mechanics

### 3.1 Core Systems

- **Combat (Torchlight/Diablo-inspired, controller-first with auto-attack):** Fast-paced action-RPG combat with skill slots, item slots, and automatic attacks when enemies are within attack radius. Skills are granted by equipped gear (see 3.4).
- **Extraction Timer:** Visible "Shroud" slowly engulfs the island from the edges inward (15–30 minute sessions). The Shroud is the primary time-pressure mechanic.
- **Procedural Generation:** The island is ProcGen per run (like Diablo/Torchlight dungeons), ensuring replayability. Layouts change subtly between runs, but player memory can still unlock shortcuts and patterns.
- **Progression (two usage-based tracks + loot rarity):**
  1. **Equipment Mastery** — earned by use per equipment line; unlocks that line's upgrade tree (see 3.5).
  2. **Attribute Progression** — earned by use per attribute (**STR / FIN / ARK**), raised by equipped **Talismans** and by **Attribute Rank** (see 3.6). No point allocation.
  - Plus **item stats/rarity** rolled per drop (not persistent progression).
- **Inventory Management:** Limited slots for consumables (potions, food), crafting materials, and loot. Extracted loot carries over; unextracted loot is lost.
- **Crafting:** Deep item mechanics and synergies. Craft keys, escape items (Portal Scrolls), **Talismans**, gear upgrades, and consumables.
- **Escape Items:** Portal Scrolls and similar items give players a chance to escape the island mid-run—a safety valve against frustration.

### 3.2 Player Systems

- **Resources:** **Health** (max HP) and **Anima** (max Anima). **Anima is the universal combat resource** — all skills, dashes, and dodges consume Anima. Anima regenerates over time (with a short delay after spending). Both are governed by attributes (see 3.6.2).
- **Attributes:** Three core attributes — **STR**, **FIN**, **ARK** (see 3.6.2). Raised by equipped **Talismans** and by **Attribute Progress** earned through use. No point allocation.
- **Abilities:** Active skills are granted by equipped gear, not chosen from a free skill tree (see 3.4). Up to 6 active skills equipped at once.
- **Currency:** Coins found throughout the island for Hub purchases (crafting, consumables, escape items).
- **Loadout:** Equipped gear (**weapon, head, body, legs, feet, hands** — 6 slots), **3 Talisman slots**, consumables, and escape items selected before entering the island. **No weapon swapping**—one active weapon loadout per run. **No Talisman swapping mid-run**—Talismans are equipped in the Hub.
- **Deep Item Synergies:** Equipment and crafting materials can be combined for powerful builds (ARPG-style). **Talismans can be used as crafting ingredients for higher-tier Talismans.**

### 3.3 Risk & Consequence

- **Death Penalty:** Dying to enemies or the Shroud results in loss of **all items and run-earned experience** from that run—including inventory and equipped gear brought into the run. **Equipment mastery and Attribute Rank are NOT lost. Talismans are NOT lost.**
- **Extraction Choice:** Players can extract early to secure loot or risk pushing deeper for rarer rewards. This is the core risk/reward decision ("Pera o Bayong" tension).
- **Story Consequences:** Failing to slay the boss reduces village population (visible in Hub).
- **Save System:** Progress only saves when in the Hub; island runs are "live" sessions.

### 3.4 Equipment-Based Skills

Skills are not selected from a free-floating skill tree. **Active skills are granted by equipped gear.** Your loadout is your build.

#### 3.4.1 Skill-Bearing Slots

| Slot | Grants |
|---|---|
| Weapon | Active skills (primary skill line) |
| Head | Active skill |
| Body | Active skill |
| Legs | Active skill |
| Feet | Active skill |
| Hands | Active skill |

- **Six skill-bearing equipment slots.** (The v4 Accessory slot is removed; attribute progression is now handled entirely by **Talismans** — see 3.6.)
- Each piece of equipment carries one or more skills tied to that item.
- Players may **mix and match equipment** to assemble their own skill set—builds are defined by gear combinations, not by a class choice.
- **Maximum 6 active skills** can be equipped at once (one per skill-bearing slot; the player may leave slots empty or use items whose skills they don't want, but the cap is 6).
- All other effects from gear (set bonuses, item affixes) are **passive**.

#### 3.4.2 Skill Slot Mapping

- **Controller:** X, Y, RB, LB, RT, LT = 6 active skill slots
- **Mouse & Keyboard:** Q, W, E, R, T, Y = 6 active skill slots
- Skills are assigned to slots by the player from the pool granted by their currently equipped gear.

#### 3.4.3 Design Intent

- Keeps input count low (6 active buttons max) while preserving build depth.
- Encourages loot hunting: a new drop isn't just a stat upgrade—it may unlock a skill you want.
- Supports the extraction loop: gear you extract is gear you can build around.
- Reference points: **Albion Online** (gear = skills), **No Rest for the Wicked** (upcoming equipment-skill update).

### 3.5 Equipment Mastery & Upgrade Tree (Usage-Based Progression)

Progression is split across tracks: **item stats/rarity** (rolled per drop), **equipment mastery** (persistent, earned by use), and **attribute progression** (persistent, earned by use — see 3.6).

#### 3.5.1 Equipment Mastery

- Wearing and using a piece of equipment earns **mastery experience for that equipment line** (e.g., "Stick", "Bow", "Light Armor").
- As mastery increases, the **skills granted by that equipment line become more powerful** (higher damage, lower cooldown, added effects—exact curve TBD).
- Mastery is **persistent across runs** and is not lost on death (unlike loot).
- Mastery is tracked per equipment line/type, not per individual item, so upgrading to a better drop doesn't reset progress.
- Progress displays as a **Mastery Rank** (see 3.5.4).

#### 3.5.2 Upgrade Tree

- A mastery tree per equipment line, **Albion Online-style**: spend mastery progress to unlock nodes that improve that line's skills and passives.
- The tree gives long-term goals for players who commit to a gear identity, while mix-and-match remains viable because mastery is per line, not per loadout.

#### 3.5.3 Relationship to Item Rarity

- **Item stats & rarity:** rolled on the drop; determines the raw power of that specific item.
- **Equipment mastery:** earned by usage; determines how strong that equipment *line's* skills are for you.
- Both matter: a high-rarity drop of a line you've mastered is the ideal outcome, creating a reason to keep extracting and hunting.

#### 3.5.4 Mastery Rank (No Character Level)

- There is **no character level** in Slayent. Progression is expressed as **Mastery Rank** (per equipment line) and **Attribute Rank** (per attribute — see 3.6.4). Both are earned by use and persistent.
- Mastery Rank is earned by using equipment of that line; it gates higher-tier mastery tree nodes and scales that line's skill power.
- Attribute Rank is earned by using an attribute line; it raises that attribute's **base** stat and gates higher-tier attribute tree nodes (see 3.6.4).

### 3.6 Talismans & Attributes (Primary Attribute Progression)

#### 3.6.1 Purpose

**Talismans** are crafted, passive, persistent artifacts that are the **primary source of raw attribute upgrades**. There is no point-allocation system. Talismans — plus the **Attribute Rank** earned by using them — are how the player builds their STR/FIN/ARK identity.

- **Passive only.** No toggling, no active use.
- **Crafted.** Built from a recipe: a **Shard** base + pairing items (which may include equipment, weapons, **and other Talismans**) + gold.
- **Tiered.** Tier 1 → Tier 2 → Tier 3 (Tier 4+ post-launch). Higher tier = higher attribute values and (optionally) secondary effects.
- **Slot-limited.** **3 Talisman slots.** Slots may be one-per-attribute or mix-and-match (e.g., 2 STR + 1 FIN). Build choice matters.
- **Persistent.** Talismans do **not** drop on death (see 3.3). They are crafted progression, like mastery.

#### 3.6.2 Core Attributes

Three attributes, kept intentionally simple:

| Attribute | Theme | Governs |
|---|---|---|
| **STR** (Strength) | Force, endurance | Max Health; melee/heavy damage bonus |
| **FIN** (Finesse) | Precision, agility | Max Anima; attack speed; movement speed; dash/dodge efficiency |
| **ARK** (Arkifex) | Arcane craft, will | Skill damage; cooldown reduction; Anima regeneration rate |

> **Renamed from v4:** AGI → **FIN (Finesse)**; INT → **ARK (Arkifex)** — "Arkifex" evokes the precolonial Filipino *babaylan*/craft-artifact identity and fits the Talisman-crafting theme. STR is unchanged.

#### 3.6.3 Attribute Coefficients (Proposed — Tunable)

Exact values live in a `StatScaling` resource so they can be tuned without code changes.

| Attribute | Derived Stat | Coefficient (per point) |
|---|---|---|
| **STR** | Max Health | +10 HP |
| **STR** | Melee/Heavy Damage | +1.5% per point |
| **FIN** | Max Anima | +8 Anima |
| **FIN** | Attack Speed | +1.0% per point |
| **FIN** | Movement Speed | +0.5% per point |
| **FIN** | Dash/Dodge Anima Cost Reduction | −0.5% per point (floor TBD) |
| **ARK** | Skill Damage | +1.5% per point |
| **ARK** | Cooldown Reduction | +0.75% per point (cap TBD) |
| **ARK** | Anima Regen Rate | +1.0% per point |

#### 3.6.4 Attribute Progress & Attribute Rank (Mirrors 3.5)

Attribute progression mirrors equipment mastery, as a **parallel usage-based track**:

- **Attribute Progress** is earned by **using an attribute line** — e.g., playing with STR-focused Talismans and STR-derived stats in combat (exact XP sources TBD).
- Accumulated Attribute Progress raises **Attribute Rank** (per attribute: STR Rank, FIN Rank, ARK Rank).
- **Attribute Rank raises the base attribute stat automatically** (like Mastery Rank scaling a line's skills). No point allocation.
- **Attribute Rank is persistent** and never lost on death.
- **Attribute Upgrade Tree** — a per-attribute tree, **structurally identical to the equipment mastery tree** (3.5.2): spend Attribute Progress on nodes that improve that attribute's derived stats and (optionally) unlock passive effects. This is the **second of the two trees**.
- **Two-tree model (symmetric):**

| Track | Earned by | Tree | Scales |
|---|---|---|---|
| **Equipment Mastery** | Using equipment of a line | Per-equipment-line tree | That line's **skills** |
| **Attribute Progress** | Using an attribute line | Per-attribute tree | That attribute's **base stat + derived stats** |

- **Interaction with Talismans:** Talismans raise the *equipped* attribute bonus; Attribute Rank raises the *base* attribute; the Attribute tree shapes *how* the attribute scales. All three stack. A player with high STR Rank and a STR tree invested gets more from any STR Talisman — rewarding commitment, while mix-and-match remains viable because progress is per attribute line.

#### 3.6.5 Talisman Tiers & Crafting (DOTA 2-style Recipes)

**Shards** are the base components: **STR Shard**, **FIN Shard**, **ARK Shard**.

| Tier | Attribute Granted | Crafting Inputs | Notes |
|---|---|---|---|
| **Tier 1** | +2 to +4 | 1 Shard + small gold | Entry-level; craftable early. |
| **Tier 2** | +5 to +8 | 1 Shard + pairing item(s) (gear/weapon/material) + **optionally a Tier 1 Talisman** + moderate gold | Requires some exploration/loot. |
| **Tier 3** | +9 to +14 | 1 Shard + a **rare pairing item** (rarity-gated) + **a Tier 2 Talisman of the same attribute** + high gold | Endgame-adjacent; meaningful investment. |
| **Tier 4+** | TBD | TBD | Post-launch. Cap at Tier 3 for launch scope. |

**Crafting rules:**

- **Recipe:** `Shard + pairing item(s) + gold (+ lower-tier Talisman for higher tiers) → Talisman of Tier N`.
- **Pairing items** may include **equipment, weapons, materials, or other Talismans**. This creates a loot sink and a use for surplus gear.
- **Higher tiers require rarity and/or the Talisman below them.** Specifically: Tier 2 may optionally consume a Tier 1 Talisman; **Tier 3 requires a Tier 2 Talisman of the same attribute** plus a rarity-gated pairing item. This makes higher-tier Talismans a **chain** (T1 → T2 → T3), not a shortcut.
- **Deterministic:** a given recipe always produces the same Talisman (no RNG on craft) — contrast with loot drops. Crafting is the reliable counter to loot variance.
- **Recipe discovery:** recipes are known from the start (or unlocked via the craftsman/elder); the *components* (Shards, pairing items, lower-tier Talismans, gold) are what gate crafting.

#### 3.6.6 Relationship to Other Systems

| System | Relationship |
|---|---|
| **Equipment (§3.4)** | Equipment grants **skills** and per-drop stat mods. Talismans grant **attributes**. They stack. Equipment can be a **crafting input** for Talismans. |
| **Equipment Mastery (§3.5)** | Mastery scales skills (per line). Attribute Progress scales attributes (per attribute). **Symmetric tracks**; both persist; both have per-line/per-attribute trees. |
| **Hub upgrades** | Hub vendors sell **crafting, consumables, and escape items for coins**. Base resource bumps (HP/Anima/inventory) are **not** a separate currency system — they are governed by **Attribute Rank** and the **Attribute tree** (see 3.6.4). |
| **Loot (§1.4)** | Loot feeds crafting (pairing items, Shards) and mastery. Talismans are the deterministic crafting output that makes loot variance feel less punishing. |
| **Death penalty (§3.3)** | Talismans, Attribute Rank, and Attribute tree nodes persist. Run loot and run-earned XP do not. |
| **Coins** | For crafting, consumables, and escape items. |

#### 3.6.7 Design Intent

- **Stat identity without point allocation.** Players express STR/FIN/ARK builds through which Talismans they slot, which attribute lines they've ranked, and which attribute tree nodes they've unlocked.
- **Symmetric depth.** Two usage-based trees (equipment lines and attributes) give long-term goals on both the *skill* axis and the *stat* axis.
- **Loot sink.** Surplus gear and lower-tier Talismans feed crafting.
- **Deterministic counter to RNG.** Talismans are crafted and chained (T1→T2→T3).
- **Two orthogonal build axes.** Equipment shapes *what* your kit is (skills); Talismans + Attribute Progress shape *how strong* it is (attributes).
- **Fits the setting.** Crafted talismans as precolonial Filipino artifacts.

---

## 4. Story & World

### 4.1 Narrative Premise

Set in a **precolonial Spanish-era Philippines** (i.e., before Spanish colonization; the exact period and alternate-history details are still being discussed and left open for now). A once-peaceful village lives under constant threat from a powerful creature—a Dragon or Kapre—whose presence brings a deadly "night shroud" that engulfs the nearby island each night. As the Hero, you answer the call to slay the beast, embarking on repeated expeditions into the dangerous island to grow strong enough to face the boss in its lair.

**Note:** The story is still under discussion. The only fixed element is the **precolonial Spanish-era Philippine setting**. All other narrative details are open and subject to change.

### 4.2 Key Story Elements

- **Hook:** Protect the village by ending the shroud curse; uncover the mystery of the island and the boss's connection to the shroud.
- **Setting:** A precolonial Spanish-era Philippine island with varied biomes (forest, ruins, caves, mountain paths), ancient ruins, and hidden secrets.
- **Protagonist:** A lone warrior armed with their chosen weapon loadout.
- **Antagonist:** The island boss—a Dragon or Kapre—master of the shroud.
- **Core Struggle:** Balancing exploration, looting, and survival while hunting your ultimate prey.
- **Mystery:** The island's layout and the boss's exact location change between runs (ProcGen). Deeper island areas hold the boss encounter.

### 4.3 Story Delivery

- Environmental storytelling through ruins, carvings, and found journals.
- Brief NPC dialogues in the Hub provide context and motivation.
- Visual storytelling: village condition worsens if the boss isn't defeated.

---

## 5. World Design

### 5.1 The Hub

- Safe zone with blacksmith (upgrades), alchemist (potions), craftsman (crafting, including Talismans), elder (story), and portal keeper.
- Visual changes reflect story progress (villager count, building repairs).
- All progression, crafting, and preparation happen here.

### 5.2 The Cursed Island (ProcGen)

- **Design Philosophy:** Roguelite extraction—a procedurally generated island per run, with a single biome-based boss. The island itself is the level.
- **Biomes:** Forest, ruins, caves, mountain paths—each with unique enemies and resources.
- **Verticality:** Multi-level exploration.
- **Secrets:** Hidden paths, optional challenge areas with better loot.
- **Time Pressure:** The Shroud visibly advances, creating natural urgency.
- **Boss Encounter:** A single randomized deep-island encounter (Dragon or Kapre). Some bosses may require keys or crafted items to access. Players must decide whether to fight or flee when encountering powerful enemies.

**Scope Note:** The game currently focuses on **one island with one boss**. Additional islands—each with their own boss, Mega Man-style—are planned as **extra/post-launch content**.

### 5.3 Inspirations Applied

- **Torchlight / Diablo:** ProcGen dungeons, loot grind, item synergies, auto-attack ARPG combat.
- **Extraction genre (PoE Heist, Vaultbreakers, Eldegarde):** Risk/reward tension, session-based progression.
- **Monster Hunter:** Preparation and hunt memorization.
- **Zelda, Moana, One Piece, Vindictus:** Art style, island adventure feel.
- **Bastion (Supergiant Games):** 2D hand-drawn character art over 3D environments; mature cartoony art direction and combat feel.
- **DOTA 2:** Deterministic, component-based item crafting (the Talisman recipe model).
- **Albion Online:** Gear = skills; per-line mastery tree.
- **Mega Man:** Multiple island bosses (post-launch extra content).

---

## 6. Art & Audio Direction

### 6.1 Visual Style

- **2D hand-drawn cartoony character sprites over 3D environments**—a key USP that stands out from AI-generated visuals.
- **Art direction reference: Bastion (Supergiant Games)**—hand-drawn, mature cartoony style for characters, with the same spirit applied to combat feel and presentation.
- Characters and enemies are authored as **2D sprite sheets**; environments are **3D**, providing depth and verticality while keeping character art hand-drawn.
- Inspired by Zelda, Moana, One Piece, Vindictus, and Bastion.
- Clean, readable environments with clear visual distinction between safe areas and shroud-affected zones.
- Day/night cycle with dramatic shroud effects.
- Simple but expressive character and enemy designs.

### 6.2 Audio Design

- Atmospheric music that intensifies as the Shroud approaches.
- Impactful combat sounds.
- Distinct audio cues for nearby secrets or dangers.
- Boss roars that echo through the island.

### 6.3 Animation Direction

#### 6.3.1 Base Animation Set

To keep scope achievable for a solo developer, the player uses a **small set of base attack animations**, with skills layering effects on top rather than each requiring a unique animation:

1. **Range Attack**
2. **Light Attack**
3. **Heavy Attack**
4. **Casting**

- Skills reuse these base animations; differentiation comes from **VFX, timing, and hit effects**.
- Base animations should be polished—quality over quantity. Reference: NRFTW reuses/rotates its animation set the same way.
- Thematic fit: precolonial Philippine setting means melee leans into **stick fighting (arnis/eskrima)** motion.

#### 6.3.2 Sprite Direction & Flipping

- Player sprites are **flippable**, so only **5 directions** need to be drawn: 3/4 front, side, 3/4 back, plus their mirrored counterparts via horizontal flip (character is effectively ambidextrous).
- This replaces the usual 8-direction requirement, roughly halving the drawing workload.
- Enemies can use simpler direction sets; the flip optimization is primarily for the player character.
- Sprites are authored as **sprite sheets**.

#### 6.3.3 Scope Guidance

- Prototype stage: placeholder anims acceptable—"attack, cast, hit" is enough to validate feel.
- Production stage: the 4 base anims are finalized and polished, with per-skill VFX doing the heavy lifting for visual variety.

---

## 7. User Interface

### 7.1 In-Game HUD

- **Health and Anima bars.**
- Quick-access skill slots (6) and item slots (4) (see Section 9.2).
- Shroud proximity indicator/timer.
- Minimal compass for orientation.
- Current objectives/clues.
- Extraction availability indicator (portal/scroll status).

### 7.2 Menu Systems

- Inventory management screen.
- **Talisman slots (3) and Talisman crafting interface.**
- **Equipment Mastery tree interface (per line).**
- **Attribute tree interface (per attribute: STR / FIN / ARK).**
- **Attribute Rank display.**
- Crafting interface.
- Hub vendor shops (coins).
- Run statistics and achievements.

---

## 8. Progression & Rewards

### 8.1 Plot Rewards

- Slaying the island boss permanently stops the Shroud.
- Village returns to prosperity (visual changes in Hub).
- Unlock "true ending" with additional lore.
- (Post-launch) Unlock new islands/biomes for future runs.

### 8.2 Gameplay Rewards

- **Materials:** For upgrading weapons, armor, crafting, and **Talisman recipes (Shards, pairing items)**.
- **Experience (earn-by-use):** Feeds **Equipment Mastery** (per line) and **Attribute Progress** (per attribute). Unlocks tree nodes on both tracks.
- **Cosmetics:** Armor variations, weapon designs (post-launch potential).
- **Persistent Upgrades:** **Attribute Rank** raises base attributes; **Talismans** are the primary equipped attribute source; **Hub coins** buy crafting/consumables/escape items.
- **Deep Item Synergies:** Powerful build-defining combinations.

### 8.3 Player Motivation

- Early gameplay shows the boss's power (difficult optional encounter).
- Village visibly suffers if players avoid the boss hunt.
- Upgrade system provides clear power progression (Mastery Rank, Attribute Rank, Talismans).
- "Almost escaped" moments create memorable stories.
- The "Pera o Bayong" risk/reward tension keeps every extraction decision meaningful.

---

## 9. Technical Implementation

### 9.1 Development Approach

- **Engine:** Godot.
- **Solo-dev friendly:** Designed for a solo developer, but scalable if additional help is available.
- **ProcGen:** Implement procedural island generation for replayability.
- **Controller-first:** All combat and UI designed around gamepad input, with mouse/keyboard as a classic ARPG alternative.
- **Art pipeline:** 2D hand-drawn sprite sheets for characters/enemies composited over 3D environments (Bastion-style).

### 9.2 Controls

**Primary: Gamepad (Controller-First)**
- **Right Stick:** Move
- **Left Stick:** Rotate / Aim
- **RT / LT:** Skill slots (2 of 6)
- **RB / LB:** Skill slots (2 of 6)
- **X / Y:** Skill slots (2 of 6)
- **A:** Interact
- **B:** Dash / Dodge
- **D-pad:** Item slots (4 items)
- **Start/Select:** Menus

**Auto-Attack:** The character automatically attacks when an enemy is within attack radius. Applies to both controller and mouse/keyboard. No dedicated basic-attack button—positioning and skill usage are the primary combat inputs.

**Secondary: Mouse & Keyboard (Classic ARPG / Diablo-style)**
- **Left Click:** Move / point-and-click movement; auto-attacks when near attack radius
- **Right Click:** Context action / interact
- **Q / W / E / R / T / Y:** Skill slots (6)
- **1 / 2 / 3 / 4:** Item slots
- **Space:** Dash / Dodge
- **F:** Interact

**Input Philosophy:** Responsive, low-latency controls. Controller is the primary design target; mouse/keyboard follows a classic Diablo-style point-and-click ARPG scheme. Auto-attack within attack radius applies to both input methods. **No weapon swapping**—one active weapon loadout per run. **No Talisman swapping mid-run.**

### 9.3 Performance Targets

- 60 FPS on mid-range PCs.
- Clean visual style optimized for performance.
- Minimal loading between Hub and Island.

---

## 10. Development Timeline (5 Months)

### Month 1: Foundation
- Set up Godot project structure and core systems.
- Implement basic movement, auto-attack, and combat.
- Create Hub prototype.
- Design core island layout and ProcGen framework.

### Month 2: Core Loop
- Build first island biome.
- Implement Shroud system and extraction mechanics.
- Create basic enemy types.
- Test initial gameplay loop.

### Month 3: Content & Systems
- Expand island with additional biomes.
- Implement equipment-based skills and mastery/upgrade tree systems.
- **Implement Talismans, Shards, Attribute Progress, Attribute Rank, and the attribute tree (mirroring the mastery tree).**
- Add puzzles and exploration elements.
- Create boss (Dragon/Kapre) encounter prototype.

### Month 4: Polish & Balance
- Refine combat feel and enemy AI.
- Balance economy, attributes, and difficulty.
- Implement all UI/UX systems (including Talisman, Attribute Rank, and both tree screens).
- Add audio and visual effects.
- Implement 2D hand-drawn art assets (sprite sheets over 3D environments).

### Month 5: Launch Preparation
- Bug fixing and optimization.
- Create Steam page and marketing assets.
- Final balancing and polish.
- Prepare for launch.

---

## 11. Marketing & Store Presence

### 11.1 Steam Page Elements

- **Short Description:** "Slayent is a roguelite extraction action-RPG about racing against time to hunt a monstrous boss before a deadly shroud consumes everything—and keeping the loot you risked everything to find."
- **Long Description:** Focus on tension, meaningful progression, the risk/reward loop, 2D hand-drawn cartoony art over 3D environments, auto-attack ARPG combat, equipment-based skills, **crafted Talismans and earned attribute ranks**, and the unique precolonial Philippine setting.
- **Key Features:**
  - Time-limited exploration with ProcGen islands.
  - Satisfying 2D hand-drawn Bastion-inspired combat with auto-attack.
  - Equipment-based skills and usage-driven mastery progression.
  - **Crafted Talismans and usage-driven Attribute Rank progression (STR / FIN / ARK).**
  - Persistent upgrades and deep item synergies.
  - Compelling boss hunt (Dragon/Kapre).
  - Precolonial Philippine setting.

### 11.2 Visual Identity

- **Cover Art:** Hero facing the boss with the Shroud approaching in background; 2D hand-drawn cartoony character art over a 3D environment.
- **Trailer:** Show Shroud mechanic, combat, exploration, and boss confrontation.
- **Screenshots:** Demonstrate variety of biomes, combat scenarios, Hub upgrades, Talisman crafting, and crafting.

### 11.3 Target Messaging

- For fans of tense, skill-based action games.
- Appeals to players who enjoy meaningful progression and ARPG loot.
- Highlights unique time-pressure mechanic and extraction risk/reward.
- Emphasizes the hand-drawn art, Bastion-inspired style, and precolonial Philippine-inspired world.
- Controller-first ARPG combat with auto-attack.

---

## 12. Success Metrics & Future Plans

### 12.1 Launch Goals

- Positive user reviews focusing on combat feel and tension.
- Completion rate that shows engaging progression.
- Community sharing "close call" extraction stories.

### 12.2 Post-Launch Considerations

- **Additional islands, each with their own boss (Mega Man-style) — extra content.**
- New weapon or ability options.
- **Tier 4+ Talismans and expanded Talisman recipes.**
- Challenge modes or difficulty settings.
- Speedrun support with timers.
- Expanded crafting and item synergy systems.
- **Nice-to-have: Co-op play** (the game is currently single-player only, but co-op is a desirable future feature).

---

## 13. Open Questions & TBD

- **Story:** Still under discussion. Only the precolonial Spanish-era Philippine setting is fixed.
- **Boss identity:** Dragon or Kapre (or both as separate bosses in future islands) — to be decided.
- **Equipment mastery curve:** Exact XP thresholds and skill power scaling per Mastery Rank TBD.
- **Attribute Progress curve:** Exact XP thresholds and base-stat gains per Attribute Rank TBD.
- **Attribute tree shape:** Node count, costs, and effects per attribute TBD — start by mirroring the equipment mastery tree structure.
- **Attribute coefficients:** Final STR/FIN/ARK derived-stat coefficients (see 3.6.3) TBD — start with the proposed values.
- **Talisman Tier cap at launch:** Tier 3 (recommended) vs. Tier 4+.
- **Skill pool per item:** How many skills each item carries (1 vs. multiple) TBD during prototyping.
- **Co-op:** Nice-to-have; not in current scope.
- **Additional islands:** Post-launch / extra content; each with its own boss.

**Resolved in v5.1:**
- ~~Mana resource~~ → replaced by **Anima** as the universal combat resource for skills, dashes, and dodges.
- ~~AGI / INT naming~~ → renamed to **FIN (Finesse)** and **ARK (Arkifex)**; STR unchanged.
- ~~Accessory slot~~ → removed; replaced by **3 Talisman slots**.
- ~~Leveling / character level~~ → replaced by **Mastery Rank** (per equipment line) and **Attribute Rank** (per attribute), both earn-by-use.
- ~~Attribute Points~~ → removed. Attributes are governed by **Attribute Progress / Attribute Rank / Attribute tree**, mirroring equipment mastery as the second of two symmetric trees.
- ~~Hub stat upgrades purchased with coins~~ → Hub coins buy crafting/consumables/escape items; base resource bumps are governed by **Attribute Rank + Attribute tree**.
- ~~Talisman persistence~~ → explicitly persistent, never lost on death (see 3.3).

---

### Conclusion

Slayent combines the loot-driven depth of Torchlight/Diablo-style ARPGs with the tense, session-based risk/reward of extraction games, all wrapped in a **2D hand-drawn cartoony character art style over 3D environments** (Bastion-inspired), set in a **precolonial Philippine-inspired world**, and built in **Godot** with **controller-first combat and auto-attack**. Equipment-based skills and usage-driven mastery give builds depth without bloating inputs; **crafted Talismans and earned Attribute Rank** give attribute identity without point allocation. Two symmetric usage-based trees — one per equipment line, one per attribute — provide long-term progression on both the skill and stat axes. The core loop—prepare, explore a ProcGen island, loot, decide whether to extract or push deeper, and face the boss—creates emergent stories and meaningful decisions. By focusing on a single island and boss at launch, the project stays achievable for a solo developer while leaving room for Mega Man-style island expansions in the future.