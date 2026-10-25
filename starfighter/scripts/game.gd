extends Node2D

const FONT = preload("res://font.ttf")
const CYAN = Color("66ebff")
const GOLD = Color("ffcf70")
var rng = RandomNumberGenerator.new()
var stars: Array = []
var enemies: Array = []
var shots: Array = []
var bullets: Array = []
var sparks: Array = []
var pickups: Array = []
var player = Vector2(240, 690)
var mode = "title"
var score = 0
var best = 0
var wave = 0
var lives = 3
var clock = 0.0
var fire_timer = 0.0
var enemy_timer = 1.0
var wave_timer = 0.0
var invincible = 0.0
var power = 0.0
var touch_id = -1
var touch_target = Vector2.ZERO
var paused = false
var kills = 0

func _ready():
	rng.randomize()
	for i in range(85):
		stars.append(Vector3(rng.randf_range(0, 480), rng.randf_range(0, 800), rng.randf_range(0.3, 1.0)))
	if FileAccess.file_exists("user://record.txt"):
		best = int(FileAccess.get_file_as_string("user://record.txt"))

func start_game():
	score = 0
	wave = 0
	lives = 3
	kills = 0
	player = Vector2(240, 690)
	shots.clear()
	bullets.clear()
	enemies.clear()
	pickups.clear()
	sparks.clear()
	power = 0.0
	invincible = 2.0
	wave_timer = 0.7
	fire_timer = 0.0
	paused = false
	mode = "playing"

func _notification(what):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and mode == "playing":
		paused = true
		touch_id = -1

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P or event.keycode == KEY_ESCAPE:
			if mode == "playing": paused = not paused
		elif event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			if mode != "playing": start_game()
		elif event.keycode == KEY_R and mode == "gameover": start_game()
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.y < 85 and event.position.x > 390 and mode == "playing":
				paused = not paused
			elif mode != "playing": start_game()
			elif paused: paused = false
			elif touch_id == -1:
				touch_id = event.index
				touch_target = event.position - Vector2(0, 65)
		elif event.index == touch_id: touch_id = -1
	if event is InputEventScreenDrag and event.index == touch_id:
		touch_target = event.position - Vector2(0, 65)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if mode != "playing": start_game()
		elif event.position.y < 85 and event.position.x > 390: paused = not paused
		elif paused: paused = false

func spawn_wave():
	wave += 1
	enemy_timer = 1.6
	if wave % 4 == 0:
		enemies.append({"p": Vector2(240, -70), "home": Vector2(240, 155), "hp": 65 + wave * 7, "max": 65 + wave * 7, "kind": 3, "phase": 0.0, "dive": false, "v": Vector2.ZERO})
	else:
		for row in range(3):
			for col in range(7):
				var home = Vector2(66 + col * 58, 145 + row * 56)
				enemies.append({"p": home - Vector2(0, 350 + col * 22), "home": home, "hp": 2 if row == 0 else 1, "max": 2 if row == 0 else 1, "kind": row % 3, "phase": col * 0.6, "dive": false, "v": Vector2.ZERO})

func burst(pos: Vector2, color: Color, count: int):
	for i in range(count):
		var angle = rng.randf_range(0, TAU)
		sparks.append({"p": pos, "v": Vector2.from_angle(angle) * rng.randf_range(35, 210), "life": rng.randf_range(0.25, 0.65), "c": color})

func hit_player():
	if invincible > 0: return
	lives -= 1
	power = 0
	invincible = 2.5
	burst(player, CYAN, 26)
	if lives <= 0:
		mode = "gameover"
		best = maxi(best, score)
		var file = FileAccess.open("user://record.txt", FileAccess.WRITE)
		if file: file.store_string(str(best))

func _process(dt):
	clock += dt
	for i in range(stars.size()):
		stars[i].y = fmod(stars[i].y + dt * (18 + stars[i].z * 60), 800)
	for i in range(sparks.size() - 1, -1, -1):
		sparks[i].p += sparks[i].v * dt
		sparks[i].life -= dt
		if sparks[i].life <= 0: sparks.remove_at(i)
	if mode == "playing" and not paused:
		update_game(minf(dt, 0.05))
	queue_redraw()

