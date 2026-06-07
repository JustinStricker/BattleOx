# Deployment Plan: Multiplayer + EOS Integration

## Architecture

**Listen server model** — one player hosts the world, others connect.
**Transport layering** — Godot `MultiplayerAPI` sits above a swappable `MultiplayerPeer`:

```
MultiplayerAPI  ← same RPCs/spawners/synchronizers
     ↕
MultiplayerPeer  ← abstract interface
     ↕
ENetMultiplayerPeer    or    EOS P2P MultiplayerPeer
     ↕                           ↕
Direct UDP/IP               Epic relay + NAT punch
```

Develop with ENet (no config, instant iteration), swap to EOS P2P in Phase 4 without touching gameplay code. Or support both.

---

## Phase 1 — Network Infrastructure + Player Sync

**Goal**: Two players can see each other moving in the same world.

**New files**:
- `src/network/network_manager.gd` — Autoload wrapping `MultiplayerAPI`, peer management, connection signals
- `src/ui/main_menu.tscn` + `src/ui/main_menu.gd` — Host/Join/Connect IP screen

**Changes**:
- `project.godot` — Register `NetworkManager` as autoload, add `ui_host`/`ui_join` input actions
- `bootstrap.gd` — Show main menu instead of immediately entering game; on host, start game as today; on join, connect then wait for world seed
- `game.gd` — Split `_ready()`: host runs full init, clients skip world gen and wait for seed RPC
- `player.tscn` — Make it `MultiplayerSpawner`-compatible
- `player.gd` — Guard input/process with `multiplayer.get_unique_id() == multiplayer_authority`. Non-owned players receive transform sync
- `NetworkManager` — `host_game(port)` / `join_game(ip, port)` / `leave_game()`. Signals: `player_connected(id)`, `player_disconnected(id)`, `server_disconnected`

**Not touched**: `zombie/`, `environment.gd`, `world_generator.gd`, `collectible_manager.gd`, `arrow.gd`, `bow.gd`, `sword_slash.gd`, `zombie_manager.gd`

**Verify**: Two instances — host sees Host Game → joiner sees Join Game + enter IP → both see player characters in world, movement synced

---

## Phase 2 — World Synchronization

**Goal**: Joiner generates the identical world from the host's seed.

**Changes**:
- `world_generator.gd` — Accept explicit seed parameter instead of `randi()` in `_init`
- `game.gd` — Host calls `rpc("send_world_config", seed, water_level, world_size)` after generating. Client waits for this, then generates WorldGen + Environment from received seed
- `game.gd:37` — Host computes player spawn and sends it per-connecting-client via RPC
- `environment.gd` — Drive `randi()` calls (line 416 `seed_base`) from `WorldGen.seed_value` for determinism
- `bootstrap.gd` — Client shows loading screen after connection, waits for world config

**Key insight**: `FastNoiseLite` is deterministic. Same seed → identical world. All random scatters (trees, grass, clouds) must derive from the shared seed.

**Verify**: Host and client see identical terrain, tree placements, water, biomes. Client loading screen shows "Receiving world..." then transitions to game.

---

## Phase 3 — Combat & Gameplay Sync

### 3a — Player Health & Death
- `player.gd` — `take_damage()` and `die()` become RPCs. `die()` on host respawns player at spawn point instead of reloading scene
- `ui.gd` — HUD references local player via `NetworkManager` instead of `get_first_node_in_group("player")`

### 3b — Zombie Authority
- `zombie_manager.gd` — Only runs on host (`multiplayer.is_server()` guard in `_process`)
- `zombie.tscn` + `zombie.gd` — Add a **replica zombie** scene with no AI, just visual transform sync. Host runs full AI zombies, syncs via `MultiplayerSpawner` + `MultiplayerSynchronizer`. Clients instantiate replicas
- `perception_component.gd` — Target finding uses `NetworkManager` to find correct player node per peer

### 3c — Bow/Sword Sync
- `bow.gd` — `arrow_fired` becomes `rpc("fire_arrow", origin, direction, speed)`. Only host spawns arrow (authoritative). Arrow hits detected by host
- `sword_slash.gd` — `_perform_slash_hit()` runs on host only. Client sends `rpc("request_slash")` → host validates cooldown → runs hit check → broadcasts result
- `arrow.gd` — Arrow body spawned only on host. Optional visual replica on clients

