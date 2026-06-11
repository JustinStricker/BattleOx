# Gameplay Specification

## Modes

Modes share core systems (shields, abilities, combat, tool system):

- **Survival** — PvE. Day/night cycle, zombie waves, collectibles, safehouse crafting, ability progression.
- **King of the Hill** — PvP. 2–4 players compete for zone control.
- **Battle Royale (TBD)** — PvP. Last-standing, storm circle, loot drops. Design phase.

---

# Core Systems (Both Modes)

## Shields

Regenerative damage buffer above health.
- Base capacity: 150 shields. Regen delay: 3s. Regen rate: 25/s.
- Damage hits shields first; overflow passes to health.
- Screen flash + sound cue on shield break. Shield bar in HUD.

### Synergies
| Trigger | Effect | Mode |
|---|---|---|
| Night | delay → 2s, rate → 35/s | Survival |
| KOTH zone | delay reduced by 0.5s | KOTH |
| Charge ability | restore 50 shields on impact | Both |
| Shield Injector (crafted) | restore 50 shields instantly | Survival |
| Volatile kills at night | restore 25 shields | Survival |
| Every 10 Hill points | restore 25 shields | KOTH |
| Nova | costs 50 shields (unavailable below 50, unless upgraded) | Both |

### Enchantments (Tomes in Echo Zones)
| Enchant | Effect |
|---|---|
| Shield Capacity I/II/III | +25/+50/+75 max shields |
| Rapid Regen | +10/s regen rate |
| Quick Restore | -1s regen delay |
| Charge Buffer | Charge restores +25 more shields |
| Volatile Leech | Volatile kills restore +25 more shields |
| Hill Conduit | 2x regen rate in Hill zone |

Enchantments are Survival-only. KOTH is a clean slate.

---

## Abilities

Replaces the earlier Biotics system. Broader ability framework drawing from Overwatch (cooldown loadout + ultimate), Mass Effect (primer/detonator combos), and RAGE (Overdrive).

### Loadout System

Players build a custom ability loadout from a pool of abilities, assigned to hotkey slots:

| Slot | Binding | Type | Cooldown Range |
|---|---|---|---|
| Ability 1 | Q (or Shift) | Movement / utility | 6–10s |
| Ability 2 | E | Combat / control | 8–14s |
| Overdrive | Shift (or side button) | Personal steroid | ~15s cooldown, ~6s duration |
| Ultimate | F | High-impact heroic moment | Builds via combat damage |

- Overdrive is separate from Ultimate: a short-lived damage/speed/regen burst rather than a big projectile.
- Ultimate charge builds at 2% per damage point dealt (keep existing system).
- Abilities can be found as schematics in the world (RAGE-style discovery) rather than earned via XP.
- **TBD**: Ability trees vs pick-from-global-pool vs hybrid.

### Primer / Detonator Combos (Mass Effect)

Some abilities apply a status effect (primer), others trigger it for bonus damage (detonator):

| Primer | Applied By | Detonator Effect |
|---|---|---|
| Lifted | Pull, Singularity | Throw → bonus fall damage, AoE knockback |
| Warped | Warp, certain weapon mods | Any damage → +50% vulnerability |
| Frozen | Cryo weapon mod | Shatter → AoE burst, bonus damage |
| Stunned | Charge, Overdrive melee | Any damage → +25% bonus |

- Combo-aware loadout building is a skill layer.
- Tooltips show which abilities combo with each other.

### Overdrive (RAGE)

Temporary combat steroid:
- Activation: Manual when bar is full (builds through dealing/taking damage, kills)
- Duration: ~6s
- Effects: +30% damage, +20% move speed, health regen, empowered melee
- Cooldown: ~15s after Overdrive ends (separate from ability cooldowns)
- Feels like a berserker mode — short enough to require timing, frequent enough to use every encounter.

### Ultimate

