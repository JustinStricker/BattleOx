# Gameplay Specification

## Modes

Modes share core systems (shields, abilities, combat, tool system):

- **Survival** — PvE. Day/night cycle, zombie waves, collectibles, safehouse crafting, Echo Zones, boss fights, ability progression.
- **Horde** — PvE. Fixed-position wave defense. Escalating difficulty. How long can you survive?
- **King of the Hill** — PvP. 2–4 players compete for zone control.
- **Arena** — PvP. FFA or team deathmatch. No objective — just kills.
- **Battle Royale (TBD)** — PvP. Last-standing, storm circle, loot drops. Design phase.

---

# Design Philosophy

## Combat Identity
- **Skillshots over hitscan**: All ranged attacks are projectiles with travel time. No point-and-click. No hitscan. Every shot requires leading, prediction, or timing.
- **Player agency preserved**: No hard CC in PvP (stuns, freezes, sleeps). All crowd control is soft — slow, knockback, displacement, vulnerability. You can always fight back.
- **Weapons defined by mechanical role**: Each weapon fills a distinct combat function (sustained DPS, burst, AoE, multi-target, etc.). The weapon's identity is what it DOES, not what it looks like.

---

# Core Systems

## Shields

The player's only health pool. When shields hit 0, you die.
- Base capacity: 150 shields. Regen delay: 3s. Regen rate: 25/s.
- Screen flash + sound cue on shield break. Shield bar in HUD.

### Synergies
| Trigger | Effect | Mode |
|---|---|---|
| Night | delay → 2s, rate → 35/s | Survival |
| KOTH zone | delay reduced by 0.5s | KOTH |
| Charge ability | restore 50 shields on impact | Both |
| Shield Injector (crafted) | restore 50 shields instantly | Survival |
| Every 10 Hill points | restore 25 shields | KOTH |
| Nova | costs 50 shields (unavailable below 50) | Both |

---

## Abilities

Broader ability framework drawing from Overwatch (cooldown loadout + ultimate) and RAGE (Overdrive).

### Loadout System

Players have 4 ability slots:

| Slot | Binding | Type | Swappable |
|---|---|---|---|
| Ability 1 | Q (or Shift) | Movement / utility | No — found in world, fixed once equipped |
| Ability 2 | E | Combat / control | No — found in world, fixed once equipped |
| Overdrive | Shift (or side button) | Personal steroid | No — always berserker mode |
| Ultimate | F | High-impact heroic moment | Yes — swap at boss fights |

- Overdrive is separate from Ultimate: a short-lived damage/speed/regen burst rather than a big projectile.
- Ultimate charge builds at 2% per damage point dealt (keep existing system).
- Q and E abilities are found in the world. Once equipped, they're fixed.
- Ultimates are earned by defeating Echo Zone bosses. After defeating a boss, you can swap your current Ultimate for the one the boss drops.
- Overdrive is always the berserker steroid — not swappable.

### Crowd Control Rules

- **All modes**: No hard CC anywhere. All crowd control is soft — target can always move and act, just at a disadvantage.
- Allowed soft CC: slow, knockback, displacement, vulnerability, silence (ability cooldown increase), disarm (weapon cooldown increase).
- Forbidden hard CC: stun, freeze, sleep, root, polymorph, banish.

### Overdrive (RAGE)

Temporary combat steroid:
- Activation: Manual when bar is full (builds through dealing/taking damage, kills)
- Duration: ~6s
- Effects: +30% damage, +20% move speed, shield regen, empowered melee
- Cooldown: ~15s after Overdrive ends (separate from ability cooldowns)
- Feels like a berserker mode — short enough to require timing, frequent enough to use every encounter.

### Ultimate

Builds via combat damage (2% per damage point), press F to activate. Ultimates are earned by defeating Echo Zone bosses and can be swapped at boss fights.

Starting Ultimate:
- **Charge/Nova**: Gap closer + AoE damage

Other Ultimates (earned from bosses):
- **Overdrive Surge**: Enter a superior Overdrive state (doubled effects, longer duration)
- **Orbital Strike**: Call down a targeted AoE barrage
- **Absorption Field**: Create a zone that drains enemy shields and restores ally shields

### Ability Pool

