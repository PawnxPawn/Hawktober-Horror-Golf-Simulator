class_name DebugLogCapture
extends Logger

func _log_error(_function: String, file: String, _line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtraces: Array) -> void:
	
	var color: Color = Color.RED if error_type == 0 else Color.YELLOW
	var text: String = rationale if rationale != "" else code
	
	var location: String = file.get_file()
	if not script_backtraces.is_empty():
		var trace: ScriptBacktrace = script_backtraces[0]
		if trace.get_frame_count() > 0:
			location = "%s:%d @ %s()" % [
				trace.get_frame_file(0).get_file(),
				trace.get_frame_line(0),
				trace.get_frame_function(0)
			]
	
	var full: String = "[i][System][/i] %s [%s]" % [text, location]
	var lines: PackedStringArray = full.split("\n", false)
	
	for line in lines:
		DebugRegistry.log_message(line, color)


func _log_message(message: String, _error: bool) -> void:
	var lines := message.split("\n", false)
	for line in lines:
		if line.strip_edges() == "":
			DebugRegistry.log_message("")
		else:
			DebugRegistry.log_message("[i][System][/i] %s" % line)
