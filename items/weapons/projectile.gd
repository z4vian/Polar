class_name WeaponProjectile
extends HitBox

var direction := Vector2.RIGHT
var speed := 700.0
var max_distance := 420.0
var travelled_distance := 0.0
var damage_source_name := ""

func _ready():
	monitoring = true
	area_entered.connect(_on_area_entered)

func _physics_process(delta):
	var motion = direction * speed * delta
	global_position += motion
	travelled_distance += motion.length()
	if travelled_distance >= max_distance:
		queue_free()

func setup(source: CharacterEntity, data_weapon: DataWeapon, shot_direction: Vector2):
	direction = shot_direction.normalized()
	rotation = direction.angle()
	speed = data_weapon.projectile_speed
	max_distance = data_weapon.projectile_range
	hp_change = -data_weapon.power
	collision_layer = source.hit_box.collision_layer
	damage_source_name = source.name

func _on_area_entered(area: Area2D):
	if area is HurtBox:
		monitoring = false
		queue_free()
