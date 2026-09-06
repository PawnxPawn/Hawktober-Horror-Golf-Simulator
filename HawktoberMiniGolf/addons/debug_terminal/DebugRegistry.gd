## Autoload for DebugTerminal. Used to register new commands and watchers.
## Has multiple debugging functions for use while running the game. 
extends Node

signal label_updated(watcher_name: String, value: Variant, color: Color)
signal label_removed(watcher_name: String)
signal log_line(bbcode_text: String)
signal log_cleared
signal layout_reset
signal settings_changed(panel_property: StringName, value: Variant)
signal appearance_changed(panel_name: String)

#region State

var _frame_count: int = 0

## String { getter: Callable, interval: int, visible: bool, persistent: bool, category: String, color_fn: Callable }
var watchers: Dictionary = {}

## String {DebugCommand}
var commands: Dictionary = {}

## alias_name { PackedStringArray } of raw command tokens the alias expands to.
var aliases: Dictionary = {}

## Inspections targeting a specific node instance.
var inspections: Dictionary = {} # name { node: Node, property: String, interval: int }

## Inspections using the given script.
var script_inspections: Dictionary = {} # name { script_path: String, property: String, interval: int }

## Conditions polled every frame; when true, pauses the game.
var break_conditions: Dictionary = {} # key { watcher: String, op: String, value: float, repeat: bool }

## Recent plain-text log lines. Capped to MAX_LOG_HISTORY
const MAX_LOG_HISTORY: int = 500
var log_history: Array[String] = []

#endregion

#region Save / Load

const CONFIG_PATH: String = "user://debug_stats.cfg"
const CONFIG_SECTION: String = "watchers"
const LAYOUT_SECTION: String = "layout"
const APPEARANCE_SECTION: String = "appearance"
const PROFILE_SECTION_PREFIX: String = "profile:"

## Visibility loaded from disk at startup.
var pending_visibility: Dictionary = {}

#endregion


#region Lifecycle

func _ready() -> void:
	OS.add_logger(DebugLogCapture.new())
	_load_visibility()
	_register_default_commands()
	_register_default_watchers()
	_register_inputs()


func _exit_tree() -> void:
	_remove_inputs()


func _register_inputs() -> void:
	_add_action(&"DebugMenu", KEY_F3)
	_add_action(&"DebugTerminal", KEY_QUOTELEFT)


func _add_action(action_name: StringName, keycode: Key) -> void:
	if InputMap.has_action(action_name):
		return
	InputMap.add_action(action_name)
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action_name, event)


func _remove_inputs() -> void:
	_remove_action(&"DebugMenu")
	_remove_action(&"DebugTerminal")


func _remove_action(action_name: StringName) -> void:
	if not InputMap.has_action(action_name):
		return
	InputMap.erase_action(action_name)


func _process(_delta: float) -> void:
	_frame_count += 1
	_update_watchers()
	_update_node_inspections()
	_update_script_inspections()
	_update_break_conditions()

#endregion



#region Update Loop

## Polls every visible watcher whose interval elapsed this frame and emits
## its latest value.
func _update_watchers() -> void:
	for watcher_name in watchers:
		var entry: Dictionary = watchers[watcher_name]
		
		if not entry[&"visible"]:
			continue
		if not entry[&"getter"].is_valid():
			unwatch(watcher_name)
			continue
		if _frame_count % entry[&"interval"] != 0:
			continue
		
		var value: Variant = entry[&"getter"].call()
		var color: Color = Color.WHITE
		if entry[&"color_fn"].is_valid():
			color = entry[&"color_fn"].call(value)
		label_updated.emit(watcher_name, value, color)


## Prints repeating `inspect_node` watches to the terminal log.
func _update_node_inspections() -> void:
	for inspect_name in inspections.keys():
		var entry: Dictionary = inspections[inspect_name]
		if not is_instance_valid(entry[&"node"]):
			inspections.erase(inspect_name)
			continue
		if _frame_count % entry[&"interval"] != 0:
			continue
		log_message("%s = %s" % [inspect_name, str(entry[&"node"].get(entry[&"property"]))])


## Prints repeating `inspect_script` watches to the terminal log.
func _update_script_inspections() -> void:
	for script_name in script_inspections.keys():
		var entry: Dictionary = script_inspections[script_name]
		if _frame_count % entry[&"interval"] != 0:
			continue
		_log_script_matches(entry[&"script_path"], entry[&"property"])

#endregion


#region Terminal Logging

func log_message(text: String, color: Color = Color.WHITE) -> void:
	var timestamp: String = "[color=gray][%s][/color]" % Time.get_time_string_from_system()
	
	var body: String = text
	if color != Color.WHITE:
		body = "[color=#%s]%s[/color]" % [color.to_html(false), text]
	
	log_history.append(text)
	if log_history.size() > MAX_LOG_HISTORY:
		log_history.remove_at(0)
	
	log_line.emit("%s %s" % [timestamp, body])

#endregion

#region Commands

