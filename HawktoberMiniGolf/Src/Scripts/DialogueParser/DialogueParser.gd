class_name DialogueParser

static func parse_tsv(path: String) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var first_line := true
	while not file.eof_reached():
		var line: String = file.get_line()
		if first_line:
			first_line = false
			continue
		if line.is_empty():
			continue
		var parts: PackedStringArray = line.split("\t")
		if parts.size() < 3:
			continue
		var char_mood: PackedStringArray = parts[1].split("_")
		lines.append({
			"scene": parts[0],
			"character": char_mood[0],
			"mood": char_mood[1] if char_mood.size() > 1 else "default",
			"text": parts[2]
		})
	file.close()
	return lines
