class_name MoveablePanel
extends PanelContainer

enum ResizeEdge { NONE, LEFT, RIGHT, TOP, BOTTOM, TOP_LEFT, TOP_RIGHT, BOTTOM_LEFT, BOTTOM_RIGHT }

const _EDGE_MARGIN: float = 7.0
const _MIN_SIZE: Vector2 = Vector2(220, 120)

var drag_handle_text: String = "\u283f (drag to move)"
var _default_font_size: int = 14

var drag_handle: HBoxContainer
var drag_label: Label
var resize_toggle_button: Button

var _drag_offset: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _resize_mode: bool = false

@export var default_position: Vector2 = Vector2(-1, -1)
@export var default_size: Vector2 = Vector2(-1, -1)

var _default_position: Vector2 = Vector2.ZERO
var _default_size: Vector2 = Vector2.ZERO

var _resize_overlay: Control

var _resize_edge: int = ResizeEdge.NONE
var _resize_start_mouse: Vector2 = Vector2.ZERO
var _resize_start_position: Vector2 = Vector2.ZERO
var _resize_start_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	set_offsets_preset(Control.PRESET_TOP_LEFT)

	if default_position != Vector2(-1, -1):
		_default_position = default_position
	else:
		_default_position = global_position

	if default_size != Vector2(-1, -1):
		_default_size = default_size
	else:
		_default_size = size

	_build_resize_handles()
	_build_drag_handle()
	_place_drag_handle()

	_restore_saved_position()
	_restore_saved_size()

	_apply_appearance()

	mouse_entered.connect(_on_panel_mouse_entered)
	mouse_exited.connect(_on_panel_mouse_exited)


func _build_drag_handle() -> void:
	drag_handle = HBoxContainer.new()
	drag_handle.mouse_filter = Control.MOUSE_FILTER_STOP
	drag_handle.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	drag_label = Label.new()
	drag_label.text = drag_handle_text
	drag_label.mouse_filter = Control.MOUSE_FILTER_STOP
	drag_label.mouse_default_cursor_shape = Control.CURSOR_MOVE
	drag_label.add_theme_color_override("font_color", Color.YELLOW)
	drag_label.gui_input.connect(_on_drag_label_input)

	resize_toggle_button = Button.new()
	resize_toggle_button.text = "\u21f2"
	resize_toggle_button.focus_mode = Control.FOCUS_NONE
	resize_toggle_button.mouse_filter = Control.MOUSE_FILTER_STOP
	resize_toggle_button.tooltip_text = "Toggle Resize Mode"
	resize_toggle_button.pressed.connect(_on_resize_toggle_pressed)

	drag_handle.add_child(drag_label)
	drag_handle.add_child(resize_toggle_button)


func _place_drag_handle() -> void:
	if drag_handle.get_parent() != self:
		add_child(drag_handle)
	if drag_handle.get_parent() == self:
		move_child(drag_handle, get_child_count() - 1)


func _on_resize_toggle_pressed() -> void:
	_resize_mode = not _resize_mode
	if _resize_mode:
		resize_toggle_button.text = "\u2b1a"
		_set_resize_handles_visible(true)
	else:
		resize_toggle_button.text = "\u21f2"
		_resize_edge = ResizeEdge.NONE
		_set_resize_handles_visible(false)


func _on_drag_label_input(event: InputEvent) -> void:
	if _resize_mode:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_resize_edge = ResizeEdge.RIGHT
			_resize_start_mouse = get_viewport().get_mouse_position()
			_resize_start_position = global_position
			_resize_start_size = size
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_dragging = true
		_drag_offset = global_position - get_viewport().get_mouse_position()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		var panel_rect: Rect2 = Rect2(global_position, size)
		if not panel_rect.has_point(mouse_pos):
			if _resize_mode:
				_resize_mode = false
				_resize_edge = ResizeEdge.NONE
				if resize_toggle_button:
					resize_toggle_button.text = "\u21f2"
				_set_resize_handles_visible(false)
			if _dragging:
				_dragging = false
			return

	if _resize_edge != ResizeEdge.NONE:
		_handle_resize_input(event)
		return

	if _dragging:
		_handle_drag_input(event)
		return


func _handle_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse: Vector2 = get_viewport().get_mouse_position()
		var target: Vector2 = mouse + _drag_offset

		var vp: Rect2 = get_viewport().get_visible_rect()
		target.x = clamp(target.x, vp.position.x, vp.position.x + vp.size.x - size.x)
		target.y = clamp(target.y, vp.position.y, vp.position.y + vp.size.y - size.y)

		global_position = target
		DebugRegistry.save_panel_position(name, global_position)
		get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dragging = false
		get_viewport().set_input_as_handled()


func _restore_saved_position() -> void:
	var saved: Variant = DebugRegistry.load_panel_position(name)
	if saved != null:
		global_position = saved


func _restore_saved_size() -> void:
	var saved: Variant = DebugRegistry.load_panel_size(name)
	if saved != null:
		size = saved


func _on_layout_reset() -> void:
	apply_default_layout()