func _register_default_commands() -> void:
	# Core
	register_command("help", _cmd_help, "help [category|prefix] - lists commands, grouped by category", "core")
	register_command("clear", func(): log_history.clear(); log_cleared.emit(); return "", "clear - clears terminal output and search history", "core")
	register_command("sysinfo", _cmd_sysinfo, "sysinfo - prints OS, CPU, GPU, RAM, display, and engine info", "core")
	
	# Watchers
	register_command("stats", _cmd_stats, "stats [category] - lists watched stats grouped by category; pass a category to show only that group", "watchers")
	register_command("show", func(id: String): toggle_visible(id, true); return "", "show [stat] - shows a watched stat on the stats panel", "watchers")
	register_command("hide", func(id: String): toggle_visible(id, false); return "", "hide [stat] - hides a watched stat from the stats panel", "watchers")
	register_command("show_category", _cmd_show_category, "show_category [category] - shows every watcher in a category at once (e.g. \"show_category rendering\")", "watchers")
	register_command("hide_category", _cmd_hide_category, "hide_category [category] - hides every watcher in a category at once", "watchers")
	register_command("watch_node", _cmd_watch_node, "watch_node [node_path] [property] - adds a live node property to the stats panel", "watchers")
	register_command("unwatch_node", func(id: String): unwatch(id); return "", "unwatch_node [name] - stops watching a node property added via watch_node", "watchers")
	
	# Profiles (saved sets of which stats are shown)
	register_command("save_profile", _cmd_save_profile, "save_profile [name] - saves the current set of shown/hidden stats under a name", "profiles")
	register_command("load_profile", _cmd_load_profile, "load_profile [name] - restores a previously saved stat visibility profile", "profiles")
	register_command("profiles", _cmd_list_profiles, "profiles - lists saved stat visibility profiles", "profiles")
	register_command("delete_profile", _cmd_delete_profile, "delete_profile [name] - deletes a saved profile", "profiles")
	
	# Inspection
	register_command("inspect_node", _cmd_inspect_node, "inspect_node [node_path] [property] [repeat=false] [interval=1] - reads a live node property; repeat=true keeps printing it to the terminal", "inspection")
	register_command("inspect_script", _cmd_inspect_script, "inspect_script [script_path] [property] [repeat=false] [interval=1] - lists property values across all live nodes using a script; repeat=true keeps printing to the terminal", "inspection")
	register_command("uninspect", _cmd_uninspect, "uninspect [name] - stops a repeating inspect_node/inspect_script watch; no args stops all (e.g., node_name.property or script.gd.property)", "inspection")
	register_command("set_node", _cmd_set_node, "set_node [node_path] [property] [value] - writes a value to a live node property", "inspection")
	register_command("set_script", _cmd_set_script, "set_script [script_path] [property] [value] - writes a value to a property on every live node using that script", "inspection")
	register_command("tree", _cmd_tree, "tree [node_path] [max_depth=6] - prints the scene hierarchy from a node (defaults to root)", "inspection")
	
	# Debug
	register_command("find", _cmd_find, "find [term] - searches recent terminal output for a term", "debug")
	register_command("break_if", _cmd_break_if, "break_if [watcher] [op: > < >= <= == !=] [value] [repeat=false] - pauses when a watcher's value crosses a threshold", "debug")
	register_command("unbreak", _cmd_unbreak, "unbreak [name] - removes a break_if condition; no args clears all", "debug")
	register_command("breaks", _cmd_breaks, "breaks - lists active break_if conditions", "debug")
	register_command("resume", _cmd_resume, "resume - Unpauses after a break_if pause", "debug")
	
	# Shortcuts
	register_command("alias", Callable(), "alias [name] [command] [args...] - creates a shortcut for a command", "shortcuts")
	register_command("unalias", Callable(), "unalias [name] - removes a shortcut", "shortcuts")
	register_command("aliases", Callable(), "aliases - lists defined shortcuts", "shortcuts")
	
	# Layout / appearance
	register_command("reset_layout", _cmd_reset_layout, "reset_layout - restores all panels to their default positions", "layout")
	register_command("reset_appearance", _cmd_reset_appearance, "reset_appearance - restores default font size and opacity", "layout")
	
	# System
	register_command("project", _cmd_project_set, "project [project_setting] [value] [hotapply=true]- changes a ProjectSettings value at runtime\nNOTE: Changes may not be seen until after restart.", "system")


## Registers a new command for the debug terminal to call
func register_command(cmd_name: String, callable: Callable, description: String = "", category: String = "general") -> void:
	commands[cmd_name] = DebugCommand.new(cmd_name, callable, description, category)


## Removes a registered command from the debug terminal
func unregister_command(cmd_name: String) -> void:
	commands.erase(cmd_name)


## Splits `line` into tokens, then resolves the first token as an alias
## or as a registered command whose remaining tokens are converted
## to typed args and passed in.
func execute(line: String) -> void:
	var tokens: PackedStringArray = _tokenize(line.strip_edges())
	if tokens.is_empty():
		return
	
	var cmd_name: String = tokens[0]
	
	if cmd_name == "alias":
		if tokens.size() < 3:
			log_message("Usage: alias [name] [command] [args...]", Color.RED)
			return
		var alias_name: String = tokens[1]
		var alias_body: PackedStringArray = tokens.slice(2)
		aliases[alias_name] = alias_body
		log_message("Alias '%s' -> %s" % [alias_name, " ".join(alias_body)])
		return
	if cmd_name == "unalias":
		if tokens.size() < 2:
			log_message("Usage: unalias [name]", Color.RED)
			return
		aliases.erase(tokens[1])
		log_message("Removed alias '%s'" % tokens[1])
		return
	if cmd_name == "aliases":
		_print_aliases()
		return
	if aliases.has(cmd_name):
		var expanded: PackedStringArray = aliases[cmd_name].duplicate()
		for i in range(1, tokens.size()):
			expanded.append(tokens[i])
		execute(" ".join(expanded))
		return
	
	if not commands.has(cmd_name):
		log_message("Unknown command: %s" % cmd_name, Color.RED)
		return
	
	var cmd: DebugCommand = commands[cmd_name]
	if not cmd.callable.is_valid():
		log_message("%s is no longer valid" % cmd_name, Color.RED)
		commands.erase(cmd_name)
		return
	
	var args: Array = []
	for i in range(1, tokens.size()):
		args.append(_parse_token(tokens[i]))
	
	var result: Variant = cmd.callable.callv(args)
	if result != null and str(result) != "":
		log_message(str(result))


