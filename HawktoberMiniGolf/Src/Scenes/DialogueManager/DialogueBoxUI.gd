class_name DialogueBoxUI extends Control

@onready var name_box: Label = $NamePanel/NameBox
@onready var dialogue_text: RichTextLabel = $TextPanel/DialogueBox
@onready var next_arrow: Label = $NextArrow

@export var chars_per_second: float = 30.0

signal line_finished

var _tween: Tween

func display_line(character: String, text: String) -> void:
	name_box.text = character
	dialogue_text.text = text
	dialogue_text.visible_ratio = 0.0
	next_arrow.hide()
	
	if _tween:
		_tween.kill()
	
	var duration: float = text.length() / chars_per_second
	_tween = create_tween()
	_tween.tween_property(dialogue_text, "visible_ratio", 1.0, duration)
	_tween.finished.connect(_on_line_finished)


func _on_line_finished() -> void:
	next_arrow.show()
	line_finished.emit()


func skip_to_end() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
		dialogue_text.visible_ratio = 1.0
		_on_line_finished()


func is_typing() -> bool:
	return _tween != null and _tween.is_running()
