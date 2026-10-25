extends SceneTree

func _initialize():
	call_deferred("run")

func run():
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.start_game()
	assert(game.mode == "playing" and game.lives == 3)
	game.spawn_wave()
	assert(game.enemies.size() == 21 and game.wave == 1)
	var enemy = game.enemies[0]
	enemy.hp = 1
	enemy.p = Vector2(240, 300)
	game.shots.append({"p": enemy.p, "v": Vector2.ZERO})
	game.update_game(0.0)
	assert(game.enemies.size() == 20 and game.score == 100)
	game.enemies.clear()
	game.wave = 3
	game.spawn_wave()
	assert(game.enemies.size() == 1 and game.enemies[0].kind == 3)
	game.pickups.append(game.player)
	game.update_game(0.01)
	assert(game.power > 9.0)
	game.invincible = 0
	game.hit_player()
	assert(game.lives == 2 and game.power == 0)
	game.hit_player()
	assert(game.lives == 2, "Invulnerability must prevent repeated damage")
	for i in range(3600):
		game.update_game(1.0 / 60.0)
		if game.mode == "gameover": break
	assert(game.bullets.size() < 200 and game.shots.size() < 100)
	game.start_game()
	assert(game.lives == 3 and game.score == 0 and game.enemies.is_empty())
	print("PASS: formation, boss, hit, pickup, invulnerability, simulation, restart")
	quit()
