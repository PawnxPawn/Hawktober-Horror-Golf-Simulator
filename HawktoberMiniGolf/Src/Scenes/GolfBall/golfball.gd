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

	queue_redraw()

func  inputs(delta):
	# Check if ball is moving
	var is_ball_moving = linear_velocity.length() > 2

	# Reset state when ball stops
	if ball_state == BallState.HIT and not is_ball_moving:
		ball_state = BallState.IDLE
	
	# Don't allow any input if hole is complete
	if ball_state == BallState.HOLE_COMPLETE:
		return
	
	if Input.is_action_just_released("Hitball"):
		if ball_state == BallState.IS_CHARGING:
			launch_ball()
			ball_state = BallState.HIT
			Scoremanager.add_hit()
	
	# Power control with up/down arrows
	if ball_state == BallState.IDLE || ball_state == BallState.IS_CHARGING and not is_ball_moving:
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
			angle += 2.0
		if Input.is_action_pressed("left"):
			angle -= 2.0

func launch_ball():
	var radians = deg_to_rad(angle)
	var force = Vector2(cos(radians), sin(radians)) * (power / max_power) * 1000
	linear_velocity = force


func complete_hole():
	"""Called when the ball enters the hole"""
	ball_state = BallState.HOLE_COMPLETE
	linear_velocity = Vector2.ZERO
	queue_redraw()


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
	
	# Draw score box (top right)
	draw_score_display(font, font_size)
	
	# Don't show instructions if hole is complete
	if ball_state == BallState.HOLE_COMPLETE:
		return
	
	match ball_state:
		BallState.IS_CHARGING:
			draw_string(font, Vector2(20, 40), "Power: %.0f%%" % (power / max_power * 100), 
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
			draw_string(font, Vector2(20, 70), "Angle: %.0f°" % angle, 
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
			draw_string(font, Vector2(20, 100), "Hits: %d / Par %d" % [Scoremanager.hit_count, Scoremanager.current_par], 
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.YELLOW)
		BallState.IDLE:
			draw_string(font, Vector2(20, 40), "SPACE: hit  |  ↑/↓: Power  |  ←/→: Angle  ", 
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
			draw_string(font, Vector2(20, 70), "Hits: %d / Par %d" % [Scoremanager.hit_count, Scoremanager.current_par], 
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.YELLOW)
		BallState.HIT:
			var speed = linear_velocity.length()
			if speed > 2:
				draw_string(font, Vector2(20, 40), "Ball Speed: %.0f" % speed, 
					HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func draw_score_display(font: Font, font_size: int):
	var score_rating = Scoremanager.get_score_rating()
	var score_diff = Scoremanager.get_score_difference()
	var score_color = Scoremanager.get_score_color()
	
	# Display in top-right corner
	var screen_width = get_viewport_rect().size.x
	var x_pos = screen_width - 200
	
	draw_string(font, Vector2(x_pos, 40), "Par: %d" % Scoremanager.current_par, 
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	draw_string(font, Vector2(x_pos, 70), score_rating, 
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, score_color)
	if Scoremanager.hit_count > 0:
		var score_str = "%+d" % score_diff if score_diff != 0 else "E"
		draw_string(font, Vector2(x_pos, 100), "Score: %s" % score_str, 
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, score_color)
