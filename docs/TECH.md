# Technical Documentation

**Engine**: Godot 4.6 | **Physics**: Jolt | **Renderer**: Forward Plus

## Scene Tree (Runtime)

```
bootstrap.tscn (Node3D)
└── Game (game.gd)
    ├── LoadingScreen (CanvasLayer)
    ├── WorldGen (world_generator.gd)
    ├── Environment (environment.gd)
    │   ├── WorldEnvironment (sky, SSAO, glow, tonemapping)
    │   ├── DirectionalLight3D (sun, shadows)
    │   ├── DirectionalLight3D (ambient fill)
    │   ├── TerrainMesh (MeshInstance3D)
    │   ├── TerrainCollision (StaticBody3D)
    │   ├── Water (MeshInstance3D)
    │   ├── MultiMeshInstance3D (trees, grass)
    │   ├── Clouds (60 MeshInstances)
    │   └── Village (village.gd)
    ├── Player (player.tscn)
    │   ├── Camera3D
    │   │   ├── Bow (bow.gd)
    │   │   └── SwordSlash (sword_slash.gd)
    │   └── Meshes (torso, head, eyes)
    ├── UI (ui.tscn)
    ├── Arrows (Node3D container)
    ├── CollectibleManager (collectible_manager.gd)
    ├── ZombieManager (zombie_manager.gd)
    │   └── Zombie × 0–30 (zombie.tscn)
    └── NetworkManager (autoload)
```

## Startup Sequence

1. `bootstrap.gd` creates `Game` node
2. `Game._ready()` runs sequentially:
   - Create `LoadingScreen`
   - Create `WorldGen` (noise init)
   - Create `Environment` (terrain, vegetation, villages)
   - Create `Player` at spawn point
   - Attach `Bow` + `SwordSlash` to camera
   - Create `UI`
   - Create `Arrows`, `CollectibleManager`, `ZombieManager`
   - Fade loading screen, capture mouse

## Networking

### Transport Layer
`NetworkManager` (autoload) abstracts the transport. Game code uses `multiplayer` API + RPCs only — never the peer directly.

```
MultiplayerAPI  ← same RPCs/spawners/synchronizers
     ↕
MultiplayerPeer  ← abstract interface
     ↕
ENetMultiplayerPeer    or    EOS P2P MultiplayerPeer
     ↕                           ↕
Direct UDP/IP               Epic relay + NAT punch
```

**Model**: Listen server (one player hosts, others connect)

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
| Player characters | Owning client (`set_multiplayer_authority`) |
| Enemies | Server |
| World seed | Server |

### Security
```gdscript
# Server-only RPC validation
if multiplayer.get_remote_sender_id() != NetworkManager.SERVER_ID:
    return
```
`@rpc("authority")` functions are inherently safe.

### Interpolation (Remote Players)
```gdscript
global_position = global_position.lerp(_target_position, clampf(delta * 15.0, 0.0, 1.0))
```

### Deployment Plan
| Phase | Scope | Status |
|---|---|---|
| 1 | Network infra + player sync | ✅ Complete |
| 2 | Deterministic world sync | ✅ Complete |
| 3 | Combat, zombies, collectibles sync | ✅ Complete |
| 3.5 | EOS readiness + cleanup | ✅ Complete |
| 4 | EOS auth, lobbies, P2P | 📋 Ready |

### EOS Integration Steps
1. Install `epic-online-services-godot` GDExtension
2. Add EOS Auth (Device ID for dev, Epic Account for prod)
3. Add EOS Lobbies for game creation/joining
4. Swap `ENetMultiplayerPeer` → `EOSGMultiplayerPeer` in `network_manager.gd`
5. Everything above transport stays the same

---

## Godot Systems Audit

### In Use (keep these)
| System | Where |
|---|---|
| `SurfaceTool` + `ArrayMesh` | Procedural meshes across all entities |
| `MultiMesh` / `MultiMeshInstance3D` | Clouds, trees, foliage |
| `ProceduralSkyMaterial` | Day/night sky dome |
| `ShaderMaterial` | Terrain, water, cloud, wind shaders |
| `Tween` | Death animations, sword slash, camera shake |
| `RigidBody3D` | Arrow projectiles, death explosion debris |
| `CPUParticles3D` / `GPUParticles3D` | Smoke, blood, trails, embers |

### Migration Summary
All planned migrations are complete:
- **Node3D pivots → Skeleton3D bones** (3 enemy types)
- **Tween deaths → PhysicalBone3D ragdoll**
- **Custom IK → SkeletonModifier3D** (foot placement + hand targeting)
- **ImmediateMesh** → KOTH zone + debug visualization

### Deferred
See `STATUS.md` for AnimationPlayer, AnimationTree, GridMap, Path3D.
