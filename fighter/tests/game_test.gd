extends SceneTree
const Main = preload("res://main.tscn")
const Fighter = preload("res://scripts/fighter.gd")
func _initialize() -> void:
	call_deferred("run_test")
func run_test() -> void:
	var game = Main.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	assert(game.fighters.size() == 2)
	assert(game.fighters[0].sprite.texture != null)
	assert(game.fighters[0].sprite.hframes == 4 and game.fighters[0].sprite.vframes == 4)
	game.start_match()
	assert(game.state == "intro")
	var art = game.fighters[0]
	art.attack("kick")
	art.step(0.24)
	art.pose(0)
	assert(art.visual_frame == 3)
	art.reset_at(Vector3(-2.1,0,0))
	art.guard = true
	art.pose(0)
	assert(art.visual_frame == 5)
	art.guard = false
	art.hp = 0
	art.pose(0)
	assert(art.visual_frame == 7)
	art.face = -1
	art.pose(0)
	assert(art.sprite.flip_h)
	art.reset_at(Vector3(-2.1,0,0))
	for i in range(140):
		game._physics_process(1.0 / 60)
	assert(game.state == "fight")
	var a = game.fighters[0]
	var b = game.fighters[1]
	a.reset_at(Vector3(-0.7, 0, 0))
	b.reset_at(Vector3(0.7, 0, 0))
	assert(a.attack("punch"))
	assert(a.resolve_hit(b).is_empty())
	a.step(0.12)
	assert(a.resolve_hit(b).damage == 7)
	assert(b.hp == 93)
	assert(a.resolve_hit(b).is_empty())
	assert(not b.attack("punch"))
	a.step(1)
	b.reset_at(Vector3(0.7, 0, 0))
	b.guard = true
	a.attack("heavy")
	a.step(0.38)
	assert(a.resolve_hit(b).blocked)
	assert(b.hp == 100)
	for axis in [0, 2]:
		a.reset_at(Vector3(-0.7, 0, 0))
		b.reset_at(Vector3(0.7, 0, 0))
		b.position[axis] = 4
		a.attack("kick")
		a.step(0.24)
		assert(a.resolve_hit(b).is_empty())
		assert(b.hp == 100)
	a.reset_at(Vector3(-0.7, 0, 0))
	b.reset_at(Vector3(0.7, 0, 0))
	a.attack("launch")
	a.step(0.30)
	assert(a.resolve_hit(b).damage == 14)
	b.step(0.1)
	assert(b.position.y > 0)
	a.step(0.4)
	a.attack("punch")
	a.step(0.12)
	assert(a.resolve_hit(b).damage == 5)
	for i in range(200):
		b.step(1.0/60)
	assert(b.position.y == 0)
	game.toggle_pause()
	assert(game.state == "paused")
	var time: float = game.round_time
	game._physics_process(1)
	assert(game.round_time == time)
	game.toggle_pause()
	assert(game.state == "fight")
	a.hp = 100
	b.hp = 0
	game.end_round()
	assert(a.wins == 1 and game.state == "end")
	game._physics_process(3.1)
	assert(game.round_number == 2 and game.state == "intro")
	assert(a.hp == 100 and b.hp == 100)
	b.hp = 0
	game.end_round()
	assert(a.wins == 2)
	game._physics_process(3.1)
	assert(game.state == "over" and game.menu.visible)
	game.start_match()
	assert(a.wins == 0 and game.round_number == 1)
	game.state = "fight"
	a.hp = 50
	b.hp = 70
	game.round_time = 0
	game.end_round()
	assert(b.wins == 1)
	game.touch_keys["guard"] = true
	game._focus_lost()
	assert(game.state == "paused" and game.touch_keys.is_empty())
	game.free()
	print("fighter game_test: PASS — sprite states, startup, hit-once, guard, evasion, juggle, pause, rounds, rematch, timeout, focus")
	quit()
