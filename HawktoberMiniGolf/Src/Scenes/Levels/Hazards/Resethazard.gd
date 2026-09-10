extends Area2D

enum Trigger { ON_ENTER, ON_EXIT }

@export var trigger: Trigger = Trigger.ON_ENTER
@export var hazard_name: String = "Water"


func _ready():
	if trigger == Trigger.ON_ENTER:
		if not body_entered.is_connected(_on_body_entered):
			body_entered.connect(_on_body_entered)
	else:
		if not body_exited.is_connected(_on_body_exited):
			body_exited.connect(_on_body_exited)


func _on_body_entered(body):
	_handle(body)


func _on_body_exited(body):
	_handle(body)


func _handle(body):
	# Only the golf ball has this method, so we won't react to anything else.
	if body.has_method("return_to_safe_position"):
		print("%s hazard: returning ball to last safe spot." % hazard_name)
		# Deferred so we don't move a physics body in the middle of a
		# collision callback (Godot doesn't allow changing physics state there).
		body.return_to_safe_position.call_deferred()
