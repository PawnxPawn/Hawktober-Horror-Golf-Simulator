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
var cue_stick: Line2D

func _ready():
	get_window().title = "Ball Hit Game"
	
	# Create and configure cue stick Line2D
	cue_stick = Line2D.new()
	add_child(cue_stick)
	cue_stick.width = 8.0
	cue_stick.default_color = Color(0.8, 0.6, 0.3)
	cue_stick.z_index = -1
	cue_stick.visible = false

func _process(delta):
	# Input handling
	if Input.is_action_pressed("Hitball"):  # Spacebar
		if ball_state == BallState.IDLE:
			ball_state = BallState.IS_CHARGING
			power = 0.0
			cue_stick.visible = true
		elif ball_state == BallState.IS_CHARGING:
			power = min(power + 500 * delta, max_power)
	
	if Input.is_action_just_released("Hitball"):
		if ball_state == BallState.IS_CHARGING:
			launch_ball()
			ball_state = BallState.HIT
			cue_stick.visible = false
	
	# Angle control with arrow keys
	if Input.is_action_pressed("right"):
		angle += 2.0
	if Input.is_action_pressed("left"):
		angle -= 2.0
	
	angle = fmod(angle, 360.0)
	
	# Update cue position and rotation
	if ball_state == BallState.IS_CHARGING:
		update_cue_stick()
	
	queue_redraw()

func update_cue_stick():
	var rad = deg_to_rad(angle)
	var cue_length = 100 + (power / max_power) * 50
	var cue_dir = Vector2(cos(rad), sin(rad))
	
	# Position cue behind ball (offset in opposite direction)
	var cue_start = -cue_dir * 60
	var cue_end = cue_dir * cue_length
	
	cue_stick.clear_points()
	cue_stick.add_point(cue_start)
	cue_stick.add_point(cue_end)

func launch_ball():
	var radians = deg_to_rad(angle)
	var force = Vector2(cos(radians), sin(radians)) * (power / max_power) * 1000
	linear_velocity = force

func _draw():
	# Draw power indicator as Line2D effect
	if ball_state == BallState.IS_CHARGING:
		draw_power_indicator()
	
	# Draw instructions
	draw_instructions()

func draw_power_indicator():
	# Visual feedback for power level
	var power_ratio = power / max_power
	var indicator_length = 30 * power_ratio
	var rad = deg_to_rad(angle)
	var dir = Vector2(cos(rad), sin(rad))
	
	# Draw a growing line to show power
	draw_line(Vector2.ZERO, dir * (ball_radius + 20), Color.YELLOW, 2.0)
	draw_line(Vector2.ZERO, dir * (ball_radius + 20 + indicator_length), Color.RED, 3.0)

func draw_instructions():
	var font = get_tree().root.get_theme_default_font()
	var font_size = get_tree().root.get_theme_default_font_size()
	
	match ball_state:
		BallState.IS_CHARGING:
			draw_string(font, Vector2(20, 60), "Power: %.0f%%" % (power / max_power * 100), 
						HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
			draw_string(font, Vector2(20, 90), "Angle: %.0f°" % angle, 
						HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
		BallState.IDLE:
			draw_string(font, Vector2(20, 60), "Press SPACE to charge", 
						HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	
	
	var speed = linear_velocity.length()
	draw_string(font, Vector2(20, 650), "SPACE: Charge | ←/→: Angle | Speed: %.0f" % speed, 
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
