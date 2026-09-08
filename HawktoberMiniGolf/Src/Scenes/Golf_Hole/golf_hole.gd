extends Area2D

@export var par: int = 4
@export var hole_number: int = 1
@export var show_score_duration: float = 3.0

var score_popup_visible: bool = false
var score_popup_timer: float = 0.0
var ball_reference: RigidBody2D = null

signal hole_completed_display

func _ready():
	# Set the initial par for this hole
	Scoremanager.set_par(par)
	print("Hole %d ready (Par %d)" % [hole_number, par])
	
	# Connect the area entered signal
	area_entered.connect(_on_ball_entered)


func _process(delta):
	# Handle score popup timer
	if score_popup_visible:
		score_popup_timer -= delta
		if score_popup_timer <= 0:
			score_popup_visible = false
			queue_redraw()


func _on_ball_entered(area):
	if area is RigidBody2D:
		ball_reference = area
		_complete_hole()


func _complete_hole():
	if Scoremanager.hit_count == 0:
		return  # Ball didn't actually hit the hole
	
	# Mark hole as complete
	Scoremanager.complete_hole()
	
	# Signal the ball that hole is complete (prevents further hitting)
	if ball_reference and ball_reference.has_method("complete_hole"):
		ball_reference.complete_hole()
	
	# Show score popup
	show_score_popup()
	
	hole_completed_display.emit()


func show_score_popup():
	score_popup_visible = true
	score_popup_timer = show_score_duration
	queue_redraw()


func _draw():
	# Draw score popup if visible
	if score_popup_visible:
		draw_score_popup()


func draw_score_popup():
	var font = get_tree().root.get_theme_default_font()
	var font_size = get_tree().root.get_theme_default_font_size() + 4
	
	var rating = Scoremanager.get_score_rating()
	var score_diff = Scoremanager.get_score_difference()
	var score_color = Scoremanager.get_score_color()
	
	# Draw semi-transparent background
	var popup_width = 250
	var popup_height = 120
	draw_rect(Rect2(-popup_width/2, -popup_height/2, popup_width, popup_height), 
		Color.BLACK.lerp(Color.TRANSPARENT, 0.3))
	
	# Draw border
	draw_rect(Rect2(-popup_width/2, -popup_height/2, popup_width, popup_height), 
		score_color, false, 3.0)
	
	# Draw text
	draw_string(font, Vector2(-100, -40), rating, 
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size + 2, score_color)
	
	var score_str = "%+d" % score_diff if score_diff != 0 else "E"
	draw_string(font, Vector2(-100, 0), "Score: %s" % score_str, 
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	
	draw_string(font, Vector2(-100, 40), "Hole %d Complete!" % Scoremanager.holes_completed, 
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 2, Color.YELLOW)


# Call this to setup next hole
func setup_next_hole(new_par: int, new_hole_number: int = 1):
	par = new_par
	hole_number = new_hole_number
	Scoremanager.set_par(par)
	Scoremanager.reset_hole()
	score_popup_visible = false
	ball_reference = null
	print("Hole %d setup (Par %d)" % [hole_number, par])


# Reset to initial state
func reset_hole():
	Scoremanager.reset_hole()
	score_popup_visible = false
	ball_reference = null
	queue_redraw()
	print("Hole %d reset" % hole_number)