The existing 8 biotics are reworked into the ability pool. Charge and Nova are partially implemented. Their status:

| Power | Slot | Fate |
|---|---|---|
| Charge | Ultimate (starting) | Gap closer + AoE damage. Starting ultimate. |
| Nova | Ultimate (starting) | Part of starting Charge/Nova ultimate. |
| Pull | Q | Pulls target toward you (forced movement). Target can still attack. |
| Throw | E | Launches enemy. Knockback, not hard CC. |
| Warp | E | Applies vulnerability. No CC. |
| Singularity | Q | AoE pull toward center (soft CC, not lift). |
| Bend Time | Q | Slow enemies in area by X%. No time freeze. |
| Dark Vision | E | Reveal enemies through walls. Intel, no CC. |

---

## Combat

### Weapon Design (Projectile-Only, RAGE-Inspired)

All weapons are projectiles. No hitscan. No point-and-click. Every weapon requires leading, prediction, or timing.

Each weapon is a unique tool (not a stat tier). Weapons are found as schematics in the world and require specific materials to craft/upgrade.

Every weapon has:
- **Primary fire** — the main attack
- **Alternate fire** — a distinct secondary mode (not just zoom)
- **Rarity** (TBD) — Common / Uncommon / Rare / Legendary variants with passive modifiers

### Weapon Roles

Weapons are defined by mechanical function, not by name. Each fills a distinct combat role:

| Mechanical Role | Skill Expression | Weapon Candidates | Status |
|---|---|---|---|
| **Sustained ranged DPS** | Leading, charge timing, movement | Bow | ✅ Implemented |
| **Melee burst + gap closer** | Timing the dash, positioning | Sword | ✅ Implemented |
| **Multi-target / ricochet** | Ricochet angles, target prioritization | Wingstick | Planned |
| **AoE / area denial** | Arc timing, positioning | Grenades, traps | TBD |
| **Burst ranged DPS** | Prediction, patience | Heavy throw, javelin, crossbow | TBD |
| **Defensive / utility** | Reaction timing, positioning | Parry, block, dodge | TBD |

### Bow
| Property | Value |
|---|---|
| Charge | 0.15–2.0s hold LMB |
| Arrow speed | 15–55 m/s (scales with charge) |
| Damage | 25 |
| Cooldown | 0.5s |

### Sword (Dash-Slash)
| Property | Value |
|---|---|
| Trigger | RMB or Shift |
| Cooldown | 1.5s |
| Damage | 25 |
| Cone | 75° half-angle, 8m range |
| Dash | 60 m/s for 0.25s |

### Wingstick (Planned)
| Property | Value |
|---|---|
| Primary | Thrown projectile, bounces between targets |
| Alt-Fire | Remote detonate |
| Inspiration | RAGE |

### Overdrive (RAGE)
| Property | Value |
|---|---|
| Charge source | Dealing/taking damage, kills |
| Duration | ~6s |
| Damage bonus | +30% |
| Speed bonus | +20% |
| Regen | Shield regen during Overdrive |
| Cooldown | ~15s (starts after duration ends) |
| Effects | Empowered melee (knockback on hit), screen FX, sound cue |
| Note | Separate from Ultimate — shorter, more frequent. Melee applies knockback, not stun. |

### Multiplayer
Host is authoritative. Clients send inputs; host validates cooldowns, runs hit checks, broadcasts results. Arrows spawned by host only.

---

## Tool System (Roblox-Inspired)

Universal item framework. Every equippable item is a **Tool** instance rather than a hardcoded script.

### Tool Structure
| Component | Description |
|---|---|
| **Handle** | 3D mesh visible in-world and in the player's hand |
| **Grip** | Position/rotation offset that places the Tool in the character's hand |
| **Activation** | Click to use — primary fire, alt fire, or context-dependent |
| **Properties** | Damage, cooldown, ammo, range, rarity, schematic ID — stored on the Tool itself |

### Current Tools
- Bow (existing) — refactored to Tool
- Sword (existing) — refactored to Tool

### Planned Tools
- Wingstick
- Grenades / traps (AoE projectile tools)
- Consumables (shield injector, etc.)
- Building hammer / blueprint tool
- Grappling hook (potential)
- Additional projectile weapons (TBD — defined by mechanical role, not gun type)

