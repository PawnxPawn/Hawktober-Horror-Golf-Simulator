class_name BasePortrait extends Control

@onready var character: AnimatedSprite2D = $Character

@export var character_name: String


func set_mood(mood: String) -> void:
	# if health <= 50:
	#	play injured50 (injured50_fear)
	# if health <= 75:
	#	play injured75
	character.play(mood)
	pass
