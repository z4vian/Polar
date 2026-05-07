class_name DataWeapon
extends DataItem

@export var power: int = 1 ## The value this entity subtracts from another entity's HP when it attacks.
@export var speed: float = 0.5 ## Affects the cooldown time between attacks.
@export var projectile_scene: PackedScene
@export var rate_of_fire: float = 0.0
@export var projectile_speed := 700.0
@export var projectile_range := 420.0
@export var pellet_count := 1
@export_range(0.0, 45.0, 0.5) var spread_degrees := 0.0
@export var use_melee_hitbox := true
@export var use_attack_lunge := true

func is_ranged() -> bool:
	return projectile_scene != null

func get_attack_cooldown() -> float:
	return 1.0 / rate_of_fire if rate_of_fire > 0.0 else speed
