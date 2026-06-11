# Technical Documentation

**Engine**: Godot 4.6 | **Physics**: Jolt | **Renderer**: Forward Plus

---

## Scene Tree (Runtime, Survival Mode)

```
bootstrap.tscn (Node3D)
└── Game (survival.gd)
    ├── LoadingScreen (CanvasLayer)
    ├── WorldGen (world_generator.gd)
    ├── Environment (environment.gd)
    │   ├── WorldEnvironment (sky, SSAO, glow, tonemapping)
    │   ├── DirectionalLight3D (sun, shadows)
    │   ├── DirectionalLight3D (ambient fill)
    │   ├── TerrainMesh (chunk_manager.gd + terrain_chunk.gd)
    │   ├── Water (MeshInstance3D)
    │   ├── MultiMeshInstance3D (trees, grass)
    │   ├── Clouds (60 MeshInstances)
    │   └── Village (village.gd)
    ├── Player (player.tscn)
    │   ├── Camera3D
    │   │   ├── Bow (bow.gd)
    │   │   ├── SwordSlash (sword_slash.gd)
    │   │   ├── Wings (wings.gd)
    │   │   └── Ultimate (ultimate.gd)
    │   └── Meshes (torso, head, eyes)
    ├── UI (ui.tscn)
    ├── Arrows (Node3D container)
    ├── CollectibleManager (collectible_manager.gd)
    ├── EnemyManager (enemy_manager.gd)
    │   └── Enemy × 0–60 (enemy.tscn)
    │       ├── HealthComponent
    │       ├── PerceptionComponent
    │       ├── MovementComponent
    │       ├── AIStateMachine
    │       ├── MultiplayerSynchronizer
    │       └── EnemySkeleton (DireWolf / Wraith / StoneGolem)
    ├── AudioManager (autoload)
    ├── MusicManager (autoload)
    └── NetworkManager (autoload)
```

---

## Startup Sequence

1. `bootstrap.gd` creates Game node with survival mode.
2. `survival.gd._ready()` runs sequentially:
   - Create LoadingScreen overlay
   - Create WorldGen (noise initialization)
   - Mode: host creates Environment (terrain, vegetation, villages), world config synced to clients via RPC
   - Mode: client receives world config, builds terrain locally
   - Create Player at spawn point (spawned via MultiplayerSpawner on host)
   - Attach Bow, SwordSlash, Wings, Ultimate to Camera3D
   - Create UI, Arrows container, CollectibleManager, EnemyManager
   - Fade loading screen, capture mouse

---

## Entity System Architecture

### Enemies (Component-Based)

Each enemy is an `enemy.tscn` scene with a CharacterBody3D root and child component nodes:

| Component | Role |
|---|---|
| **HealthComponent** | HP pool, invulnerability timer, damaged/died signals |
| **PerceptionComponent** | Nearest player, per-frame cached LOS raycast |
| **MovementComponent** | Gravity, move_toward, face_target, ground_height |
| **AIStateMachine** | 4-state FSM (IDLE→WANDER→CHASE→ATTACK), ranged projectile creation |
| **MultiplayerSynchronizer** | Replicates position, rotation, health |

At runtime, an **EnemySkeleton** subclass is created dynamically based on type:

```
EnemySkeleton (Node3D) — abstract base
├── Skeleton3D (procedural bone hierarchy)
├── BoneAttachment3D ×N (meshes on bones)
├── PhysicalBoneSimulator3D (ragdoll death)
├── FootPlacementModifier3D (IK, ground enemies)
└── HandTargetModifier3D (IK, stone golem)
```

| Skeleton | Bones | Type | Notes |
|---|---|---|---|
| **DireWolfSkeleton** | 15 | Quadruped | Melee, foot IK (4 feet) |
| **WraithSkeleton** | 12 | Floating orb | Ranged, energy bolt projectiles |
| **StoneGolemSkeleton** | 15 | Bipedal | Melee, foot IK (2 feet), hand IK punch |

State machine: transitions based on distance + line-of-sight. Ranged enemies fire dynamically-created projectile RigidBody3Ds. Death uses PhysicalBoneSimulator3D ragdoll or tween collapse.

### Player Weapons

All weapons are Node3D children of Camera3D in `player.tscn`:

