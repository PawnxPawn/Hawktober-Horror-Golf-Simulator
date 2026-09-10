extends Area2D
 
# Higher = thicker sand (ball stops sooner). Tune this to taste.
@export var sand_damping: float = 8.0
 
 
func _ready():
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
 
 
func _on_body_entered(body):
	if body.has_method("enter_sand"):
		body.enter_sand(sand_damping)
 
 
func _on_body_exited(body):
	if body.has_method("exit_sand"):
		body.exit_sand()
 
