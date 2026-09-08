class_name DialogueBoxUI
extends Control

@onready var dialogue_text: RichTextLabel = $DialogueBox
@onready var next_arrow: TextureRect = $NextArrow
@onready var next_arrow_shadow: TextureRect = $ Shadow

@export var chars_per_second: float = 30.0
@export var arrow_pulse_scale: float = 1.15
@export var arrow_pulse_duration: float = 0.5
@export var shadow_offset: Vector2 = Vector2(12, 12)

signal line_finished

var _tween: Tween
var _pulse_tween: Tween

func _ready() -> void:
	next_arrow.pivot_offset = next_arrow.size / 2.0
	next_arrow_shadow.pivot_offset = next_arrow_shadow.size / 2.0
	
	next_arrow_shadow.modulate = Color(0, 0, 0, 0.5)
	next_arrow_shadow.position = next_arrow.position + shadow_offset


func display_line(_character: String, text: String) -> void:
	dialogue_text.text = text
	dialogue_text.visible_ratio = 0.0
	_hide_arrow()
	
	if _tween:
		_tween.kill()
	
	var duration: float = text.length() / chars_per_second
	_tween = create_tween()
	_tween.tween_property(dialogue_text, "visible_ratio", 1.0, duration)
	_tween.finished.connect(_on_line_finished)


func _on_line_finished() -> void:
	_show_arrow()
	line_finished.emit()


func skip_to_end() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
		dialogue_text.visible_ratio = 1.0
		_on_line_finished()


func is_typing() -> bool:
	return _tween != null and _tween.is_running()


func _show_arrow() -> void:
	next_arrow.show()
	#next_arrow_shadow.show()
	_start_pulse()


func _hide_arrow() -> void:
	next_arrow.hide()
	next_arrow_shadow.hide()
	_stop_pulse()


func _start_pulse() -> void:
	_stop_pulse()
	var shadow_peak_scale: float = 1.0 + (arrow_pulse_scale - 1.0) * 0.6
	
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(next_arrow, "scale", Vector2.ONE * arrow_pulse_scale, arrow_pulse_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.parallel().tween_property(next_arrow_shadow, "scale", Vector2.ONE * shadow_peak_scale, arrow_pulse_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	_pulse_tween.tween_property(next_arrow, "scale", Vector2.ONE, arrow_pulse_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.parallel().tween_property(next_arrow_shadow, "scale", Vector2.ONE, arrow_pulse_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
	next_arrow.scale = Vector2.ONE
	next_arrow_shadow.scale = Vector2.ONE
