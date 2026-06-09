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
| 4a | EOS Auth (Connect Interface) | 📋 Ready |
| 4b | EOS Lobbies (quick-play matchmaking) | 📋 Ready |
| 4c | EOS P2P transport swap | 📋 Ready |
| 4d | EOS Stats + Leaderboards | 📋 Ready |
| 4e | Player Data Storage (Survival saves) | 📋 Ready |

---

## EOS Integration

### Service Map
| Interface | BattleOx Use |
|---|---|
| Connect | Player authentication (Device ID dev, Epic Account prod) |
| Lobbies | KOTH matchmaking — create, search, join, attribute filtering |
| P2P | Game transport via EOSGMultiplayerPeer |
| Stats | KOTH wins/losses per player |
| Leaderboards | Ranked display from Stats |
| Player Data Storage | Survival save/load |

### Quick-Play Matchmaking (KOTH)

No lobby browser. Single "Find KOTH Match" button. All EOS-native, no backend.

#### Lobby Attribute Schema
Set on lobby creation, public, searchable:

| Key | Type | Search Op | Purpose |
|---|---|---|---|
| mode | string | EQ | "koth" |
| status | string | EQ | "waiting" → "in_progress" |
| min_mmr | int64 | LTE | Lower skill bound |
| max_mmr | int64 | GTE | Upper skill bound |

#### MMR Computation
```gdscript
# Client-side, derived from EOS Stats
var mmr := 1000 + stats.koth_wins * 25 - stats.koth_losses * 25
```
First play (no stats): mmr = 1000.

#### Client State Machine
```
IDLE → SEARCHING → IN_LOBBY → IN_MATCH → IDLE
                        ↓
              (host migration → IN_LOBBY)
```

#### SEARCHING Implementation
```gdscript
func _on_find_match_pressed():
    enter_state(State.SEARCHING)
    _search_timer.start(0.0)

func _search_tick():
    var bw = _bandwidth(_search_elapsed)
    var search = HLobbies.create_lobby_search()
    search.set_parameter("mode", "koth", EOS.ComparisonOp.EQ)
    search.set_parameter("status", "waiting", EOS.ComparisonOp.EQ)
    search.set_parameter("min_mmr", player_mmr - bw, EOS.ComparisonOp.GTE)
    search.set_parameter("max_mmr", player_mmr + bw, EOS.ComparisonOp.LTE)
    
    var results = await search.find_async()
    if results.size() > 0:
        _join_lobby(results[0])
    elif _search_elapsed > 10.0 and not _created_lobby:
        _create_lobby()
    
    _search_timer.start(3.0)

func _bandwidth(sec: float) -> int:
    match sec:
        x < 15.0: return 100
        x < 30.0: return 200
        x < 60.0: return 400
        _:       return 99999
```

#### Lobby Lifecycle
1. **Create**: host sets public attributes (mode, status, min_mmr, max_mmr)
2. **Search**: clients query with MMR range filter, auto-join first result
3. **Join**: joiner sets member attribute `mmr` on arrival
4. **Validate**: host can reject joiner if MMR outside acceptable range (optional)
5. **Start**: host sets status="in_progress", swaps ENet→EOSGMultiplayerPeer, match begins
6. **Match**: P2P game runs via existing MultiplayerAPI (same RPCs, same spawners)
7. **End**: host calls IngestStat for all players, leaves lobby
8. **Cleanup**: lobby auto-disbands once last member leaves (EOS ~15 min if orphaned)

#### Host Migration
- **During lobby waiting**: EOS Lobby promotes next member to owner automatically. New host continues waiting.
- **During active match**: match ends (listen server model — no host migration mid-game). Results may be lost.

### Storage Architecture

#### Survival Saves (Player Data Storage)
- **File**: `survival_save_<slot>.json` (or Godot Resource format)
- **Limits**: 200 MB/file, 400 MB/user, 1000 files/user, 1000 req/min
- **Save triggers**: bed sleep, manual save, on quit, periodic autosave (60s, debounced)
- **Load triggers**: Continue game, joining Survival session (load host's save)

#### KOTH Stats (Stats Interface)
- `koth_wins` (int64): cumulative wins
- `koth_losses` (int64): cumulative losses
- `koth_matches` (int64): total matches played
- Written by host via `EOS_Stats_IngestStat` after match end
- Read by clients for MMR computation + profile display

#### KOTH Leaderboards
- Created in Developer Portal, source: `koth_wins`
- Aggregation: Sum (lifetime). Visibility: Global + friends.
- Updates: Automatic from Stat ingestion — no manual sync needed.

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
