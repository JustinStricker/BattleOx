# Project Plan

## Day/Night Cycle

- **Visuals**: Sun position drives sky colors, ambient light, and fog. Moon + stars appear at night. Smooth transitions between day and night phases.
- **Gameplay impact**: Zombie behavior changes at night — increased speed, aggro range, and spawn rate. New night-specific zombie types (volatiles) that are faster and more dangerous.
- **UI**: Sun/moon icon indicating time of day. Warning flash during dusk/dawn transitions.
- **Shields synergy**: Night reduces shield regen delay to 2s and increases regen rate to 35/sec.

## Shields

- Shields are a regenerative damage buffer above health
- Base capacity: 150 shields
- Regenerates automatically after 3 seconds of not taking damage
- Regeneration rate: 25 shields per second
- Taking damage resets the regen delay
- Shields break screen flash and sound cue
- Charge ability restores 50 shields on impact
- Shield Injector (crafted) restores 50 shields instantly
- Kill a Volatile at night restores 25 shields

## King of the Hill Mode

- **Zone**: A marked area on the terrain (glowing ring/beam) that the player must stand in to score points.
- **Scoring**: Points accumulate while the player is inside the zone. Score target to win (e.g. first to 100) or endless survival variant.
- **Zombie behavior**: Zombies are attracted to the hill zone, creating waves of enemies as the player holds position.
- **UI**: Score progress bar, current points, zone status indicator.
- **Shields synergy**: Standing in the zone reduces regen delay by 0.5s. Every 10 Hill points earned restores 25 shields.

## Mass Effect Biotics

### Powers
- **Pull** — lift enemy toward you
- **Throw** — fling lifted enemy away
- **Warp** — damage + armor shred
- **Singularity** — gravity well area denial
- **Charge** — lunge forward, impact damage + shields
- **Nova** — AoE ground pound (normally costs shields)
- **Bend Time** — slow-motion field
- **Dark Vision** — see enemies through walls

### Cooldown system
- Each power has a shared or individual cooldown. Ammo/energy pickups can reset or reduce cooldowns.

### Upgrade Tree (Echo Shards)
- Permanent upgrades purchased with Echo Shards. Each biotic has 4 tiers.
- Tier 1: 3-5 shards | Tier 2: 5-8 shards | Tier 3: 7-10 shards | Tier 4 (capstone): 10-15 shards

| Power | Tier 1 | Tier 2 | Tier 3 | Tier 4 |
|---|---|---|---|---|
| Pull | Range | Multi-target | Bonus airborne damage | Volatile stagger |
| Throw | Projectile speed | AoE knockback | Fall damage | Double projectile |
| Warp | Damage | Armor shred duration | Damage over time | Detonates combos |
| Singularity | Radius | Duration | Damage over time | Pulls Volatiles |
| Charge | Range | Stun duration | Shield restore amount | Chain to multiple enemies |
| Nova | Radius | Damage | Knockback distance | No shield requirement |
| Bend Time | Duration | Player speed | Recharge rate | Cooldown freeze |
| Dark Vision | Duration | Reveals loot crates | Reveals health bars | Extra charge |

### UI
- Power radial wheel or hotbar. Cooldown indicators, active effect timers.

### Visuals
- Blue biotic glow on character, distortion effects on lifted enemies, particle trails on projectiles.

### Synergy with existing systems
- Biotic powers affect zombies differently at night (e.g. Singularity lasts longer but more zombies spawn). Use Pull/Throw to knock zombies off the King of the Hill zone.

## Safehouse Crafting System

- Single-room safehouse with buildable zones
- **Crafting Table** (default) — 3x3 grid for crafting
- **Storage Chest** (default) — 64 slots
- **Upgrade Altar** (default) — spend Echo Shards on biotic upgrades
- **Bed** (craftable) — set spawn point, skip night
- **Furnace** (craftable) — smelt ore into metal
- **Enchanting Table** (find + craft) — permanent enchantments
- **Brewing Stand** (craftable) — brew potions
- **Garden** (craftable) — grow renewable food

### Basic resources
Wood, Stone, Cloth, Scrap Metal, Echo Shards, Gunpowder, Mushrooms, Diamond, Alcohol

### Craftable consumables
| Item | Recipe | Effect |
|---|---|---|
| Bandage | 2 Cloth | Heal 25 HP |
| Medkit | 3 Cloth + 1 Alcohol | Heal 75 HP |
| Shield Injector | 2 Scrap Metal + 1 Echo Shard | Restore 50 shields |
| Shield Capacitor | 3 Scrap Metal + 2 Echo Shards | +25 max shields next hold |
| Biotic Surge | 1 Echo Shard + 1 Mushroom | Reduce cooldowns 50% for 10s |
| Nightshade Potion | 1 Echo Shard + 1 Mushroom | Invisibility for 10s |

### Craftable blocks
| Item | Recipe | Notes |
|---|---|---|
| Wood Block | 1 Wood | 2 hits to break |
| Stone Block | 1 Stone | 3 hits to break |
| Torch | 1 Wood + 1 Coal | Prevents spawns |
| Ladder | 3 Wood | Climbable |
| TNT | 4 Gunpowder + 1 Sand | Place and shoot to explode |

## Progression Systems

### Biotic unlocks (start with Pull only)
| Power | Unlock condition |
|---|---|
| Throw | Complete first Hill hold |
| Warp | Kill 5 Volatiles |
| Singularity | Survive 3 night cycles |
| Charge | Complete hold with shields breaking <3 times |
| Nova | Kill 3 enemies with one Throw |
| Bend Time | Reach 500 total Hill points |
| Dark Vision | Find scroll in Echo Cache |

### Enchantment unlocks (find Tomes in Echo Zones)
| Enchant | Effect |
|---|---|
| Shield Capacity I/II/III | Increase max shields |
| Rapid Regen | Increase regen rate |
| Quick Restore | Reduce regen delay |
| Charge Buffer | Charge restores more shields |
| Volatile Leech | Killing Volatiles restores shields |
| Hill Conduit | Double regen rate in Hill |

### Recipe unlocks (automatic when ingredients found)
| Recipe | Trigger |
|---|---|
| Bandage, Medkit, Shield Injector, Wood Block, Stone Block, Torch, Ladder | Default (unlocked at start) |
| TNT | Find Gunpowder |
| Furnace | Find 8 Stone |
| Bed | Find 3 Wood + 2 Cloth |
| Shield Capacitor | Unlock Charge |
| Biotic Surge | Find Echo Shard + Mushroom |
| Nightshade Potion | Complete a no-damage hold |
| Enchanting Table (craft more) | Find one Enchanting Table |
| Brewing Stand | Kill a Volatile with a biotic power |
| Garden | Find Water Bucket |
