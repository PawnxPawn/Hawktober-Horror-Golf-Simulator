extends CanvasLayer


## Angle convention: 0° = right, 90° = UP, 180° = left, 270° = down.
@export var ball: Node2D
@export var protractor_texture: Texture2D
@export var arrow_texture: Texture2D
@export var dial_width: float = 190.0
@export var arrow_length: float = 0.0            # 0 = auto (reach the outer arc)
@export var arrow_angle_offset_deg: float = 0.0  # rotate if your arrow isn't "up"
@export var pivot_nudge: Vector2 = Vector2.ZERO   # move the needle's pivot point

# These MUST match the order of the enum in golfball.gd
# (IDLE = 0, IS_CHARGING = 1, HIT = 2, HOLE_COMPLETE = 3).
const STATE_IDLE := 0
const STATE_CHARGING := 1
const STATE_HIT := 2
const STATE_HOLE_COMPLETE := 3

var root: Control

# Left column
var instructions_label: Label
var angle_label: Label
var hits_label: Label

# Right column
var par_label: Label
var rating_label: Label
var score_label: Label

# Center popup
var popup: Label

# Power fill bar (bottom-right)
var power_bar: ProgressBar
var power_caption: Label
var _power_fill_style: StyleBoxFlat

# Angle dial (bottom-left)
var dial: AngleDial


func _ready() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	instructions_label = _add_label(20, Color.WHITE, false)
	angle_label        = _add_label(50, Color.WHITE, false)
	hits_label         = _add_label(80, Color.YELLOW, false)

	par_label    = _add_label(20, Color.WHITE, true)
	rating_label = _add_label(50, Color.WHITE, true)
	score_label  = _add_label(80, Color.WHITE, true)

	popup = Label.new()
	popup.set_anchors_preset(Control.PRESET_CENTER)
	popup.offset_left = -160
	popup.offset_right = 160
	popup.offset_top = -70
	popup.offset_bottom = 70
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	popup.add_theme_font_size_override("font_size", 26)
	popup.visible = false
	root.add_child(popup)

	_build_power_bar()
	_build_angle_dial()

	Scoremanager.score_changed.connect(_on_score_changed)
	Scoremanager.hole_completed.connect(_on_hole_completed)
	Scoremanager.round_reset.connect(_on_round_reset)

	_on_score_changed(Scoremanager.hit_count, Scoremanager.current_par)


func _process(_delta: float) -> void:
	_update_live_labels()


func _add_label(y: float, color: Color, align_right: bool) -> Label:
	var label := Label.new()
	root.add_child(label)
	label.anchor_top = 0.0
	label.anchor_bottom = 0.0
	label.offset_top = y
	label.offset_bottom = y + 30
	if align_right:
		label.anchor_left = 1.0
		label.anchor_right = 1.0
		label.offset_left = -220
		label.offset_right = -20
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	else:
		label.offset_left = 20
		label.offset_right = 420
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_color_override("font_color", color)
	return label


func _build_power_bar() -> void:
	power_caption = Label.new()
	root.add_child(power_caption)
	power_caption.text = "POWER"
	power_caption.anchor_left = 1.0
	power_caption.anchor_right = 1.0
	power_caption.anchor_top = 1.0
	power_caption.anchor_bottom = 1.0
	power_caption.offset_left = -220
	power_caption.offset_right = -20
	power_caption.offset_top = -76
	power_caption.offset_bottom = -52
	power_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	power_caption.add_theme_color_override("font_color", Color.WHITE)

	power_bar = ProgressBar.new()
	root.add_child(power_bar)
	power_bar.anchor_left = 1.0
	power_bar.anchor_right = 1.0
	power_bar.anchor_top = 1.0
	power_bar.anchor_bottom = 1.0
	power_bar.offset_left = -220
	power_bar.offset_right = -20
	power_bar.offset_top = -48
	power_bar.offset_bottom = -20
	power_bar.min_value = 0.0
	power_bar.max_value = 100.0
	power_bar.value = 0.0
	power_bar.show_percentage = false

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bg.set_corner_radius_all(4)
	bg.set_border_width_all(2)
	bg.border_color = Color(1, 1, 1, 0.6)
	power_bar.add_theme_stylebox_override("background", bg)

	_power_fill_style = StyleBoxFlat.new()
	_power_fill_style.bg_color = Color.GREEN
	_power_fill_style.set_corner_radius_all(3)
	power_bar.add_theme_stylebox_override("fill", _power_fill_style)

	_set_power_bar_visible(false)


func _build_angle_dial() -> void:
	var w := dial_width
	var h := w * 0.6
	if protractor_texture:
		var ts := protractor_texture.get_size()
		if ts.x > 0.0:
			h = w * (ts.y / ts.x)

	dial = AngleDial.new()
	dial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dial.texture = protractor_texture
	dial.arrow_texture = arrow_texture
	dial.arrow_length = arrow_length
	dial.arrow_angle_offset_deg = arrow_angle_offset_deg
	dial.pivot_nudge = pivot_nudge
	dial.anchor_left = 0.0
	dial.anchor_right = 0.0
	dial.anchor_top = 1.0
	dial.anchor_bottom = 1.0
	dial.offset_left = 20
	dial.offset_right = 20 + w
	dial.offset_top = -(h + 15)
	dial.offset_bottom = -15
	root.add_child(dial)
	dial.visible = false


func _set_power_bar_visible(v: bool) -> void:
	power_bar.visible = v
	power_caption.visible = v


func _update_power_bar() -> void:
	var ratio: float = clamp(ball.power / ball.max_power, 0.0, 1.0)
	power_bar.value = ratio * 100.0
	if ratio < 0.5:
		_power_fill_style.bg_color = Color.GREEN.lerp(Color.YELLOW, ratio * 2.0)
	else:
		_power_fill_style.bg_color = Color.YELLOW.lerp(Color.RED, (ratio - 0.5) * 2.0)


