class_name Debug
extends CanvasLayer

var enabled: bool = OS.is_debug_build()

@onready var terminal: PanelContainer = $Terminal


func _ready() -> void:
	if not enabled:
		queue_free()
		return
	visible = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"DebugMenu"):
		visible = not visible
		if terminal.visible == true:
			terminal.focus_input()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed(&"DebugTerminal"):
		terminal.toggle()
		get_viewport().set_input_as_handled()