func _build_resize_handles() -> void:
	_resize_overlay = Control.new()
	_resize_overlay.name = "ResizeOverlay"
	_resize_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resize_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_resize_overlay)

	_add_resize_handle(ResizeEdge.LEFT, Control.CURSOR_HSIZE)
	_add_resize_handle(ResizeEdge.RIGHT, Control.CURSOR_HSIZE)
	_add_resize_handle(ResizeEdge.TOP, Control.CURSOR_VSIZE)
	_add_resize_handle(ResizeEdge.BOTTOM, Control.CURSOR_VSIZE)
	_add_resize_handle(ResizeEdge.TOP_LEFT, Control.CURSOR_FDIAGSIZE)
	_add_resize_handle(ResizeEdge.TOP_RIGHT, Control.CURSOR_BDIAGSIZE)
	_add_resize_handle(ResizeEdge.BOTTOM_LEFT, Control.CURSOR_BDIAGSIZE)
	_add_resize_handle(ResizeEdge.BOTTOM_RIGHT, Control.CURSOR_FDIAGSIZE)


func _add_resize_handle(edge: int, cursor_shape: Control.CursorShape) -> void:
	var handle: Control = Control.new()
	handle.name = "resize_handle_%d" % int(edge)
	handle.set_meta("edge", int(edge))
	handle.visible = false
	handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	handle.mouse_default_cursor_shape = cursor_shape
	_layout_resize_handle(handle, edge)
	handle.gui_input.connect(_on_resize_handle_gui_input.bind(edge))
	handle.mouse_entered.connect(func() -> void:
		handle.mouse_filter = Control.MOUSE_FILTER_STOP
	)
	handle.mouse_exited.connect(func() -> void:
		if not _resize_mode:
			handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	)
	_resize_overlay.add_child(handle)


func _layout_resize_handle(handle: Control, edge: int) -> void:
	var bar_thickness: int = 8

	match edge:
		ResizeEdge.LEFT:
			handle.set_anchors_preset(Control.PRESET_LEFT_WIDE)
			handle.offset_left = _EDGE_MARGIN
			handle.offset_right = _EDGE_MARGIN + bar_thickness
			handle.offset_top = _EDGE_MARGIN
			handle.offset_bottom = -_EDGE_MARGIN

		ResizeEdge.RIGHT:
			handle.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
			handle.offset_left = -(_EDGE_MARGIN + bar_thickness)
			handle.offset_right = -_EDGE_MARGIN
			handle.offset_top = _EDGE_MARGIN
			handle.offset_bottom = -_EDGE_MARGIN

		ResizeEdge.TOP:
			handle.set_anchors_preset(Control.PRESET_TOP_WIDE)
			handle.offset_top = _EDGE_MARGIN
			handle.offset_bottom = _EDGE_MARGIN + bar_thickness
			handle.offset_left = _EDGE_MARGIN
			handle.offset_right = -_EDGE_MARGIN

		ResizeEdge.BOTTOM:
			handle.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			handle.offset_top = -(_EDGE_MARGIN + bar_thickness)
			handle.offset_bottom = -_EDGE_MARGIN
			handle.offset_left = _EDGE_MARGIN
			handle.offset_right = -_EDGE_MARGIN

		ResizeEdge.TOP_LEFT:
			handle.set_anchors_preset(Control.PRESET_TOP_LEFT)
			handle.offset_left = _EDGE_MARGIN
			handle.offset_top = _EDGE_MARGIN
			handle.offset_right = _EDGE_MARGIN + bar_thickness
			handle.offset_bottom = _EDGE_MARGIN + bar_thickness

		ResizeEdge.TOP_RIGHT:
			handle.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			handle.offset_left = -(_EDGE_MARGIN + bar_thickness)
			handle.offset_top = _EDGE_MARGIN
			handle.offset_right = -_EDGE_MARGIN
			handle.offset_bottom = _EDGE_MARGIN + bar_thickness

		ResizeEdge.BOTTOM_LEFT:
			handle.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
			handle.offset_left = _EDGE_MARGIN
			handle.offset_top = -(_EDGE_MARGIN + bar_thickness)
			handle.offset_right = _EDGE_MARGIN + bar_thickness
			handle.offset_bottom = -_EDGE_MARGIN

		ResizeEdge.BOTTOM_RIGHT:
			handle.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			handle.offset_left = -(_EDGE_MARGIN + bar_thickness)
			handle.offset_top = -(_EDGE_MARGIN + bar_thickness)
			handle.offset_right = -_EDGE_MARGIN
			handle.offset_bottom = -_EDGE_MARGIN


