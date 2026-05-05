class_name UserPrefs extends Resource

@export_range(0, 1, .05) var music_volume: float = 1.0
@export_range(0, 1, .05) var sfx_volume: float = 1.0
@export var language: String = ""
@export var keybinds: Dictionary = {}  # action_name -> physical_keycode (int)

const USER_PREFS_PATH: String = "user://user_prefs.tres"

func save() -> void:
	ResourceSaver.save(self, USER_PREFS_PATH)

func apply_keybinds() -> void:
	for action in keybinds:
		if InputMap.has_action(action):
			var ev := InputEventKey.new()
			ev.physical_keycode = keybinds[action]
			InputMap.action_erase_events(action)
			InputMap.action_add_event(action, ev)

static func load_or_create() -> UserPrefs:
	var res: UserPrefs
	if FileAccess.file_exists(USER_PREFS_PATH):
		res = load(USER_PREFS_PATH) as UserPrefs
	else:
		res = UserPrefs.new()
	return res
