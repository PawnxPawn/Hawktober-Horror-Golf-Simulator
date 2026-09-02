extends MoveablePanel

@onready var stats_container: VBoxContainer = %Stats

const DEFAULT_FONT_SIZE: int = 16

var labels: Dictionary[String, Label] = {}
var current_font_size: int = DEFAULT_FONT_SIZE


func _ready() -> void:
	drag_handle_text = "\u283f Stats (drag to move)"
	_default_font_size = 16
	super._ready()

	global_position = Vector2(20, 20)

	DebugRegistry.settings_changed.connect(_on_settings_changed)
	DebugRegistry.label_updated.connect(_on_label_updated)
	DebugRegistry.label_removed.connect(_on_label_removed)


func _on_label_updated(id: String, value: Variant, color: Color) -> void:
	if not labels.has(id):
		var label: Label = Label.new()
		label.name = id
		label.add_theme_font_size_override("font_size", _current_font_size())
		stats_container.add_child(label)
		labels[id] = label
	labels[id].text = "%s: %s" % [id, str(value)]
	if color == Color.WHITE:
		labels[id].remove_theme_color_override("font_color")
	else:
		labels[id].add_theme_color_override("font_color", color)
	var saved: int = DebugRegistry.load_appearance_setting("DebugStatsPanel.font_size", 16)
	var scaled: int = compute_scaled_font_size(saved)
	_apply_font_size(scaled)


func _on_label_removed(id: String) -> void:
	if labels.has(id):
		labels[id].queue_free()
		labels.erase(id)


func _place_drag_handle() -> void:
	if drag_handle:
		stats_container.add_child(drag_handle)
		stats_container.move_child(drag_handle, 0)


func apply_default_layout() -> void:
	global_position = Vector2(20, 20)
	apply_viewport_percentage(0.25, 0.30, "top_left")
	var scaled_font: int = apply_viewport_font_scale(16, 1.0)
	_apply_font_size(scaled_font)


func _apply_font_size(font_size: int) -> void:
	super._apply_font_size(font_size)
	for label_name: String in labels:
		labels[label_name].add_theme_font_size_override("font_size", font_size)


func _on_settings_changed(name: StringName, value: Variant) -> void:
	match name:
		&"DebugStatsPanel.opacity":
			_apply_opacity(float(value))
		&"DebugStatsPanel.font_size":
			var scaled: int = compute_scaled_font_size(int(value))
			_apply_font_size(scaled)


func _apply_appearance() -> void:
	var saved: int = DebugRegistry.load_appearance_setting("DebugStatsPanel.font_size", 16)
	var scaled: int = compute_scaled_font_size(saved)
	_apply_font_size(scaled)
	var opacity: float = DebugRegistry.load_appearance_setting("DebugStatsPanel.opacity", 1.0)
	_apply_opacity(opacity)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		var saved: int = DebugRegistry.load_appearance_setting("%s.font_size" % name, _default_font_size)
		var scaled: int = compute_scaled_font_size(saved)
		_apply_font_size(scaled)
