# Demo — Godot 4.6 3D Open-World Action Game

A procedurally generated open-world 3D action game built in **Godot 4.6** using **Jolt Physics** and the **Forward Plus** renderer. Features terrain/biome generation, procedural villages, a chargeable bow and dash-slash melee combat, zombie enemies with state-machine AI, collectible scoring, and custom GLSL shaders.

---

## Quick Facts

| Property | Value |
|---|---|
| **Engine** | Godot 4.6 |
| **Physics** | Jolt Physics |
| **Renderer** | Forward Plus |
| **Main Scene** | `res://bootstrap.tscn` |
| **Input** | Keyboard + Mouse |
| **Target Window** | 2560×1664 |
| **Dependencies** | None (pure Godot) |

---

## Features

### Procedural World Generation
- **Terrain:** Perlin noise (FBM fractal) with 200×200 vertex grid, 200×200 world units. Height compression near extremes produces rolling hills and steep mountains.
- **Biomes:** 5 biomes determined by elevation, moisture, and temperature noise:
  - **Ocean** — below elevation −0.15
  - **Meadows** — moderate elevation/moisture, green grass
  - **Black Forest** — higher moisture, darker vegetation
  - **Swamp** — high moisture, low elevation
  - **Mountain** — high elevation, rocky/snowy peaks
- **Snow Caps:** GPU-based snow blending on terrain via `terrain.gdshader` (smoothstep at configurable elevation).
- **Water Plane:** Animated wave vertex displacement with depth-based color blending and foam.
- **Trees / Foliage:** Poisson-disk sampling for even distribution. Three tree types (oak, pine, swamp) with MultiMesh instancing. Grass blades scattered across non-mountain/non-ocean biomes.
- **Clouds:** 60 billboarded QuadMesh clouds using FBM noise shader with drift animation.

### Procedural Villages
- Zone-based placement system (16-unit zones) that evaluates terrain suitability.
- 8 building blueprints (small house, long house, round tower, ruined wall, stone circle, campsite, well, guard post).
- Each blueprint defines footprint, allowed biomes, elevation range, max terrain steepness, quantity, and a build function.
- Buildings are StaticBody3D with collision shapes; some have dynamic elements (chimney smoke particles, campfire fire/sparks, lantern OmniLights).

### Combat System
- **Bow:** Charged projectile weapon attached to camera. Hold left mouse to charge (0.15–2.0s), release to fire. Arrow speed scales from 15 to 55 m/s. Visual string pull + shake at full charge. 0.5s cooldown between shots.
- **Arrow:** RigidBody3D with CapsuleShape3D collision, visual shaft/tip/fletching/nock, GPUParticles3D trail, 25 damage to zombies, 5-second auto-despawn.
- **Sword (Dash-Slash):** Right-click / Shift to trigger. 1.5s cooldown. 3-phase animation (draw → slash → sheathe). Cone-based hit detection (75° half-angle, 8m range, 25 damage). Debug visualization: expanding translucent sphere. Slash trail arc mesh + particles.
- **Hit Particles:** Red hit particles on zombie damage; explosive gib particles (RigidBody3D chunks) on arrow/explosive kills.

### Enemy AI (Zombies)
- 3 types with distinct stats:

| Type | Health | Speed Mult | Size | Color |
|---|---|---|---|---|
| **Shambler** (60% weight) | 20 | ×1.0 | 3.0–5.0 (random) | Greenish-brown |
| **Runner** (25% weight) | 12 | ×1.6 | 2.25–4.75 | Dark red-brown |
| **Brute** (15% weight) | 50 | ×0.55 | 3.9–8.0 | Very dark red |

- **State Machine:** `IDLE → WANDER → CHASE → ATTACK` with transitions based on distance and line-of-sight.
  - **IDLE:** Faces player, breathes/sways animation.
  - **WANDER:** Moves to random points within 8-unit radius.
  - **CHASE:** 0.2s surprise pause, then pursues player at chase speed. LOS required.
  - **ATTACK:** 1.2s cooldown, 8/14 damage (Shambler/Brute).
- **Despawn:** Beyond 120 units for >5 seconds.
- **Procedural Mesh:** Random body scale, hue, limb segments built with SurfaceTool, glowing red eyes (emission + OmniLight3D), capsule collision scaled to body.
- **Spawn Manager:** 30 max zombies, 4s cooldown, spawns 24–60 units from player on valid terrain (not ocean/mountain/blocked/steep).

