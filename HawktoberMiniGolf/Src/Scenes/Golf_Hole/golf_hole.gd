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

	# Record the score for this hole. This emits Scoremanager.hole_completed,
	# which the HUD listens to and shows the "Hole Complete!" popup as UI text.
	Scoremanager.complete_hole()

	# Tell the ball the hole is done so the player can no longer hit it.
	if ball_reference and ball_reference.has_method("complete_hole"):
		ball_reference.complete_hole()

	# Emit this so you can hook up a results screen / next-hole button elsewhere.
	hole_completed_display.emit()


# Call this to set up the next hole
func setup_next_hole(new_par: int, new_hole_number: int = 1):
	par = new_par
	hole_number = new_hole_number
	Scoremanager.set_par(par)
	Scoremanager.reset_hole()
	hole_is_complete = false
	ball_reference = null
	print("Hole %d setup (Par %d)" % [hole_number, par])


# Reset to initial state
func reset_hole():
	Scoremanager.reset_hole()
	hole_is_complete = false
	ball_reference = null
	print("Hole %d reset" % hole_number)