func _update_live_labels() -> void:
	if ball == null:
		return

	var state: int = ball.ball_state
	var aiming := state == STATE_IDLE or state == STATE_CHARGING

	var disp_angle: float = fmod(ball.angle, 360.0)
	if disp_angle < 0.0:
		disp_angle += 360.0

	if state == STATE_CHARGING:
		instructions_label.text = ""
		angle_label.text = "Angle: %.0f°" % disp_angle
		_set_power_bar_visible(true)
		_update_power_bar()
	elif state == STATE_IDLE:
		instructions_label.text = "SPACE: hit  |  ↑/↓: Power  |  ←/→: Angle"
		angle_label.text = "Angle: %.0f°" % disp_angle
		_set_power_bar_visible(false)
	else:
		instructions_label.text = ""
		angle_label.text = ""
		_set_power_bar_visible(false)

	dial.visible = aiming
	if aiming:
		dial.current_angle = ball.angle
		dial.queue_redraw()


func _on_score_changed(new_hits: int, par: int) -> void:
	hits_label.text = "Hits: %d / Par %d" % [new_hits, par]
	par_label.text = "Par: %d" % par

	if new_hits > 0:
		var color: Color = Scoremanager.get_score_color()
		rating_label.text = Scoremanager.get_score_rating()
		rating_label.add_theme_color_override("font_color", color)
		var diff: int = Scoremanager.get_score_difference()
		var score_str: String = "%+d" % diff if diff != 0 else "E"
		score_label.text = "Score: %s" % score_str
		score_label.add_theme_color_override("font_color", color)
	else:
		rating_label.text = ""
		score_label.text = ""


func _on_hole_completed(rating: String, score_diff: int) -> void:
	var score_str: String = "%+d" % score_diff if score_diff != 0 else "E"
	popup.text = "%s\nScore: %s\nHole %d Complete!" % [
		rating, score_str, Scoremanager.holes_completed
	]
	popup.add_theme_color_override("font_color", Scoremanager.get_score_color())
	popup.visible = true


func _on_round_reset() -> void:
	popup.visible = false
	_set_power_bar_visible(false)
	dial.visible = false
	_on_score_changed(0, Scoremanager.current_par)



class AngleDial extends Control:
	var current_angle: float = 0.0
	var texture: Texture2D = null            # protractor image
	var arrow_texture: Texture2D = null      # arrow / needle image (points UP)
	var arrow_length: float = 0.0            # 0 = auto
	var arrow_angle_offset_deg: float = 0.0
	var pivot_nudge: Vector2 = Vector2.ZERO

	func _draw() -> void:
		var r: float = min(size.x * 0.5, size.y) - 8.0
		var c: Vector2

		if texture:
			draw_texture_rect(texture, Rect2(Vector2.ZERO, size), false)
			c = Vector2(size.x * 0.5, size.y) + pivot_nudge
		else:
			c = Vector2(size.x * 0.5, size.y - 8.0) + pivot_nudge
			_draw_protractor(c, r)

		# up = 90 convention: negate the y term so 90° points up.
		var a := deg_to_rad(current_angle)
		var dir := Vector2(cos(a), -sin(a))

		if arrow_texture:
			_draw_arrow_texture(c, r, dir)
		else:
			_draw_needle(c, r, dir)

	func _draw_protractor(c: Vector2, r: float) -> void:
		draw_line(c + Vector2(-r - 6, 0), c + Vector2(r + 6, 0),
			Color(0.82, 0.82, 0.82, 0.95), 6.0)
		draw_arc(c, r,        PI, TAU, 48, Color(0.85, 0.50, 0.62), 3.0)
		draw_arc(c, r * 0.68, PI, TAU, 48, Color(0.62, 0.45, 0.80), 3.0)
		draw_arc(c, r * 0.38, PI, TAU, 48, Color(0.45, 0.55, 0.85), 3.0)
		var tick_col := Color(0.85, 0.85, 0.85, 0.9)
		var deg := 180.0
		while deg <= 360.0:
			var rad := deg_to_rad(deg)
			var d := Vector2(cos(rad), sin(rad))
			draw_line(c + d * (r + 2.0), c + d * (r + 10.0), tick_col, 2.0)
			deg += 15.0

	func _draw_arrow_texture(c: Vector2, r: float, dir: Vector2) -> void:
		var ts := arrow_texture.get_size()
		if ts.y <= 0.0:
			return
		var length: float = arrow_length if arrow_length > 0.0 else r
		var scl: float = length / ts.y
		# Arrow image is assumed to point UP, so add 90° to align with "dir".
		var rot: float = dir.angle() + PI / 2.0 + deg_to_rad(arrow_angle_offset_deg)
		draw_set_transform(c, rot, Vector2(scl, scl))
		# Base-center on the pivot, tip extending upward (-Y) before rotation.
		draw_texture(arrow_texture, Vector2(-ts.x * 0.5, -ts.y))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)  # reset

	func _draw_needle(c: Vector2, r: float, dir: Vector2) -> void:
		var perp := Vector2(-dir.y, dir.x)
		var tip := c + dir * (r - 4.0)
		var head_len := 14.0
		var head_w := 8.0
		var base := tip - dir * head_len
		var needle := Color(1.0, 0.85, 0.2)
		draw_line(c, base, needle, 4.0)
		draw_colored_polygon(
			PackedVector2Array([tip, base + perp * head_w, base - perp * head_w]),
			needle
		)
		draw_circle(c, 5.0, Color.WHITE)
