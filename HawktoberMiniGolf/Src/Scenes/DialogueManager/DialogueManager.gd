class_name DialogueManager extends Node

@onready var dialogue_box: DialogueBoxUI = $DialogueBox

var dialogue_lines: Array[Dictionary] = []
var current_index: int = 0
var portraits: Dictionary = {}


func _ready() -> void:
	for child in get_children():
		if child is BasePortrait:
			portraits[child.character_name] = child


func load_scene(path: String) -> void:
	dialogue_lines = DialogueParser.parse_tsv(path)
	current_index = 0
	advance()


func advance() -> void:
	if current_index >= dialogue_lines.size():
		return
	var line := dialogue_lines[current_index]
	var portrait: BasePortrait = portraits.get(line.character)
	if portrait:
		portrait.set_mood(line.mood)
		portrait.show()
	dialogue_box.display_line(line.character, line.text)
	current_index += 1
