class_name BasePortrait extends Control

@onready var character: AnimatedSprite2D = $Character

@export var character_name: String
@export var character_name_print: String

func set_mood(mood: String) -> void:
	#if health <= 50:
		#if mood == "fear":
			#character.play(&"injured50_default")
			#return
		#character.play(&"injured50_fear")
		#return
	#elif health <= 75:
		#if mood == "fear":
			#character.play(&"injured50_default")
			#return
		#character.play(&"injured75")
	for anim in character.sprite_frames.get_animation_names():
		if mood == anim:
			character.play(mood)
			return
	character.play(&"default")
	pass
