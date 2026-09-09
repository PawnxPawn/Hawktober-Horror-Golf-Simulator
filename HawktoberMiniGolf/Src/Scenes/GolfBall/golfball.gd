extends RigidBody2D

enum BallState {
	IDLE,
	IS_CHARGING,
	HIT,
	HOLE_COMPLETE
}

var power: float = 0.0
var max_power: float = 1000.0
var angle: float = 0.0
var ball_state: BallState = BallState.IDLE
var ball_radius: float = 10.0

var power_increment: float = 5.0


func _process(delta):
	inputs(delta)

	angle = fmod(angle, 360.0)


func inputs(delta):
	# If the hole is complete, block ALL input so the player can't hit the ball.
	if ball_state == BallState.HOLE_COMPLETE:
		return

	# Check if ball is moving
	var is_ball_moving = linear_velocity.length() > 2

	# Reset state when ball stops
	if ball_state == BallState.HIT and not is_ball_moving:
		ball_state = BallState.IDLE

	if Input.is_action_just_released("Hitball"):
		if ball_state == BallState.IS_CHARGING:
			launch_ball()
			ball_state = BallState.HIT
			Scoremanager.add_hit()

	# Power control with up/down arrows
	if (ball_state == BallState.IDLE or ball_state == BallState.IS_CHARGING) and not is_ball_moving:
		rotation = 0
		linear_velocity = Vector2.ZERO

		if Input.is_action_pressed("Up"):
			ball_state = BallState.IS_CHARGING
			power = min(power + power_increment, max_power)
		if Input.is_action_pressed("Down"):
			ball_state = BallState.IS_CHARGING
			power = max(power - power_increment, 0.0)

		# Angle control with arrow keys
		if Input.is_action_pressed("right"):
			angle -= 2.0
		if Input.is_action_pressed("left"):
			angle += 2.0


func launch_ball():
	var radians = deg_to_rad(angle)
	var force = Vector2(cos(radians), -sin(radians)) * (power / max_power) * 1000
	linear_velocity = force


func complete_hole():
	"""Called by the hole when the ball enters it."""
	ball_state = BallState.HOLE_COMPLETE
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	# Freeze the body so gravity / leftover forces can't move it out of the hole.
	freeze = true


# Optional helper if you reset/reuse the same ball for the next hole.
func reset_ball(start_position: Vector2 = global_position):
	freeze = false
	ball_state = BallState.IDLE
	power = 0.0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	global_position = start_position
