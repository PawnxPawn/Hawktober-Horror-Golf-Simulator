extends Node

# Signals
signal score_changed(new_hits: int, par: int)
signal hole_completed(rating: String, score_diff: int)
signal round_reset

# Current hole data
var current_par: int = 4
var hit_count: int = 0

# Round data (for multiple holes)
var holes_completed: int = 0
var total_score: int = 0  # Total strokes relative to par (can be negative)
var hole_scores: Array = []  # Array of score differences per hole


func _ready():
	print("ScoreManager initialized")


# Set par for current hole
func set_par(new_par: int) -> void:
	current_par = new_par
	reset_hole()


# Increment hit count and emit signal
func add_hit() -> void:
	hit_count += 1
	score_changed.emit(hit_count, current_par)


# Get score difference for current hole
func get_score_difference() -> int:
	return hit_count - current_par


# Get rating based on score
func get_score_rating() -> String:
	var score_difference = get_score_difference()
	
	match score_difference:
		-3:
			return "Albatross!"
		-2:
			return "Eagle!"
		-1:
			return "Birdie!"
		0:
			return "Par"
		1:
			return "Bogey"
		2:
			return "Double Bogey"
		_:
			if score_difference < -3:
				return "Amazing!"
			else:
				return "+%d" % score_difference


# Get color based on score
func get_score_color() -> Color:
	var score_diff = get_score_difference()
	
	if score_diff < 0:
		return Color.GREEN
	elif score_diff > 0:
		return Color.RED
	else:
		return Color.YELLOW


# Complete current hole and move to next
func complete_hole() -> void:
	var score_diff = get_score_difference()
	var rating = get_score_rating()
	
	hole_scores.append(score_diff)
	total_score += score_diff
	holes_completed += 1
	
	hole_completed.emit(rating, score_diff)
	print("Hole %d completed: %s (Score: %+d, Total: %+d)" % [holes_completed, rating, score_diff, total_score])


# Reset current hole
func reset_hole() -> void:
	hit_count = 0
	score_changed.emit(0, current_par)


# Reset entire round
func reset_round() -> void:
	current_par = 4
	hit_count = 0
	holes_completed = 0
	total_score = 0
	hole_scores.clear()
	round_reset.emit()
	print("Round reset")


# Get total score as string
func get_total_score_string() -> String:
	if holes_completed == 0:
		return "E"
	
	if total_score == 0:
		return "E"
	elif total_score > 0:
		return "+%d" % total_score
	else:
		return "%d" % total_score


# Get stats for current round
func get_round_stats() -> Dictionary:
	var birdies = hole_scores.filter(func(s): return s == -1).size()
	var eagles = hole_scores.filter(func(s): return s == -2).size()
	var albatrosses = hole_scores.filter(func(s): return s == -3).size()
	var pars = hole_scores.filter(func(s): return s == 0).size()
	var bogeys = hole_scores.filter(func(s): return s == 1).size()
	var double_bogeys = hole_scores.filter(func(s): return s == 2).size()
	
	return {
		"holes_completed": holes_completed,
		"total_score": total_score,
		"albatrosses": albatrosses,
		"eagles": eagles,
		"birdies": birdies,
		"pars": pars,
		"bogeys": bogeys,
		"double_bogeys": double_bogeys
	}