func _tokenize(line: String) -> PackedStringArray:
	var tokens: PackedStringArray = []
	var current: String = ""
	var depth: int = 0
	
	for i in range(line.length()):
		var c: String = line[i]
		if c == "(":
			depth += 1
			current += c
		elif c == ")":
			depth = max(depth - 1, 0)
			current += c
		elif c == " " and depth == 0:
			if current != "":
				tokens.append(current)
				current = ""
		else:
			current += c
	
	if current != "":
		tokens.append(current)
	return tokens


func _parse_token(token: String) -> Variant:
	if token.is_valid_int():
		return token.to_int()
	if token.is_valid_float():
		return token.to_float()
	if token == "true":
		return true
	if token == "false":
		return false
		
	if token.contains("(") and token.ends_with(")"):
		var parsed: Variant = str_to_var(token)
		if parsed != null:
			return parsed
	
	if token.contains(","):
		var parts: PackedStringArray = token.split(",", false)
		if parts.size() == 2 and parts[0].is_valid_float() and parts[1].is_valid_float():
			return Vector2(parts[0].to_float(), parts[1].to_float())
		if parts.size() == 3 and parts[0].is_valid_float() and parts[1].is_valid_float() and parts[2].is_valid_float():
			return Vector3(parts[0].to_float(), parts[1].to_float(), parts[2].to_float())
	
	return token

#endregion


#region Command Handlers

## Help command
func _cmd_help(filter: String = "") -> String:
	var available_categories: Array = _command_categories()
	
	if filter != "":
		var wanted_category: String = filter.to_lower()
		if available_categories.has(wanted_category):
			return "\n%s" % _format_help_section(wanted_category, _commands_in_category(wanted_category))
		return _format_help_prefix(filter)
	
	var sections: PackedStringArray = []
	for cat in available_categories:
		sections.append(_format_help_section(cat, _commands_in_category(cat)))
	
	var header: String = "\nCategories: %s\nuse \"help [category]\" to filter, or \"help [prefix]\" to search by command name" % ", ".join(available_categories)
	return "%s\n\n%s" % [header, "\n\n".join(sections)]


## Returns every distinct command category, sorted.
func _command_categories() -> Array:
	var cats: Dictionary = {}
	for cmd_name in commands:
		cats[commands[cmd_name].category] = true
	var result: Array = cats.keys()
	result.sort()
	return result


## Returns the command names belonging to `category`.
func _commands_in_category(category: String) -> Array:
	var names: Array = []
	for cmd_name in commands:
		if commands[cmd_name].category == category:
			names.append(cmd_name)
	names.sort()
	return names


## Grouped listing and the single-category filter.
func _format_help_section(category: String, cmd_names: Array) -> String:
	var lines: PackedStringArray = []
	for cmd_name in cmd_names:
		var cmd: DebugCommand = commands[cmd_name]
		lines.append("- [b]%s[/b] - [color=gray]%s[/color]" % [cmd_name, cmd.description])
	return "[color=gray][b][i][%s][/i][/b][/color]\n%s" % [category.capitalize(), "\n".join(lines)]


## Fallback for 'help [text]'
func _format_help_prefix(prefix: String) -> String:
	var lines: PackedStringArray = []
	for cmd_name in commands:
		if cmd_name.begins_with(prefix):
			var cmd: DebugCommand = commands[cmd_name]
			lines.append("- [b]%s[/b] - [color=gray]%s[/color]" % [cmd_name, cmd.description])
	lines.sort()
	
	if lines.is_empty():
		return "\nNo commands matching: %s" % prefix
	return "\nCommands matching \"%s\":\n%s" % [prefix, "\n".join(lines)]


## Lists watchers grouped under their category
func _cmd_stats(category: String = "") -> String:
	var grouped: Dictionary = {}   # category { Array[String] }
	for watcher_name in watchers:
		var entry: Dictionary = watchers[watcher_name]
		var watcher_category: String = entry[&"category"]
		if category and watcher_category.to_lower() != category.to_lower():
			continue
		
		var state: String = "shown" if entry[&"visible"] else "hidden"
		var line: String = "-[b]%s[/b] ([color=gray]%s[/color])" % [watcher_name, state]
		if not grouped.has(watcher_category):
			grouped[watcher_category] = []
		grouped[watcher_category].append(line)
	
	if grouped.is_empty():
		if category:
			return "\nNo stats in category: %s" % category
		return "\nNo stats registered"
	
	var categories: Array = grouped.keys()
	categories.sort()
	
	var sections: PackedStringArray = []
	for cat in categories:
		var cat_lines: Array = grouped[cat]
		cat_lines.sort()
		sections.append("[color=gray][b][i][%s][/i][/b][/color]\n%s" % [cat.capitalize(), "\n".join(cat_lines)])
	
	var header: String = "\nuse \"show [stat]\"/\"hide [stat]\", \"show_category\"/\"hide_category [cat]\", or \"stats [category]\" to filter"
	return "%s\n\n%s" % [header, "\n\n".join(sections)]


## Shows every watcher in a category at once.
func _cmd_show_category(category: String) -> String:
	return _set_category_visibility(category, true)


## Hides every watcher in a category at once.
func _cmd_hide_category(category: String) -> String:
	return _set_category_visibility(category, false)


## Shared implementation for show_category/hide_category.
func _set_category_visibility(category: String, p_visibility: bool) -> String:
	var count: int = 0
	for watcher_name in watchers:
		if watchers[watcher_name][&"category"].to_lower() == category.to_lower():
			toggle_visible(watcher_name, p_visibility)
			count += 1
	
	if count == 0:
		return "No stats in category: %s" % category
	return "%s %d stat(s) in category '%s'" % ["Shown" if p_visibility else "Hidden", count, category]