### Multiplayer
Tool state (equipped slot, ammo, cooldown) synced via RPC. Host validates tool actions.

---

## Building (TBD)

Building is under consideration. Two possible directions:

| Direction | Description | Source |
|---|---|---|
| **Minecraft-style** | Grid-based permanent structures. Blocks snap, edit mode. Safehouse expansion. | Minecraft |
| **Fortnite-style** | Quick-place walls/ramps/floors during combat. Resource harvesting from environment. Zero-build option for purists. | Fortnite |

**TBD**: Neither, either, or both. Design decision deferred.

---

# Survival Mode (PvE)

## Core Loop
Explore procedurally-generated terrain → fight night waves → survive → craft upgrades → discover Echo Zones → defeat bosses → unlock new Ultimates → repeat.

## Day/Night Cycle
- Full cycle: 12 min (8 day, 4 night). Transitions: 30s each.
- Visual: sun position drives sky colors, light, fog. Moon + stars at night.
- Day: Shamblers only (rare, passive unless provoked). Safe exploration time.
- Night: All types spawn (Shambler, Runner, Brute). Aggressive. 3x spawn rate. +30% speed, 2x aggro.
- UI: sun/moon icon, dusk/dawn warning flash.

## Enemies (Zombies)
| Type | Weight | Health | Speed | Size | Damage |
|---|---|---|---|---|---|
| Shambler | 60% | 20 | ×1.0 | 3.0–5.0 | 8 |
| Runner | 25% | 12 | ×1.6 | 2.25–4.75 | 6 |
| Brute | 15% | 50 | ×0.55 | 3.9–8.0 | 14 |

State machine: IDLE → WANDER → CHASE → ATTACK.
- Max concurrent: 30. Spawn cooldown: 4s. Distance: 24–60 units from player.
- Valid terrain only. Despawn >120 units for >5s.

### Multiplayer
AI runs on host. Clients receive replicated state. Host authoritative for spawn/despawn.

## Collectibles
- 11 orbs at fixed positions. +10 score. Respawn 3–6s at random position.
- Host-only process; state synced via RPC.

## Safehouse & Crafting

### Space
Single room, 10×6×4m grid (1m³ cells). Blocks snap to grid.

### Workbenches
| Item | Purpose |
|---|---|
| Crafting Table | 3×3 recipe grid |
| Storage Chest | 64 inventory slots |
| Bed | Set spawn, skip night |
| Furnace | Smelt ore |
| Brewing Stand | Brew potions |
| Garden | Grow food |

### Resources
Wood, Stone, Scrap Metal, Gunpowder, Mushrooms, Alcohol

### Consumables
| Item | Recipe | Effect |
|---|---|---|
| Shield Injector | 2 Scrap Metal | Restore 50 shields |
| Biotic Surge | 1 Mushroom + 1 Gunpowder | -50% cooldowns 10s |
| Nightshade Potion | 1 Alcohol + 1 Mushroom | Invisibility 10s |

### Blocks
| Item | Recipe | Notes |
|---|---|---|
| Wood Block | 1 Wood | 2 hits |
| Stone Block | 1 Stone | 3 hits |
| Torch | 1 Wood + 1 Coal | Prevents spawn radius |
| Ladder | 3 Wood | Climbable |
| TNT | 4 Gunpowder + 1 Sand | Place + shoot to explode |

### Recipe Unlocks
| Recipe | Trigger |
|---|---|
| Shield Injector, Wood, Stone, Torch, Ladder | Default |
| TNT | Find Gunpowder |
| Furnace | Find 8 Stone |
| Bed | Find 3 Wood + 2 Scrap Metal |
| Biotic Surge | Find Mushroom + Gunpowder |
| Nightshade Potion | Find Alcohol + Mushroom |
| Brewing Stand | Find Alcohol |
| Garden | Find Water Bucket |

### Multiplayer
Safehouse, inventory, and upgrades are per-player. Crafting UI is local-only.

---

# Horde Mode (PvE)

## Core Loop
Defend a fixed position against escalating waves of enemies. Survive as long as you can. How many waves can you hold?