func update_game(dt: float):
	invincible = maxf(0, invincible - dt)
	power = maxf(0, power - dt)
	var axis = Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	player += axis.normalized() * 320 * dt
	if touch_id >= 0: player = player.move_toward(touch_target, 570 * dt)
	player = player.clamp(Vector2(22, 410), Vector2(458, 752))
	fire_timer -= dt
	if fire_timer <= 0:
		fire_timer = 0.14 if power > 0 else 0.21
		shots.append({"p": player - Vector2(0, 23), "v": Vector2(0, -640)})
		if power > 0:
			for side in [-1, 1]: shots.append({"p": player + Vector2(side * 12, -10), "v": Vector2(side * 90, -610)})
	if enemies.is_empty():
		wave_timer -= dt
		if wave_timer <= 0:
			bullets.clear()
			spawn_wave()
	else: wave_timer = 1.8
	for e in enemies:
		e.phase += dt
		if e.dive:
			e.p += e.v * dt
			if e.p.y > 850:
				e.p = Vector2(e.home.x, -45)
				e.dive = false
		else:
			var target: Vector2 = e.home + Vector2(sin(e.phase * 1.8) * (85 if e.kind == 3 else 19), 0)
			e.p = e.p.move_toward(target, dt * 190)
		if e.p.distance_to(player) < (43 if e.kind == 3 else 26): hit_player()
	enemy_timer -= dt
	if enemy_timer <= 0 and not enemies.is_empty():
		enemy_timer = maxf(0.24, 1.0 - wave * 0.055)
		var e = enemies[rng.randi_range(0, enemies.size() - 1)]
		if e.p.y > 80 and e.p.y < 650:
			var direction: Vector2 = (player - e.p).normalized()
			for spread in ([-0.38, -0.19, 0.0, 0.19, 0.38] if e.kind == 3 else [0.0]):
				bullets.append({"p": e.p + Vector2(0, 15), "v": direction.rotated(spread) * (170 + mini(wave, 15) * 9)})
			if e.kind != 3 and not e.dive and rng.randf() < 0.6:
				e.dive = true
				e.v = direction * (150 + wave * 5)
	for i in range(shots.size() - 1, -1, -1):
		var shot = shots[i]
		shot.p += shot.v * dt
		var consumed = shot.p.y < -20
		for j in range(enemies.size() - 1, -1, -1):
			var e = enemies[j]
			if not consumed and shot.p.distance_to(e.p) < (47 if e.kind == 3 else 22):
				consumed = true
				e.hp -= 1
				burst(shot.p, GOLD, 4)
				if e.hp <= 0:
					score += 1500 if e.kind == 3 else 100 + e.kind * 50
					kills += 1
					burst(e.p, Color("ff7c95"), 32 if e.kind == 3 else 14)
					if kills % 9 == 0 or e.kind == 3: pickups.append(e.p)
					enemies.remove_at(j)
		if consumed: shots.remove_at(i)
	for i in range(bullets.size() - 1, -1, -1):
		bullets[i].p += bullets[i].v * dt
		var p: Vector2 = bullets[i].p
		if p.distance_to(player) < 13:
			hit_player()
			bullets.remove_at(i)
		elif p.y > 830 or p.x < -30 or p.x > 510 or p.y < -40: bullets.remove_at(i)
	for i in range(pickups.size() - 1, -1, -1):
		pickups[i].y += 115 * dt
		if pickups[i].distance_to(player) < 28:
			power = 10
			score += 50
			pickups.remove_at(i)
		elif pickups[i].y > 830: pickups.remove_at(i)

