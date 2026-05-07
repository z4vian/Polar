class_name GrenadeProjectile
extends HitBox

@export var throw_speed := 240.0
@export var drag := 360.0
@export var fuse_time := 0.8
@export var blast_damage := 4
@export var texture: Texture2D

var velocity := Vector2.ZERO
var exploded := false
var damage_source_name := ""

@onready var travel_shape: CollisionShape2D = $TravelShape
@onready var blast_shape: CollisionShape2D = $BlastShape
@onready var blast_visual: Polygon2D = $BlastVisual
@onready var body_visual: Polygon2D = $BodyVisual
@onready var body_sprite: Sprite2D = $BodySprite

func _ready():
	monitoring = false
	monitorable = false
	collision_layer = 0
	hp_change = 0
	body_sprite.texture = texture
	body_sprite.visible = texture != null
	body_visual.visible = texture == null
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
	_damage_entities_in_blast()
	await get_tree().create_timer(0.08).timeout
	queue_free()

func _damage_entities_in_blast() -> void:
	var radius := _get_blast_radius()
	var damaged := {}
	for group_name in [Const.GROUP.PLAYER, Const.GROUP.ENEMY]:
		for entity in get_tree().get_nodes_in_group(group_name):
			if entity is CharacterEntity and entity.health_controller and not damaged.has(entity):
				if global_position.distance_to(entity.global_position) <= radius:
					entity.health_controller.change_hp(-blast_damage, damage_source_name)
					damaged[entity] = true

func _get_blast_radius() -> float:
	if blast_shape.shape is CircleShape2D:
		var circle := blast_shape.shape as CircleShape2D
		return circle.radius * max(abs(global_scale.x), abs(global_scale.y))
	return 0.0