| Weapon | Class | Lines | Role |
|---|---|---|---|
| Bow | `bow.gd` | 474 | Chargeable projectile, procedural recurve mesh |
| Sword | `sword_slash.gd` | 542 | 3-phase iaijutsu slash, procedural katana |
| Wings | `wings.gd` | 495 | Procedural energy wings, jump assist |
| Ultimate | `ultimate.gd` | 144 | Charge via damage, beam projectile on F key |

Arrow factory (`arrow.gd`) is a static script producing RigidBody3D projectiles with procedural shaft/tip/fletching mesh + GPUParticles3D trail.

### World Generation

Dual system:
- **Original**: Single 200×200 vertex terrain mesh with Perlin FBM noise, 5 biomes (Ocean, Meadows, Black Forest, Swamp, Mountain), procedural villages, MultiMesh vegetation.
- **Chunk system** (newer): `ChunkManager` + `TerrainChunk` — 64-unit chunks, 3-load-radius, thread-pool generation, mesh/collision pooling. Overrides the original terrain.

Day/night cycle drives ProceduralSkyMaterial + DirectionalLight3D rotation. SSAO, ACES tonemapping, glow/bloom.

---

## Shaders (5 Custom)

| Shader | Type | Purpose |
|---|---|---|
| `terrain.gdshader` | spatial | Terrain vertex color + snow blend + normal perturbation |
| `water.gdshader` | spatial | Gerstner wave vertex displacement, depth color, foam |
| `clouds.gdshader` | spatial | FBM noise cloud billboards with drift |
| `wind_foliage.gdshader` | spatial | Noise-driven vertex sway for grass/trees |
| `beam.gdshader` | spatial | Ultimate energy beam — scrolling bands, FBM distortion, emission |

---

## Networking

### Transport Layer

`NetworkManager` (autoload) abstracts transport. Game code uses `multiplayer` API + RPCs only.

```
MultiplayerAPI  ← same RPCs/spawners/synchronizers
     ↕
MultiplayerPeer  ← abstract interface
     ↕
ENetMultiplayerPeer    or    EOSGMultiplayerPeer
     ↕                           ↕
Direct UDP/IP               Epic relay + NAT punch
```

**Model**: Listen server (one player hosts, others connect). Transport switchable via enum (`ENET_LAN`, `EOS_P2P`).

### Entity Sync

| Entity | Method | Why |
|---|---|---|
| Player | Custom RPCs (input forwarding → authoritative state) | Foundation for client-side prediction |
| Enemy | `MultiplayerSynchronizer` | Continuous NPC state |
| Enemy animation | RPC (`_sync_enemy_anim`) | Discrete state changes |
| World | Deterministic seed sync | Both peers generate identical terrain |
| Combat | RPCs | Discrete events |

### Authority

| Entity | Authority |
|---|---|
| Server | All game logic, AI, physics |
| Player characters | Owning client |
| Enemies | Server |
| World seed | Server |

### Interpolation (Remote Players)

```gdscript
global_position = global_position.lerp(_target_position, clampf(delta * 15.0, 0.0, 1.0))
```

---

## EOS Integration

### Service Map

| Interface | BattleOx Use |
|---|---|
| Connect | Player authentication (Device ID dev, Epic Account prod) |
| Lobbies | KOTH + Battle Royale match discovery + lifecycle |
| P2P | Game transport via EOSGMultiplayerPeer |
| Stats | KOTH / BR win/loss/kill tracking |
| Leaderboards | Ranked display from Stats |
| Player Data Storage | Survival save/load |

### Progression-Light Storage Model

Survival progression is a single flat blob — no XP, no skill trees, no biome gates.

**Survival Save Blob (EOS Player Data Storage)**:

```json
{
  "version": 1,
  "schematics": {
    "abilities": ["pull", "throw", "charge"],
    "weapons": ["bow", "wingstick"],
    "upgrades": ["rapid_regen", "shield_capacity_1"]
  },
  "enchantments": ["shield_capacity_1", "quick_restore"],
  "inventory": {
    "echo_shards": 47,
    "materials": { "wood": 120, "stone": 64, "cloth": 12 }
  },
  "base_blocks": {
    "size": [32, 16, 16],
    "run_length_data": "..."
  },
  "stats": {
    "survival_time": 43200,
    "zombie_kills": 89
  }
}
```

