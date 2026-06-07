extends Resource
class_name ZombieType

enum HeadStyle { ROUND, SKULL, HORNED }
enum LegStyle { HUMANOID, DIGITIGRADE }
enum JawStyle { NONE, HANGING, TUSK }

@export var type_name: String = "Shambler"
@export var health: int = 20
@export var speed_multiplier: float = 1.0
@export var damage: int = 8
@export var body_scale_min: float = 3.0
@export var body_scale_max: float = 5.0
@export var arm_radius: float = 0.04
@export var leg_radius: float = 0.05
@export var color_hue_min: float = 0.2
@export var color_hue_max: float = 0.35
@export var color_saturation: float = 0.5
@export var color_value: float = 0.3

@export var head_style: HeadStyle = HeadStyle.SKULL
@export var horn_length: float = 0.0
@export var claw_length: float = 0.06
@export var spike_size: float = 0.04
@export var arm_length_mult: float = 1.0
@export var leg_style: LegStyle = LegStyle.HUMANOID
@export var hunch: float = 0.0
@export var emissive_color: Color = Color(0.5, 0.05, 0.0)
@export var emissive_strength: float = 0.5
@export var roughness: float = 0.9
@export var metallic: float = 0.0

@export var attack_windup_ratio: float = 0.4
@export var attack_recover_ratio: float = 0.3
@export var walk_cadence_mult: float = 1.0
@export var torso_lean_forward: float = 0.0
@export var flinch_strength: float = 1.0
@export var death_collapse_time: float = 0.4

# --- Visual Redesign Parameters ---
@export var arm_length_mult_right: float = -1.0  # -1 = symmetric (use arm_length_mult)
@export var jaw_style: JawStyle = JawStyle.NONE
@export var extra_eyes: int = 0
@export var armor_plates: bool = false
@export var spine_extension: float = 0.0
@export var torso_width_mult: float = 1.0
@export var neck_ring: bool = false
