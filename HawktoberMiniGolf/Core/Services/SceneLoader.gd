class_name SceneLoader
extends Node



enum Scenes{
	DEMO,
	MAIN_MENU,
}

const _PRELOADED_SCENES: Dictionary = {
	#Scenes.DEMO: preload("uid://b6xjiup8cfts8"), 
	Scenes.MAIN_MENU: preload("uid://c7xr7pjq40o2g"), 
}

const _DYNAMIC_SCENES: Dictionary = {

}

var scene_manager: Node = null
var is_transitioning: bool = false
var _loaded_scenes: Dictionary = {}


func _init() -> void:
	DebugRegistry.register_command("load", _cmd_load, "load [scene] - loads a scene (e.g. load MAIN_MENU)", "SceneLoad")


func load_scene(scene: Scenes, transition: bool = true) -> void :
	if not scene_manager:
		push_error("SceneLoader: %s can't load because SceneManager is not set.")
		return
	
	if transition:
		is_transitioning = true
		
		_swap_scene(scene)
		
		transition = false
		is_transitioning = false
		
		#Services.debug.add_debug_label(
			#&"ScenesLoaded", 
			#( func() -> Array:
				#var arr: Array = []
				#for i in _loaded_scenes:
					#arr.append(Scenes.keys()[i])
				#return arr
				#).call()
		#)
		
		return
		
	_add_to_scene(scene)


func _swap_scene(scene: Scenes) -> void :
	if _loaded_scenes.has(scene):
		push_warning("SceneLoader: %s already is loaded." % Scenes.keys()[scene])
		return
		
	_clean_up()
	
	var instance: Node = _PRELOADED_SCENES[scene].instantiate()
	scene_manager.add_child(instance)
	_loaded_scenes[scene] = instance


func _add_to_scene(_scene: Scenes) -> void :
	pass


func _clean_up() -> void :
	if not _loaded_scenes.is_empty():
		for key in _loaded_scenes:
			var scene_instance: Node = _loaded_scenes[key]
			scene_instance.queue_free()
			
		_loaded_scenes.clear()


func _scene_manager_check() -> bool:
	if not scene_manager:
		push_error("SceneLoader: Can't load new scenes because scene_manager is not set.")
		return false
		
	return true


func quit() -> void :
	_clean_up()
	if scene_manager:
		scene_manager.get_tree().quit()


func _cmd_load(scene_name: String) -> String:
	var index: int = Scenes.keys().find(scene_name.to_upper())
	if index == -1:
		return "Unknown scene: %s" % scene_name
	
	load_scene(index)
	return "Loading %s..." % scene_name
