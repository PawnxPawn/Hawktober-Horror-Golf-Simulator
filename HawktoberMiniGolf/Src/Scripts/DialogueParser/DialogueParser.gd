class_name DialogueParser

static func parse_tsv(path: String) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	var file := FileAccess.open(path, FileAccess.READ)
	while not file.eof_reached():
		var line := file.get_line()
		if line.is_empty():
			continue
		var parts := line.split("\t")
		if parts.size() < 3:
			continue
		var char_mood := parts[1].split("_")
		lines.append({
			"scene": parts[0],
			"character": char_mood[0],
			"mood": char_mood[1] if char_mood.size() > 1 else "default",
			"text": parts[2]
		})
	file.close()
	return lines
