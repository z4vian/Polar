class_name StartScreen extends Control

@export_file("*.tscn") var start_level = "" ## The level from which the game starts when starting a new game.

var user_prefs: UserPrefs

@onready var newgame_button: Button = %NewGame
@onready var continue_button: Button = %Continue
@onready var quit_button: Button = %Quit
@onready var version_num: Label = %VersionNum

func _ready() -> void:
	var version = ProjectSettings.get_setting("application/config/version")
	version_num.text = "v%s" % version
	user_prefs = UserPrefs.load_or_create()
	_check_continue()
	if not user_prefs.language.is_empty():
		TranslationServer.set_locale(user_prefs.language)
	quit_button.visible = OS.get_name() != "Web"

func _check_continue():
	# Continue button is always visible; greyed out (disabled) when there's no
	# usable save. A "usable" save is one whose recorded level still exists on disk.
	continue_button.visible = true
	if _has_usable_save():
		continue_button.disabled = false
		continue_button.grab_focus()
	else:
		continue_button.disabled = true
		newgame_button.grab_focus()

func _has_usable_save() -> bool:
	if not SaveFileManager.save_file_exists():
		return false
	var save = SaveFileManager.load_save_file()
	if not save or not save.game_data:
		return false
	var level_path: String = save.game_data.level
	return not level_path.is_empty() and ResourceLoader.exists(level_path)

func _on_new_game_button_up() -> void:
	DataManager.reset_file_data()
	SceneManager.swap_scenes(start_level, get_tree().root, self, Const.TRANSITION.FADE_TO_WHITE)

func _on_continue_button_up() -> void:
	DataManager.load_file_data()
	var level_to_load: String = DataManager.get_file_data().game_data.level
	if level_to_load.is_empty() or not ResourceLoader.exists(level_to_load):
		# Stale save pointing at a level that no longer exists. Reset and start fresh.
		push_warning("Save file points to invalid level '%s'; starting a new game." % level_to_load)
		DataManager.reset_file_data()
		level_to_load = start_level
	SceneManager.swap_scenes(level_to_load, get_tree().root, self, Const.TRANSITION.FADE_TO_WHITE)

func _on_settings_button_up() -> void:
	Globals.open_settings_menu()

func _on_quit_button_up() -> void:
	get_tree().quit()
