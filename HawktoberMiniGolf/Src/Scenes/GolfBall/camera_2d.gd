extends Camera2D


@export var ball: Golfball            # drag your golf ball node here
@export var hole: Golfhole            # drag your hole node here

@export var pan_duration: float = 2.5      # seconds to travel hole -> ball
@export var hold_at_hole: float = 0.4      # pause on the hole before moving
@export var follow_ball_after: bool = true # keep camera on the ball afterwards
@export var allow_skip: bool = true        # press Hitball / Enter to skip

var _intro_playing: bool = false
var _tween: Tween


func _ready() -> void:
	make_current()

	if ball == null or hole == null:
		push_warning("IntroCamera: assign both 'Ball' and 'Hole' in the Inspector.")
		return

	_play_intro()


func _play_intro() -> void:
	_intro_playing = true

	# Lock the ball so it can't be hit during the fly-over.
	if ball.has_method("set_input_locked"):
		ball.set_input_locked(true)

	# Start the view on the hole.
	global_position = hole.global_position

	# Smoothly pan from the hole to the ball.
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.set_trans(Tween.TRANS_SINE)
	if hold_at_hole > 0.0:
		_tween.tween_interval(hold_at_hole)
	_tween.tween_property(self, "global_position", ball.global_position, pan_duration)
	_tween.tween_callback(_finish_intro)


func _finish_intro() -> void:
	_intro_playing = false
	if ball and ball.has_method("set_input_locked"):
		ball.set_input_locked(false)


func _process(_delta: float) -> void:
	if _intro_playing:
		if allow_skip and (Input.is_action_just_pressed("Hitball") or Input.is_action_just_pressed("ui_accept")):
			_skip_intro()
		return

	# After the intro, keep the ball centred (skip this if your camera is a
	# child of the ball, or if another script already handles camera follow).
	if follow_ball_after and ball:
		global_position = ball.global_position


func _skip_intro() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	global_position = ball.global_position
	_finish_intro()
