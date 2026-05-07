## Handle main camera movement and target following.
class_name GameCamera
extends Camera2D

@export var target_manager: TargetManager

func _ready() -> void:
	_enable_smoothing(false)
	target_manager.target_reached.connect(_init_camera)

func _physics_process(_delta: float) -> void:
	# If TargetManager has no valid target yet, actively search for the player.
	# PlayerInstantiator uses two deferred add_child calls, so the player may
	# not be in the scene when _init_target() first runs.
	if target_manager and not is_instance_valid(target_manager.target):
		var players = Globals.get_players()
		if players.size() > 0:
			target_manager.target = players[0] as Node2D
	_follow_target()

##internal - When transitioning between levels, the camera will be activated upon completing the transfer.
func _init_camera():
	_enable_smoothing(true)

func _enable_smoothing(value):
	position_smoothing_enabled = value

##internal - Manages camera tracking of the assigned target.
func _follow_target():
	if target_manager and is_instance_valid(target_manager.target):
		global_position = target_manager.get_target_position()
