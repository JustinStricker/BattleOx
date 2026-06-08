extends Resource
class_name EnemyType
## Base resource defining an enemy type's stats, visuals, and behavior.

enum SkeletonType { DIRE_WOLF, WRAITH, STONE_GOLEM }
enum AttackType { MELEE, RANGED }

@export var type_name: String = "Enemy"
@export var skeleton_type: SkeletonType = SkeletonType.DIRE_WOLF
@export var attack_type: AttackType = AttackType.MELEE

# --- Stats ---
@export var health: int = 20
@export var speed_multiplier: float = 1.0
@export var damage: int = 8
@export var attack_range: float = 1.8

# --- Body ---
@export var body_scale_min: float = 3.0
@export var body_scale_max: float = 5.0

# --- Visuals ---
@export var color_hue_min: float = 0.2
@export var color_hue_max: float = 0.35
@export var color_saturation: float = 0.5
@export var color_value: float = 0.3
@export var emissive_color: Color = Color(0.5, 0.05, 0.0)
@export var emissive_strength: float = 0.5
@export var roughness: float = 0.9
@export var metallic: float = 0.0

# --- Combat ---
@export var attack_windup_ratio: float = 0.4
@export var attack_recover_ratio: float = 0.3
@export var flinch_strength: float = 1.0
@export var death_collapse_time: float = 0.4

# --- Movement ---
@export var walk_cadence_mult: float = 1.0
@export var float_height: float = 0.0  # >0 means the enemy hovers (e.g. Wraith)