### Collectibles
- 11 starting orbs (random colors, metallic, emissive) at fixed positions.
- Collected by player body or arrow collision → +10 score.
- Respawn after 3–6s at random position within ±20×±30 units.
- Visual: rotating, hovering, pulsing glow light.

### HUD / UI
- **Crosshair:** Custom-drawn on Control node (center dot + 4 gap lines).
- **Score Label:** Top-center, "Score: N", flashes yellow on change.
- **Loading Screen:** Dark overlay with progress bar and phase messages.

### Atmosphere & Lighting
- Day/night cycle (sun orbits via procedural sky + rotating DirectionalLight3D).
- SSAO enabled, ACES tonemapping with glow/bloom.
- ProceduralSkyMaterial (dark blue top, warm horizon, brown ground).
- Shadow-mapped directional light (parallel 2-splits, 80m max distance).
- Fill light for ambient.

### Shaders (4 custom)
| Shader | Purpose | Key Features |
|---|---|---|
| `terrain.gdshader` | Terrain coloring + snow | Height-based snow blending, FBM micro-detail, normal perturbation |
| `water.gdshader` | Animated water plane | Vertex wave displacement, depth color, foam, animated normals |
| `clouds.gdshader` | Cloud billboards | FBM noise density, drift animation, edge vignette |
| `wind_foliage.gdshader` | Grass/tree wind sway | Noise-driven vertex displacement, height-based bending |

---

## Project Structure

```
res://
├── bootstrap.gd              # Entry point: instantiates Game node
├── bootstrap.gd.uid           # UID reference
├── bootstrap.tscn             # Main scene (Node3D with bootstrap.gd)
├── icon.svg                   # Project icon
├── icon.svg.import            # Icon import metadata
├── project.godot              # Engine config (inputs, physics, rendering)
├── .editorconfig
├── .gitattributes
├── .gitignore                 # Ignores .godot/ and android/
├── src/
│   ├── game.gd                # Game orchestrator (loading, spawning, scoring)
│   ├── player.gd              # CharacterBody3D — movement, health, dash-slash
│   ├── player.tscn            # Player scene (capsule, torso, head, eyes, camera)
│   ├── bow.gd                 # Camera-attached bow with charge mechanic
│   ├── arrow.gd               # Static spawner for RigidBody3D arrows
│   ├── sword_slash.gd         # Camera-attached sword with slash animation/hit
│   ├── zombie.gd              # Zombie enemy (class_name Zombie) with AI + procedural mesh
│   ├── zombie.tscn            # Zombie scene (capsule collision + script)
│   ├── zombie_manager.gd      # Spawns/despawns zombies around player
│   ├── collectible_manager.gd # Score orbs with respawn logic
│   ├── ui.gd                  # CanvasLayer HUD (crosshair + score label)
│   ├── ui.tscn                # UI scene
│   ├── environment.gd         # Terrain, water, trees, grass, sky, clouds
│   ├── world_generator.gd     # class_name WorldGen — noise-based biome/height
│   ├── village.gd             # Procedural village placement and building blueprints
│   ├── loading_screen.gd      # Loading overlay with progress bar
│   └── loading_screen.tscn    # Loading screen scene
└── shaders/
    ├── terrain.gdshader       # Terrain vertex color + snow blend + normal detail
    ├── water.gdshader         # Animated water with wave displacement
    ├── clouds.gdshader        # Cloud billboard FBM noise shader
    └── wind_foliage.gdshader  # Wind-driven foliage vertex animation
```

---

## Architecture

### Scene Tree (Runtime)