func label_at(text: String, pos: Vector2, size: int, color: Color):
	draw_string(FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func centered(text: String, y: float, size: int, color: Color):
	label_at(text, Vector2((480 - FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x) / 2, y), size, color)

func ship(pos: Vector2, kind: int, color: Color, scale_factor: float = 1.0):
	var shape = PackedVector2Array()
	var points = [Vector2(0, -24), Vector2(9, -5), Vector2(23, 12), Vector2(22, 19), Vector2(7, 13), Vector2(0, 19), Vector2(-7, 13), Vector2(-22, 19), Vector2(-23, 12), Vector2(-9, -5)]
	if kind >= 0:
		points = [Vector2(0, 19), Vector2(10, 6), Vector2(23, 13), Vector2(18, -9), Vector2(8, -15), Vector2(0, -6), Vector2(-8, -15), Vector2(-18, -9), Vector2(-23, 13), Vector2(-10, 6)]
	for p in points: shape.append(pos + p * scale_factor)
	draw_colored_polygon(shape, Color(color, 0.22))
	shape.append(shape[0])
	draw_polyline(shape, color, 1.8, true)
	draw_circle(pos, 4 * scale_factor, color)
	if kind == -1:
		draw_line(pos + Vector2(-5, 20), pos + Vector2(-3, 30 + sin(clock * 30) * 7), GOLD, 3)
		draw_line(pos + Vector2(5, 20), pos + Vector2(3, 30 + sin(clock * 30) * 7), GOLD, 3)

func _draw():
	draw_rect(Rect2(0, 0, 480, 800), Color("050b1c"))
	for s in stars:
		draw_circle(Vector2(s.x, s.y), s.z * 1.5, Color(0.5, 0.75, 1, s.z * 0.7))
	for x in range(0, 481, 48): draw_line(Vector2(x, 80), Vector2(x, 780), Color(0.2, 0.5, 0.8, 0.035))
	for s in shots:
		draw_line(s.p, s.p + Vector2(0, 16), Color(CYAN, 0.16), 9)
		draw_line(s.p, s.p + Vector2(0, 14), CYAN, 3, true)
	for b in bullets:
		draw_circle(b.p, 8, Color(1, 0.28, 0.4, 0.13))
		draw_circle(b.p, 4, Color("ff718e"))
	for e in enemies:
		var color: Color = [Color("ffbd69"), Color("ff718e"), Color("b49bff"), Color("ff718e")][e.kind]
		ship(e.p, e.kind, color, 2.2 if e.kind == 3 else 0.8)
		if e.kind == 3:
			draw_rect(Rect2(e.p + Vector2(-50, -48), Vector2(100, 4)), Color("342741"))
			draw_rect(Rect2(e.p + Vector2(-50, -48), Vector2(100.0 * e.hp / e.max, 4)), color)
	for p in pickups:
		draw_circle(p, 14, Color("173f49"))
		draw_arc(p, 14, 0, TAU, 24, CYAN, 1.5)
		label_at("P", p + Vector2(-5, 6), 16, CYAN)
	for s in sparks: draw_circle(s.p, 2.5, Color(s.c, minf(1, s.life * 2)))
	if mode == "playing" and (invincible <= 0 or int(clock * 12) % 2 == 0):
		ship(player, -1, CYAN)
		if invincible > 0: draw_arc(player, 32, 0, TAU, 40, Color(CYAN, 0.25), 1)
	draw_rect(Rect2(0, 0, 480, 84), Color("0b1429"))
	draw_line(Vector2(20, 84), Vector2(460, 84), Color("24405b"), 1)
	label_at("STAR / SQUADRON", Vector2(20, 26), 12, CYAN)
	label_at("%07d" % score, Vector2(20, 62), 26, Color.WHITE)
	label_at("WAVE %02d" % wave, Vector2(224, 30), 13, GOLD)
	label_at("♥ ".repeat(maxi(0, lives)), Vector2(224, 61), 19, Color("ff718e"))
	label_at("Ⅱ" if not paused else "▶", Vector2(424, 53), 25, CYAN)
	draw_rect(Rect2(0, 775, 480, 25), Color("0b1429"))
	centered("트리플 샷  %.1fs" % power if power > 0 else "이동  WASD / 방향키 · 드래그     |     일시정지  P", 792, 11, CYAN if power > 0 else Color("8194b5"))
	if mode == "playing" and enemies.is_empty(): centered("WAVE %02d" % (wave + 1), 345, 30, GOLD)
	if mode == "title" or mode == "gameover" or paused:
		draw_rect(Rect2(0, 85, 480, 690), Color(0.02, 0.04, 0.10, 0.9))
		if mode == "title":
			ship(Vector2(240, 230), -1, CYAN, 2.0)
			centered("STAR", 333, 56, Color.WHITE)
			centered("S Q U A D R O N", 369, 25, CYAN)
			centered("스타 편대", 410, 19, GOLD)
			centered("적 편대를 돌파하고 우주를 지켜라", 466, 15, Color("9badc9"))
		elif mode == "gameover":
			centered("MISSION OVER", 300, 32, Color("ff718e"))
			centered("%07d" % score, 362, 46, Color.WHITE)
			centered("도달 웨이브  %02d    ·    격추  %d" % [wave, kills], 409, 16, CYAN)
		else: centered("PAUSED", 350, 40, CYAN)
		draw_style_box(button_style(), Rect2(80, 515, 320, 58))
		centered("계속하기" if paused else ("다시 출격" if mode == "gameover" else "출격하기"), 552, 21, Color("071321"))
		centered("화면 터치 또는 ENTER", 603, 13, Color("9badc9"))
		centered("자동 발사 · 파워업 P 획득 · 4웨이브마다 보스", 649, 12, Color("9badc9"))
		centered("BEST  %07d" % best, 706, 16, GOLD)

func button_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = CYAN
	style.set_corner_radius_all(10)
	return style