func _on_resize_handle_gui_input(event: InputEvent, edge: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_resize_edge = edge
		_resize_start_mouse = get_viewport().get_mouse_position()
		_resize_start_position = global_position
		_resize_start_size = size
		get_viewport().set_input_as_handled()


func _handle_resize_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_apply_resize(get_viewport().get_mouse_position() - _resize_start_mouse)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_resize_edge = ResizeEdge.NONE
		if not _resize_mode:
			_set_resize_handles_visible(false)
		get_viewport().set_input_as_handled()


func _apply_resize(mouse_delta: Vector2) -> void:
	var left: float = _resize_start_position.x
	var top: float = _resize_start_position.y
	var right: float = _resize_start_position.x + _resize_start_size.x
	var bottom: float = _resize_start_position.y + _resize_start_size.y

	var affects_left: bool = _resize_edge in [ResizeEdge.LEFT, ResizeEdge.TOP_LEFT, ResizeEdge.BOTTOM_LEFT]
	var affects_right: bool = _resize_edge in [ResizeEdge.RIGHT, ResizeEdge.TOP_RIGHT, ResizeEdge.BOTTOM_RIGHT]
	var affects_top: bool = _resize_edge in [ResizeEdge.TOP, ResizeEdge.TOP_LEFT, ResizeEdge.TOP_RIGHT]
	var affects_bottom: bool = _resize_edge in [ResizeEdge.BOTTOM, ResizeEdge.BOTTOM_LEFT, ResizeEdge.BOTTOM_RIGHT]

	if affects_left:
		left = min(_resize_start_position.x + mouse_delta.x, right - _MIN_SIZE.x)
	if affects_right:
		right = max(_resize_start_position.x + _resize_start_size.x + mouse_delta.x, left + _MIN_SIZE.x)
	if affects_top:
		top = min(_resize_start_position.y + mouse_delta.y, bottom - _MIN_SIZE.y)
	if affects_bottom:
		bottom = max(_resize_start_position.y + _resize_start_size.y + mouse_delta.y, top + _MIN_SIZE.y)

	var vp: Rect2 = get_viewport().get_visible_rect()
	left = max(left, vp.position.x)
	top = max(top, vp.position.y)
	right = min(right, vp.position.x + vp.size.x)
	bottom = min(bottom, vp.position.y + vp.size.y)

	global_position = Vector2(left, top)
	size = Vector2(right - left, bottom - top)

	DebugRegistry.save_panel_position(name, global_position)
	DebugRegistry.save_panel_size(name, size)


func _set_resize_handles_visible(visible: bool) -> void:
	for child: Node in _resize_overlay.get_children():
		if child is Control:
			child.visible = visible
			child.mouse_filter = Control.MOUSE_FILTER_STOP if visible else Control.MOUSE_FILTER_IGNORE


func _on_panel_mouse_entered() -> void:
	if not _resize_mode:
		_set_resize_handles_visible(true)


func _on_panel_mouse_exited() -> void:
	if not _resize_mode:
		_set_resize_handles_visible(false)
	_resize_edge = ResizeEdge.NONE
	_dragging = false


func apply_default_layout() -> void:
	call_deferred("_apply_default_layout_deferred")


func _apply_default_layout_deferred() -> void:
	if _default_position != Vector2(-1, -1):
		global_position = _default_position
	if _default_size != Vector2(-1, -1):
		size = _default_size

	DebugRegistry.save_panel_position(name, global_position)
	DebugRegistry.save_panel_size(name, size)


func _on_appearance_changed(panel_name: String) -> void:
	if panel_name == name:
		_apply_appearance()


func _apply_appearance() -> void:
	_apply_font_size(_current_font_size())
	var opacity: float = DebugRegistry.load_appearance_setting("%s.opacity" % name, 1.0)
	_apply_opacity(opacity)


func _current_font_size() -> int:
	var font_size: int = DebugRegistry.load_appearance_setting("%s.font_size" % name, _default_font_size)
	return font_size


func apply_viewport_percentage(width_pct: float, height_pct: float, anchor: String = "bottom_left", margin: float = 20.0) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	size = Vector2(vp.x * width_pct, vp.y * height_pct)

	match anchor:
		"bottom_left":
			global_position = Vector2(margin, vp.y - size.y - margin)
		"bottom_right":
			global_position = Vector2(vp.x - size.x - margin, vp.y - size.y - margin)
		"top_left":
			global_position = Vector2(margin, margin)
		"top_right":
			global_position = Vector2(vp.x - size.x - margin, margin)
		_:
			global_position = Vector2(margin, margin)


func apply_viewport_font_scale(base_size: int, height_pct: float) -> int:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	return int(round(base_size * (vp.y * height_pct) / 1000.0))


func _apply_font_size(font_size: int) -> void:
	if drag_label:
		drag_label.add_theme_font_size_override("font_size", font_size)


func _apply_opacity(alpha: float) -> void:
	var base: StyleBox = get_theme_stylebox("panel")
	var style: StyleBoxFlat
	if base is StyleBoxFlat:
		style = base.duplicate() as StyleBoxFlat
	else:
		style = StyleBoxFlat.new()
	var bg: Color = style.bg_color
	bg.a = alpha
	style.bg_color = bg
	add_theme_stylebox_override("panel", style)


func compute_scaled_font_size(base_size: int) -> int:
	var ui_scale: float = DebugRegistry.load_appearance_setting("global.ui_scale", 1.0)
	var vp: float = get_viewport().get_visible_rect().size.y
	var viewport_factor: float = vp / 1000.0
	return int(round(base_size * ui_scale * viewport_factor))
