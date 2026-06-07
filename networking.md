# Networking Architecture — BattleOx

## Transport Layer

`network_manager.gd` is the single transport abstraction. Game code must never reference
the peer directly — use `multiplayer` API and RPCs only.

```
ENet (LAN) — current default
EOS P2P — future internet play (swap MultiplayerPeer only)
```

**Key principle:** EOS replaces the transport layer (`MultiplayerPeer`), not the game logic.
All RPCs, MultiplayerSynchronizer, and game code stay the same when swapping transports.

## Entity Sync Architecture

| Entity | Sync Method | Properties | Why |
|---|---|---|---|
| **Player** | Custom RPCs (`_server_input` → `_server_simulate_remote` → `_sync_authoritative_state`) | position, velocity | Server-authoritative with input forwarding; foundation for future client-side prediction |
| **Enemy** | `MultiplayerSynchronizer` (enemy.tscn) | position, rotation, `HealthComponent:current_health` | Continuous NPC state; engine handles replication and interpolation |
| **Enemy animation** | RPC (`_sync_enemy_anim`) | is_moving, is_attacking | Discrete state changes; not continuous enough for synchronizer |
| **Collectibles** | RPCs for pickup events | — | One-shot events |
| **World/terrain** | Deterministic seed sync | seed, world_size, water_level | Both peers generate identical world from shared seed |
| **Combat events** | RPCs | damage, death, effects | Discrete events |

## Files Modified

| File | Changes |
|---|---|
| `network_manager.gd` | Transport abstraction (MultiplayerPeer base type, TransportType enum, EOS-ready) |
| `main_menu.gd` | Fixed JOIN race condition (now waits for `connected_to_server` signal) |
| `player.tscn` | Removed `MultiplayerSynchronizer` (player sync handled by RPCs) |
| `enemy.tscn` | Added `HealthComponent:current_health` to `MultiplayerSynchronizer` config |
| `enemy.gd` | Removed manual `_sync_enemy_health` RPC (now synced by MultiplayerSynchronizer) |
| `enemy_manager.gd` | Removed `EnemySyncTimer` and `_sync_enemy_position` RPC (now synced by MultiplayerSynchronizer) |
| `survival.gd` | Fixed client `enemy_mgr` missing `world_gen` reference |

## Remaining Networking Issues

1. **No client-side prediction** — Player movement waits for server round-trip on clients.
   Future: Add tick numbers to `_server_input`/`_sync_authoritative_state`, input history buffer,
   and server reconciliation. See rrc.codes tutorial for reference implementation.

2. **No entity interpolation** — Remote players teleport between RPC updates.
   Future: Add snapshot interpolation with fixed delay (100ms behind real-time).

3. **No NAT traversal for internet play** — UPNP is unreliable.
   Future: Integrate EOS P2P via `EOSGMultiplayerPeer` for relay-based NAT traversal.

4. **No late-joiner enemy streaming** — `_on_host_player_connected` sends existing enemies,
   but new enemies spawned after a late joiner connects ARE sent via `_spawn_enemy_replica`.

5. **No player identity** — No names, colors, or display beyond unique ID.

## EOS Integration Path

When ready for internet play:
1. Install `epic-online-services-godot` GDExtension
2. Add EOS Auth (Device ID for dev, Epic Account for prod)
3. Add EOS Lobbies for game creation/joining
4. Replace `ENetMultiplayerPeer` with `EOSGMultiplayerPeer` in `network_manager.gd`
5. Everything above transport stays the same — RPCs, MultiplayerSynchronizer, game logic

## Authority Model

| Entity | Authority | Notes |
|---|---|---|
| Server | Default (ID 1) | Runs all game logic, AI, physics simulation |
| Player characters | Owning client | `set_multiplayer_authority(peer_id)` cascades to children |
| Enemies | Server | AI only runs on server; clients receive replicated state |
| World seed | Server | Sent to clients via `send_world_config` RPC |
| Combat/damage | Server | Clients send input requests; server validates and broadcasts results |