```
Root (bootstrap.tscn — Node3D)
└── Game (game.gd — Node)
    ├── LoadingScreen (CanvasLayer — loading_screen.tscn)
    ├── WorldGen (WorldGen — world_generator.gd)
    ├── Environment (Node3D — environment.gd)
    │   ├── WorldEnvironment (sky, SSAO, glow, tonemapping)
    │   ├── DirectionalLight3D (sun with shadows)
    │   ├── DirectionalLight3D (ambient fill)
    │   ├── Clouds (Node3D — 60 cloud MeshInstances)
    │   ├── TerrainMesh (MeshInstance3D — terrain shader)
    │   ├── TerrainCollision (StaticBody3D + ConcavePolygonShape3D)
    │   ├── Water (MeshInstance3D — water shader)
    │   ├── MultiMeshInstance3D (trees × 3 types)
    │   ├── MultiMeshInstance3D (grass)
    │   └── Village (Node3D — village.gd)
    │       ├── SmallHouse × ~5 (StaticBody3D)
    │       ├── LongHouse × ~3
    │       ├── RoundTower × ~4
    │       ├── ... (other blueprints)
    │       └── Per-structure: meshes, collision, lights, particle emitters
    ├── Player (CharacterBody3D — player.tscn)
    │   ├── CollisionShape3D (capsule)
    │   ├── Torso / Head / Eyes (MeshInstance3D)
    │   ├── Camera3D (first-person)
    │   │   ├── Bow (Node3D — bow.gd) [added at runtime]
    │   │   └── SwordSlash (Node3D — sword_slash.gd) [added at runtime]
    │   └── ... (player meshes)
    ├── UI (CanvasLayer — ui.tscn)
    ├── Arrows (Node3D — container for arrow RigidBody3Ds)
    ├── CollectibleManager (Node — collectible_manager.gd)
    └── ZombieManager (Node — zombie_manager.gd)
        └── Zombie × ~0–30 (CharacterBody3D — zombie.tscn)
```

### Data Flow

1. **Startup** → `bootstrap.gd` creates `Game` node.
2. **Game._ready()** runs sequentially:
   - Creates `LoadingScreen` overlay.
   - Creates `WorldGen` (noise initialization).
   - Creates `Environment` (caches terrain data, builds terrain mesh, scatters trees/grass, places villages).
   - Creates `Player` at a suitable spawn point (flat terrain, above water).
   - Attaches `Bow` and `SwordSlash` to player's Camera3D.
   - Creates `UI` (HUD).
   - Creates `Arrows` container, `CollectibleManager`, `ZombieManager` (with world_gen reference).
   - Fades out loading screen, captures mouse.
3. **Per-frame:**
   - `Player._physics_process`: movement, jumping, dash-slash, invincibility.
   - `Bow._process`: charge logic, string pull animation.
   - `SwordSlash._process`: cooldown tracking.
   - `Zombie._physics_process`: state machine, animation, line-of-sight, attacks.
   - `ZombieManager._process`: spawn timer, cleanup.
   - `CollectibleManager._process`: rotation/bobbing/pulse animation.
   - `Environment._process`: day/ncycle sun update + cloud drift.

### Signal Wiring

| Signal | Emitter | Receiver | Purpose |
|---|---|---|---|
| `arrow_fired` | `Bow` | `Game._on_arrow_fired` | Spawn arrow RigidBody3D |
| `score_changed` | `CollectibleManager` | `Game._on_score_changed` | Update UI score |
| `died` | `Zombie` | `ZombieManager._on_zombie_died` | Clean zombie list |
| `body_entered` | Collectible `Area3D` | `CollectibleManager._on_collect` | Score + respawn |
| `body_entered` | Arrow `RigidBody3D` | Lambda callback | Damage zombie + despawn |

### Input Map

| Action | Key | Usage |
|---|---|---|
| `move_forward` | W | Move forward |
| `move_back` | S | Move backward |
| `move_left` | A | Strafe left |
| `move_right` | D | Strafe right |
| `jump` | Space | Jump |
| `dash_slash` | Shift (physical 4194325) | Dash-slash attack |
| `ui_cancel` | Esc | Quit game |
| Mouse left btn | — | Charge/release bow |
| Mouse motion | — | Look around (captured mode) |

---

## Key Classes Reference

### `game.gd` — Game (Node)
- **Role:** Top-level game controller.
- **Signals:** None (receives signals from children).
- **Key Methods:**
  - `_ready()` — Loading sequence (5 phases with progress bar), spawns all subsystems.
  - `_on_arrow_fired(origin, direction, speed)` — Instantiates arrow in Arrows container.
  - `_on_score_changed(amount, ui)` — Updates `score` and UI text.
  - `_input(event)` — Quit on `ui_cancel`.