Keep the existing system: builds via combat damage (2% per damage point), press F to activate. The current Charge/Nova becomes one possible Ultimate. Future ultimates could include:
- **Overdrive Surge**: Enter a superior Overdrive state (doubled effects, longer duration)
- **Orbital Strike**: Call down a targeted AoE barrage
- **Absorption Field**: Create a zone that drains enemy shields and restores ally shields
- **Mass Singularity**: Pull all enemies in a large radius to a single point, then detonate

### Known Biotics Legacy

The existing 8 biotics (Pull, Throw, Warp, Singularity, Charge, Nova, Bend Time, Dark Vision) are candidates for rework into the ability pool and upgrade tree system. Charge and Nova are partially implemented. Their status:

| Power | Fate |
|---|---|
| Charge, Nova | Re-evaluate as Ultimate candidates or individual abilities |
| Pull, Throw | Keep as primer/detonator pair |
| Warp | Keep as vulnerability primer |
| Singularity, Bend Time, Dark Vision | Deferred — revisit after ability system redesign

---

## Combat

### Weapon Design (RAGE-Inspired)

Each weapon is a unique tool (not a stat tier). Weapons are found as schematics in the world and require specific materials to craft/upgrade.

Every weapon has:
- **Primary fire** — the main attack
- **Alternate fire** — a distinct secondary mode (not just zoom)
- **Rarity** (TBD) — Common / Uncommon / Rare / Legendary variants with passive modifiers

| Weapon | Primary | Alt-Fire | Inspiration |
|---|---|---|---|
| Wingstick (TBD) | Thrown, bounces between targets | Remote detonate | RAGE |
| Bow (existing) | Charge shot | (keep existing) | Existing |
| Sword (existing) | Dash-slash combo | (keep existing) | Existing |
| Assault Rifle (TBD) | Full-auto | Armor-piercing rounds | RAGE / Mass Effect |
| Shotgun (TBD) | Spread | Slug / focused | RAGE |
| Sniper (TBD) | Precision shot | Thermal / penetrator | RAGE |
| Rocket Launcher (TBD) | Explosive | Manual detonate | Mass Effect |

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

### Overdrive (RAGE)
| Property | Value |
|---|---|
| Charge source | Dealing/taking damage, kills |
| Duration | ~6s |
| Damage bonus | +30% |
| Speed bonus | +20% |
| Regen | Health regen during Overdrive |
| Cooldown | ~15s (starts after duration ends) |
| Effects | Empowered melee, screen FX, sound cue |
| Note | Separate from Ultimate — shorter, more frequent |

### Multiplayer (Both Modes)
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
- Assault Rifle, Shotgun, Sniper, Rocket Launcher
- Consumables (bandage, shield injector, etc.)
- Building hammer / blueprint tool
- Grappling hook (potential)

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
Explore procedurally-generated terrain → fight zombie waves → complete Hill hold → survive night → craft upgrades → discover new abilities and schematics → repeat with escalating difficulty.

## Day/Night Cycle
- Full cycle: 12 min (8 day, 4 night). Transitions: 30s each.
- Visual: sun position drives sky colors, light, fog. Moon + stars at night.
- Night: zombies +30% speed, 2x aggro, 3x spawn rate. Volatiles spawn.
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
| Upgrade Altar | Spend Echo Shards on biotic upgrades |
| Bed | Set spawn, skip night |
| Furnace | Smelt ore |
| Enchanting Table | Apply enchantments (first found in Echo Zone) |
| Brewing Stand | Brew potions |
| Garden | Grow food |

### Resources
Wood, Stone, Cloth, Scrap Metal, Echo Shards, Gunpowder, Mushrooms, Diamond, Alcohol

