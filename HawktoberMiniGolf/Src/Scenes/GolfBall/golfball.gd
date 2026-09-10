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

# --- Hazard / reset support -------------------------------------------------
# The last spot the ball was resting on safe ground, captured the moment it was
# hit. If the ball ends up in water or out of bounds, we drop it back here.
var last_safe_position: Vector2 = Vector2.ZERO

# We remember the ball's normal damping so the sand trap can temporarily raise
# it (to slow the ball down) and then restore it when the ball leaves the sand.
var default_linear_damp: float = 0.0

# Add a +1 penalty stroke when the ball lands in water / goes out of bounds.
# Set to false in the Inspector if you don't want the penalty.
@export var hazard_penalty: bool = true


func _ready():
	# Start with a valid safe position in case the very first shot goes wrong.
	last_safe_position = global_position
	default_linear_damp = linear_damp


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
		last_safe_position = global_position
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


# --- Called by the Water / Out-of-bounds hazard -----------------------------
func return_to_safe_position():
	# Stop the ball dead and drop it back where it was last hit from.
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	rotation = 0.0
	global_position = last_safe_position

	# Ready to be hit again.
	ball_state = BallState.IDLE
	power = 0.0

	if hazard_penalty:
		Scoremanager.add_hit()  # +1 penalty stroke.


# --- Called by the Sand trap ------------------------------------------------
func enter_sand(sand_damp: float):
	# Crank up damping so the ball slows quickly, like real sand.
	linear_damp = sand_damp


func exit_sand():
	# Back to normal rolling.
	linear_damp = default_linear_damp


# Optional helper if you reset/reuse the same ball for the next hole.
func reset_ball(start_position: Vector2 = global_position):
	freeze = false
	ball_state = BallState.IDLE
	power = 0.0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	global_position = start_position
	last_safe_position = start_position
