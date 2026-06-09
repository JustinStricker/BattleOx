# Architecture & Technical Notes

## Official Godot Systems Audit

This section tracks which built-in Godot systems are used vs. where custom implementations exist that could be replaced with official alternatives.

### ✅ Currently Using Official Systems (keep these)

| Category | Godot System | Where Used |
|---|---|---|
| Procedural Mesh Generation | `SurfaceTool` + `ArrayMesh` | `environment.gd`, `dire_wolf_skeleton.gd`, `stone_golem_skeleton.gd`, `wraith_skeleton.gd`, `sword_slash.gd`, `wings.gd`, `death_explosion.gd`, `terrain_chunk.gd` |
| Instanced Rendering | `MultiMesh` / `MultiMeshInstance3D` | Clouds (120 instances), Trees (oak/pine/swamp), Foliage (grass, bushes, flowers, mushrooms) — all in `environment.gd` |
| Procedural Sky | `ProceduralSkyMaterial` + `Sky` | `environment.gd` — day/night sky dome |
| GPU Visual Effects | `ShaderMaterial` (custom `.gdshader` files) | Terrain, water, clouds, wind foliage, beam effects |
| Procedural Animation | `Tween` | Enemy deaths, sword slash, wings launch/sweep, camera shake, death explosion rings/flashes |
| Seeded Randomness | `RandomNumberGenerator` | Tree/foliage scattering in `environment.gd` |
| Physics Body | `RigidBody3D` | Death explosion debris chunks in `death_explosion.gd` |
| Particles (CPU) | `CPUParticles3D` | Death explosion smoke, blood, mist in `death_explosion.gd` |
| Particles (GPU) | `GPUParticles3D` | Sword slash trail/sparks, wings particle trails, death explosion fire/embers |

### ❌ Custom Code Replaced With Official Systems

| Custom Approach | Official System Used | Files | Status |
|---|---|---|---|
| **Node3D pivot tree animation** | `Skeleton3D` + `BoneAttachment3D` + `set_bone_pose_rotation()` | `dire_wolf_skeleton.gd`, `stone_golem_skeleton.gd`, `wraith_skeleton.gd` | ✅ **Done** — All 3 skeletons now use programmatic Skeleton3D bones. |
| **Tween-based death animations** | `PhysicalBone3D` + `PhysicalBoneSimulator3D` | All skeleton files | ✅ **Done** — Death methods call `physical_bones_start_simulation()` for ragdoll. |
| **No IK system** | `SkeletonModifier3D` subclasses | `foot_placement_modifier_3d.gd`, `hand_target_modifier_3d.gd` | ✅ **Done** — Dire wolf 4-foot IK, stone golem 2-foot IK + hand targeting. |
| **ImmediateMesh not used** | `ImmediateMesh` | `hill_zone_debug.gd`, `skeleton_debug_drawer.gd` | ✅ **Done** — King of the Hill zone ring/beam + skeleton bone debug visualization. |
| **AnimationPlayer not used** | `AnimationPlayer` | All skeleton files | 🔄 **Deferred** — Procedural bone-pose animation via `_anim_time` is clean and sufficient for now. Can add AnimationPlayer clips later for polish. |
| **AnimationTree not used** | `AnimationTree` | All skeleton files | 🔄 **Deferred** — Not needed until discrete animation states are added. |
| **MeshDataTool** | — | N/A | 🔮 Future consideration |
| **GridMap** | — | N/A | 🔮 Future consideration (safehouse) |
| **Path3D / PathFollow3D** | — | N/A | 🔮 Future consideration (patrol routes) |

### 🔄 Migration Plan — 5 Phases

> **Note**: Phases 1 and 2 are tightly coupled and should be done together. Phases 3–5 can be done independently in any order once Phase 1 is complete.

#### Phase 1: Skeleton3D Bone Hierarchy (Foundation)

**Goal**: Replace Node3D pivot trees with `Skeleton3D` + programmatic bones in all 3 enemy types.

**What changes**:
- Each enemy skeleton class creates a `Skeleton3D` node and defines bones programmatically:
  ```gdscript
  var skel = Skeleton3D.new()
  add_child(skel)
  skel.add_bone("Torso")
  skel.set_bone_rest(0, Transform3D(Basis.IDENTITY, Vector3(0, 0.22, 0)))
  skel.add_bone("Head")
  skel.set_bone_parent(1, 0)
  skel.set_bone_rest(1, Transform3D(Basis.IDENTITY, Vector3(0, 0.04, 0.55)))
  ```
- Procedural meshes (SurfaceTool/ArrayMesh) are built as before, then bound to bones via `Skin` resource + `set_bone_pose_rotation()`.
- `update_animation()` drives `set_bone_pose_rotation(idx, quaternion)` instead of rotating Node3D pivots.
- Keep existing `EnemySkeleton` base class API — `build()`, `update_animation()`, `play_hit_flinch()`, `play_death_animation()`, `set_attack_timer()` all stay the same externally.

**Key APIs**: `Skeleton3D.add_bone()`, `set_bone_parent()`, `set_bone_rest()`, `set_bone_pose_rotation()`, `set_bone_pose_position()`, `BoneAttachment3D`, `Skin`.

**Complication**: Meshes are built procedurally at runtime (no glTF import pipeline). Each mesh must be bound to its bone via `Skin.add_bind()` or by making the mesh a child of a `BoneAttachment3D` node. The `BoneAttachment3D` approach is simpler for this use case.

