class_name DialogueManager
extends Node

@onready var dialogue_box: DialogueBoxUI = $DialogueBox
@onready var portraitcontainer: Control = $Portraitcontainer

var all_lines: Array[Dictionary] = []
var dialogue_lines: Array[Dictionary] = []
var current_line_index: int = 0

var portraits: Dictionary = {}
var current_portrait: BasePortrait = null

var _scene_queue: Array = []
var _queue_index: int = 0


func _ready() -> void:
	all_lines = DialogueParser.parse_tsv("res://Assets/Dialogue/golfalogue.tsv")
	
	for child in portraitcontainer.get_children():
		if child is BasePortrait:
			portraits[child.character_name] = child
			child.hide()
	
	dialogue_box.hide()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Interact"):
		if dialogue_box.is_typing():
			dialogue_box.skip_to_end()
		else:
			advance()


func play_scene(scene_name: String) -> void:
	dialogue_lines = all_lines.filter(func(l): return l.scene == scene_name)
	current_line_index = 0
	dialogue_box.show()
	advance()


func advance() -> void:
	if current_line_index >= dialogue_lines.size():
		_end_scene()
		return
	
	var line: Dictionary = dialogue_lines[current_line_index]
	var portrait: BasePortrait = portraits.get(line.character)
	
	if portrait != current_portrait:
		if current_portrait:
			current_portrait.hide()
		if portrait:
			portrait.show()
		current_portrait = portrait
	
	if portrait:
		portrait.set_mood(line.mood)
	
	dialogue_box.display_line(portrait.character_name_print, line.text)
	current_line_index += 1


func play_sequence(base_name: String) -> void:
	var numbered_scenes: Dictionary = {}
	for line in all_lines:
		if line.scene.begins_with(base_name):
			var suffix: String = line.scene.substr(base_name.length())
			if suffix.is_valid_int():
				numbered_scenes[line.scene] = suffix.to_int()
	
	var sorted_names: Array = numbered_scenes.keys()
	sorted_names.sort_custom(func(a, b): return numbered_scenes[a] < numbered_scenes[b])
	
	if sorted_names.is_empty():
		push_warning("No numbered scenes found for: " + base_name)
		return
	
	_scene_queue = sorted_names
	_queue_index = 0
	_play_next_in_queue()


func _play_next_in_queue() -> void:
	if _queue_index >= _scene_queue.size():
		_scene_queue.clear()
		_end_dialogue()
		return
	play_scene(_scene_queue[_queue_index])
	_queue_index += 1


func _end_scene() -> void:
	if _queue_index < _scene_queue.size():
		_play_next_in_queue()
	else:
		_end_dialogue()


func _end_dialogue() -> void:
	if current_portrait:
		current_portrait.hide()
	dialogue_box.hide()
