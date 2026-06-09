# Roadmap

**Current focus**: Shields system.

## Build Order

### 1. Shields (next)
Regenerative damage buffer. Foundational combat system that unlocks several other features (Nova, Charge synergy, night synergy, KOTH synergy). Every other system references it.

### 2. Day/Night Cycle
Visual + gameplay day/night. Required before Volatiles can exist. Shields synergy (night regen boost) depends on this.

### 3. King of the Hill
Zone-based scoring mode. Required for biotic progression unlocks (Throw requires first Hill hold). Shields synergy (regen reduction in zone, point-based shield restore).

### 4. Biotics — Charge + Nova
The two shield-linked powers first. Charge restores shields, Nova costs shields. Other powers can come later.

### 5. Safehouse + Crafting
Independent track — can start whenever. Shield Injector and Shield Capacitor recipes depend on shields being implemented.

### 6. Volatiles
Night-specific enemies. Unlock Warp, enable Volatile kill shield restore mechanic. Requires day/night cycle.

### 7. Remaining Biotics + Upgrade Tree
Pull, Throw, Warp, Singularity, Bend Time, Dark Vision. Echo Shard economy.

### 8. Enchantments
Tomes in Echo Zones. All tie into shield system, so shields must be done first.

## Feature Dependencies

```
Shields ──→ Nova, Charge synergy, Shield Injector/Capacitor
   │
   ├──→ Night synergy ──→ Volatiles, Warp unlock
   │
   └──→ KOTH synergy ──→ Progression unlocks (Throw, Bend Time, Charge)
```
