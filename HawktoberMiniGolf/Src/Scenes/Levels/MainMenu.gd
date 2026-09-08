extends Control

func _ready() -> void:
	var message: String = "This\nis\na\ntest"
	DebugRegistry.log_message(message, Color.RED)
	Services.dialogue.play_sequence("End")
