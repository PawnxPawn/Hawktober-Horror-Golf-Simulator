class_name DebugCommand extends RefCounted

var name: String = ""
var callable: Callable
var description: String = ""
var category: String = "general"

func _init(p_name: String, p_callable: Callable, p_description: String = "", p_category: String = "general") -> void:
	name = p_name
	callable = p_callable
	description = p_description
	category = p_category