## Saves which stats are currently shown/hidden under a named profile.
func _cmd_save_profile(profile_name: String = "") -> String:
	if profile_name.is_empty():
		return "Usage: save_profile [name]"
	
	var config: ConfigFile = ConfigFile.new()
	config.load(CONFIG_PATH)
	var section: String = PROFILE_SECTION_PREFIX + profile_name
	for watcher_name in watchers:
		config.set_value(section, watcher_name, watchers[watcher_name][&"visible"])
	config.save(CONFIG_PATH)
	return "Saved profile '%s' (%d stats)" % [profile_name, watchers.size()]


## Restores a previously saved stat visibility profile. Watchers that no
## longer exist are skipped; new watchers not in the profile are left
## untouched.
func _cmd_load_profile(profile_name: String = "") -> String:
	if profile_name.is_empty():
		return "Usage: load_profile [name]"
	
	var config: ConfigFile = ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return "No profiles saved yet"
	
	var section: String = PROFILE_SECTION_PREFIX + profile_name
	if not config.has_section(section):
		return "No such profile: %s" % profile_name
	
	var applied: int = 0
	for watcher_name in config.get_section_keys(section):
		if watchers.has(watcher_name):
			toggle_visible(watcher_name, config.get_value(section, watcher_name, false))
			applied += 1
	return "Loaded profile '%s' (%d stats applied)" % [profile_name, applied]


## Lists saved stat visibility profiles.
func _cmd_list_profiles() -> String:
	var config: ConfigFile = ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return "No profiles saved yet"
	
	var names: PackedStringArray = []
	for section in config.get_sections():
		if section.begins_with(PROFILE_SECTION_PREFIX):
			names.append(section.substr(PROFILE_SECTION_PREFIX.length()))
	
	if names.is_empty():
		return "No profiles saved yet"
	names.sort()
	return "\nSaved profiles:\n%s" % "\n".join(names)


## Deletes a saved profile.
func _cmd_delete_profile(profile_name: String = "") -> String:
	if profile_name.is_empty():
		return "Usage: delete_profile [name]"
	
	var config: ConfigFile = ConfigFile.new()
	config.load(CONFIG_PATH)
	var section: String = PROFILE_SECTION_PREFIX + profile_name
	if not config.has_section(section):
		return "No such profile: %s" % profile_name
	config.erase_section(section)
	config.save(CONFIG_PATH)
	return "Deleted profile '%s'" % profile_name


## Adds a live node property to the stats panel as a non-persistent watcher.
func _cmd_watch_node(node_path: String, property: String) -> String:
	var node: Node = get_tree().root.get_node_or_null(node_path)
	if node == null:
		return "No node at path: %s" % node_path
	
	if not property in node:
		return "%s has no property '%s'" % [node_path, property]
	
	var watch_name: String = "%s.%s" % [node.name, property]
	watch(watch_name, func():
		if not is_instance_valid(node):
			return null
		return node.get(property),
		1,
		false,
		"node"
	)
	toggle_visible(watch_name, true)
	return "Watching %s" % watch_name


## Reads a node property.
func _cmd_inspect_node(node_path: String, property: String, repeat: bool = false, interval: int = 1) -> String:
	var node: Node = get_tree().root.get_node_or_null(node_path)
	if node == null:
		return "No node at path: %s" % node_path
	
	if not property in node:
		return "%s has no property '%s'" % [node_path, property]
	
	if not repeat:
		return "%s.%s = %s" % [node_path, property, str(node.get(property))]
	
	var inspect_name: String = "%s.%s" % [node.name, property]
	var clamped_interval: int = max(interval, 1)
	inspections[inspect_name] = {
		&"node": node,
		&"property": property,
		&"interval": clamped_interval,
	}
	return "Watching %s in terminal (every %d frames)" % [inspect_name, clamped_interval]


## Reads a property across all live nodes using `script_path` once.
func _cmd_inspect_script(script_path: String, property: String, repeat: bool = false, interval: int = 1) -> String:
	var matches: Array = []
	_find_script_instances(get_tree().root, script_path, matches)
	
	if matches.is_empty():
		return "No nodes found using script: %s" % script_path
	
	if not repeat:
		return _format_script_matches(matches, property)
	
	var clamped_interval: int = max(interval, 1)
	var script_name: String = "%s.%s" % [script_path.get_file(), property]
	script_inspections[script_name] = {
		&"script_path": script_path,
		&"property": property,
		&"interval": clamped_interval,
	}
	return "Watching %s in terminal (every %d frames)" % [script_name, clamped_interval]



## Clears saved font size/opacity settings for every panel.
func clear_appearance_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(CONFIG_PATH)
	if config.has_section(APPEARANCE_SECTION):
		config.erase_section(APPEARANCE_SECTION)
		config.save(CONFIG_PATH)
	appearance_changed.emit("DebugTerminal")
	appearance_changed.emit("DebugStatsPanel")
 
 
## Clears saved font size/opacity settings for one panel only.
func remove_appearance_settings_for_panel(panel_name: String) -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	if not config.has_section(APPEARANCE_SECTION):
		return
	
	var prefix: String = "%s." % panel_name
	for key in config.get_section_keys(APPEARANCE_SECTION):
		if key.begins_with(prefix):
			config.erase_section_key(APPEARANCE_SECTION, key)
	config.save(CONFIG_PATH)
	appearance_changed.emit(panel_name)


## Stops one repeating inspection by name or all of them if no name given.
func _cmd_uninspect(target: String = "") -> String:
	if target.is_empty():
		var count: int = inspections.size() + script_inspections.size()
		inspections.clear()
		script_inspections.clear()
		return "Stopped %d repeating inspection(s)" % count
	
	if inspections.has(target):
		inspections.erase(target)
		return "Stopped inspecting %s" % target
	if script_inspections.has(target):
		script_inspections.erase(target)
		return "Stopped inspecting %s" % target
	
	return "Not currently inspecting: %s" % target