### `world_generator.gd` — WorldGen (Node, class_name)
- **Role:** Noise-based terrain/biome data provider. Used by Environment, Village, ZombieManager.
- **Exports:** None (all internal).
- **Key Methods:**
  - `get_height(x, z) → float` — Raw noise height (−2 to ~6).
  - `get_terrain_height(x, z) → float` — Bilinear-interpolated height at any position.
  - `get_elevation(x, z) → float` — Raw noise value for biome classification.
  - `get_moisture(x, z) → float`, `get_temperature(x, z) → float`, `get_forest(x, z) → float` — Normalized noise (0–1).
  - `get_biome(x, z) → Biome` — Classifies based on elevation/moisture/temperature.
  - `get_terrain_delta(x, z, radius) → float` — Max-min height difference in a ring (steepness).
  - `biome_color(biome, x, z, h) → Color` — Vertex color per biome.
  - `sample_biome_color(x, z) → Color` — Blended color at edges using neighbor sampling.
  - `add_vegetation_blocker(rect)` / `is_blocked(x, z)` — Prevent vegetation on village footprints.

### `environment.gd` — Environment (Node3D)
- **Role:** Builds the visual world: terrain mesh, collision, water, trees, grass, sky, clouds, atmosphere.
- **Exports:** `world_gen: WorldGen`
- **Key Constants:** `RESOLUTION = 200`, `HALF_WORLD = 100.0`, `CACHE_RES = 2.0`
- **Key Methods:**
  - `_ready()` — Caches terrain/biome/forest data, sets up atmosphere, generates terrain, adds water, scatters grass.
  - `_cache_terrain_data()` — Pre-computes height/biome/forest into packed arrays for fast lookup.
  - `_poisson_disk_sample(half_size, min_dist) → Array[Vector2]` — Poisson-disk sampling for vegetation.
  - `_generate_terrain()` — Builds terrain MeshInstance3D + StaticBody3D collision (ConcavePolygonShape3D).
  - `_add_water()` — Water plane with shader.
  - `_scatter_trees()` — Oak/pine/swamp trees via MultiMesh on Poisson-disk points.
  - `_scatter_grass()` — Grass MultiMesh with Poisson-disk.
  - `_setup_atmosphere()` — WorldEnvironment (glow, SSAO, ACES tonemap) + ProceduralSky + sun + fill light + clouds.
  - `_update_sun()` — Day/night cycle.

### `player.gd` — Player (CharacterBody3D)
- **Role:** First-person character with movement, mouse look, health, and dash-slash.
- **Exports:** None.
- **Key State:** `health: int = 100`, `is_dashing: bool`, `dash_cooldown: float`
- **Key Methods:**
  - `_input(event)` — Mouse look, dash-slash trigger.
  - `_physics_process(delta)` — Movement (WASD), jump, gravity, dash physics.
  - `take_damage(amount)` — Reduces health with 0.5s invincibility window.
  - `die()` — Reloads scene on health ≤ 0.
  - `_start_dash_slash()` — 60 m/s dash forward for 0.25s, 1.5s cooldown. Only if sword allows.

### `bow.gd` — Bow (Node3D)
- **Role:** Attached to Camera3D, provides chargeable ranged attack.
- **Signals:** `arrow_fired(origin: Vector3, direction: Vector3, speed: float)`
- **Key State:** `is_charging: bool`, `shoot_cooldown: float`
- **Key Methods:**
  - `_input(event)` — Left mouse press/release for charge.
  - `start_charge()` — Begin charge (checks cooldown).
  - `release_arrow()` — Calculate charge time, emit arrow with scaled speed (15–55), trigger cooldown + string snap animation.
  - `_process(delta)` — Update string pull position, shake at full charge.

### `arrow.gd` — Arrow (static script, no instance)
- **Role:** Static `spawn()` factory that creates arrow RigidBody3D instances.
- **Key Methods:**
  - `static spawn(parent, origin, direction, speed)` — Builds arrow mesh (shaft, tip, fletching, nock), sets physics, attaches GPUParticles3D trail, adds 5s despawn timer, connects body_entered for 25 damage to zombies.