### 3d — Collectibles & Score
- `collectible_manager.gd` — Host-only `_process`. State synced to clients. `_on_collect` fires only on host, which RPCs score update and respawn position to all
- `game.gd` — `score` variable and `_on_score_changed` updated via RPC

**Verify**: Client bow fire spawns arrow visible to all, sword slash damages zombies visible to all, zombies move synchronized, collectible pickups update shared score.

---

## Phase 4 — EOS Integration (Ready to Implement)

**Goal**: Replace direct IP connection with Epic Online Services for internet play.

**New dependency**: [`epic-online-services-godot`](https://github.com/3ddelano/epic-online-services-godot) (GDExtension, Godot 4.2+, actively maintained)
- Provides `EOSGMultiplayerPeer` — drop-in replacement for `ENetMultiplayerPeer`
- High Level API (HEOS): `HAuth`, `HLobbies`, `HP2P`, `HLeaderboards` — clean GDScript interface
- Supports: Auth, Lobbies, P2P with NAT traversal + relay, Voice, Leaderboards, Anti-Cheat

**Changes** (minimal — transport is already abstracted):
- `network_manager.gd` — Add `EOS_P2P` branch in `host_game()`/`join_game()` using `EOSGMultiplayerPeer`
- `eos_auth.gd` (new autoload) — EOS Platform init (ProductID, SandboxID, DeploymentID, ClientId/Secret), login via `HAuth`
- `main_menu.gd` — Replace IP fields with "Sign in with Epic" → "Create Lobby" / "Find Lobbies"
- `eos_lobby.gd` (new) — Wraps `HLobbies` for create/search/join with attributes
- `player.gd` — Set display name from `HAuth.display_name`
- `project.godot` — Add EOS autoload, SDK config values

**Considerations**:
- Social Overlay (Shift+F2) for friend invites and presence
- Auth: `HAuth.login_async()` with DeviceID (dev) or Epic Account Portal (prod)
- Voice chat via EOS RTC (optional, for team coordination)
- Use `BucketId` on lobbies for regional grouping (reduces latency)
- `HP2P.set_relay_control(EOS.P2P.RelayControl.AllowRelays)` — NAT traversal works out of the box

**Verify**: Player launches → "Sign in with Epic" → lobby browser → join friend → connected via EOS P2P → gameplay identical to Phase 3

---

## Timeline

| Phase | Scope | Status | New files | Files touched |
|---|---|---|---|---|
| **1** | Network infra + player sync | ✅ Complete | — | `network_manager.gd`, `main_menu.gd`, `player.tscn`, `player.gd`, `survival.gd` |
| **2** | Deterministic world sync | ✅ Complete | — | `world_generator.gd`, `survival.gd` |
| **3** | Combat, zombies, collectibles | ✅ Complete | — | `enemy.gd`, `enemy.tscn`, `enemy_manager.gd`, `bow.gd`, `sword_slash.gd`, `ultimate.gd`, `arrow.gd`, `collectible_manager.gd` |
| **3.5** | Networking cleanup + EOS readiness | ✅ Complete | — | `network_manager.gd`, `main_menu.gd`, `player.tscn`, `enemy.tscn`, `enemy.gd`, `enemy_manager.gd`, `survival.gd`, `networking.md` |
| **4** | EOS auth, lobbies, P2P | 📋 Ready to implement | `eos_auth.gd`, `eos_lobby.gd` | `network_manager.gd`, `main_menu.gd`, `survival.gd` |

**Networking is fully functional for LAN play.** EOS integration is the final step for internet play.

---

## Why ENet first, EOS later

Godot's `MultiplayerAPI` is transport-agnostic — it works with any `MultiplayerPeer`. ENet is zero-config and instant for development. When EOS comes in, you only swap the peer implementation; all RPCs, spawners, synchronizers, and game logic remain untouched. Iterating through auth/lobby bugs while also debugging netcode would be slow.
