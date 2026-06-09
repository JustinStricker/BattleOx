# Project Status

## ✅ Complete

| Feature | Notes |
|---|---|---|
| Shields | 150 cap, 3s delay, 25/s regen, all synergies |
| Day/Night Cycle | 12min cycle, visual + gameplay effects |
| Survival (PvE) | Zombies, collectibles, safehouse, crafting — implemented |
| KOTH (PvP) | Zone scoring implemented as PvE (zombie waves) — needs PvP rework |
| Biotics (Charge + Nova) | Shield-linked powers, upgrade trees |
| Multiplayer (LAN) | Phases 1–3.5: player sync, world sync, combat sync, EOS readiness |
| Skeleton Migration | All 5 phases: Skeleton3D bones, ragdoll, IK, debug viz |
| Combat | Bow (charged), sword (dash-slash) |
| Enemies | 3 zombie types, state-machine AI, spawn system |

## 🔜 Next

### EOS Integration (Multiplayer Phase 4)
Replace ENet with Epic Online Services for internet play.

1. Install `epic-online-services-godot` GDExtension — SDK+setup
2. Set up EOS credentials in Developer Portal (ProductID, SandboxID, etc.)
3. Add `eos_auth.gd` — Connect Interface login (Device ID dev, Epic Account prod)
4. Add `eos_matchmaking.gd` — Quick-play: lobby search, create, join, attribute filtering, MMR widening
5. Add `eos_stats.gd` — IngestStat for KOTH wins/losses, leaderboard query
6. Add `eos_storage.gd` — Player Data Storage for Survival save/load
7. Swap `ENetMultiplayerPeer` → `EOSGMultiplayerPeer` in network_manager.gd
8. Replace LAN menu with Epic sign-in + "Find KOTH Match" button + Survival save slots
9. Host migration handling for lobby owner disconnect during waiting phase
10. Match end flow: stats ingest for all players → lobby disband → return to menu

### Volatiles
Night-specific enemies. Requires day/night cycle (done). Gated: Warp unlock requires Volatile kills (5) — currently a circular dependency since Volatiles aren't implemented.

### Remaining Biotics
Pull, Throw, Warp, Singularity, Bend Time, Dark Vision. Pull is a passive utility.

### Enchantments
Tomes in Echo Zones. All tie into shield system (done).

## ⏸️ Deferred

| Item | Reason | Unblock When |
|---|---|---|
| AnimationPlayer clips | Procedural anim is sufficient | Want more polished attack/flinch |
| AnimationTree state machine | Not enough states yet | AnimationPlayer clips exist |
| GridMap (safehouse) | Blocks work with simple grid | Need runtime editing |
| Path3D patrol routes | Current wander is fine | Want boss movement patterns |
| Client-side prediction | LAN latency is negligible | EOS internet play (Phase 4) |
| Player identity | No names or colors | Before public release |

## 🐛 Known Issues

- Warp unlock requires 5 Volatile kills, but Volatiles are not yet implemented — Warp is currently unobtainable
- Nova unlock requires killing 3 enemies with one Throw — may need tuning if the combo is too hard
- Dark Vision requires finding a scroll in an Echo Cache — spawn locations undefined
- No client-side prediction — will cause visible lag on internet connections
- Late-joiner enemy streaming works but is unoptimized (sends redundant state on each join)