## Match Flow
1. Players spawn at a fixed position on a map (could be a Survival biome or a purpose-built arena).
2. Wave countdown begins (5s).
3. Enemies spawn in increasing numbers and difficulty.
4. Between waves: brief respite to reposition, use consumables, or upgrade.
5. On death: instant respawn at defend point. Match ends when all players are dead simultaneously or all enemies are defeated.

## Waves
| Wave | Enemies | Modifier |
|---|---|---|
| 1–5 | Shambler-heavy, low count | Baseline |
| 6–10 | Mix of Shambler/Runner, moderate count | Runner speed +10% |
| 11–15 | Brutes appear, mixed waves | Shambler health +25% |
| 16–20 | Full mix, high count | All enemies +15% damage |
| 21+ | Escalating. Every 5 waves: elite modifier | Random modifier per 5 waves |

### Elite Modifiers (every 5 waves)
- **Swift**: All enemies +30% speed
- **Armored**: All enemies +50% health
- **Swarm**: 2x enemy count, -30% health each
- **Brutal**: All enemies +25% health and damage

## Scoring
- Wave reached: wave number × 10 points
- Enemies killed: 1 point each
- No-damage waves: bonus 50 points

## Multiplayer
- Co-op (2–4 players). Shared position defense.
- AI runs on host. Same as Survival.

## What's NOT in Horde
- Exploration or procedural terrain (fixed arena)
- Safehouse or crafting (no time for it between waves)
- Day/night cycle (waves ARE the pacing)
- Progression or unlocks (clean slate per match)
- Collectibles

---

## Echo Zones (in Survival)

Echo Zones are mysterious ruins scattered across the Survival world. Enter, fight through rooms of enemies, defeat the boss, earn a new Ultimate.

### Flow
1. Discover an Echo Zone in the world.
2. Enter the zone. Procedurally generated interior (rooms, corridors, arenas).
3. Clear rooms of enemies to progress deeper.
4. Reach the boss room. Defeat the boss.
5. Boss drops a new Ultimate. Swap it into your loadout immediately.

### Echo Zone Tiers
| Tier | Enemies | Boss | Unlock |
|---|---|---|---|
| **Echo I** | Shambler/Runner mix, low density | Guardian (single elite enemy) | Default |
| **Echo II** | Mixed + Brutes, medium density | Warden (elite + minions) | Clear 1 Echo I |
| **Echo III** | Full mix, high density, elite modifiers | Herald (multi-phase boss) | Clear 1 Echo II |

### Boss Design (Examples)

#### Guardian (Echo I Boss)
- Large Shambler variant. High health, slow, telegraphed melee attacks.
- Summons 2–3 Shamblers periodically.
- Tests: sustained DPS, dodging, crowd control on adds.

#### Warden (Echo II Boss)
- Armored biped. Shielded (must break shield before health).
- Spawns Runner adds. Charges at players.
- Tests: burst damage, target prioritization.

#### Herald (Echo III Boss)
- Floating entity. Ranged projectiles + AoE attacks.
- Phases: shielded → exposed → enraged.
- Tests: everything — positioning, Overdrive timing, Ultimate usage.

### Echo Zone Rules
- One-time clears. Zone marked complete on map after boss kill.
- No loot loss on death. Respawn at zone entrance. Can retry boss.
- Boss reward (Ultimate) is guaranteed — not random.
- Materials and consumables found in the zone are kept regardless of death.
- Interior is always dark (no day/night cycle inside).

### Multiplayer
- Co-op (2–4 players). Shared boss reward.

---

# King of the Hill Mode (PvP)

## Zone
- Glowing ring/beam on terrain. Radius: 8 units.
- Points awarded while standing inside.

## Scoring
- **Solo** in zone: 1 point per second.
- **Contested** (2+ players in zone): no one scores.
- **Target**: first to 100 points wins. Timed match variant available.
- Players: 2–4. Free-for-all (no teams).

## Match Flow
1. Players load on the same flat arena map (not procedural terrain).
2. Zone activates after 5s countdown.
3. On death: instant respawn at edge of arena.
4. Match ends when a player reaches 100 points.

## Matchmaking (Quick-Play)

Single "Find KOTH Match" button. No lobby browser. Powered by EOS Lobbies.