### Consumables
| Item | Recipe | Effect |
|---|---|---|
| Bandage | 2 Cloth | Heal 25 HP |
| Medkit | 3 Cloth + 1 Alcohol | Heal 75 HP |
| Shield Injector | 2 Scrap Metal + 1 Echo Shard | Restore 50 shields |
| Shield Capacitor | 3 Scrap Metal + 2 Echo Shards | +25 max shields next hold |
| Biotic Surge | 1 Echo Shard + 1 Mushroom | -50% cooldowns 10s |
| Nightshade Potion | 1 Echo Shard + 1 Alcohol | Invisibility 10s |

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
| Bandage, Medkit, Shield Injector, Wood, Stone, Torch, Ladder | Default |
| TNT | Find Gunpowder |
| Furnace | Find 8 Stone |
| Bed | Find 3 Wood + 2 Cloth |
| Shield Capacitor | Unlock Charge |
| Biotic Surge | Find Echo Shard + Mushroom |
| Nightshade Potion | Complete a no-damage hold |
| Enchanting Table | Find one in Echo Zone |
| Brewing Stand | Kill Volatile with a biotic power |
| Garden | Find Water Bucket |

### Multiplayer
Safehouse, inventory, and upgrades are per-player. Crafting UI is local-only.

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
3. On death: respawn at edge of arena after 3s.
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
- Hill Conduit enchantment works here (2x regen rate in zone).

## Ability Multiplayer Notes
- Primer/detonator combos work on other players (same as enemies).
- Overdrive is personal (no effect on others).
- Ultimate abilities affect all players in range.
- Specific ability effects (lift, stun, slow) apply to other players.

## What's NOT in KOTH
- Zombies, Volatiles
- Day/night cycle (always day)
- Collectibles
- Safehouse or crafting
- Progression or unlocks — clean slate (all abilities available via loot, no carry-over from Survival)
- Enchantments

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
- Consumables: shield injectors, bandages, medkits
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
- **Player customization**: Avatar skins, accessories, emotes (Roblox-inspired). Earned via achievements or found in-world.

---

# Progression (Survival Only)

Progression is discovery-driven, not XP-driven. No skill trees, no XP levels, no biome gates.

- **Ability schematics**: Found in the world (Echo Zones, boss drops, hidden caches). Found = unlocked permanently.
- **Weapon schematics**: Found in the world. Craft weapons at the crafting table from materials.
- **Echo Shards**: Single currency. Spent on upgrades at the Upgrade Altar.
- **Enchantments**: Found as Tomes in Echo Zones. Passive shield modifiers.
- **Building blocks**: Harvest materials, craft blocks. Base data stored in EOS blob.

Progression does not cross modes — KOTH and Battle Royale are clean slates (all abilities/weapons found as in-match loot).

---

# Data Storage & Persistence

## Survival (PvE)
| Data | Store | Authority | Notes |
|---|---|---|---|
| Schematics, enchantments, materials, base blocks, Echo Shards | EOS Player Data Storage | Player-authoritative | Single JSON blob. See TECH.md for schema. PvE — tampering doesn't matter. |
| World state | Host memory | Host | Generated from seed, discarded |

Save triggers: bed sleep, manual save, on quit, periodic autosave (60s).

## KOTH (PvP)
| Data | Store | Authority | Notes |
|---|---|---|---|
| Match state (positions, scores, health) | Host memory | Host | Ephemeral — discarded on match end |
| Wins, losses, matches played | EOS Stats | Host writes (IngestStat) | Used for MMR + leaderboards |

## Battle Royale (TBD)
| Data | Store | Authority | Notes |
|---|---|---|---|
| Match state (positions, loot, storm, health) | Host memory | Host | Ephemeral — discarded on match end |
| Wins, kills, matches played | EOS Stats | Host writes (IngestStat) | Leaderboards |

## EOS Service Map
| Service | BattleOx Use |
|---|---|---|
| Connect | Player authentication (Device ID dev, Epic Account prod) |
| Lobbies | KOTH + Battle Royale match discovery + lifecycle |
| P2P | In-game multiplayer transport |
| Stats | KOTH + Battle Royale win/loss/kill tracking |
| Leaderboards | KOTH + Battle Royale ranking display |
| Player Data Storage | Survival save/load |
