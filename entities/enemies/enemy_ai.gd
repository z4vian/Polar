extends Node
class_name EnemyAI

enum FSMState { IDLE, CHASE, ATTACK, HURT, DEAD }

## Distance at which the enemy notices and starts chasing the player.
@export var aggro_range: float = 150.0
## Distance at which the enemy stops and attacks the player.
@export var attack_range: float = 40.0
## HP removed from the player per attack hit.
@export var attack_damage: int = 1
## Seconds between each attack hit.
@export var attack_interval: float = 1.5

var _entity: CharacterEntity
var _nav_agent: NavigationAgent2D
var _state: FSMState = FSMState.IDLE
var _attack_timer: float = 0.0
var _hurt_timer: float = 0.0
var _prev_hp: int = 0
var _player: CharacterEntity = null

signal enemy_died

func _ready() -> void:
	_entity = get_parent() as CharacterEntity
	if not _entity:
		push_error("EnemyAI must be a direct child of CharacterEntity")
		return

	_nav_agent = NavigationAgent2D.new()
	_nav_agent.name = "NavigationAgent2D"
	_entity.add_child(_nav_agent)

	_prev_hp = _entity.health_controller.max_hp
	_entity.health_controller.hp_changed.connect(_on_hp_changed)

	call_deferred("_find_player")

func _find_player() -> void:
	var players := Globals.get_players()
	if players.size() > 0:
		_player = players[0]
	else:
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
	if not _player or not is_instance_valid(_player):
		return

	match _state:
		FSMState.IDLE:
			_tick_idle()
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

func _tick_chase() -> void:
	var dist := _dist_to_player()
	if dist > aggro_range:
		_set_state(FSMState.IDLE)
		return
	if dist <= attack_range:
		_set_state(FSMState.ATTACK)
		return

	_nav_agent.target_position = _player.global_position
	var next_pos := _nav_agent.get_next_path_position()
	# Falls back to direct movement if navigation mesh is not set up.
	if next_pos != _entity.global_position:
		_entity.move_towards(next_pos)
	else:
		_entity.move_towards(_player.global_position)

func _tick_attack(delta: float) -> void:
	var dist := _dist_to_player()
	if dist > attack_range:
		_attack_timer = 0.0
		_set_state(FSMState.CHASE)
		return
	_entity.stop()
	_entity.face_towards(_player.global_position)
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_attack_timer = attack_interval
		_do_attack()

func _tick_hurt(delta: float) -> void:
	_hurt_timer -= delta
	_entity.move(Vector2.ZERO)
	if _hurt_timer <= 0.0:
		_set_state(FSMState.CHASE)

func _enter_hurt() -> void:
	_hurt_timer = 0.3
	_state = FSMState.HURT
	var knockback_dir := _player.global_position.direction_to(_entity.global_position)
	_entity.velocity += knockback_dir * 300.0
	_entity.flash(1.0, 0.2)

func _do_attack() -> void:
	if _player and is_instance_valid(_player) and _player.health_controller:
		_player.health_controller.change_hp(-attack_damage, _entity.name)

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