### Flow
1. Player clicks "Find KOTH Match"
2. Client searches EOS lobbies with: mode="koth", status="waiting", player_count < 4, MMR range matching player's skill
3. Found → auto-join
4. Not found in 10s → auto-create lobby as host, rescan every 3s for joiners
5. Once 4 players accumulate → host starts match
6. Match ends → host writes wins/losses to EOS Stats → lobby disbands

### Skill Range Widening
| Time | ±MMR |
|---|---|
| 0–15s | 100 |
| 15–30s | 200 |
| 30–60s | 400 |
| 60s+ | No limit |

MMR is derived client-side from EOS Stats: `1000 + wins×25 − losses×25`. Trust-based — lying only makes matches harder.

### Lobby Attributes
| Key | Type | Purpose |
|---|---|---|
| mode | string | "koth" |
| status | string | "waiting" → "in_progress" |
| min_mmr | int | Lower skill bound |
| max_mmr | int | Upper skill bound |

### Member Attributes (per joiner)
| Key | Type | Purpose |
|---|---|---|
| mmr | int | Joiner's MMR (for host validation) |

### Post-Match
Host calls `EOS_Stats_IngestStat` for all players:
- Winner: koth_wins +1
- Losers: koth_losses +1
- All: koth_matches +1

## Shield Synergy
- Standing in zone: -0.5s regen delay.
- Every 10 points earned: +25 shields (one-time per threshold).

## Ability Multiplayer Notes
- Overdrive is personal (no effect on others).
- Ultimate abilities affect all players in range.
- Ability effects (displacement, slow, vulnerability) apply to other players.
- No hard CC on players — all crowd control is soft (slow, knockback, displacement, vulnerability).

## What's NOT in KOTH
- Zombies
- Day/night cycle (always day)
- Collectibles
- Safehouse or crafting
- Progression or unlocks — clean slate (all abilities available via loot, no carry-over from Survival)

---

# Arena Mode (PvP)

## Core Loop
FFA or team deathmatch. No objective. Just kills. Respawn on death.

## Scoring
- **FFA**: First to 30 kills wins. Timed variant (10 min, most kills wins).
- **Teams**: First team to 50 kills wins. 2v2 or 4v4.

## Match Flow
1. Players load on a map (same arenas as KOTH, or new deathmatch-specific maps).
2. Combat begins immediately. No countdown.
3. On death: instant respawn at random point.
4. Match ends when kill target is reached or time expires.

## Matchmaking
- Shares the same quick-play system as KOTH.
- "Find Match" button → searches for KOTH or Arena lobbies.
- Player can select preferred mode or "any."

## Loadouts
- Same ability loadout system as KOTH.
- Players spawn with their chosen loadout.
- Weapon pickups spawn on the map (Wingstick, grenades, etc.) — limited ammo, respawns after 30s.

## Maps
- Can reuse KOTH arenas (flat or terrain-based).
- Larger maps for 4v4 teams.
- No zone, no objective markers — pure combat space.

## What's NOT in Arena
- Zone, scoring zones, or objectives
- Zombies or PvE enemies
- Day/night cycle
- Safehouse, crafting, or progression
- Collectibles

---

# Battle Royale Mode (TBD)

PvP last-standing mode. Design phase — not yet implemented.

### Core Loop
1. Players drop onto procedural map (static terrain, no building persistence)
2. Loot weapons, abilities, consumables from scattered caches
3. Storm circle shrinks the playable area over time
4. Last player/squad standing wins

### Squad Options
- Solo
- Duo
- Squads (4 players)

### Storm
| Phase | Wait | Shrink Duration | Circle Diameter (start → end) | Damage/tick |
|---|---|---|---|---|
| 1 | 3 min | 2 min | 256 → 128 | 2 |
| 2 | 2 min | 1.5 min | 128 → 64 | 4 |
| 3 | 1.5 min | 1 min | 64 → 32 | 6 |
| 4 | 1 min | 45s | 32 → 16 | 10 |
| 5 | 45s | 30s | 16 → 0 | 15 |

### Loot
- Uncommon/rare weapons from floor loot and chests
- Abilities found as single-use pickups (activate once, replaced by next pickup) or permanent until death
- Consumables: shield injectors
- Ammo: found per weapon type

