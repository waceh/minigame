extends SceneTree

const Game = preload("res://scripts/game.gd")

func _initialize() -> void:
	if Game.PLATFORMS.size() != 81 or Game.PLATFORMS[-1].position.y > -7800.0:
		_fail("The course must retain 80 ledges across five tiers")
		return
	var needles := 0
	for platform: Rect2 in Game.PLATFORMS:
		if platform.size.x < 16.0:
			_fail("Ledges must retain at least 16 pixels of support")
			return
		if platform.size.x <= 24.0:
			needles += 1
	if needles < 20:
		_fail("The course must contain sustained precision landings")
		return
	var fixtures: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/course_routes.json"))
	if fixtures["route"].size() != 80 or fixtures["shortcuts"].size() != 5:
		_fail("Every normal transition and one shortcut per tier need a physical route")
		return
	var shortest_charge := 60
	var longest_charge := 0
	for jump in fixtures["route"]:
		shortest_charge = mini(shortest_charge, int(jump["frames"]))
		longest_charge = maxi(longest_charge, int(jump["frames"]))
	if shortest_charge > 15 or longest_charge < 45:
		_fail("The route must require both short and near-full charges")
		return
	print("course_test: PASS (%d needle ledges; varied charges and 5 shortcuts)" % needles)
	quit()

func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
