## This script is attached to the Player node and is specifically designed to represent player entities in the game.
## The Player node serves as the foundation for creating main playable characters.
class_name PlayerEntity
extends CharacterEntity

@export_group("States")
@export var on_transfer_start: State ## State to enable when player starts transfering.
@export var on_transfer_end: State ## State to enable when player ends transfering.
@export var on_roll: State

const _DEATH_SCREEN_SCENE: PackedScene = preload("res://scenes/menus/death_screen.tscn")
const _DEATH_SCREEN_DELAY: float = 1.0

var player_id: int = 1 ## A unique id that is assigned to the player on creation. Player 1 will have player_id = 1 and each additional player will have an incremental id, 2, 3, 4, and so on.
var equipped = -1 ## The inventory weapon slot equipped by the player.
var _death_screen_shown := false
var roll_cooldown := 0.45
var grenade_cooldown := 0.75
var roll_cooldown_timer: Timer
var grenade_cooldown_timer: Timer

const GRENADE_SCENE: PackedScene = preload("res://items/weapons/grenade.tscn")


func _ready():
	super._ready()
	_init_ability_timers()
	Globals.transfer_start.connect(func():

		on_transfer_start.enable()
	)
	Globals.transfer_complete.connect(func(): on_transfer_end.enable())
	Globals.destination_found.connect(func(destination_path): _move_to_destination(destination_path))
	if health_controller:
		health_controller.hp_changed.connect(_on_hp_changed)
	if inventory:
		inventory.equip_weapon.connect(_on_weapon_equipped)
	receive_data(DataManager.get_player_data(player_id))

func _init_ability_timers():
	if !roll_cooldown_timer:
		roll_cooldown_timer = Timer.new()
		roll_cooldown_timer.one_shot = true
		add_child(roll_cooldown_timer)
	if !grenade_cooldown_timer:
		grenade_cooldown_timer = Timer.new()
		grenade_cooldown_timer.one_shot = true
		add_child(grenade_cooldown_timer)

func _on_hp_changed(new_hp: int) -> void:
	if new_hp > 0 or _death_screen_shown:
		return
	_death_screen_shown = true
	if _DEATH_SCREEN_DELAY > 0.0:
		await get_tree().create_timer(_DEATH_SCREEN_DELAY).timeout
	if not is_inside_tree():
		return
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(canvas)
	canvas.add_child(_DEATH_SCREEN_SCENE.instantiate())

##Get the player data to save.
func get_data():
	var data = DataPlayer.new()
	var player_data = DataManager.get_player_data(player_id)
	if player_data:
		data = player_data
	data.position = position
	data.facing = facing
	data.hp = health_controller.hp
	data.max_hp = health_controller.max_hp
	data.inventory = inventory.items if inventory else []
	data.equipped = equipped
	return data

##Handle the received player data (from a save file or when moving to another level).
func receive_data(data):
	if data:
		global_position = data.position
		facing = data.facing
		# Sync the particle baseline first so the upcoming hp setter doesn't
		# spawn hit particles for the save-load HP delta.
		_hp_for_particles = data.hp
		health_controller.hp = data.hp
		health_controller.max_hp = data.max_hp
		if inventory:
			inventory.items = data.inventory
		equipped = data.equipped
		equip_loadout_slot(equipped)

func _move_to_destination(destination_path: String):
	if !destination_path:
		return
	var destination = get_tree().root.get_node(destination_path)
	if !destination:
		return
	var direction = facing
	if destination is Transfer and destination.direction:
		direction = destination.direction.to_vector
	DataManager.save_player_data(player_id, {
		position = destination.global_position,
		facing = direction
	})

func disable_entity(value: bool, delay = 0.0):
	await get_tree().create_timer(delay).timeout
	stop()
	input_enabled = !value

func equip_loadout_slot(slot_index: int):
	var weapon_indices := _get_inventory_weapon_indices()
	if slot_index < 0 or slot_index >= weapon_indices.size():
		return
	equipped = slot_index
	weapon = inventory.items[weapon_indices[slot_index]].item as DataWeapon

func _on_weapon_equipped(equipped_weapon: DataWeapon) -> void:
	var weapon_indices := _get_inventory_weapon_indices()
	for i in weapon_indices.size():
		if inventory.items[weapon_indices[i]].item == equipped_weapon:
			equipped = i
			return

func _get_inventory_weapon_indices() -> Array[int]:
	var weapon_indices: Array[int] = []
	if !inventory:
		return weapon_indices
	for i in inventory.items.size():
		if inventory.items[i].item is DataWeapon:
			weapon_indices.append(i)
	return weapon_indices

func roll():
	if !input_enabled or is_attacking or is_jumping or is_rolling or roll_cooldown_timer.time_left > 0:
		return
	roll_cooldown_timer.start(roll_cooldown)
	enable_state(on_roll)

func throw_grenade():
	if !input_enabled or is_rolling or grenade_cooldown_timer.time_left > 0:
		return
	grenade_cooldown_timer.start(grenade_cooldown)
	var grenade = GRENADE_SCENE.instantiate()
	if grenade == null:
		return
	var spawn_parent: Node = get_tree().current_scene
	if spawn_parent == null:
		spawn_parent = get_tree().root
	if spawn_parent == null:
		return
	spawn_parent.add_child(grenade)
	grenade.global_position = global_position + (facing * 10.0)
	if grenade.has_method("setup"):
		grenade.call("setup", self, facing)