**Files affected**: `enemy_skeleton.gd`, `dire_wolf_skeleton.gd`, `stone_golem_skeleton.gd`, `wraith_skeleton.gd`, `enemy.tscn`

**Estimated code reduction**: ~60% per skeleton file (eliminates Node3D pivot variables, manual pivot tree construction, and pivot rotation code).

---

#### Phase 2: PhysicalBone3D Ragdoll Deaths

**Goal**: Replace tween-based death animations with physics-driven ragdoll.

**What changes**:
- Add `PhysicalBone3D` child nodes to `Skeleton3D` for each major bone (torso, head, limbs). Each gets a collision shape matching the bone's extent.
- Add a `PhysicalBoneSimulator3D` node to the skeleton.
- On death, call `physical_bones_start_simulation()` — the skeleton collapses under gravity with physics.
- Remove all tween-based death code (`play_death_animation()` tween chains).
- Keep the `death_animation_finished` signal — emit it after a short delay or when bodies come to rest.

**Key APIs**: `PhysicalBone3D`, `PhysicalBoneSimulator3D`, `physical_bones_start_simulation()`, `physical_bones_stop_simulation()`.

**Enhancement opportunity**: Combine with the existing death explosion FX (RigidBody3D chunks + GPUParticles3D) for maximum impact — ragdoll collapse + explosion particles + screen shake.

**Files affected**: All 3 skeleton files (`play_death_animation()` methods), `enemy.tscn`, `death_explosion.gd`

---

#### Phase 3: SkeletonModifier3D Foot/Hand IK

**Goal**: Enemies' feet adapt to terrain slopes; hand attacks visually match hit detection.

**What changes**:
- Create a custom `FootPlacementModifier3D extends SkeletonModifier3D` script:
  - Overrides `_process_modification()`.
  - For each foot bone, raycast downward to find ground position/normal.
  - Set foot bone position to match ground point, rotate to align with surface normal.
  - Clamp IK solve to prevent unnatural limb angles.
- Create a `HandTargetModifier3D extends SkeletonModifier3D` for the stone golem:
  - Overrides `_process_modification()`.
  - Positions the fist bone based on attack target position during wind-up phase.
  - Ensures fist visual aligns with hitbox during strike.
- Add modifier nodes to the skeleton in `_ready()`. They layer on top of base bone poses automatically.

**Key APIs**: `SkeletonModifier3D`, `_process_modification()`, `set_bone_pose_position()`, `set_bone_pose_rotation()`.

**Files affected**: `dire_wolf_skeleton.gd` (4 feet), `stone_golem_skeleton.gd` (2 hands), new modifier scripts in `src/enemy/components/`

---

#### Phase 4: AnimationPlayer for Event Clips

**Goal**: Use `AnimationPlayer` for discrete event animations (attack, flinch) while keeping manual timing for procedural locomotion.

**What changes**:
- Create `Animation` resources programmatically for each enemy type's attack sequence:
  ```gdscript
  var attack_anim = Animation.new()
  attack_anim.track_set_path(0, "Skeleton3D:Head")
  attack_anim.track_insert_key(0, 0.0, Quaternion.IDENTITY)           # neutral
  attack_anim.track_insert_key(0, 0.15, Quaternion.from_euler(...))  # wind-up
  attack_anim.track_insert_key(0, 0.4, Quaternion.from_euler(...))   # strike
  attack_anim.track_insert_key(0, 0.7, Quaternion.IDENTITY)          # recover
  $AnimationPlayer.add_animation("attack", attack_anim)
  ```
- `play_hit_flinch()` plays a short flinch clip via `$AnimationPlayer.play("flinch")`.
- `play_death_animation()` is removed (Phase 2 ragdoll replaces it).
- **Keep manual timing for locomotion** (idle, walk) — sin/cos-driven procedural animation is simpler and more flexible than keyframed clips for continuous movement.
- If `AnimationTree` is desired later, add `AnimationNodeStateMachine` as a child of `AnimationPlayer` to handle transitions between idle/walk/attack/flinch states with crossfade blending.

**Key APIs**: `AnimationPlayer`, `Animation.new()`, `Animation.track_set_path()`, `track_insert_key()`, `AnimationTree`, `AnimationNodeStateMachine`.

**Files affected**: All skeleton files, `enemy.gd`

---

#### Phase 5: Debug Visualization & Polish

**Goal**: Add debug tools and evaluate optional systems.

**What changes**:
- Use `ImmediateMesh` to draw the King of the Hill zone ring/beam in real-time.
- Add debug skeleton bone visualization (draw bone positions as lines) during development.
- Evaluate `GridMap` for safehouse block placement if/when the safehouse system is built.
- Evaluate `Path3D` + `PathFollow3D` for zombie patrol routes or boss movement if predictable paths become desired.

**Key APIs**: `ImmediateMesh`, `ImmediateMesh.surface_begin()`, `surface_add_vertex()`, `GridMap`, `Path3D`, `PathFollow3D`.

**Files affected**: King of the Hill mode, safehouse (future), debug utilities.

---

### 📋 Phase Dependency Summary

```
Phase 1 (Skeleton3D bones) ──→ Phase 2 (Ragdoll)     [can start immediately after Phase 1]
                │
                ├──────→ Phase 3 (Foot/Hand IK)      [can start immediately after Phase 1]
                │
                ├──────→ Phase 4 (AnimationPlayer)    [can start immediately after Phase 1]
                │
                └──────→ Phase 5 (Debug/Polish)       [can start immediately after Phase 1]
```

Phases 2–5 are independent of each other and can be done in any order or in parallel once Phase 1 is complete.