### Differences from Survival / KOTH
- No day/night cycle (storm replaces the clock pressure)
- No persistent building (unless Fortnite-style combat building is implemented)
- No safehouse or crafting bench
- Abilities are found, not unlocked
- Loot is randomized, not crafted

---

# Social (TBD)

Planned social features, all TBD:

- **Ping system**: Contextual radial menu — mark enemy, location, warning, request (Overwatch-inspired)
- **Scoreboard**: Tab key — kills, damage dealt, damage taken, healing, objective time (Overwatch-inspired)
- **Party system**: Invite friends before match, squad up, ready-up (Fortnite-inspired)
- **Player customization**: Avatar skins, accessories, emotes. Purchased (monetization).

---

# Progression (Survival Only)

Progression is discovery-driven, not XP-driven. No skill trees, no XP levels, no grind.

## Ability Progression

### Q and E Abilities (4 total, found in world)
| Ability | Slot | How Found |
|---|---|---|
| Pull | Q | World exploration |
| Singularity | Q | World exploration |
| Bend Time | Q | World exploration |
| Throw | E | World exploration |
| Warp | E | World exploration |
| Dark Vision | E | World exploration |

- Found = unlocked permanently.
- Once equipped, fixed. Cannot be changed.

### Ultimates (4 total, earned from bosses)
| Ultimate | Boss |
|---|---|
| Charge/Nova | Starting ultimate |
| Overdrive Surge | Echo I boss (Guardian) |
| Orbital Strike | Echo II boss (Warden) |
| Absorption Field | Echo III boss (Herald) |

- Earned by defeating Echo Zone bosses.
- Can be swapped at boss fights only.

## Weapon Progression
- **Bow**: Found in world. Craft at crafting table from materials.
- **Sword**: Found in world. Craft at crafting table from materials.
- **Wingstick**: Found in world. Craft at crafting table from materials.

## Building
- Harvest materials, craft blocks. Base data stored in EOS blob.

## Cosmetic Progression
- Base skins, character clothes, emotes — purchased, not crafted.

Progression does not cross modes — KOTH, Arena, Horde, and Battle Royale are clean slates (all abilities/weapons found as in-match loot).

---

# Data Storage & Persistence

## Survival (PvE)
| Data | Store | Authority | Notes |
|---|---|---|---|
| Abilities, weapon schematics, materials, base blocks, echo_zones_cleared, bosses_killed | EOS Player Data Storage | Player-authoritative | Single JSON blob. PvE — tampering doesn't matter. |
| World state | Host memory | Host | Generated from seed, discarded |

Save triggers: bed sleep, manual save, on quit, periodic autosave (60s).

## KOTH (PvP)
| Data | Store | Authority | Notes |
|---|---|---|---|
| Match state (positions, scores, health) | Host memory | Host | Ephemeral — discarded on match end |
| Wins, losses, matches played | EOS Stats | Host writes (IngestStat) | Used for MMR + leaderboards |

## Horde (PvE)
| Data | Store | Authority | Notes |
|---|---|---|---|
| Match state (wave, enemies, player positions) | Host memory | Host | Ephemeral — discarded on match end |
| Score (waves, kills) | EOS Stats | Host writes (IngestStat) | Used for leaderboards |

## Arena (PvP)
| Data | Store | Authority | Notes |
|---|---|---|---|
| Match state (positions, kills, health) | Host memory | Host | Ephemeral — discarded on match end |
| Wins, kills, matches played | EOS Stats | Host writes (IngestStat) | Used for MMR + leaderboards |

## Battle Royale (TBD)
| Data | Store | Authority | Notes |
|---|---|---|---|
| Match state (positions, loot, storm, health) | Host memory | Host | Ephemeral — discarded on match end |
| Wins, kills, matches played | EOS Stats | Host writes (IngestStat) | Leaderboards |

## EOS Service Map
| Service | BattleOx Use |
|---|---|
| Connect | Player authentication (Device ID dev, Epic Account prod) |
| Lobbies | KOTH + Arena + Battle Royale match discovery + lifecycle |
| P2P | In-game multiplayer transport |
| Stats | KOTH + Arena + Battle Royale win/loss/kill tracking |
| Leaderboards | KOTH + Arena + Battle Royale ranking display |
| Player Data Storage | Survival save/load |
