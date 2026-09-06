extends RigidBody2D

enum BallState {
	IDLE,
	IS_CHARGING,
	HIT
}

var power: float = 0.0
var max_power: float = 1000.0
var angle: float = 0.0
var ball_state: BallState = BallState.IDLE
var ball_radius: float = 10.0

var hit_count: int = 0
var power_increment: float = 5.0 

func _process(delta):
	inputs(delta)
	
	angle = fmod(angle, 360.0)

	queue_redraw()

func  inputs(delta):
	# Check if ball is moving
	var is_ball_moving = linear_velocity.length() > 2

	
	# Reset state when ball stops
	if ball_state == BallState.HIT and not is_ball_moving:
		ball_state = BallState.IDLE
	
	if ball_state == BallState.IDLE :
		linear_velocity = Vector2.ZERO
		rotation = 0 

	if Input.is_action_just_released("Hitball"):
		if ball_state == BallState.IS_CHARGING:
			launch_ball()
			ball_state = BallState.HIT
			hit_count += 1
	
	# Power control with up/down arrows
	if ball_state == BallState.IDLE || ball_state == BallState.IS_CHARGING    and not is_ball_moving:
		if Input.is_action_pressed("Up"):
			ball_state = BallState.IS_CHARGING
			power = min(power + power_increment, max_power)
		if Input.is_action_pressed("Down"):
			ball_state = BallState.IS_CHARGING
			power = max(power - power_increment, 0.0)
	
	# Angle control with arrow keys
	if Input.is_action_pressed("right"):
		angle += 2.0
	if Input.is_action_pressed("left"):
		angle -= 2.0

func launch_ball():
	var radians = deg_to_rad(angle)
	var force = Vector2(cos(radians), sin(radians)) * (power / max_power) * 1000
	linear_velocity = force




func _draw():
	# Draw power indicator as Line2D effect
	if ball_state == BallState.IS_CHARGING:
		draw_power_indicator()
	
	# Only draw UI when ball is not moving
	var is_ball_moving = linear_velocity.length() > 2
	draw_instructions()

	

func draw_power_indicator():
	# Visual feedback for power level
	var power_ratio = power / max_power
	var indicator_length = 50 * power_ratio
	var rad = deg_to_rad(angle)
	var dir = Vector2(cos(rad), sin(rad))
	
	# Draw a growing line to show power
	draw_line(Vector2.LEFT, dir * (ball_radius + 20 + indicator_length), Color.RED, 3.0)

func draw_instructions():
	var font = get_tree().root.get_theme_default_font()
	var font_size = get_tree().root.get_theme_default_font_size()
	
	match ball_state:
		BallState.IS_CHARGING:
			draw_string(font, Vector2(20, 40), "Power: %.0f%%" % (power / max_power * 100), 
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
			draw_string(font, Vector2(20, 70), "Angle: %.0f°" % angle, 
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
			draw_string(font, Vector2(20, 100), "Hits: %d" % hit_count, 
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.YELLOW)
		BallState.IDLE:
			draw_string(font, Vector2(20, 40), "SPACE: hit  |  ↑/↓: Power  |  ←/→: Angle  ", 
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
			draw_string(font, Vector2(20, 70), "Hits: %d" % hit_count, 
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.YELLOW)
		BallState.HIT:
			var speed = linear_velocity.length()
			if speed > 2:
				draw_string(font, Vector2(20, 40), "Ball Speed: %.0f" % speed, 
					HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
