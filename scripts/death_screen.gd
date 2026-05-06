extends Control
## Dark Souls-style death screen. Pauses the game, fades in over a few seconds,
## and offers Restart (load last save) or Quit.
class_name DeathScreen

## If no save file exists, restart loads this scene instead.
@export_file("*.tscn") var fallback_start_level: String = ""
## Total fade-in time, seconds.
@export var fade_in_duration: float = 2.5

var _restart_button: Button
var _quit_button: Button

func _ready() -> void:
	# If we're not under a CanvasLayer, wrap ourselves in one so we render above the HUD.
	if not _has_canvas_layer_ancestor():
		_wrap_in_canvas_layer.call_deferred()
		return
	_initialize()

func _initialize() -> void:
	# The screen must keep running while the rest of the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Cover the full viewport.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Background ColorRects default to mouse_filter=STOP and would absorb
	# all clicks before they reach the buttons. Force any non-Button Control
	# (ColorRects, Labels, container backgrounds) to ignore mouse input.
	_make_passthrough(self)
	_locate_and_wire_buttons()
	# Start fully transparent, fade in.
	modulate.a = 0.0
	get_tree().paused = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, fade_in_duration)
	await tween.finished
	if _restart_button:
		_restart_button.grab_focus()

func _make_passthrough(node: Node) -> void:
	# Recursively set mouse_filter=IGNORE on every Control that isn't a Button,
	# so the buttons are the only things that can intercept clicks.
	for child in node.get_children():
		if child is Control and not (child is Button):
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_make_passthrough(child)

func _locate_and_wire_buttons() -> void:
	# Find buttons by inspecting every descendant. Robust to scene-tree changes.
	var buttons: Array[Button] = []
	for n in find_children("*", "Button", true, false):
		buttons.append(n as Button)
	for btn in buttons:
		var t := btn.text.to_lower()
		var n := btn.name.to_lower()
		if _restart_button == null and ("restart" in t or "new" in t or "restart" in n or "newgame" in n or "new_game" in n):
			_restart_button = btn
		elif _quit_button == null and ("quit" in t or "exit" in t or "quit" in n or "exit" in n):
			_quit_button = btn
	# Fallback: if we still couldn't tell which is which, take the first two.
	if not _restart_button and buttons.size() > 0:
		_restart_button = buttons[0]
	if not _quit_button and buttons.size() > 1:
		_quit_button = buttons[1]
	print("[DEATH] _restart_button: ", _restart_button, " _quit_button: ", _quit_button)
	if _restart_button:
		_restart_button.disabled = false
		_restart_button.mouse_filter = Control.MOUSE_FILTER_STOP
		_restart_button.focus_mode = Control.FOCUS_ALL
		if not _restart_button.pressed.is_connected(_on_restart_pressed):
			_restart_button.pressed.connect(_on_restart_pressed)
	else:
		printerr("[DEATH] No restart button found in death screen scene")
	if _quit_button:
		_quit_button.disabled = false
		_quit_button.mouse_filter = Control.MOUSE_FILTER_STOP
		_quit_button.focus_mode = Control.FOCUS_ALL
		if not _quit_button.pressed.is_connected(_on_quit_pressed):
			_quit_button.pressed.connect(_on_quit_pressed)
	else:
		printerr("[DEATH] No quit button found in death screen scene")

func _unhandled_input(event: InputEvent) -> void:
	# Keyboard fallback in case the buttons themselves can't receive clicks.
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ENTER, KEY_KP_ENTER, KEY_R:
				_on_restart_pressed()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE, KEY_Q:
				_on_quit_pressed()
				get_viewport().set_input_as_handled()

func _has_canvas_layer_ancestor() -> bool:
	var n: Node = get_parent()
	while n:
		if n is CanvasLayer:
			return true
		n = n.get_parent()
	return false

func _wrap_in_canvas_layer() -> void:
	var p := get_parent()
	if not p:
		_initialize()
		return
	var idx := get_index()
	p.remove_child(self)
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	p.add_child(canvas)
	p.move_child(canvas, idx)
	canvas.add_child(self)
	_initialize()

func _on_restart_pressed() -> void:
	print("[DEATH] Restart pressed")
	var current_level := Globals.get_current_level()
	get_tree().paused = false
	if SaveFileManager.save_file_exists():
		DataManager.load_file_data()
		var level_to_load: String = DataManager.get_file_data().game_data.level
		if level_to_load:
			SceneManager.swap_scenes(level_to_load, get_tree().root, current_level, Const.TRANSITION.FADE_TO_BLACK)
			_close()
			return
	# No save: reset and go to the configured fallback level (typically the start screen).
	DataManager.reset_file_data()
	if not fallback_start_level.is_empty():
		SceneManager.swap_scenes(fallback_start_level, get_tree().root, current_level, Const.TRANSITION.FADE_TO_BLACK)
	_close()

func _on_quit_pressed() -> void:
	print("[DEATH] Quit pressed")
	get_tree().quit()

func _close() -> void:
	# Free the CanvasLayer wrapper too, if we were spawned wrapped (PlayerEntity does this).
	var p := get_parent()
	if p is CanvasLayer and p != get_tree().root:
		p.queue_free()
	else:
		queue_free()