## Sets a live node property to a new value.
func _cmd_set_node(node_path: String, property: String, value: Variant) -> String:
	var node: Node = get_tree().root.get_node_or_null(node_path)
	if node == null:
		return "No node at path: %s" % node_path
	
	if not property in node:
		return "%s has no property '%s'" % [node_path, property]
	
	var old_value: Variant = node.get(property)
	node.set(property, value)
	return "%s.%s: %s -> %s" % [node_path, property, str(old_value), str(value)]


## Sets a property across every live node using `script_path`.
func _cmd_set_script(script_path: String, property: String, value: Variant) -> String:
	var matches: Array = []
	_find_script_instances(get_tree().root, script_path, matches)
	
	if matches.is_empty():
		return "No nodes found using script: %s" % script_path
	
	var updated: int = 0
	for node in matches:
		if property in node:
			node.set(property, value)
			updated += 1
	return "Set %s on %d/%d matching node(s)" % [property, updated, matches.size()]


## Prints the scene hierarchy starting at `node_path`. Root is default.
func _cmd_tree(node_path: String = "", max_depth: int = 6) -> String:
	var start: Node = get_tree().root
	if node_path != "":
		start = get_tree().root.get_node_or_null(node_path)
		if start == null:
			return "No node at path: %s" % node_path
	
	var lines: PackedStringArray = []
	_build_tree_lines(start, 0, max_depth, lines)
	return "\n%s" % "\n".join(lines)


## Helper for `tree`, building one indented line per node.
func _build_tree_lines(node: Node, depth: int, max_depth: int, lines: PackedStringArray) -> void:
	var indent: String = "  ".repeat(depth)
	var class_label: String = node.get_class()
	if node.get_script() != null and node.get_script().get_global_name() != "":
		class_label = node.get_script().get_global_name()
	lines.append("%s%s [color=gray](%s)[/color]" % [indent, node.name, class_label])
	
	if depth >= max_depth:
		if node.get_child_count() > 0:
			lines.append("%s  [color=gray]...[/color]" % indent)
		return
	
	for child in node.get_children():
		_build_tree_lines(child, depth + 1, max_depth, lines)


## Searches recent terminal output for `term` and
## prints matching lines, most recent last.
func _cmd_find(term: String = "") -> String:
	if term.is_empty():
		return "Usage: find [term]"
	
	var matches: PackedStringArray = []
	for entry in log_history:
		for line in entry.split("\n"):
			if line.to_lower().contains(term.to_lower()):
				matches.append(line)
	
	if matches.is_empty():
		return "No matches for: %s" % term
	
	var shown: PackedStringArray = matches.slice(max(0, matches.size() - 50), matches.size())
	return "\nFound %d match(es), showing last %d:\n%s" % [matches.size(), shown.size(), "\n".join(shown)]


## Registers a condition that pauses the game if met.
func _cmd_break_if(watcher_name: String, op: String, value: float, repeat: bool = false) -> String:
	if not watchers.has(watcher_name):
		return "No such stat: %s" % watcher_name
	if not op in ["<", ">", "<=", ">=", "==", "!="]:
		return "Unknown operator '%s' - use < > <= >= == !=" % op
	
	var key: String = "%s %s %s" % [watcher_name, op, str(value)]
	break_conditions[key] = {
		&"watcher": watcher_name,
		&"op": op,
		&"value": value,
		&"repeat": repeat,
	}
	return "Will pause when %s" % key


## Removes one break_if condition by name, or all of them if no name given.
func _cmd_unbreak(target: String = "") -> String:
	if target.is_empty():
		var count: int = break_conditions.size()
		break_conditions.clear()
		return "Removed %d break condition(s)" % count
	
	if break_conditions.has(target):
		break_conditions.erase(target)
		return "Removed break condition: %s" % target
	
	return "No such break condition: %s" % target


## Lists active break_if conditions.
func _cmd_breaks() -> String:
	if break_conditions.is_empty():
		return "No active break conditions"
	
	var lines: PackedStringArray = []
	for key in break_conditions:
		lines.append("- %s" % key)
	lines.sort()
	return "\n%s" % "\n".join(lines)


## Pauses after a break_if pause.
func _cmd_resume() -> String:
	get_tree().paused = false
	return "Resumed"


## Sets a panel's position precisely (in addition to dragging it).
func _cmd_panel_pos(panel: String, x: float, y: float) -> String:
	var target_name: String = _resolve_panel_node_name(panel)
	if target_name.is_empty():
		return "Unknown panel '%s' - use 'stats' or 'terminal'" % panel
	
	var node: Node = get_tree().root.find_child(target_name, true, false)
	if node == null or not (node is Control):
		return "Could not find panel node: %s" % target_name
	
	node.set("position", Vector2(x, y))
	save_panel_position(target_name, Vector2(x, y))
	return "%s moved to (%.0f, %.0f)" % [target_name, x, y]


## Sets a panel's size precisely.
func _cmd_panel_size(panel: String, width: float, height: float) -> String:
	var target_name: String = _resolve_panel_node_name(panel)
	if target_name.is_empty():
		return "Unknown panel '%s' - use 'stats' or 'terminal'" % panel
	
	var node: Node = get_tree().root.find_child(target_name, true, false)
	if node == null or not (node is Control):
		return "Could not find panel node: %s" % target_name
	
	var clamped: Vector2 = Vector2(max(width, 100.0), max(height, 80.0))
	node.set("size", clamped)
	save_panel_size(target_name, clamped)
	return "%s resized to (%.0f, %.0f)" % [target_name, clamped.x, clamped.y]


## Maps the friendly names used by commands to actual scene node names.
func _resolve_panel_node_name(panel: String) -> String:
	match panel.to_lower():
		"stats", "statspanel", "debugstatspanel":
			return "DebugStatsPanel"
		"terminal", "debugterminal":
			return "DebugTerminal"
		_:
			return ""


