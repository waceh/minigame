extends Node3D
const Fighter = preload("res://scripts/fighter.gd")
const Arena = preload("res://scripts/arena.gd")
const V = preload("res://scripts/visuals.gd")
const BASE_FONT = preload("res://font.ttf")
var FONT: FontVariation = make_font()
var fighters: Array = []
var camera: Camera3D
var ui: Control
var menu: Panel
var title_label: Label
var description: Label
var start_button: Button
var mode_select: OptionButton
var difficulty_select: OptionButton
var callout: Label
var combo_label: Label
var timer_label: Label
var round_label: Label
var health: Array[ProgressBar] = []
var win_labels: Array[Label] = []
var pause_button: Button
var touch_root: Control
var touch_keys: Dictionary = {}
var state := "menu"
var previous_state := "fight"
var match_mode := 0
var difficulty := 1
var round_number := 1
var round_time := 60.0
var phase_time := 0.0
var ai_wait := 0.0
var freeze_time := 0.0
var shake := 0.0
var elapsed := 0.0
var combo_display_time := 0.0
var effects: Array = []
var shadows: Array[MeshInstance3D] = []
var audio_player: AudioStreamPlayer
var hit_sound: AudioStreamWAV
var block_sound: AudioStreamWAV
var touch_visible := false
const KEYS = [
	{"left": KEY_A, "right": KEY_D, "up": KEY_W, "down": KEY_S, "guard": KEY_L, "punch": KEY_J, "kick": KEY_K, "launch": KEY_U, "heavy": KEY_I},
	{"left": KEY_LEFT, "right": KEY_RIGHT, "up": KEY_UP, "down": KEY_DOWN, "guard": KEY_3, "punch": KEY_1, "kick": KEY_2, "launch": KEY_4, "heavy": KEY_5}
]

func make_font() -> FontVariation:
	var font := FontVariation.new()
	font.base_font = BASE_FONT
	font.variation_embolden = 0.4
	font.variation_opentype = {"wght": 650.0}
	return font

func _ready() -> void:
	Input.emulate_mouse_from_touch = true
	add_child(Arena.new())
	for i in range(2):
		var f = Fighter.new()
		add_child(f)
		f.setup(i)
		f.reset_at(Vector3(-2.0 if i == 0 else 2.0, 0, 0))
		f.face = 1 if i == 0 else -1
		f.pose(0)
		fighters.append(f)
		var shadow_mat := V.material(Color(0.005, 0.009, 0.02, 0.35))
		shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var shadow := V.cylinder(self, 0.65, 0.65, 0.002, Vector3.ZERO, shadow_mat, 32)
		shadow.scale.z = 0.55
		shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shadows.append(shadow)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 45
	camera.position = Vector3(0.7, 6.3, 12.8)
	add_child(camera)
	camera.look_at(Vector3(0, 1.2, 0))
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	hit_sound = make_sound(false)
	block_sound = make_sound(true)
	build_ui()
	get_window().focus_exited.connect(_focus_lost)
	get_viewport().size_changed.connect(layout_ui)
	layout_ui()

func make_sound(blocked: bool) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var bytes := PackedByteArray()
	for i in range(3500):
		var t := float(i) / 22050
		var envelope := exp(-t * 34)
		var sample := (sin(t * (1600 if blocked else 520) * exp(-t * 10)) * 0.55 + randf_range(-0.4, 0.4)) * envelope * 17000
		bytes.append_array(PackedInt32Array([int(sample)]).to_byte_array().slice(0, 2))
	wav.data = bytes
	return wav

func label_at(parent: Control, text: String, font_size: int, color: Color = Color("f7f1dd")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.04, 0.09, 0.07, 0.8))
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func style(color: Color, border: Color = Color.TRANSPARENT, radius: int = 5) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 16
	s.content_margin_right = 16
	return s

