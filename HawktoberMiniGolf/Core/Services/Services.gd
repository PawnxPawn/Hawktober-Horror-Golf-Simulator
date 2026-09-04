extends Node

var game_state: GameState
var scene_loader: SceneLoader
var ui: UI
var debug: Debug
var audio: Audio
var globals: Globals
var dialogue: DialogueManager


func _ready() -> void :
	get_tree().set_auto_accept_quit(false)
	_register_services()


func _register_services() -> void :
	game_state = GameState.new()
	add_child(game_state)
	
	scene_loader = SceneLoader.new()
	ui = UI.new()
	
	audio = Audio.new()
	add_child(audio)
	
	var dialogue_scene: PackedScene = preload("uid://buaidirs1c4xf")
	dialogue = dialogue_scene.instantiate()
	add_child(dialogue)
	
	globals = Globals.new()


func _deregister_service() -> void :
	pass


func set_ui_manager(ui_manager: Node) -> void :
	ui.ui_manager = ui_manager


func set_audio_manager(audio_manager: Node) -> void :
	audio.audio_manager = audio_manager


func set_scene_manager(scene_manager: Node) -> void :
	scene_loader.scene_manager = scene_manager


func _notification(what: int) -> void :
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		scene_loader.quit()