## Sets the terminal's output/input font size, persisted across sessions.
func _cmd_term_font_size(size: int) -> String:
	var clamped: int = clampi(size, 6, 72)
	save_appearance_setting("DebugTerminal.font_size", clamped)
	appearance_changed.emit("DebugTerminal")
	return "Terminal font size set to %d" % clamped


## Sets the stats panel's label font size, persisted across sessions.
func _cmd_stats_font_size(size: int) -> String:
	var clamped: int = clampi(size, 6, 72)
	save_appearance_setting("DebugStatsPanel.font_size", clamped)
	appearance_changed.emit("DebugStatsPanel")
	return "Stats font size set to %d" % clamped


## Sets the terminal's background opacity (0 = fully transparent).
func _cmd_term_opacity(alpha: float) -> String:
	var clamped: float = clampf(alpha, 0.0, 1.0)
	save_appearance_setting("DebugTerminal.opacity", clamped)
	appearance_changed.emit("DebugTerminal")
	return "Terminal opacity set to %.2f" % clamped


## Sets the stats panel's background opacity (0 = fully transparent).
func _cmd_stats_opacity(alpha: float) -> String:
	var clamped: float = clampf(alpha, 0.0, 1.0)
	save_appearance_setting("DebugStatsPanel.opacity", clamped)
	appearance_changed.emit("DebugStatsPanel")
	return "Stats opacity set to %.2f" % clamped


## Clears saved panel positions.
func _cmd_reset_layout() -> String:
	var config: ConfigFile = ConfigFile.new()
	config.load(CONFIG_PATH)
	if config.has_section(LAYOUT_SECTION):
		config.erase_section(LAYOUT_SECTION)
		config.save(CONFIG_PATH)

	# Notify listeners that layout was reset
	layout_reset.emit()

	# Panels we want to restore to their built-in defaults
	var panel_names: PackedStringArray = PackedStringArray(["DebugStatsPanel", "DebugTerminal"])

	# Defer the actual apply until the next frame so panels have time to exist in the tree
	call_deferred("_apply_defaults_deferred", panel_names)

	return "Layout reset"


func _apply_defaults_deferred(panel_names: PackedStringArray) -> void:
	# Wait one frame so panels are present and ready
	await get_tree().process_frame

	var root: Node = get_tree().get_root()
	for pname in panel_names:
		var node: Node = _find_node_recursive(root, pname)
		if node != null and node.has_method("apply_default_layout"):
			node.call_deferred("apply_default_layout")


func _find_node_recursive(node: Node, target_name: String) -> Node:
	if node == null:
		return null
	if node.name == target_name:
		return node
	for i in range(node.get_child_count()):
		var child: Node = node.get_child(i)
		var found: Node = _find_node_recursive(child, target_name)
		if found != null:
			return found
	return null


## Clears saved font size/opacity settings.
func _cmd_reset_appearance() -> String:
	clear_appearance_settings()
	return "Appearance reset to defaults"


## Update project settings through terminal.
func _cmd_project_set(path: String, value: Variant) -> String:
	if not ProjectSettings.has_setting(path):
		return "No such project setting: %s" % path
	
	ProjectSettings.set_setting(path, value)
	ProjectSettings.save()
	
	return "%s = %s" % [path, str(value)]


## Prints a details of the host system
func _cmd_sysinfo() -> String:
	var lines: PackedStringArray = []
	
	lines.append("[color=gray][b][i][OS][/i][/b][/color]")
	lines.append("- Name: %s" % OS.get_name())
	if OS.has_method("get_distribution_name") and OS.get_distribution_name() != "":
		lines.append("- Distribution: %s" % OS.get_distribution_name())
	lines.append("- Locale: %s" % OS.get_locale())
	lines.append("- Debug build: %s" % str(OS.is_debug_build()))
	lines.append("")
	
	lines.append("[color=gray][b][i][CPU][/i][/b][/color]")
	if OS.has_method("get_processor_name"):
		lines.append("- Processor: %s" % OS.get_processor_name())
	lines.append("- Logical cores: %d" % OS.get_processor_count())
	lines.append("")
	
	lines.append("[color=gray][b][i][GPU][/i][/b][/color]")
	lines.append("- Adapter: %s" % RenderingServer.get_video_adapter_name())
	lines.append("- Vendor: %s" % RenderingServer.get_video_adapter_vendor())
	if RenderingServer.has_method("get_video_adapter_api_version"):
		lines.append("- Driver API: %s" % RenderingServer.get_video_adapter_api_version())
	lines.append("")
	
	lines.append("[color=gray][b][i][Memory][/i][/b][/color]")
	lines.append("- Static usage: %.1f MB" % (OS.get_static_memory_usage() / 1048576.0))
	lines.append("- Static peak: %.1f MB" % (Performance.get_monitor(Performance.MEMORY_STATIC_MAX) / 1048576.0))
	if OS.has_method("get_memory_info"):
		var mem_info: Dictionary = OS.get_memory_info()
		if mem_info.has("physical"):
			lines.append("- System RAM: %.1f MB" % (float(mem_info["physical"]) / 1048576.0))
		if mem_info.has("available"):
			lines.append("- Available RAM: %.1f MB" % (float(mem_info["available"]) / 1048576.0))
	lines.append("")
	
	lines.append("[color=gray][b][i][Display][/i][/b][/color]")
	lines.append("- Screens: %d" % DisplayServer.get_screen_count())
	lines.append("- Window size: %s" % str(get_window().size))
	lines.append("- Content scale: %.2f" % get_window().content_scale_factor)
	lines.append("")
	
	lines.append("[color=gray][b][i][Engine][/i][/b][/color]")
	var version: Dictionary = Engine.get_version_info()
	lines.append("- Godot: %s" % version.get("string", "unknown"))
	lines.append("- Build: %s (%s)" % [version.get("status", "unknown"), version.get("build", "unknown")])
	
	return "\n%s" % "\n".join(lines)