### `sword_slash.gd` — SwordSlash (Node3D)
- **Role:** Camera-attached melee weapon with animation and area cone hit.
- **Signals:** `slash_completed()`
- **Key State:** `is_slashing: bool`, `slash_cooldown: float`
- **Key Constants:** `SLASH_DAMAGE = 25`, `HIT_RANGE = 8.0`, `CONE_HALF_ANGLE = 75.0`
- **Key Methods:**
  - `_ready()` — Build mesh and trail.
  - `start_slash()` → `bool` — Initiate if cooldown ready.
  - `can_slash()` → `bool` — Cooldown + not already slashing.
  - `_perform_slash_hit()` — Cone check against all `zombie` group nodes.
  - `_play_slash_animation()` — 3-phase tween (draw→slash→sheathe), generates trail mesh, flash particles.
  - `_debug_show_range(origin)` — Debug sphere that fades out.

### `zombie.gd` — Zombie (CharacterBody3D, class_name)
- **Role:** Enemy with AI state machine and fully procedural mesh.
- **Signals:** `died(pos: Vector3)`
- **Enums:** `State { IDLE, WANDER, CHASE, ATTACK }`, `Type { SHAMBLER, RUNNER, BRUTE }`
- **Key State:** `health: int`, `state: State`, `zombie_type: Type`, `_dead: bool`
- **Key Methods:**
  - `_ready()` — Pick type, build mesh, find player.
  - `_physics_process(delta)` — State machine, line-of-sight, animation, eye pulsing.
  - `take_damage(amount, explosive)` — Reduce health, spawn hit particles, die.
  - `die(explode)` — Normal death (tween collapse) or explosive (gib RigidBody3D chunks + particles + light flash).
  - `_has_line_of_sight()` → `bool` — Physics raycast to player.
  - `_build_mesh()` — Full procedural body: torso, head, arms (upper+forearm), legs (thigh+shin), glowing eyes, eye light, scaled collision.
  - `_animate_idle/walk/attack(delta)` — Limb rotation animation with sine-based breathing/swaying/walking.

### `zombie_manager.gd` — ZombieManager (Node)
- **Role:** Periodic zombie spawning around player with terrain validation.
- **Exports:** `world_gen: WorldGen`, `type_weight_shambler/runner/brute: float`
- **Key State:** `max_zombies = 30`, `spawn_cooldown = 4.0`, `min_spawn_dist = 24.0`, `max_spawn_dist = 60.0`
- **Key Methods:**
  - `_process(delta)` — Spawn timer + dead cleanup.
  - `roll_zombie_type()` → `int` — Weighted random.
  - `_try_spawn()` — Find valid spawn point (not ocean/mountain/blocked/steep, within world bounds ±95), instantiate Zombie.
  - `_on_zombie_died(pos)` — Cleanup list.

### `collectible_manager.gd` — CollectibleManager (Node)
- **Role:** Score orbs with collection/respawn.
- **Signals:** `score_changed(amount: int)`
- **Key Methods:**
  - `_ready()` — Spawn 11 orbs at fixed positions.
  - `spawn_collectible(pos)` — Area3D with sphere mesh (random hue, metallic, glow light, rotation animation).
  - `_on_collect(body, item)` — Collect by player or arrow, +10 score, respawn after delay.
  - `_process(delta)` — Rotate, bob, pulse glow for all active orbs.

### `village.gd` — Village (Node3D)
- **Role:** Procedurally generate village structures using zone-based placement.
- **Exports:** `world_gen: WorldGen`
- **Key Constants:** `ZONE_SIZE = 16.0`, `HALF_WORLD = 100.0`
- **Key Methods:**
  - `_ready()` — Init materials, build candidate zones, place blueprints.
  - `_build_candidate_zones()` — Scan world for valid zones (non-ocean/mountain, suitable elevation).
  - `_try_place(blueprint)` → `bool` — Find unoccupied zone matching biome/elevation/delta constraints.
  - `_place_blueprints()` — Place 8 blueprint types with defined quantities.
  - `_build_small_house/long_house/round_tower/ruined_wall/stone_circle/campsite/well/guard_post(parent, cx, cz)` — Each builds meshes, collision, lights, particles on a StaticBody3D.

### `ui.gd` — UI (CanvasLayer)
- **Role:** HUD with crosshair and score.
- **Key Methods:**
  - `_draw_crosshair()` — Custom crosshair via Control.draw_rect calls.
  - `set_score(value)` — Update score label text with yellow flash tween.

### `loading_screen.gd` — LoadingScreen (CanvasLayer)
- **Role:** Progress overlay during world generation.
- **Key Methods:**
  - `update(phase_name, progress)` — Set message text and animate progress bar.

