class_name GrenadeProjectile
extends HitBox

@export var throw_speed := 240.0
@export var drag := 360.0
@export var fuse_time := 0.8
@export var blast_damage := 4

var velocity := Vector2.ZERO
var exploded := false
var damage_source_name := ""

@onready var travel_shape: CollisionShape2D = $TravelShape
@onready var blast_shape: CollisionShape2D = $BlastShape
@onready var blast_visual: Polygon2D = $BlastVisual

func _ready():
	monitoring = false
	hp_change = -blast_damage
	blast_visual.visible = false
	_start_fuse()

func setup(source: CharacterEntity, throw_direction: Vector2):
	damage_source_name = source.name
	velocity = throw_direction.normalized() * throw_speed

func _physics_process(delta):
	if exploded:
		return
	global_position += velocity * delta
	velocity = velocity.move_toward(Vector2.ZERO, drag * delta)

func _start_fuse():
	await get_tree().create_timer(fuse_time).timeout
	_explode()

func _explode():
	if exploded:
		return
	exploded = true
	velocity = Vector2.ZERO
	travel_shape.disabled = true
	blast_shape.disabled = false
	blast_visual.visible = true
	monitoring = true
	await get_tree().physics_frame
	monitoring = false
	await get_tree().create_timer(0.08).timeout
	queue_free()
