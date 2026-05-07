extends Node
class_name EnemyAI

enum FSMState { IDLE, PATROL, CHASE, ATTACK, HURT, DEAD }

## Distance at which the enemy notices and starts chasing the player.
@export var aggro_range: float = 150.0
## Distance at which the enemy stops and attacks the player.
@export var attack_range: float = 40.0
## HP removed from the player per attack hit.
@export var attack_damage: int = 3
## Seconds between each attack hit.
@export var attack_interval: float = 1.5
## Optional Path2D for patrolling. If unset, the enemy stays idle until aggroed.
@export var patrol_path: Path2D
## How close to a waypoint counts as "reached" before advancing to the next one.
@export var patrol_point_threshold: float = 4.0

var _entity: CharacterEntity
var _state: FSMState = FSMState.IDLE
var _attack_timer: float = 0.0
var _hurt_timer: float = 0.0
var _prev_hp: int = 0
var _player: CharacterEntity = null
var _patrol_index: int = 0

signal enemy_died

func _ready() -> void:
	_entity = get_parent() as CharacterEntity
	if not _entity:
		push_error("EnemyAI must be a direct child of CharacterEntity")
		return

	# Fallback: if the entity scene didn't bind its health_controller export, find it by name.
	if not _entity.health_controller:
		_entity.health_controller = _entity.get_node_or_null("HealthController")
	if _entity.health_controller:
		_prev_hp = _entity.health_controller.max_hp
		_entity.health_controller.hp_changed.connect(_on_hp_changed)
	else:
		push_warning("EnemyAI: %s has no HealthController; HP-driven states disabled." % _entity.name)

	if patrol_path and patrol_path.curve and patrol_path.curve.point_count > 0:
		_state = FSMState.PATROL

	_find_player()

func _find_player() -> void:
	for p in Globals.get_players():
		if p is PlayerEntity and is_instance_valid(p):
			_player = p
			return
	if not Globals.player_added_to_scene.is_connected(_on_player_added):
		Globals.player_added_to_scene.connect(_on_player_added, CONNECT_ONE_SHOT)

func _on_player_added(p: PlayerEntity) -> void:
	_player = p

func _on_hp_changed(new_hp: int) -> void:
	if new_hp <= 0 and _state != FSMState.DEAD:
		_state = FSMState.DEAD
		_entity.stop()
		enemy_died.emit()
	elif new_hp < _prev_hp and _state != FSMState.HURT and _state != FSMState.DEAD:
		_enter_hurt()
	_prev_hp = new_hp

func _physics_process(delta: float) -> void:
	# If our cached player ref got freed (e.g. on a level restart that
	# swaps the player out from under us), look for the new one.
	if not _player or not is_instance_valid(_player):
		_find_player()
	match _state:
		FSMState.IDLE:
			_tick_idle()
		FSMState.PATROL:
			_tick_patrol()
		FSMState.CHASE:
			_tick_chase()
		FSMState.ATTACK:
			_tick_attack(delta)
		FSMState.HURT:
			_tick_hurt(delta)
		FSMState.DEAD:
			pass

func _tick_idle() -> void:
	_entity.stop()
	if _dist_to_player() <= aggro_range:
		_set_state(FSMState.CHASE)

func _tick_patrol() -> void:
	if _dist_to_player() <= aggro_range:
		_set_state(FSMState.CHASE)
		return
	if not patrol_path or not patrol_path.curve or patrol_path.curve.point_count == 0:
		_set_state(FSMState.IDLE)
		return
	var curve := patrol_path.curve
	var target: Vector2 = curve.get_point_position(_patrol_index) + patrol_path.global_position
	if _entity.global_position.distance_to(target) <= patrol_point_threshold:
		_patrol_index = (_patrol_index + 1) % curve.point_count
	else:
		_entity.move_towards(target)

func _tick_chase() -> void:
	var dist := _dist_to_player()
	if dist > aggro_range:
		_set_state(FSMState.PATROL if patrol_path else FSMState.IDLE)
		return
	if dist <= attack_range:
		_set_state(FSMState.ATTACK)
		return
	# Direct pursuit; CharacterBody2D.move_and_slide handles wall sliding.
	_entity.move_towards(_player.global_position)

func _tick_attack(delta: float) -> void:
	var dist := _dist_to_player()
	if dist > attack_range:
		_attack_timer = 0.0
		_set_state(FSMState.CHASE)
		return
	_entity.stop()
	_entity.face_towards(_player.global_position)
	# Note: we deliberately do not call _play_animation("attack") here.
	# The shared AnimationTree forces an AT_END exit from "attack" every
	# animation cycle, which produces a visible flicker when re-entered.
	# Leaving the entity in idle keeps the sprite stable; damage is still
	# dealt on attack_interval below.
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_attack_timer = attack_interval
		_do_attack()

func _tick_hurt(delta: float) -> void:
	_hurt_timer -= delta
	_entity.move(Vector2.ZERO)
	if _hurt_timer <= 0.0:
		_entity.is_hurting = false
		_set_state(FSMState.CHASE)

func _enter_hurt() -> void:
	_hurt_timer = 0.3
	_state = FSMState.HURT
	_entity.is_hurting = true
	_play_animation("hurt")
	var knockback_dir := _player.global_position.direction_to(_entity.global_position)
	_entity.velocity += knockback_dir * 300.0
	_entity.flash(1.0, 0.2)

func _do_attack() -> void:
	if _player and is_instance_valid(_player) and _player.health_controller:
		_player.health_controller.change_hp(-attack_damage, _entity.name)
	# Trigger the attack animation directly. The AnimationTree's AT_END transition
	# will return to idle/walk/run on its own, so no flag toggling is needed.
	_play_animation("attack")

## Forces the AnimationTree's state machine into the given state by traveling
## along its transition graph. No-op if we're already in that state.
func _play_animation(state_name: String) -> void:
	if not _entity or not _entity.animation_tree:
		return
	var playback = _entity.animation_tree.get("parameters/playback")
	if not playback or playback.get_current_node() == state_name:
		return
	playback.travel(state_name)

func _set_state(new_state: FSMState) -> void:
	_state = new_state
	if new_state == FSMState.IDLE:
		_entity.stop()
	elif new_state == FSMState.ATTACK:
		_attack_timer = 0.0

func _dist_to_player() -> float:
	if not _player or not is_instance_valid(_player):
		return INF
	return _entity.global_position.distance_to(_player.global_position)
