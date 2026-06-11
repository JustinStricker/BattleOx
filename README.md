# BattleOx — Godot 4.6 Open-World Action Game

A procedurally generated open-world action game blending ability-driven combat (Overwatch loadouts + RAGE gunplay + Mass Effect combos), sandbox creativity (Minecraft/Roblox/Fortnite), and competitive PvP modes. Built in **Godot 4.6** with **Jolt Physics**.

---

## Quick Facts

| Property | Value |
|---|---|
| **Engine** | Godot 4.6 |
| **Physics** | Jolt Physics |
| **Renderer** | Forward Plus |
| **Main Scene** | `res://bootstrap.tscn` |
| **Input** | Keyboard + Mouse |
| **Dependencies** | None (pure Godot + EOS GDExtension) |

---

## Implemented

**Player** — WASD movement, mouse look, charge jump (hold Space), roll dash (double-tap WASD, 3 charges), dash-slash (Shift/Right Click). Procedural energy wings with spring-animated charge assist. 100 HP with invincibility window on hit.

**Weapons** — Bow (hold/release LMB, charge 0.15–2.0s, arrow speed 15–55 m/s, 25 damage), Sword (3-phase iaijutsu slash, cone hit 75°×8m, 25 damage, 1.5s cooldown), Ultimate (builds via damage dealt, press F to fire energy beam). All camera-attached with fully procedural meshes.

**Enemies** — 3 types (Dire Wolf, Wraith, Stone Golem) with component-based AI: AIStateMachine (IDLE→WANDER→CHASE→ATTACK), PerceptionComponent (LOS raycast), HealthComponent, MovementComponent. Skeleton3D system with bone animation, IK foot placement (FootPlacementModifier3D), ragdoll death. Procedural hit FX and death explosions. Weighted spawn manager (60 max, 2s cooldown, 16–60 unit range).

**World** — Perlin FBM terrain, 5 biomes (Ocean, Meadows, Black Forest, Swamp, Mountain), chunk-based generation with threaded loading (WorkerThreadPool), procedural villages (8 blueprint types with collision/lights/particles), animated water (Gerstner waves, depth color, foam), wind-driven foliage, FBM cloud billboards, day/night cycle with ProceduralSkyMaterial + SSAO + ACES tonemapping.

**Multiplayer** — LAN listen-server via ENet. Server-authoritative player movement with input forwarding, MultiplayerSynchronizer for enemies, world seed sync (deterministic generation), combat RPCs. EOS transport ready for swap.

**Audio** — All sounds procedurally generated (SoundGenerator + AudioManager). Chiptune-style music (ChiptuneGenerator + MusicManager). No imported assets.

**UI** — Crosshair (custom drawn), ability bar (4 slots with cooldown curtains, charge bars, recharge arcs), score display, loading screen with progress phases.

---

## Status

- **Implemented**: See above. Full Survival PvE mode playable. LAN multiplayer working.
- **In progress**: EOS Integration (Phase 4a–4e). See `docs/STATUS.md` for full build order.
- **Design phase**: Ability loadout system, RAGE weapon overhaul, Tool system, Battle Royale, building, social features. See `docs/SPEC.md` and `docs/INSPIRATIONS.md`.

| Doc | Answers |
|---|---|
| `docs/DESIGN.md` | Design pillars and philosophy |
| `docs/SPEC.md` | Full gameplay specification |
| `docs/TECH.md` | Architecture, networking, EOS |
| `docs/STATUS.md` | Build order and project status |
| `docs/INSPIRATIONS.md` | Source material reference |

---

## Project Structure

```
res://
├── bootstrap.tscn / bootstrap.gd   # Entry point
├── project.godot                    # Engine config
├── src/
│   ├── modes/                       # Game modes (survival.gd)
│   ├── player/                      # Player, bow, sword, ultimate, wings
│   ├── enemy/                       # Component-based enemy system
│   │   ├── components/              # AIStateMachine, Health, Perception, Movement, IK
│   │   ├── skeletons/               # DireWolf, Wraith, StoneGolem
│   │   ├── effects/                 # Hit FX, Death Explosion
│   │   └── resources/               # EnemyType resource files
│   ├── enemies/enemy_manager.gd     # Spawner (legacy naming, active)
│   ├── world/                       # World generation, environment, chunks
│   ├── network/                     # NetworkManager (ENet + EOS transport)
│   ├── audio/                       # Procedural audio generation
│   ├── ui/                          # HUD, loading screen
│   ├── collectible_manager.gd       # Score orbs
│   └── event_bus.gd                 # Global signal bus
├── shaders/                         # 5 custom GLSL shaders
└── docs/                            # Design, spec, tech, status, inspirations
```

---

## Controls

| Action | Input |
|---|---|
| Move | W / A / S / D |
| Jump / Charge Jump | Space (hold to charge) |
| Look | Mouse (captured) |
| Bow — Charge/Fire | Hold / Release Left Mouse |
| Dash-Slash | Right Click / Shift |
| Roll | Double-tap WASD |
| Ultimate | F |
| Weapon 1 (Bow) | 1 |
| Weapon 2 (Sword) | 2 |
| Quit | Esc |

---

## Setup

1. Install **Godot 4.6**.
2. Open `project.godot`.
3. Press **F5** to run.
4. No external assets required.

### GDScript Warning Check

```bash
godot -d -s validate.gd 2>&1 | tee -a godot.log
```
