class_name SettingsMenu extends CanvasLayer

@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SFXSlider
@onready var close_button: Button = %CloseButton
@onready var MUSIC_BUS_ID = AudioServer.get_bus_index("Music")
@onready var SFX_BUS_ID = AudioServer.get_bus_index("SFX")

var user_prefs: UserPrefs
var _keybinds_card: Control = null
var should_manage_pause: bool = true


func _ready() -> void:
	user_prefs = UserPrefs.load_or_create()
	if music_slider:
		music_slider.value = user_prefs.music_volume
	if sfx_slider:
		sfx_slider.value = user_prefs.sfx_volume
	music_slider.grab_focus()


func _input(event: InputEvent) -> void:
	var card_open := _keybinds_card != null and is_instance_valid(_keybinds_card)
	if not card_open and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_settings()


func _on_key_binds_button_pressed() -> void:
	if _keybinds_card != null and is_instance_valid(_keybinds_card):
		return
	_keybinds_card = KeybindsCard.new()
	add_child(_keybinds_card)


func close_settings() -> void:
	queue_free()


func _on_close_button_pressed() -> void:
	close_settings()


func _on_music_slider_value_changed(_value) -> void:
	AudioServer.set_bus_volume_linear(MUSIC_BUS_ID, _value)
	AudioServer.set_bus_mute(MUSIC_BUS_ID, _value < .05)
	user_prefs.music_volume = _value


func _on_sfx_slider_value_changed(_value) -> void:
	AudioServer.set_bus_volume_linear(SFX_BUS_ID, _value)
	AudioServer.set_bus_mute(SFX_BUS_ID, _value < .05)
	user_prefs.sfx_volume = _value


func _notification(what: int) -> void:
	var pause: bool = process_mode == PROCESS_MODE_WHEN_PAUSED
	match what:
		NOTIFICATION_ENTER_TREE:
			if should_manage_pause:
				get_tree().paused = pause
		NOTIFICATION_EXIT_TREE:
			user_prefs.save()
			if should_manage_pause:
				get_tree().paused = false
