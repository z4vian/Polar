extends CanvasLayer
class_name PauseMenu

var _main_panel: Control
var _confirm_panel: Control
var _confirm_label: Label
var _feedback_label: Label
var _confirm_yes_action: Callable


func _ready() -> void:
	process_mode = PROCESS_MODE_WHEN_PAUSED
	layer = 5
	_build_ui()
	get_tree().paused = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _confirm_panel.visible:
			_show_main()
		else:
			_resume()


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.65)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	_main_panel = _build_main_panel()
	center.add_child(_main_panel)

	_confirm_panel = _build_confirm_panel()
	_confirm_panel.visible = false
	center.add_child(_confirm_panel)


func _build_main_panel() -> Control:
	var panel := PanelContainer.new()

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.custom_minimum_size = Vector2(200, 0)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	_add_button(vbox, "Resume Game", Callable(self, "_resume"))
	_add_button(vbox, "Save",        Callable(self, "_save"))
	_add_button(vbox, "Load",        Callable(self, "_confirm_load"))
	_add_button(vbox, "Settings",    Callable(self, "_open_settings"))
	_add_button(vbox, "Exit",        Callable(self, "_confirm_exit"))

	_feedback_label = Label.new()
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	vbox.add_child(_feedback_label)

	return panel


func _build_confirm_panel() -> Control:
	var panel := PanelContainer.new()

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.custom_minimum_size = Vector2(200, 0)
	margin.add_child(vbox)

	_confirm_label = Label.new()
	_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_confirm_label)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(hbox)

	var yes_btn := Button.new()
	yes_btn.text = "Yes"
	yes_btn.custom_minimum_size = Vector2(80, 0)
	yes_btn.pressed.connect(Callable(self, "_on_confirm_yes"))
	hbox.add_child(yes_btn)

	var no_btn := Button.new()
	no_btn.text = "No"
	no_btn.custom_minimum_size = Vector2(80, 0)
	no_btn.pressed.connect(Callable(self, "_show_main"))
	hbox.add_child(no_btn)

	return panel


func _add_button(parent: VBoxContainer, label: String, action: Callable) -> void:
	var btn := Button.new()
	btn.text = label
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(action)
	parent.add_child(btn)


func _show_confirm(message: String, yes_action: Callable) -> void:
	_confirm_label.text = message
	_confirm_yes_action = yes_action
	_main_panel.visible = false
	_confirm_panel.visible = true


func _show_main() -> void:
	_confirm_panel.visible = false
	_main_panel.visible = true


func _on_confirm_yes() -> void:
	if _confirm_yes_action.is_valid():
		_confirm_yes_action.call()


func _resume() -> void:
	get_tree().paused = false
	queue_free()


func _save() -> void:
	DataManager.save_game()
	_feedback_label.text = "Game Saved!"
	_feedback_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(_feedback_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): _feedback_label.text = "")


func _confirm_load() -> void:
	_show_confirm("Load last save?\nUnsaved progress will be lost.", Callable(self, "_do_load"))


func _do_load() -> void:
	get_tree().paused = false
	queue_free()
	DataManager.call_deferred("load_game")


func _open_settings() -> void:
	var settings := Globals.settings_menu_scene.instantiate()
	settings.should_manage_pause = false
	settings.layer = 10
	_main_panel.visible = false
	settings.tree_exited.connect(func(): _main_panel.visible = true)
	add_child(settings)


func _confirm_exit() -> void:
	_show_confirm("Exit the game?\nAny unsaved progress will be lost.", Callable(self, "_do_exit"))


func _do_exit() -> void:
	get_tree().quit()
