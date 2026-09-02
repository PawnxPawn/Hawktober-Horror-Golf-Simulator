extends MoveablePanel

@onready var output: RichTextLabel = %Output
@onready var input_field: LineEdit = %Input
@onready var layout_container: VBoxContainer = $Layout

var history: PackedStringArray = []
var history_index: int = -1

var _completion_matches: PackedStringArray = []
var _completion_index: int = -1

const _EXEMPT_ACTIONS: PackedStringArray = ["Debug", "DebugTerminal"]
const _EXEMPT_ACTION_PREFIXES: PackedStringArray = ["ui_"]


func _ready() -> void:
	drag_handle_text = "\u283f Terminal (drag to move)"
	_default_font_size = 14

	super._ready()

	call_deferred("_place_bottom_left")

	input_field.text_submitted.connect(_on_submitted)
	DebugRegistry.settings_changed.connect(_on_settings_changed)
	DebugRegistry.log_line.connect(func(text: String) -> void:
		output.append_text(text.strip_edges(true, false).strip_edges(false, true).rstrip("\n") + "\n")
	)
	DebugRegistry.log_cleared.connect(output.clear)
	_add_submit_button()


func _place_bottom_left() -> void:
	var vp: Rect2 = get_viewport().get_visible_rect()
	apply_viewport_percentage(0.40, 0.25, "bottom_left")
	var scaled_font: int = apply_viewport_font_scale(14, 1.00)
	_apply_font_size(scaled_font)
	global_position = Vector2(20, vp.size.y - size.y - 20)


func toggle() -> void:
	visible = not visible
	if visible:
		focus_input()
	else:
		input_field.release_focus()


func focus_input() -> void:
	input_field.grab_focus()
	call_deferred("_enter_edit_mode")


func _enter_edit_mode() -> void:
	input_field.edit()


func _process(_delta: float) -> void:
	if not input_field.has_focus():
		return
	for action: StringName in InputMap.get_actions():
		if _is_exempt_action(action):
			continue
		if Input.is_action_pressed(action):
			Input.action_release(action)


func _is_exempt_action(action: StringName) -> bool:
	if action in _EXEMPT_ACTIONS:
		return true
	for prefix: String in _EXEMPT_ACTION_PREFIXES:
		if String(action).begins_with(prefix):
			return true
	return false


func _input(event: InputEvent) -> void:
	super._input(event)

	if not visible or not (event is InputEventKey):
		return

	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed:
		return

	if key_event.keycode == KEY_UP:
		_history_navigate(-1)
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_DOWN:
		_history_navigate(1)
	elif key_event.keycode == KEY_TAB:
		_autocomplete()
		get_viewport().set_input_as_handled()
	else:
		_completion_matches.clear()
		_completion_index = -1


func _on_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	history.append(text)
	history_index = history.size()
	DebugRegistry.log_message("> %s" % text, Color.GRAY)
	DebugRegistry.execute(text)
	input_field.clear()
	focus_input()


func _history_navigate(direction: int) -> void:
	if history.is_empty():
		return
	history_index = clampi(history_index + direction, 0, history.size() - 1)
	input_field.text = history[history_index]
	input_field.caret_column = input_field.text.length()


#region Submit Button

func _add_submit_button() -> void:
	var parent: Node = input_field.get_parent()
	var input_index: int = input_field.get_index()

	var row: HBoxContainer = HBoxContainer.new()
	parent.add_child(row)
	parent.move_child(row, input_index)

	parent.remove_child(input_field)
	row.add_child(input_field)
	input_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var submit_button: Button = Button.new()
	submit_button.text = "Submit"
	submit_button.pressed.connect(func() -> void:
		_on_submitted(input_field.text)
	)
	row.add_child(submit_button)

#endregion


#region Tab Completion

func _autocomplete() -> void:
	var prefix: String = input_field.text
	if prefix.is_empty():
		return

	if _completion_matches.is_empty():
		var candidates: Array[String] = []
		candidates.append_array(DebugRegistry.commands.keys())
		candidates.append_array(DebugRegistry.aliases.keys())
		candidates.sort()
		for candidate: String in candidates:
			if candidate.begins_with(prefix):
				_completion_matches.append(candidate)
		_completion_index = -1

	if _completion_matches.is_empty():
		return

	_completion_index = (_completion_index + 1) % _completion_matches.size()
	input_field.text = _completion_matches[_completion_index]
	input_field.caret_column = input_field.text.length()

#endregion


#region Panel Overrides

func _place_drag_handle() -> void:
	if drag_handle:
		layout_container.add_child(drag_handle)
		layout_container.move_child(drag_handle, 0)


func apply_default_layout() -> void:
	size = Vector2(600, 250)
	var vp: Rect2 = get_viewport().get_visible_rect()
	global_position = Vector2(20, vp.size.y - size.y - 20)


func _apply_font_size(font_size: int) -> void:
	super._apply_font_size(font_size)
	output.add_theme_font_size_override("normal_font_size", font_size)
	output.add_theme_font_size_override("bold_font_size", font_size)
	output.add_theme_font_size_override("italics_font_size", font_size)
	input_field.add_theme_font_size_override("font_size", font_size)


func _on_settings_changed(name: StringName, value: Variant) -> void:
	match name:
		&"DebugTerminal.opacity":
			_apply_opacity(float(value))
		&"DebugTerminal.font_size":
			var scaled: int = compute_scaled_font_size(int(value))
			_apply_font_size(scaled)


func _apply_appearance() -> void:
	var saved: int = DebugRegistry.load_appearance_setting("DebugTerminal.font_size", 14)
	var scaled: int = compute_scaled_font_size(saved)
	_apply_font_size(scaled)
	var opacity: float = DebugRegistry.load_appearance_setting("DebugTerminal.opacity", 1.0)
	_apply_opacity(opacity)

#endregion

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		var saved: int = DebugRegistry.load_appearance_setting("%s.font_size" % name, _default_font_size)
		var scaled: int = compute_scaled_font_size(saved)
		_apply_font_size(scaled)