---

## Biome Reference

| Biome | Elevation | Moisture | Temperature | Color | Vegetation |
|---|---|---|---|---|---|
| **Ocean** | < −0.15 | — | — | Dark teal | None |
| **Meadows** | −0.15 to 0.65 | < 0.25 | Any | Green | Oak trees, grass |
| **Black Forest** | 0.0 to 0.5 | 0.25–0.55 | Any | Dark green | Pine trees, grass |
| **Swamp** | −0.05 to 0.35 | > 0.55 | Any | Brown-green | Swamp trees, limited grass |
| **Mountain** | > 0.65 | — | — | Gray (brightness scales with height) | Snow cap, no grass |

---

## Controls

| Action | Input | Details |
|---|---|---|
| **Move** | W / A / S / D | Forward, strafe left, backward, strafe right |
| **Jump** | Space | 4.5 m/s velocity |
| **Look** | Mouse (captured) | Horizontal: rotate body; Vertical: tilt camera (clamped ±80°) |
| **Bow — Charge** | Hold Left Mouse | 0.15s min charge, 2.0s max charge |
| **Bow — Fire** | Release Left Mouse | Speed interpolates 15–55 m/s |
| **Dash-Slash** | Right Click / Shift | 25 damage in 75° cone, 8m range, 1.5s cooldown, 0.25s dash at 60 m/s |
| **Quit** | Esc | Immediately exits |

---

## Setup & Running

1. Install **Godot 4.6** (mono or standard).
2. Open the project in Godot — select the `project.godot` file.
3. The main scene is already set to `bootstrap.tscn`.
4. Press **F5** (Run Project) to play.
5. No external assets, plugins, or dependencies required.

---

## File Reference (Every `.gd` File)

| File | Class | Type | Purpose |
|---|---|---|---|
| `bootstrap.gd` | (Node3D) | Script | Entry point; creates Game node |
| `src/game.gd` | Game | Node | Orchestrates loading, spawning, scoring |
| `src/player.gd` | Player | CharacterBody3D | Movement, health, dash-slash |
| `src/bow.gd` | Bow | Node3D | Chargeable ranged weapon |
| `src/arrow.gd` | (none) | Static | Arrow factory (RigidBody3D) |
| `src/sword_slash.gd` | SwordSlash | Node3D | Melee cone-slash weapon |
| `src/zombie.gd` | Zombie | CharacterBody3D | Enemy AI + procedural mesh |
| `src/zombie_manager.gd` | ZombieManager | Node | Zombie spawn controller |
| `src/collectible_manager.gd` | CollectibleManager | Node | Score orb spawn/collect/respawn |
| `src/ui.gd` | UI | CanvasLayer | Crosshair + score display |
| `src/environment.gd` | Environment | Node3D | Terrain, water, trees, grass, sky |
| `src/world_generator.gd` | WorldGen | Node | Noise-based world data provider |
| `src/village.gd` | Village | Node3D | Procedural village builder |
| `src/loading_screen.gd` | LoadingScreen | CanvasLayer | Loading overlay |
| `shaders/terrain.gdshader` | — | Shader | Terrain color + snow + normal detail |
| `shaders/water.gdshader` | — | Shader | Animated water with waves |
| `shaders/clouds.gdshader` | — | Shader | Cloud billboard noise + drift |
| `shaders/wind_foliage.gdshader` | — | Shader | Wind-driven vertex deformation |

---

## LLM-Friendly Summary

This is a **Godot 4.6** project that implements a complete open-world action game. The entry point is `bootstrap.tscn`, which runs `bootstrap.gd` → creates a `Game` node. `Game._ready()` is a sequential loading pipeline: instantiate `WorldGen` (noise), `Environment` (terrain + vegetation + villages), `Player` (FPS character), weapons (Bow + SwordSlash attached to camera), HUD (UI), collectibles, and zombie spawning. All visual content is procedurally generated at runtime — no imported 3D models or textures are used. The game features a full zombie AI system (state machine with line-of-sight), charged ranged combat, melee dash-slash, and a scoring loop. Custom GLSL shaders handle terrain coloring/snow, water animation, cloud rendering, and foliage wind. The physics engine is Jolt Physics with the Forward Plus renderer.
