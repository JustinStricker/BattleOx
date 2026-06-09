# Gameplay Specification

## Modes

Two distinct modes share core systems (shields, biotics, combat):

- **Survival** — PvE. Day/night cycle, zombie waves, collectibles, safehouse crafting, biotic progression.
- **King of the Hill** — PvP. 2–4 players compete for zone control.

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

## Biotics

Cooldowns: per-power (not shared). Base: 12s unless noted.

| Power | Description | Unlock | Cooldown |
|---|---|---|---|
| Pull | Lift enemy toward you | Default | 8s |
| Throw | Fling lifted enemy away | Complete first Hill hold | 6s |
| Warp | Damage + 1.5x vulnerability | Kill 5 Volatiles | 10s |
| Singularity | Gravity well area denial | Survive 3 night cycles | 20s |
| Charge | Lunge forward, impact + shields | Shields break <3 times in a hold | 10s |
| Nova | AoE ground pound (costs 50 shields) | Kill 3 enemies with one Throw | 8s |
| Bend Time | Slow-motion field, 5s | Reach 500 Hill points | 30s |
| Dark Vision | See enemies through walls, 8s | Scroll in Echo Cache | 25s |

Upgrade tree (4 tiers per power, purchased with Echo Shards):

| Power | Tier 1 | Tier 2 | Tier 3 | Tier 4 |
|---|---|---|---|---|
| Pull | Range | Multi-target | Bonus airborne damage | Volatile stagger |
| Throw | Projectile speed | AoE knockback | Fall damage | Double projectile |
| Warp | Damage | Vulnerability duration | Damage over time | Detonates combos |
| Singularity | Radius | Duration | Damage over time | Pulls Volatiles |
| Charge | Range | Stun duration | Shield restore amount | Chain to multiple enemies |
| Nova | Radius | Damage | Knockback distance | No shield requirement |
| Bend Time | Duration | Player speed | Recharge rate | Cooldown freeze |
| Dark Vision | Duration | Reveals loot crates | Reveals health bars | Extra charge |

### Multiplayer
- Independent cooldowns per player
- Effects sync via RPCs. Server validates Charge shield restore and Nova shield cost.

---

## Combat

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

### Multiplayer (Both Modes)
Host is authoritative. Clients send inputs; host validates cooldowns, runs hit checks, broadcasts results. Arrows spawned by host only.

---

# Survival Mode (PvE)

## Core Loop
Explore procedurally-generated terrain → fight zombie waves → complete Hill hold → survive night → craft upgrades → unlock new biotic powers → repeat with escalating difficulty.

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

## Biotic Multiplayer Notes
- Pull/Throw work on other players (physics-driven, same as enemies).
- Charge damages and stuns other players.
- Nova hits all players in radius.
- Bend Time slows all other players.
- Singularity pulls all players in range.

## What's NOT in KOTH
- Zombies, Volatiles
- Day/night cycle (always day)
- Collectibles
- Safehouse or crafting
- Progression or unlocks — all 8 biotics available by default (clean slate, no carry-over from Survival)
- Enchantments

---

# Progression (Survival Only)

Biotic powers unlock via Survival achievements. Earn Echo Shards to upgrade them. Enchantments found in Echo Zone Tomes. Progression does not cross modes — KOTH is a clean slate with all 8 biotics available by default.

---

# Data Storage & Persistence

## Survival (PvE)
| Data | Store | Authority | Notes |
|---|---|---|---|
| Inventory, safehouse, upgrades, enchantments, biotic progress | EOS Player Data Storage | Player-authoritative | PvE — tampering doesn't matter |
| World state | Host memory | Host | Generated from seed, discarded |

Save triggers: bed sleep, manual save, on quit, periodic autosave (60s).

## KOTH (PvP)
| Data | Store | Authority | Notes |
|---|---|---|---|
| Match state (positions, scores, health) | Host memory | Host | Ephemeral — discarded on match end |
| Wins, losses, matches played | EOS Stats | Host writes (IngestStat) | Used for MMR + leaderboards |

## EOS Service Map
| Service | BattleOx Use |
|---|---|
| Connect | Player authentication (Device ID dev, Epic Account prod) |
| Lobbies | KOTH match discovery + lifecycle |
| P2P | In-game multiplayer transport |
| Stats | KOTH win/loss tracking |
| Leaderboards | KOTH ranking display |
| Player Data Storage | Survival save/load |
