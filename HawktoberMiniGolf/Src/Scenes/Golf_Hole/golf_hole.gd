extends Area2D

@export var par: int = 4
@export var hole_number: int = 1

var ball_reference: RigidBody2D = null
var hole_is_complete: bool = false

signal hole_completed_display


func _ready():
	# Set the initial par for this hole
	Scoremanager.set_par(par)

	# IMPORTANT: the ball is a RigidBody2D (a physics body), so we must listen
	# to "body_entered", NOT "area_entered". "area_entered" only fires when
	# another Area2D enters, which is why the ball was never being detected.
	# Connecting here in code means you don't need any signal wired in the editor.
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	print("Hole %d ready (Par %d)" % [hole_number, par])


func _on_body_entered(body):
	# Only react to the ball, and only once per hole.
	if hole_is_complete:
		return
	if body is RigidBody2D:
		ball_reference = body
		_complete_hole()


func _complete_hole():
	if Scoremanager.hit_count == 0:
		return  # Ball is in the hole but was never actually hit — ignore.

	# Lock the hole so it can't complete twice (e.g. ball bouncing in/out).
	hole_is_complete = true

	# Record the score for this hole.
	Scoremanager.complete_hole()

	# Tell the ball the hole is done so the player can no longer hit it.
	if ball_reference and ball_reference.has_method("complete_hole"):
		ball_reference.complete_hole()

	# Show the final score. Because the level is over, we keep it on screen.
	queue_redraw()

	# Emit this so you can hook up a results screen / next-hole button elsewhere.
	hole_completed_display.emit()


func _draw():
	# Draw the score popup once the hole is complete (stays visible — level ended).
	if hole_is_complete:
		draw_score_popup()


func draw_score_popup():
	var font = get_tree().root.get_theme_default_font()
	var font_size = get_tree().root.get_theme_default_font_size() + 4

	var rating = Scoremanager.get_score_rating()
	var score_diff = Scoremanager.get_score_difference()
	var score_color = Scoremanager.get_score_color()

	# Semi-transparent background
	var popup_width = 250
	var popup_height = 120
	draw_rect(Rect2(-popup_width / 2.0, -popup_height / 2.0, popup_width, popup_height),
		Color.BLACK.lerp(Color.TRANSPARENT, 0.3))

	# Border
	draw_rect(Rect2(-popup_width / 2.0, -popup_height / 2.0, popup_width, popup_height),
		score_color, false, 3.0)

	# Text
	draw_string(font, Vector2(-100, -40), rating,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size + 2, score_color)

	var score_str = "%+d" % score_diff if score_diff != 0 else "E"
	draw_string(font, Vector2(-100, 0), "Score: %s" % score_str,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

	draw_string(font, Vector2(-100, 40), "Hole %d Complete!" % Scoremanager.holes_completed,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 2, Color.YELLOW)


# Call this to set up the next hole
func setup_next_hole(new_par: int, new_hole_number: int = 1):
	par = new_par
	hole_number = new_hole_number
	Scoremanager.set_par(par)
	Scoremanager.reset_hole()
	hole_is_complete = false
	ball_reference = null
	queue_redraw()
	print("Hole %d setup (Par %d)" % [hole_number, par])


# Reset to initial state
func reset_hole():
	Scoremanager.reset_hole()
	hole_is_complete = false
	ball_reference = null
	queue_redraw()
	print("Hole %d reset" % hole_number)
