extends Area2D

# How the pad decides which way to launch the ball.
#   FIXED_ANGLE        -> always fires toward `launch_angle` (a normal jump pad)
#   CONTINUE_DIRECTION -> keeps the ball going the way it was already moving
#   BOUNCE             -> reflects the ball off the pad, like a flat wall, so
#                         the exit angle depends on the angle it came in at
#   RADIAL_BUMPER      -> pushes the ball straight away from the pad's center,
#                         from any side, like a pinball bumper (use a round
#                         CollisionShape2D for this one)
enum LaunchMode { FIXED_ANGLE, CONTINUE_DIRECTION, BOUNCE, RADIAL_BUMPER }

@export var mode: LaunchMode = LaunchMode.RADIAL_BUMPER

# Only used in FIXED_ANGLE mode (and as a fallback). Matches the ball's angle
# convention (see launch_ball): 0 = right, 90 = straight up, 180 = left.
@export var launch_angle: float = 90.0

# The speed the ball leaves the pad at (used when keep_incoming_speed is false).
@export var launch_strength: float = 1200.0

# If true, the ball keeps the speed it arrived with instead of using
# launch_strength. Great for a pure bumper that redirects without boosting.
# If false, the ball always leaves at launch_strength (a real boost).
@export var keep_incoming_speed: bool = false

# Short cooldown so one touch = one launch (stops it re-firing every physics
# frame while the ball is still overlapping the pad).
@export var cooldown: float = 0.3

var _on_cooldown: bool = false


func _ready():
	body_entered.connect(_on_body_entered)


func _on_body_entered(body):
	if _on_cooldown:
		return

	# Only launch things that know how to be launched (i.e. the golf ball).
	if not body.has_method("launch_from_pad"):
		return

	var incoming: Vector2 = body.linear_velocity
	var direction: Vector2 = _get_direction(incoming, body.global_position)

	# Pick the exit speed.
	var strength: float = launch_strength
	if keep_incoming_speed and incoming.length() > 0.0:
		strength = incoming.length()

	body.launch_from_pad(direction, strength)

	# Optional: play a sound / animation here.
	# $Sound.play()

	_start_cooldown()


func _get_direction(incoming: Vector2, ball_pos: Vector2) -> Vector2:
	# If the ball is basically stopped, direction-based modes have nothing to
	# work with, so fall back to the fixed angle.
	var moving := incoming.length() > 1.0

	match mode:
		LaunchMode.CONTINUE_DIRECTION:
			if moving:
				return incoming.normalized()
			return _angle_to_vector(launch_angle)

		LaunchMode.BOUNCE:
			if moving:
				# The pad's local "up" is its surface normal. Rotate the pad in
				# the editor to change which way the bumper faces.
				var n := (-global_transform.y).normalized()
				# Standard reflection: v - 2 (v . n) n
				var reflected := incoming - 2.0 * incoming.dot(n) * n
				return reflected.normalized()
			return _angle_to_vector(launch_angle)

		LaunchMode.RADIAL_BUMPER:
			# Fling the ball straight away from the pad's center, whatever side
			# it came in on. Works like a pinball bumper.
			var away := ball_pos - global_position
			if away.length() > 0.01:
				return away.normalized()
			# Ball is right on the center: just send it back the way it came.
			if moving:
				return (-incoming).normalized()
			return _angle_to_vector(launch_angle)

		_:  # FIXED_ANGLE
			return _angle_to_vector(launch_angle)


func _angle_to_vector(deg: float) -> Vector2:
	var radians := deg_to_rad(deg)
	return Vector2(cos(radians), -sin(radians))


func _start_cooldown():
	_on_cooldown = true
	await get_tree().create_timer(cooldown).timeout
	_on_cooldown = false
