class_name HealthComponent
extends Node

signal health_changed(current: int, max_hp: int)
signal damaged(amount: int, knockback: bool)
signal died

@export var max_health: int = 20
@export var invulnerability_time: float = 0.0

var current_health: int
var invuln_timer: float = 0.0
var is_alive: bool = true


func _ready() -> void:
	current_health = max_health


func _process(delta: float) -> void:
	if invuln_timer > 0.0:
		invuln_timer = max(invuln_timer - delta, 0.0)


func take_damage(amount: int, knockback: bool = false) -> void:
	if not is_alive or invuln_timer > 0.0:
		return
	current_health -= amount
	invuln_timer = invulnerability_time
	health_changed.emit(current_health, max_health)
	damaged.emit(amount, knockback)
	if current_health <= 0:
		is_alive = false
		died.emit()