#endregion


#region Script Inspection Helpers

## 'tick' function for finding all living instances of a script
func _log_script_matches(script_path: String, property: String) -> void:
	var matches: Array = []
	_find_script_instances(get_tree().root, script_path, matches)
	
	if matches.is_empty():
		log_message("No live nodes using script: %s" % script_path, Color.YELLOW)
		return
	
	log_message(_format_script_matches(matches, property))


## Builds one "ClassName | node_name | property = value" line per matched node.
func _format_script_matches(matches: Array, property: String) -> String:
	var lines: Array = []
	for node in matches:
		var class_label: String = node.get_script().get_global_name() + " |" if node.get_script().get_global_name() != "" else ""
		var node_label: String = node.name + " |" if node.name != "" else ""
		if property in node:
			lines.append("%s %s %s = %s" % [class_label, node_label, property, str(node.get(property))])
		else:
			lines.append("%s %s has no property '%s'" % [class_label, node_label, property])
	return "\n".join(lines)


## Collects every node in the tree whose attached script matches `script_path`.
func _find_script_instances(node: Node, script_path: String, matches: Array) -> void:
	var script: Script = node.get_script()
	if script != null and script.resource_path == script_path:
		matches.append(node)
	for child in node.get_children():
		_find_script_instances(child, script_path, matches)

#endregion


#region Break Conditions

## Checks every registered break_if condition against its watcher.
func _update_break_conditions() -> void:
	for key in break_conditions.keys():
		var cond: Dictionary = break_conditions[key]
		if not watchers.has(cond[&"watcher"]):
			break_conditions.erase(key)
			continue
		
		var entry: Dictionary = watchers[cond[&"watcher"]]
		if not entry[&"getter"].is_valid():
			continue
		
		var value: Variant = entry[&"getter"].call()
		if not (value is int or value is float):
			continue
		
		if _compare(float(value), cond[&"op"], cond[&"value"]):
			get_tree().paused = true
			log_message("Break condition met: %s (value=%s) - type 'resume' to continue" % [key, str(value)], Color.RED)
			if not cond[&"repeat"]:
				break_conditions.erase(key)


## Evaluates `value op target` for the comparison operators break_if accepts.
func _compare(value: float, op: String, target: float) -> bool:
	match op:
		">":
			return value > target
		"<":
			return value < target
		">=":
			return value >= target
		"<=":
			return value <= target
		"==":
			return is_equal_approx(value, target)
		"!=":
			return not is_equal_approx(value, target)
		_:
			return false

#endregion


#region Aliases

## Prints all defined command aliases to the terminal.
func _print_aliases() -> void:
	if aliases.is_empty():
		log_message("No aliases defined")
		return
	
	var lines: PackedStringArray = []
	for alias_name in aliases:
		lines.append("- [b]%s[/b] - %s" % [alias_name, " ".join(aliases[alias_name])])
	lines.sort()
	log_message("\nAliases:\n%s" % "\n".join(lines))

#endregion


#region Watchers

## Registers the built-in engine/performance stats, grouped by category.
func _register_default_watchers() -> void:
	# Frame / timing
	watch("FPS", func(): return Engine.get_frames_per_second(), 1, true, "performance", _fps_color)
	watch("FrameTime", func(): return "%.2f MS" % Performance.get_monitor(Performance.TIME_PROCESS), 1, true, "performance")
	watch("PhysicsTime", func(): return "%.2f MS" % Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS), 1, true, "performance")
	watch("TimeScale", func(): return Engine.time_scale, 1, true, "performance")
	watch(
		"Uptime",
		func() -> String:
			var total_seconds: float = Time.get_ticks_msec() / 1000.0
			var hours: int = int(total_seconds / 3600.0)
			var minutes: int = int((int(total_seconds) % 3600) / 60.0)
			var seconds: int = int(total_seconds) % 60
			
			return "%02dh %02dm %02ds" % [hours, minutes, seconds],
		1,
		true,
		"performance"
	)
	
	# Memory
	watch("StaticMemory", func(): return "%.1f MB" % (OS.get_static_memory_usage() / 1048576.0), 1, true, "memory")
	watch("StaticMemoryPeak", func(): return "%.1f MB" % (Performance.get_monitor(Performance.MEMORY_STATIC_MAX) / 1048576.0), 1, true, "memory")
	watch("ObjectCount", func(): return Performance.get_monitor(Performance.OBJECT_COUNT), 1, true, "memory")
	watch("NodeCount", func(): return Performance.get_monitor(Performance.OBJECT_NODE_COUNT), 1, true, "memory", _node_count_color)
	watch("OrphanNodes", func(): return Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), 1, true, "memory", _orphan_color)
	watch("ResourceCount", func(): return Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT), 1, true, "memory")
	
	# Rendering
	watch("DrawCalls", func(): return Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), 1, true, "rendering")
	watch("PrimitivesDrawn", func(): return Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), 1, true, "rendering")
	watch("VideoMemory", func(): return "%.1f MB" % (Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0), 1, true, "rendering")
	watch("TextureMemory", func(): return "%.1f MB" % (Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0), 1, true, "rendering")
	watch("BufferMemory", func(): return "%.1f MB" % (Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0), 1, true, "rendering")
	
	# Physics (2D)
	watch("ActiveObjects2D", func(): return Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS), 1, true, "physics")
	watch("CollisionPairs2D", func(): return Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS), 1, true, "physics")
	watch("Islands2D", func(): return Performance.get_monitor(Performance.PHYSICS_2D_ISLAND_COUNT), 1, true, "physics")
	
	# Physics (3D)
	watch("ActiveObjects3D", func(): return Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS), 1, true, "physics")
	watch("CollisionPairs3D", func(): return Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS), 1, true, "physics")
	watch("Islands3D", func(): return Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT), 1, true, "physics")
	
	
	# Audio
	watch("AudioOutputLatency", func(): return "%.1f MS" % (AudioServer.get_output_latency() * 1000.0), 1, true, "audio")
	
	# Navigation
	watch("NavActiveMaps", func(): return Performance.get_monitor(Performance.NAVIGATION_ACTIVE_MAPS), 1, true, "navigation")
	watch("NavAgents", func(): return Performance.get_monitor(Performance.NAVIGATION_AGENT_COUNT), 1, true, "navigation")
	watch("NavRegionCount", func(): return Performance.get_monitor(Performance.NAVIGATION_REGION_COUNT), 1, true, "navigation")
	watch("NavEdgeConnections", func(): return Performance.get_monitor(Performance.NAVIGATION_EDGE_CONNECTION_COUNT), 1, true, "navigation")
	
	# Scene / viewport
	watch("CurrentScene", func(): return str(get_tree().current_scene.name) if get_tree().current_scene else "none", 1, true, "scene")
	watch("MousePos", func(): return get_viewport().get_mouse_position(), 1, true, "scene")
	watch("WindowSize", func(): return get_window().size, 1, true, "scene")


