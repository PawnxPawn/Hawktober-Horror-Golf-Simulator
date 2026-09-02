extends MoveablePanel
class_name DebugSettingsPanel

@onready var root: VBoxContainer = %Root
@onready var body: VBoxContainer = %Body

@onready var terminal_opacity_slider: HSlider = %TerminalOpacitySlider
@onready var terminal_font_slider: HSlider = %TerminalFontSlider
@onready var terminal_reset_button: Button = %TerminalResetButton

@onready var stats_opacity_slider: HSlider = %StatsOpacitySlider
@onready var stats_font_slider: HSlider = %StatsFontSlider
@onready var stats_reset_button: Button = %StatsResetButton

@onready var reset_all_button: Button = %ResetAllButton

var collapse_button: Button
var collapsed: bool = false
var _expanded_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	drag_handle_text = "\u283f Settings (drag to move)"
	_default_font_size = 14

	super._ready()

	call_deferred("_place_on_right")

	_add_collapse_button()
	_load_collapsed_state()

	terminal_opacity_slider.value_changed.connect(_on_terminal_opacity_changed)
	terminal_font_slider.value_changed.connect(_on_terminal_font_changed)
	terminal_reset_button.pressed.connect(_on_terminal_reset_pressed)

	stats_opacity_slider.value_changed.connect(_on_stats_opacity_changed)
	stats_font_slider.value_changed.connect(_on_stats_font_changed)
	stats_reset_button.pressed.connect(_on_stats_reset_pressed)

	reset_all_button.pressed.connect(_on_reset_all_pressed)

	DebugRegistry.appearance_changed.connect(_on_external_appearance_changed)

	_load_values()


func _place_on_right() -> void:
	var vp_width: float = get_viewport().get_visible_rect().size.x
	apply_viewport_percentage(0.30, 0.40, "top_right")
	var saved: int = DebugRegistry.load_appearance_setting("DebugSettingsPanel.font_size", 14)
	var scaled: int = compute_scaled_font_size(saved)
	_apply_font_size(scaled)

	global_position = Vector2(vp_width - size.x - 10, 10)


func _apply_font_size(font_size: int) -> void:
	super._apply_font_size(font_size)
	if root:
		root.add_theme_font_size_override("font_size", font_size)
	if body:
		body.add_theme_font_size_override("font_size", font_size)


func _place_drag_handle() -> void:
	if drag_handle:
		root.add_child(drag_handle)
		root.move_child(drag_handle, 0)


func apply_default_layout() -> void:
	global_position = Vector2(440, 20)
	size = Vector2(340, 260)


func _add_collapse_button() -> void:
	collapse_button = Button.new()
	collapse_button.text = "\u25be"
	collapse_button.focus_mode = Control.FOCUS_NONE
	collapse_button.custom_minimum_size = Vector2(28, 0)
	collapse_button.pressed.connect(_on_collapse_pressed)
	drag_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drag_handle.add_child(collapse_button)
	drag_handle.move_child(collapse_button, 1)


func _on_collapse_pressed() -> void:
	collapsed = not collapsed
	body.visible = not collapsed
	collapse_button.text = "\u25b8" if collapsed else "\u25be"
	DebugRegistry.save_appearance_setting("DebugSettingsPanel.collapsed", collapsed)
	_apply_collapsed_size()


func _load_collapsed_state() -> void:
	collapsed = bool(DebugRegistry.load_appearance_setting("DebugSettingsPanel.collapsed", false))
	body.visible = not collapsed
	collapse_button.text = "\u25b8" if collapsed else "\u25be"
	_apply_collapsed_size()


func _apply_collapsed_size() -> void:
	if collapsed:
		_expanded_size = size
		call_deferred("_shrink_to_collapsed_size")
	else:
		if _expanded_size != Vector2.ZERO:
			size = _expanded_size
		DebugRegistry.save_panel_size(name, size)


func _shrink_to_collapsed_size() -> void:
	size = Vector2(size.x, get_combined_minimum_size().y)


func _on_terminal_opacity_changed(value: float) -> void:
	DebugRegistry.save_appearance_setting("DebugTerminal.opacity", value)
	DebugRegistry.settings_changed.emit(&"DebugTerminal.opacity", value)
	DebugRegistry.appearance_changed.emit("DebugTerminal")


func _on_terminal_font_changed(value: float) -> void:
	DebugRegistry.save_appearance_setting("DebugTerminal.font_size", int(value))
	DebugRegistry.settings_changed.emit(&"DebugTerminal.font_size", int(value))
	DebugRegistry.appearance_changed.emit("DebugTerminal")


func _on_terminal_reset_pressed() -> void:
	DebugRegistry.remove_appearance_settings_for_panel("DebugTerminal")
	_load_values()


func _on_stats_opacity_changed(value: float) -> void:
	DebugRegistry.save_appearance_setting("DebugStatsPanel.opacity", value)
	DebugRegistry.settings_changed.emit(&"DebugStatsPanel.opacity", value)
	DebugRegistry.appearance_changed.emit("DebugStatsPanel")


func _on_stats_font_changed(value: float) -> void:
	DebugRegistry.save_appearance_setting("DebugStatsPanel.font_size", int(value))
	DebugRegistry.settings_changed.emit(&"DebugStatsPanel.font_size", int(value))
	DebugRegistry.appearance_changed.emit("DebugStatsPanel")


func _on_stats_reset_pressed() -> void:
	DebugRegistry.remove_appearance_settings_for_panel("DebugStatsPanel")
	_load_values()


func _on_reset_all_pressed() -> void:
	DebugRegistry.clear_appearance_settings()
	_load_values()


func _on_external_appearance_changed(panel_name: String) -> void:
	if panel_name == "DebugTerminal" or panel_name == "DebugStatsPanel":
		_load_values()


func _load_values() -> void:
	terminal_opacity_slider.set_value(float(DebugRegistry.load_appearance_setting("DebugTerminal.opacity", 1.0)))
	terminal_font_slider.set_value(float(DebugRegistry.load_appearance_setting("DebugTerminal.font_size", 14)))
	stats_opacity_slider.set_value(float(DebugRegistry.load_appearance_setting("DebugStatsPanel.opacity", 1.0)))
	stats_font_slider.set_value(float(DebugRegistry.load_appearance_setting("DebugStatsPanel.font_size", 16)))


func _apply_appearance() -> void:
	var saved: int = DebugRegistry.load_appearance_setting("DebugSettingsPanel.font_size", 14)
	var scaled: int = compute_scaled_font_size(saved)
	_apply_font_size(scaled)
	var opacity: float = DebugRegistry.load_appearance_setting("DebugSettingsPanel.opacity", 1.0)
	_apply_opacity(opacity)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		var saved: int = DebugRegistry.load_appearance_setting("%s.font_size" % name, _default_font_size)
		var scaled: int = compute_scaled_font_size(saved)
		_apply_font_size(scaled)
