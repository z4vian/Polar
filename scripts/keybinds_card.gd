extends Control
class_name KeybindsCard

const REBINDABLE_ACTIONS: Dictionary = {
	"move_up":    "Move Up",
	"move_down":  "Move Down",
	"move_left":  "Move Left",
	"move_right": "Move Right",
	"attack":     "Attack",
	"run":        "Run",
	"jump":       "Jump",
	"interact":   "Interact",
	"inventory":  "Inventory",
}

const ESCAPE_HOLD_THRESHOLD: float = 0.5

var _rows_container: VBoxContainer
var user_prefs: UserPrefs
var _rebinding_action: String = ""
var _rebinding_button: Button = null
var _escape_hold_time: float = 0.0


func _ready() -> void:
	_build_ui()
	user_prefs = UserPrefs.load_or_create()
	_populate_rows()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 10

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.6)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var card := PanelContainer.new()
	card.anchor_left = 0.08
	card.anchor_top = 0.04
	card.anchor_right = 0.92
	card.anchor_bottom = 0.96
	card.offset_left = 0.0
	card.offset_top = 0.0
	card.offset_right = 0.0
	card.offset_bottom = 0.0
	add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Key Binds"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_rows_container = VBoxContainer.new()
	_rows_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_container.add_theme_constant_override("separation", 4)
	scroll.add_child(_rows_container)

	var hint := Label.new()
	hint.text = "Click a key to remap it   |   Hold [Esc] to close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 10)
	vbox.add_child(hint)


func _process(delta: float) -> void:
	if Input.is_action_pressed("ui_cancel"):
		_escape_hold_time += delta
		if _escape_hold_time >= ESCAPE_HOLD_THRESHOLD:
			if not _rebinding_action.is_empty():
				_stop_rebinding()
			queue_free()
	else:
		if _escape_hold_time > 0.0 and not _rebinding_action.is_empty():
			_stop_rebinding()
		_escape_hold_time = 0.0


func _populate_rows() -> void:
	for action in REBINDABLE_ACTIONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var lbl := Label.new()
		lbl.text = REBINDABLE_ACTIONS[action]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(lbl)

		var btn := Button.new()
		btn.text = _get_key_label(action)
		btn.custom_minimum_size = Vector2(90, 0)
		btn.pressed.connect(_on_rebind_pressed.bind(action, btn))
		row.add_child(btn)

		_rows_container.add_child(row)


func _get_key_label(action: String) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return event.as_text_physical_keycode()
	return "Unbound"


func _on_rebind_pressed(action: String, btn: Button) -> void:
	if not _rebinding_action.is_empty():
		_stop_rebinding()
	_rebinding_action = action
	_rebinding_button = btn
	btn.text = "Press a key..."


func _input(event: InputEvent) -> void:
	if _rebinding_action.is_empty():
		return
	if not event is InputEventKey or not event.pressed:
		return
	if event.physical_keycode == KEY_ESCAPE:
		_stop_rebinding()
		get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()
	_apply_rebind(event as InputEventKey)


func _apply_rebind(event: InputEventKey) -> void:
	InputMap.action_erase_events(_rebinding_action)
	InputMap.action_add_event(_rebinding_action, event)
	user_prefs.keybinds[_rebinding_action] = event.physical_keycode
	user_prefs.save()
	_rebinding_button.text = event.as_text_physical_keycode()
	_stop_rebinding()


func _stop_rebinding() -> void:
	if not _rebinding_action.is_empty() and _rebinding_button:
		if _rebinding_button.text == "Press a key...":
			_rebinding_button.text = _get_key_label(_rebinding_action)
	_rebinding_action = ""
	_rebinding_button = null