## Threshold color for FPS: red under 30, yellow under 50, otherwise green.
func _fps_color(value: Variant) -> Color:
	var fps: float = float(value)
	if fps < 30.0:
		return Color.RED
	if fps < 50.0:
		return Color.YELLOW
	return Color.GREEN


## Threshold color for live node count: yellow past 5000, red past 10000.
func _node_count_color(value: Variant) -> Color:
	var count: float = float(value)
	if count > 10000.0:
		return Color.RED
	if count > 5000.0:
		return Color.YELLOW
	return Color.WHITE


## Threshold color for orphan nodes: any orphan at all is worth flagging.
func _orphan_color(value: Variant) -> Color:
	return Color.YELLOW if float(value) > 0.0 else Color.WHITE


## Registers a value to be polled and shown as a label on the stats panel.
## Hidden by default.
func watch(p_name: String, p_getter: Callable, p_interval: int = 1, p_persistent: bool = true, p_category: String = "general", p_color_fn: Callable = Callable()) -> void:
	var interval: int = max(p_interval, 1)
	
	watchers[p_name] = {
		&"getter": p_getter,
		&"interval": interval,
		&"visible": false,
		&"persistent": p_persistent,
		&"category": p_category,
		&"color_fn": p_color_fn,
	}
	
	if p_persistent and pending_visibility.has(p_name):
		toggle_visible(p_name, pending_visibility[p_name])


## Removes a non-persistent watcher. Example: One added via `watch_node`.
func unwatch(p_name: String) -> void:
	if not watchers.has(p_name):
		return
	if watchers[p_name][&"persistent"]:
		log_message("%s is a permanent stat and can't be unwatched" % p_name, Color.RED)
		return
	watchers.erase(p_name)
	label_removed.emit(p_name)


## Shows or hides a watcher on the stats panel and persists the change.
func toggle_visible(p_name: String, p_visibility: bool) -> void:
	if not watchers.has(p_name):
		log_message("No such stat: %s" % p_name, Color.RED)
		return
	watchers[p_name][&"visible"] = p_visibility
	if not p_visibility:
		label_removed.emit(p_name)
	_save_visibility()

#endregion


#region Save / Load

## Loads which stats should be visible from disk.
func _load_visibility() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return

	if not config.has_section(CONFIG_SECTION):
		# nothing saved yet; avoid the error
		return

	for key in config.get_section_keys(CONFIG_SECTION):
		pending_visibility[key] = config.get_value(CONFIG_SECTION, key, false)



## Saves the current visibility of every watcher to disk.
func _save_visibility() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(CONFIG_PATH)
	for watcher_name in watchers:
		config.set_value(CONFIG_SECTION, watcher_name, watchers[watcher_name][&"visible"])
	config.save(CONFIG_PATH)

#endregion


#region Panel Layout Persistence

## Saves a panel's screen position under the layout section.
func save_panel_position(panel_name: String, panel_position: Vector2) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(CONFIG_PATH)
	config.set_value(LAYOUT_SECTION, panel_name, panel_position)
	config.save(CONFIG_PATH)


## Returns a panel's saved position, or null if none has been saved.
func load_panel_position(panel_name: String) -> Variant:
	var config: ConfigFile = ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return null
	if not config.has_section_key(LAYOUT_SECTION, panel_name):
		return null
	return config.get_value(LAYOUT_SECTION, panel_name)


## Saves a panel's size under the layout section, keyed by '<name>.size'.
func save_panel_size(panel_name: String, panel_size: Vector2) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(CONFIG_PATH)
	config.set_value(LAYOUT_SECTION, "%s.size" % panel_name, panel_size)
	config.save(CONFIG_PATH)


## Returns a panel's saved size, or null if none has been saved.
func load_panel_size(panel_name: String) -> Variant:
	var config: ConfigFile = ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return null
	var key: String = "%s.size" % panel_name
	if not config.has_section_key(LAYOUT_SECTION, key):
		return null
	return config.get_value(LAYOUT_SECTION, key)

#endregion


#region Appearance Persistence

## Saves an appearance setting (e.g. "DebugTerminal.font_size") to disk.
func save_appearance_setting(key: String, value: Variant) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(CONFIG_PATH)
	config.set_value(APPEARANCE_SECTION, key, value)
	config.save(CONFIG_PATH)


## Returns a saved appearance setting, or `default_value` if none is saved.
func load_appearance_setting(key: String, default_value: Variant) -> Variant:
	var config: ConfigFile = ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return default_value
	return config.get_value(APPEARANCE_SECTION, key, default_value)

#endregion