- **Limit**: ~1MB per blob (EOS quota: 200MB/file, 400MB/user, 1000 files/user)
- **Base block volume**: capped at 32×16×16 units. Run-length encoding keeps it ~16KB at max density.
- **Auth**: Player-authoritative (tamperable by design — PvE sandbox, integrity doesn't matter)
- **Save triggers**: bed sleep, manual save, on quit, periodic autosave (60s, debounced)
- **Load triggers**: Continue game, joining Survival session (load host's save)

**KOTH Stats (EOS Stats Interface)**:

```
koth_wins: int64     — written by host post-match
koth_losses: int64   — written by host post-match
koth_matches: int64  — written by host post-match
```

All players: `mmr = 1000 + wins×25 − losses×25`. Client-derived from Stats.

**Battle Royale Stats (EOS Stats Interface)**:

```
br_wins: int64       — written by host post-match
br_kills: int64      — written by host post-match
br_matches: int64    — written by host post-match
```

**Leaderboards**: Created in Developer Portal, source stat per mode. Aggregation: Sum. Visibility: Global + friends.

### Quick-Play Matchmaking (KOTH)

Single "Find KOTH Match" button. No lobby browser. EOS-native.

**Lobby Attribute Schema**:

| Key | Type | Search Op | Purpose |
|---|---|---|---|
| mode | string | EQ | "koth" |
| status | string | EQ | "waiting" → "in_progress" |
| min_mmr | int64 | LTE | Lower skill bound |
| max_mmr | int64 | GTE | Upper skill bound |

**Client State Machine**: `IDLE → SEARCHING → IN_LOBBY → IN_MATCH → IDLE`

**MMR Bandwidth Widening**:

| 0–15s | 15–30s | 30–60s | 60s+ |
|---|---|---|---|
| ±100 | ±200 | ±400 | No limit |

### Planned: Battle Royale Matchmaking

Same EOS Lobbies flow with `mode="br"`. Squad sizes 1-4. Lobby attribute: `squad_size`.

### Host Migration

- **During lobby waiting**: EOS Lobby promotes next member to owner automatically. New host continues waiting.
- **During active match**: match ends (listen server model — no host migration mid-game). Results may be lost.

---

## Planned Architecture

### Ability System (Overwatch + Mass Effect + RAGE)

Replaces legacy Biotics. Loadout-based: 3 ability slots + Overdrive + Ultimate.

If schematic-based acquisition: discovered abilities stored as boolean flags in Survival blob. At runtime, `AbilityManager` (new autoload or mode-level node) manages hotkey bindings, cooldowns, and primer/detonator state.

Overdrive system separate from Ultimate charge — uses its own resource pool built via combat activity. ~15s cooldown, ~6s duration.

### Tool System (Roblox)

All equippable items become **Tool** instances with Handle (3D mesh), Grip (hand offset), and Activation (primary/alt fire). Tool scene template:

```
Tool (Node3D)
├── Handle (MeshInstance3D)
├── Grip (Node3D — position/rotation offset)
├── Activator (Area3D or RayCast — context-dependent use)
└── Properties (resource — damage, cooldown, ammo, schematic_id, rarity)
```

Bow and Sword refactored into Tool instances. New weapons (Wingstick, Assault Rifle, etc.) implement the same interface.

### RAGE Weapon System

Each weapon has distinct primary + alt-fire. Rarity system (Common→Legendary) adds passive modifiers without stat tiers. Weapons found as schematics and crafted. Weapon wheel for quick-swap.

### Godot Systems Used

| System | Where |
|---|---|
| `SurfaceTool` + `ArrayMesh` | Procedural meshes across all entities |
| `MultiMeshInstance3D` | Clouds, trees, foliage |
| `ProceduralSkyMaterial` | Day/night sky dome |
| `ShaderMaterial` | Terrain, water, cloud, wind, beam shaders |
| `Tween` | Death animations, sword slash, camera shake |
| `RigidBody3D` | Arrow projectiles, death explosion debris |
| `CPUParticles3D` / `GPUParticles3D` | Smoke, blood, trails, embers |
| `Skeleton3D` + `PhysicalBoneSimulator3D` | Enemy skeleton system, ragdoll death |
| `SkeletonModifier3D` | Foot placement + hand targeting IK |
| `MultiplayerSynchronizer` | Enemy state replication |
| `MultiplayerSpawner` | Player spawning in multiplayer |
| `WorkerThreadPool` | Chunk terrain generation |