func button_at(parent: Control, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_stylebox_override("normal", style(Color("243d37"), Color("6c9270")))
	b.add_theme_stylebox_override("hover", style(Color("3b6249"), Color("e1e6a0")))
	b.add_theme_stylebox_override("pressed", style(Color("3c605d")))
	parent.add_child(b)
	return b

func stripe(parent: Control, color: Color) -> ColorRect:
	var node := ColorRect.new()
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform vec4 tint:source_color; void fragment(){float band=step(.5,fract((FRAGCOORD.x+FRAGCOORD.y)/18.0)); COLOR=vec4(tint.rgb*(.92+band*.08),tint.a);}"
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("tint", color)
	node.material = material
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	var clock_card := Panel.new()
	clock_card.name = "ClockCard"
	clock_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clock_card.add_theme_stylebox_override("panel", style(Color(0.07, 0.12, 0.16, 0.96), Color("b8b18b"), 14))
	ui.add_child(clock_card)
	for i in range(2):
		var card := Panel.new()
		card.name = "Card" + str(i)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_theme_stylebox_override("panel", style(Color(0.07, 0.12, 0.16, 0.94), Color("59786b"), 14))
		ui.add_child(card)
		var band := stripe(card, Color("376e5a") if i == 0 else Color("8f4e4b"))
		band.position = Vector2(8, 8)
		band.size = Vector2(470, 22)
		band.name = "Band"
		var portrait := TextureRect.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = preload("res://assets/fighters.png")
		var cell := atlas.atlas.get_width()/4.0
		atlas.region = Rect2(cell*.29, (cell*2 if i == 1 else 0)+cell*.015, cell*.49, cell*.49)
		portrait.texture = atlas
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		portrait.position = Vector2(12 if i == 0 else 408, 6)
		portrait.size = Vector2(72,72)
		portrait.name = "Portrait"
		card.add_child(portrait)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.max_value = 100
		bar.value = 100
		bar.add_theme_stylebox_override("background", style(Color("283c39"), Color("63787c"), 2))
		bar.add_theme_stylebox_override("fill", style(Color("7fdb9e") if i == 0 else Color("f1aa79"), Color.TRANSPARENT, 2))
		if i == 1:
			bar.fill_mode = ProgressBar.FILL_END_TO_BEGIN
		ui.add_child(bar)
		health.append(bar)
		var name_label := label_at(ui, "01 / RYU   ·   청린" if i == 0 else "적월   ·   KAI / 02", 18)
		name_label.name = "Name" + str(i)
		var wins := label_at(ui, "○  ○", 21, Color("d2f4b0"))
		win_labels.append(wins)
	timer_label = label_at(ui, "60", 45)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_label = label_at(ui, "ROUND 01", 10, Color("c4d3bb"))
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_button = button_at(ui, "일시정지  ESC")
	pause_button.pressed.connect(toggle_pause)
	var touch_toggle := button_at(ui, "터치 조작")
	touch_toggle.name = "TouchToggle"
	touch_toggle.pressed.connect(func():
		touch_visible = not touch_visible
		touch_root.visible = touch_visible and state != "menu" and state != "over"
		touch_keys.clear())
	var footer_card := Panel.new()
	footer_card.name = "FooterCard"
	footer_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer_card.add_theme_stylebox_override("panel", style(Color(0.06, 0.12, 0.12, 0.88), Color("526b53"), 8))
	ui.add_child(footer_card)
	var engine_label := label_at(ui, "FOREST CLASH  /  숲속 무투장", 10, Color("d3dfc5"))
	engine_label.name = "EngineLabel"
	var help := label_at(ui, "WASD 이동·횡이동    J 펀치    K 킥    U 띄우기    I 강킥    L 가드", 13, Color("f2f0d0"))
	help.name = "Help"
	var help2 := label_at(ui, "2P  방향키 이동    1 펀치 / 2 킥 / 4 띄우기 / 5 강킥 / 3 가드", 11, Color("d0ddbb"))
	help2.name = "Help2"
	callout = label_at(ui, "", 64, Color("d5f4bc"))
	callout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	callout.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	callout.add_theme_constant_override("shadow_offset_y", 5)
	combo_label = label_at(ui, "", 24, Color("ceefaf"))
	menu = Panel.new()
	menu.add_theme_stylebox_override("panel", style(Color(0.07, 0.13, 0.12, 0.96), Color("779a70"), 8))
	ui.add_child(menu)
	var menu_stripe := stripe(menu, Color("4d856b"))
	menu_stripe.position = Vector2(1,1)
	menu_stripe.size = Vector2(402, 10)
	var eyebrow := label_at(menu, "W O O D L A N D  /  D U E L", 10, Color("f0dba0"))
	eyebrow.position = Vector2(32, 28)
	title_label = label_at(menu, "FOREST\nCLASH", 62)
	title_label.position = Vector2(28, 50)
	title_label.add_theme_constant_override("line_spacing", -15)
	description = label_at(menu, "청린 vs 적월\n거리를 읽고, 빈틈을 노려라.\n띄우기 → 펀치 → 킥으로 공중 콤보!", 14, Color("d1dfc7"))
	description.position = Vector2(32, 208)
	var mode_label := label_at(menu, "대전 모드", 11, Color("b7ccad"))
	mode_label.position = Vector2(32, 300)
	var difficulty_label := label_at(menu, "CPU 난이도", 11, Color("b7ccad"))
	difficulty_label.position = Vector2(222, 300)
	mode_select = OptionButton.new()
	mode_select.add_item("CPU 대전")
	mode_select.add_item("로컬 2인 대전")
	menu.add_child(mode_select)
	mode_select.position = Vector2(32, 325)
	mode_select.size = Vector2(175, 40)
	difficulty_select = OptionButton.new()
	for item in ["연습", "보통", "도전"]:
		difficulty_select.add_item(item)
	difficulty_select.selected = 1
	menu.add_child(difficulty_select)
	difficulty_select.position = Vector2(222, 325)
	difficulty_select.size = Vector2(150, 40)
	for select in [mode_select, difficulty_select]:
		select.add_theme_font_override("font", FONT)
		select.add_theme_font_size_override("font_size", 15)
		select.add_theme_stylebox_override("normal", style(Color("2d4439"), Color("668763")))
		select.get_popup().add_theme_font_override("font", FONT)
	start_button = button_at(menu, "대전 시작     ↗")
	start_button.position = Vector2(32, 390)
	start_button.size = Vector2(340, 52)
	start_button.add_theme_stylebox_override("normal", style(Color("f3d88f")))
	start_button.add_theme_color_override("font_color", Color("172c2b"))
	start_button.add_theme_font_size_override("font_size", 20)
	start_button.pressed.connect(start_match)
	var note := label_at(menu, "2라운드 선승   /   60초   /   숲속 무투장", 11, Color("8ba5ae"))
	note.position = Vector2(32, 462)
	touch_root = Control.new()
	touch_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(touch_root)
	touch_visible = DisplayServer.is_touchscreen_available()
	touch_root.visible = false
	for info in [["↑", "up", Vector2(55, 0)], ["←", "left", Vector2(0, 55)], ["↓", "down", Vector2(55, 55)], ["→", "right", Vector2(110, 55)], ["띄우기", "launch", Vector2(0, 0)], ["강킥", "heavy", Vector2(60, 0)], ["펀치", "punch", Vector2(0, 55)], ["킥", "kick", Vector2(60, 55)], ["가드", "guard", Vector2(120, 55)]]:
		var button := button_at(touch_root, info[0])
		button.size = Vector2(52, 50)
		button.set_meta("action", info[1])
		button.set_meta("offset", info[2])
		var action: String = info[1]
		button.button_down.connect(func():
			touch_keys[action] = true
			if state == "fight" and action in Fighter.MOVES:
				fighters[0].attack(action))
		button.button_up.connect(func(): touch_keys.erase(action))

func layout_ui() -> void:
	if not is_instance_valid(ui):
		return
	var size := get_viewport().get_visible_rect().size
	var width: float = size.x
	var height: float = size.y
	var margin := 42.0
	var card_width := (width - 160) / 2
	var bar_width := card_width - 106
	for i in range(2):
		var x := 24.0 if i == 0 else width / 2 + 56
		var card: Panel = ui.get_node("Card" + str(i))
		card.position = Vector2(x, 20)
		card.size = Vector2(card_width, 82)
		card.get_node("Band").size.x = card_width - 16
		card.get_node("Portrait").position.x = 10 if i == 0 else card_width - 82
		health[i].position = Vector2(x + (90 if i == 0 else 16), 70)
		health[i].size = Vector2(bar_width, 16)
		var name_label: Label = ui.get_node("Name" + str(i))
		name_label.position = Vector2(x + (92 if i == 0 else 16), 32)
		name_label.size = Vector2(bar_width, 28)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		win_labels[i].position = Vector2(x + card_width - 72 if i == 0 else x + 14, 40)
		win_labels[i].add_theme_font_size_override("font_size", 15)
	ui.get_node("ClockCard").position = Vector2(width / 2 - 47, 16)
	ui.get_node("ClockCard").size = Vector2(94, 94)
	timer_label.position = Vector2(width / 2 - 55, 23)
	timer_label.size = Vector2(110, 58)
	round_label.position = Vector2(width / 2 - 55, 84)
	round_label.size = Vector2(110, 24)
	pause_button.position = Vector2(width - 180, height - 42)
	pause_button.size = Vector2(145, 29)
	ui.get_node("TouchToggle").position = Vector2(width - 300, height - 42)
	ui.get_node("TouchToggle").size = Vector2(105, 29)
	ui.get_node("EngineLabel").position = Vector2(margin, height - 32)
	ui.get_node("FooterCard").position = Vector2(26, height - 108)
	ui.get_node("FooterCard").size = Vector2(660, 96)
	ui.get_node("Help").position = Vector2(margin, height - 96)
	ui.get_node("Help2").position = Vector2(margin, height - 70)
	callout.position = Vector2(0, height * 0.36)
	callout.size = Vector2(width, 100)
	combo_label.position = Vector2(margin, height * 0.27)
	menu.size = Vector2(404, 500)
	var menu_scale := minf(1, (height - 140) / 500)
	menu.scale = Vector2.ONE * menu_scale
	menu.position = Vector2(margin, (height - 500 * menu_scale) / 2 + 10)
	touch_root.position = Vector2(30, height - 165)
	for b in touch_root.get_children():
		var offset: Vector2 = b.get_meta("offset")
		var action: String = b.get_meta("action")
		b.position = offset
		if action in ["punch", "kick", "launch", "heavy", "guard"]:
			b.position.x += width - 240

func start_match() -> void:
	match_mode = mode_select.selected
	difficulty = difficulty_select.selected
	round_number = 1
	for f in fighters:
		f.wins = 0
	menu.hide()
	begin_round()

func begin_round() -> void:
	for i in range(2):
		fighters[i].reset_at(Vector3(-2.1 if i == 0 else 2.1, 0, 0))
		fighters[i].rig.rotation.z = 0
	phase_time = 2.2
	round_time = 60
	freeze_time = 0
	ai_wait = 0.4
	state = "intro"
	touch_keys.clear()
	combo_label.text = ""
	touch_root.visible = touch_visible
	pause_button.text = "일시정지  ESC"

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			toggle_pause()
		elif state == "fight":
			for i in range(2 if match_mode == 1 else 1):
				for kind in Fighter.MOVES:
					if event.physical_keycode == KEYS[i][kind]:
						fighters[i].attack(kind)
	if event is InputEventScreenTouch and not event.pressed:
		# Button signals own each touch; focus loss clears any interrupted gesture.
		pass

func held(index: int, action: String) -> bool:
	return Input.is_physical_key_pressed(KEYS[index][action]) or (index == 0 and touch_keys.has(action))

func control_fighter(index: int, dt: float) -> void:
	var f = fighters[index]
	f.guard = held(index, "guard") and f.move == "" and f.stun == 0 and f.position.y == 0
	f.moving = false
	if f.move != "" or f.stun > 0 or f.position.y > 0:
		return
	var movement := Vector3(float(held(index, "right")) - float(held(index, "left")), 0, float(held(index, "down")) - float(held(index, "up")))
	f.moving = movement.length() > 0
	f.position += movement.limit_length(1) * (1.2 if f.guard else 3.6) * dt

func control_ai(dt: float) -> void:
	var f = fighters[1]
	var p = fighters[0]
	ai_wait -= dt
	f.moving = false
	f.guard = false
	if f.stun > 0 or f.move != "" or f.position.y > 0:
		return
	var distance: float = absf(f.position.x - p.position.x)
	if p.move != "" and distance < 2.9 and difficulty > 0 and ai_wait < 0.2:
		f.guard = true
		return
	if distance > 1.8:
		f.position.x += signf(p.position.x - f.position.x) * (1.8 if difficulty == 0 else 2.8) * dt
		f.moving = true
	if absf(f.position.z - p.position.z) > 0.15:
		f.position.z += signf(p.position.z - f.position.z) * 2 * dt
		f.moving = true
	if ai_wait <= 0:
		ai_wait = randf_range(0.7, 1.3) if difficulty == 0 else randf_range(0.18, 0.55) if difficulty == 2 else randf_range(0.35, 0.85)
		if distance < 2.7:
			var choices := ["kick", "heavy"] if distance > 2.1 else ["punch", "punch", "kick", "launch", "heavy"]
			f.attack(choices.pick_random())

func toggle_pause() -> void:
	if state in ["menu", "over"]:
		return
	if state == "paused":
		state = previous_state
		callout.text = ""
		pause_button.text = "일시정지  ESC"
	else:
		previous_state = state
		state = "paused"
		touch_keys.clear()
		callout.text = "PAUSED"
		pause_button.text = "계속하기  ESC"

func _focus_lost() -> void:
	touch_keys.clear()
	if state in ["intro", "fight", "end"]:
		toggle_pause()

func _physics_process(dt: float) -> void:
	if state == "paused":
		return
	elapsed += dt
	for i in range(fighters.size()):
		var f = fighters[i]
		f.face = 1 if fighters[1-i].position.x >= f.position.x else -1
		f.pose(dt)
		shadows[i].position = Vector3(f.position.x, 0.036, f.position.z)
		shadows[i].scale.x = 1 / (1 + f.position.y * 0.2)
	update_camera(dt)
	update_effects(dt)
	if state in ["menu", "over"]:
		return
	if state == "intro":
		phase_time -= dt
		callout.text = "ROUND %02d" % round_number if phase_time > 0.7 else "FIGHT"
		if phase_time <= 0:
			state = "fight"
			callout.text = ""
	elif state == "end":
		phase_time -= dt
		if phase_time <= 0:
			if fighters[0].wins >= 2 or fighters[1].wins >= 2:
				state = "over"
				menu.show()
				callout.text = ""
				title_label.text = "RYU\nWINS" if fighters[0].wins >= 2 else "KAI\nWINS"
				description.text = "대전 종료 / %d : %d\n가드로 빈틈을 만들고 반격하세요.\n모드를 바꿔 다시 도전할 수 있습니다." % [fighters[0].wins, fighters[1].wins]
				start_button.text = "다시 대전     ↗"
				touch_root.hide()
			else:
				round_number += 1
				begin_round()
	elif freeze_time > 0:
		freeze_time -= dt
	else:
		round_time = maxf(0, round_time - dt)
		for f in fighters:
			f.step(dt)
		control_fighter(0, dt)
		if match_mode == 1:
			control_fighter(1, dt)
		else:
			control_ai(dt)
		constrain_fighters()
		for i in range(2):
			var result: Dictionary = fighters[i].resolve_hit(fighters[1-i])
			if not result.is_empty():
				impact(result, i)
		if round_time <= 0 or fighters[0].hp <= 0 or fighters[1].hp <= 0:
			end_round()
	combo_display_time -= dt
	if combo_display_time <= 0:
		combo_label.text = ""
	update_hud()

func constrain_fighters() -> void:
	for f in fighters:
		f.position.x = clampf(f.position.x, -5.8, 5.8)
		f.position.z = clampf(f.position.z, -2.1, 2.1)
	var a = fighters[0]
	var b = fighters[1]
	if absf(a.position.x - b.position.x) < 0.95 and absf(a.position.z - b.position.z) < 0.7:
		var center: float = (a.position.x + b.position.x) / 2
		a.position.x = center - a.face * 0.48
		b.position.x = center + a.face * 0.48

func end_round() -> void:
	state = "end"
	phase_time = 3
	touch_keys.clear()
	if fighters[0].hp == fighters[1].hp:
		callout.text = "DRAW"
		return
	var winner := 0 if fighters[0].hp > fighters[1].hp else 1
	fighters[winner].wins += 1
	callout.text = ("TIME UP / " if round_time <= 0 else "K.O. / ") + ("RYU" if winner == 0 else "KAI")

func update_hud() -> void:
	for i in range(2):
		health[i].value = fighters[i].hp
		win_labels[i].text = ("●" if fighters[i].wins > 0 else "○") + "  " + ("●" if fighters[i].wins > 1 else "○")
	timer_label.text = "%02d" % ceili(round_time)
	round_label.text = "ROUND %02d" % round_number

func update_camera(dt: float) -> void:
	var center: Vector3 = (fighters[0].position + fighters[1].position) / 2
	center.y = 1.25
	var distance: float = absf(fighters[0].position.x - fighters[1].position.x)
	var portrait: float = maxf(1, 1.65 / get_viewport().get_visible_rect().size.aspect())
	var target := Vector3(center.x * 0.35, 5.5, maxf(10.2, distance * 1.1 + 4.5) * portrait)
	if state in ["menu", "over"]:
		target = Vector3(3.6, 6.3, 12.0) * Vector3(portrait, 1, portrait)
		center.x = -0.8
	camera.position = camera.position.lerp(target, minf(dt * 3, 1))
	camera.look_at(center)
	if shake > 0:
		camera.h_offset = randf_range(-shake, shake)
		camera.v_offset = randf_range(-shake, shake)
		shake = maxf(0, shake - dt * 0.7)
	else:
		camera.h_offset = 0
		camera.v_offset = 0

func impact(result: Dictionary, attacker: int) -> void:
	var blocked: bool = result.blocked
	shake = 0.025 if blocked else 0.10
	freeze_time = 0.025 if blocked else 0.055
	audio_player.stream = block_sound if blocked else hit_sound
	audio_player.play()
	if not blocked:
		combo_display_time = 1.3
		combo_label.text = ("RYU" if attacker == 0 else "KAI") + " / %d HIT\n%d DAMAGE" % [result.combo, int(result.damage)]
	var mat := V.material(Color("9cdbff") if blocked else Color("e2ffb2"), 0, 0.3, 4)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in range(18):
		var spark := V.box(self, Vector3(0.025, 0.025, randf_range(0.07, 0.22)), result.position, mat)
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var velocity := Vector3(randf_range(-4, 4), randf_range(-1, 5), randf_range(-3, 3))
		effects.append({"node": spark, "velocity": velocity, "life": 0.25 + randf() * 0.15})
	var ring := V.ring(self, 0.28, 0.018, result.position, mat)
	ring.rotation.x = PI / 2
	effects.append({"node": ring, "velocity": Vector3.ZERO, "life": 0.18, "ring": true})

func update_effects(dt: float) -> void:
	for i in range(effects.size()-1, -1, -1):
		var effect: Dictionary = effects[i]
		effect.life -= dt
		if effect.life <= 0:
			effect.node.queue_free()
			effects.remove_at(i)
			continue
		if effect.has("ring"):
			effect.node.scale += Vector3.ONE * dt * 9
		else:
			effect.node.position += effect.velocity * dt
			effect.velocity.y -= dt * 9
			effect.node.scale *= 1 - dt * 3
