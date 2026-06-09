# BattleOx — Project Overview

Open-world survival FPS with zombies, Mass Effect-style biotics, and a King of the Hill objective mode. Built in Godot 4.6.

## Core Loop

Explore procedurally-generated terrain → fight zombie waves → hold the Hill for points → survive the night → craft upgrades → unlock new biotic powers → repeat with escalating difficulty.

## Key Systems
- Day/night cycle (zombies get faster, spawn more, new types at night)
- Regenerative shield buffer above health
- 8 biotic powers (Pull, Throw, Warp, Singularity, Charge, Nova, Bend Time, Dark Vision)
- King of the Hill zone-based scoring
- Safehouse crafting (consumables, blocks, enchantments)
- Echo Shard economy (upgrade currency)
- Multiplayer (server-authoritative, up to 4 players)

## Repo Structure
```
src/
├── player/          # Player character, weapons, abilities
├── enemy/           # Enemy AI, skeletons, components
├── enemies/         # Enemy manager (spawning)
├── world/           # Terrain generation, environment
├── ui/              # HUD, minimap, loading screen
├── audio/           # Procedural audio generation
├── modes/           # Game modes (survival)
├── network/         # Multiplayer manager
└── event_bus.gd     # Global signal bus
docs/                # Design docs, technical notes, roadmap
ARCHITECTURE.md      # Godot systems audit + migration plans
```
