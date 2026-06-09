# Gameplay Specification

## Core Loop

Explore procedurally-generated terrain → fight zombie waves → hold the Hill for points → survive the night → craft upgrades → unlock new biotic powers → repeat with escalating difficulty.

---

## Shields

### Core Mechanics
- Regenerative damage buffer above health
- Base capacity: 150 shields
- Regen delay: 3s (resets on damage)
- Regen rate: 25/s
- Damage hits shields first; overflow passes to health

### Feedback
- Screen flash + sound cue on shield break
- Shield bar in HUD

### Synergies
| Trigger | Effect |
|---|---|
| Night | delay → 2s, rate → 35/s |
| KOTH zone | delay reduced by 0.5s |
| Charge ability | restore 50 shields on impact |
| Shield Injector (crafted) | restore 50 shields instantly |
| Volatile kills at night | restore 25 shields |
| Every 10 Hill points | restore 25 shields |
| Nova | costs 50 shields (unavailable below 50, unless upgraded) |

### Enchantments (Tomes in Echo Zones)
| Enchant | Effect |
|---|---|
| Shield Capacity I/II/III | +25/+50/+75 max shields |
| Rapid Regen | +10/s regen rate |
| Quick Restore | -1s regen delay |
| Charge Buffer | Charge restores +25 more shields |
| Volatile Leech | Volatile kills restore +25 more shields |
| Hill Conduit | 2x regen rate in Hill zone |

---

## Day/Night Cycle

### Timing
- Full cycle: 12 minutes (8 min day, 4 min night)
- Transitions: 30s dusk, 30s dawn

### Visuals
- Sun position drives sky colors, ambient light, fog
- Moon + stars at night

### Gameplay Impact
- Night: zombies +30% speed, 2x aggro range, 3x spawn rate
- Night spawns Volatiles (faster, +50% damage, more dangerous)
- Shield synergy: faster regen at night

### UI
- Sun/moon icon
- Dusk/dawn warning flash

---

## King of the Hill

### Zone
- Glowing ring/beam on terrain
- Player must stand inside to score
- Zone radius: 8 units

### Scoring
- 1 point per second in zone
- Target: 100 points (endless survival variant available)
- **Multiplayer**: each player scores independently; no friendly fire

### Zombie Behavior
- Zombies path toward zone center (not the player)
- If player leaves zone, zombies stay at the zone
- Waves trigger every 15s while zone is occupied
- Wave size: starts at 3, +1 each wave, caps at 15

### Difficulty Scaling (Multiplayer)
- Base spawn rate × (1 + 0.5 per additional player)

### UI
- Score progress bar, current points, zone indicator

### Shield Synergy
- -0.5s regen delay while in zone
- Every 10 points: +25 shields (once per threshold)

---

## Biotics

Cooldowns are per-power (not shared). Base cooldown: 12s unless noted.

### Powers
| Power | Description | Unlock | Cooldown |
|---|---|---|---|
| Pull | Lift enemy toward you | Default | 8s |
| Throw | Fling lifted enemy away | Complete first Hill hold | 6s |
| Warp | Damage enemy + applies 1.5x vulnerability | Kill 5 Volatiles | 10s |
| Singularity | Gravity well, pulls nearby enemies | Survive 3 night cycles | 20s |
| Charge | Lunge forward, impact damage + shields | Hold with shields breaking <3 times | 10s |
| Nova | AoE ground pound (costs 50 shields) | Kill 3 enemies with one Throw | 8s |
| Bend Time | Slow-motion field, 5s duration | Reach 500 Hill points | 30s |
| Dark Vision | See enemies through walls, 8s duration | Find scroll in Echo Cache | 25s |

### Upgrade Tree (Echo Shards)
Each power has 4 tiers. Permanent upgrades purchased with Echo Shards.

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

### Visuals
- Blue biotic glow on character
- Distortion effects on lifted enemies
- Particle trails on projectiles

### Multiplayer
- Each player has independent cooldowns
- Biotic effects sync via RPCs
- Server validates shield restore/cost for Charge and Nova

---

## Combat

### Bow
| Property | Value |
|---|---|
| Charge time | 0.15–2.0s (hold LMB) |
| Arrow speed | 15–55 m/s (scales with charge) |
| Damage | 25 |
| Cooldown | 0.5s between shots |
| Visual | String pull animation, shake at full charge |

### Sword (Dash-Slash)
| Property | Value |
|---|---|
| Trigger | RMB or Shift |
| Cooldown | 1.5s |
| Damage | 25 |
| Cone | 75° half-angle, 8m range |
| Dash speed | 60 m/s for 0.25s |
| Animation | 3-phase: draw → slash → sheathe |

### Multiplayer
- Host is authoritative for all combat
- Clients send input requests; host validates cooldowns, runs hit checks, broadcasts
- Arrows spawned by host only; client-side visual replicas optional

---

## Enemies

### Zombie Types
| Type | Weight | Health | Speed | Size | Damage |
|---|---|---|---|---|---|
| Shambler | 60% | 20 | ×1.0 | 3.0–5.0 | 8 |
| Runner | 25% | 12 | ×1.6 | 2.25–4.75 | 6 |
| Brute | 15% | 50 | ×0.55 | 3.9–8.0 | 14 |

### State Machine
```
IDLE → WANDER → CHASE → ATTACK
```
- **IDLE**: faces player, breathes/sways
- **WANDER**: moves to random point within 8 units
- **CHASE**: 0.2s pause, then pursues. Requires line-of-sight.
- **ATTACK**: 1.2s cooldown between hits

### Spawning
| Property | Value |
|---|---|
| Max concurrent | 30 |
| Spawn cooldown | 4s |
| Spawn distance | 24–60 units from player |
| Valid terrain | Not ocean, mountain, blocked, or steep |
| Despawn | >120 units for >5s |

### Multiplayer
- AI runs on host only
- Clients receive replicated state via MultiplayerSynchronizer
- Host is authoritative for all spawn/despawn

---

## Collectibles

| Property | Value |
|---|---|
| Count | 11 orbs at fixed positions |
| Score | +10 per collect |
| Respawn | 3–6s at random position (±20×±30 units) |
| Visual | Rotating, hovering, pulsing glow |

**Multiplayer**: host-only process; state synced via RPC.

---

## Safehouse & Crafting

### Space
Single room, 10×6×4 meter grid (1m³ cells). Blocks snap to the grid.

### Default Workbenches
| Item | Purpose |
|---|---|
| Crafting Table | 3×3 grid for recipes |
| Storage Chest | 64 inventory slots |
| Upgrade Altar | Spend Echo Shards on biotic upgrades |

### Craftable Workbenches
| Item | Purpose |
|---|---|
| Bed | Set spawn point, skip night |
| Furnace | Smelt ore into metal |
| Enchanting Table | Apply enchantments (first one found in Echo Zone) |
| Brewing Stand | Brew potions |
| Garden | Grow renewable food |

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
| Wood Block | 1 Wood | 2 hits to break |
| Stone Block | 1 Stone | 3 hits to break |
| Torch | 1 Wood + 1 Coal | Prevents spawns in radius |
| Ladder | 3 Wood | Climbable |
| TNT | 4 Gunpowder + 1 Sand | Place and shoot to explode |

### Recipe Unlocks
| Recipe | Trigger |
|---|---|
| Bandage, Medkit, Shield Injector, Wood Block, Stone Block, Torch, Ladder | Default |
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
- Safehouse, inventory, and upgrades are per-player (not shared)
- Crafting UI is local-only
