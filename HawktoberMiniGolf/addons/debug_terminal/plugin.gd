@tool
extends EditorPlugin
## Enabling this plugin (Project Settings > Plugins) registers two autoloads:
## - DebugRegistry: the command/watcher engine, usable from any script.
## - DebugOverlay: the CanvasLayer holding the stats panel and terminal UI.
## Both are removed automatically if the plugin is disabled.

const REGISTRY_AUTOLOAD_NAME: String = "DebugRegistry"
const REGISTRY_AUTOLOAD_PATH: String = "res://addons/debug_terminal/DebugRegistry.gd"
const OVERLAY_AUTOLOAD_NAME: String = "DebugOverlay"
const OVERLAY_AUTOLOAD_PATH: String = "res://addons/debug_terminal/DebugOverlay.tscn"


func _enter_tree() -> void:
	add_autoload_singleton(REGISTRY_AUTOLOAD_NAME, REGISTRY_AUTOLOAD_PATH)
	add_autoload_singleton(OVERLAY_AUTOLOAD_NAME, OVERLAY_AUTOLOAD_PATH)


func _exit_tree() -> void:
	remove_autoload_singleton(OVERLAY_AUTOLOAD_NAME)
	remove_autoload_singleton(REGISTRY_AUTOLOAD_NAME)
