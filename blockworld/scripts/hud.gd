extends Control

const FONT = preload("res://font.ttf")
var world: Node3D
var overlay: ColorRect
var status: Label
var coords: Label
var hint: Label
var palette: HBoxContainer
var crosshair: Label
var mobile = false
var mobile_buttons: HBoxContainer
var buttons: Array = []
var menu_title: Label
var start_button: Button
var has_started = false
var last_selected = -1

func style(color: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box

func label(text: String, font_size: int, color: Color) -> Label:
	var node = Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_shadow_color", Color(0.03, 0.08, 0.09, 0.7))
	node.add_theme_constant_override("shadow_offset_x", 1)
	node.add_theme_constant_override("shadow_offset_y", 2)
	return node

func button(text: String, callback: Callable) -> Button:
	var node = Button.new()
	node.text = text
	node.add_theme_stylebox_override("normal", style(Color("183d43"), Color("507276")))
	node.add_theme_stylebox_override("hover", style(Color("31616a"), Color("b8e1c5")))
	node.add_theme_stylebox_override("pressed", style(Color("487f6b"), Color("f3d69a")))
	node.add_theme_font_size_override("font_size", 17)
	node.pressed.connect(callback)
	node.focus_mode = Control.FOCUS_NONE
	return node

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme_resource = Theme.new()
	var readable_font = FontVariation.new()
	readable_font.base_font = FONT
	readable_font.variation_opentype = {"wght": 550}
	readable_font.variation_embolden = 0.45
	theme_resource.default_font = readable_font
	theme = theme_resource
	mobile = DisplayServer.is_touchscreen_available()
	if OS.has_feature("web"):
		mobile = mobile or bool(JavaScriptBridge.eval("window.matchMedia('(pointer: coarse)').matches"))
	var header = HBoxContainer.new()
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 18
	header.offset_top = 14
	header.offset_right = -18
	header.add_theme_constant_override("separation", 8)
	add_child(header)
	var brand = label("BLOCK / ISLAND", 20, Color("fff4d7"))
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(brand)
	header.add_child(button("Ⅱ 메뉴", world.pause_game))
	coords = label("", 13, Color("e9f1de"))
	coords.position = Vector2(20, 64)
	add_child(coords)
	crosshair = label("+", 28, Color("fff9dc"))
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -9
	crosshair.offset_top = -20
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crosshair)
	var footer = VBoxContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.grow_vertical = Control.GROW_DIRECTION_BEGIN
	footer.offset_top = -116
	footer.offset_bottom = -15
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(footer)
	status = label("", 15, Color("fff2bd"))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_child(status)
	palette = HBoxContainer.new()
	palette.alignment = BoxContainer.ALIGNMENT_CENTER
	palette.add_theme_constant_override("separation", 5)
	footer.add_child(palette)
	for i in range(7):
		var index = i
		var item = button(str(i + 1) + "\n" + world.BLOCK_NAMES[i], func(): world.selected = index)
		item.add_theme_font_size_override("font_size", 12)
		item.custom_minimum_size = Vector2(42, 48)
		item.tooltip_text = world.BLOCK_NAMES[i]
		palette.add_child(item)
		buttons.append(item)
	hint = label("", 13, Color("fff7df"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_child(hint)
	mobile_buttons = HBoxContainer.new()
	mobile_buttons.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	mobile_buttons.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	mobile_buttons.offset_left = -220
	mobile_buttons.offset_top = -210
	mobile_buttons.offset_right = -18
	mobile_buttons.offset_bottom = -155
	add_child(mobile_buttons)
	mobile_buttons.add_child(button("채굴", func(): world.edit_target(false)))
	mobile_buttons.add_child(button("쌓기", func(): world.edit_target(true)))
	mobile_buttons.add_child(button("점프", func(): world.player.jump_requested = true))
	make_overlay()
	refresh_overlay()

func make_overlay():
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.025, 0.085, 0.10, 0.78)
	add_child(overlay)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	overlay.add_child(scroll)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", style(Color("102e33"), Color("597a69")))
	center.add_child(card)
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	card.add_child(content)
	var eyebrow = label("A LITTLE WORLD OF YOUR OWN", 12, Color("b1d5b4"))
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(eyebrow)
	menu_title = label("블록 아일랜드", 34, Color("fff1ca"))
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(menu_title)
	var subtitle = label("작은 섬, 마음대로 만드는 나만의 풍경", 15, Color("d6e4d4"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(subtitle)
	var instructions = label("WASD 이동 · 마우스 이동으로 시점\nSpace 점프 · Shift 달리기\n좌클릭 채굴 · 우클릭 블록 쌓기\n1–7 / 휠 블록 선택 · Esc 메뉴\n모바일: 왼쪽 이동 · 오른쪽 시점 회전", 15, Color("d6e4d4"))
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(instructions)
	start_button = button("섬 탐험하기  →", func():
		has_started = true
		world.begin())
	start_button.add_theme_stylebox_override("normal", style(Color("527d58"), Color("b2cf87")))
	content.add_child(start_button)
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(row)
	row.add_child(button("저장", world.save_world))
	row.add_child(button("시작점", func(): world.respawn()))
	row.add_child(button("터치 조작", func():
		mobile = not mobile
		refresh_overlay()))
	var note = label("블록 무제한 · 변경한 월드는 이 기기에 자동 저장", 12, Color("acc7b8"))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(note)

func refresh_overlay():
	overlay.visible = not world.active
	crosshair.visible = world.active
	mobile_buttons.visible = mobile and world.active
	menu_title.text = "잠시 쉬어가기" if has_started else "블록 아일랜드"
	start_button.text = "계속 탐험하기  →" if has_started else "섬 탐험하기  →"

func _process(_dt):
	coords.text = "X %d   Y %d   Z %d   /   로컬 월드" % [world.player.position.x, world.player.position.y, world.player.position.z]
	status.text = world.message if world.message_time > 0 else ""
	hint.text = world.BLOCK_NAMES[world.selected] + "  ·  ∞" + ("   |   왼쪽 이동 · 오른쪽 시점" if mobile else "   |   좌클릭 채굴 · 우클릭 쌓기 · Esc 고정 해제")
	if last_selected != world.selected:
		last_selected = world.selected
		for i in range(buttons.size()):
			var color: Color = world.COLORS[i]
			var tile = style(color.darkened(0.35), Color("ffe2a2") if i == world.selected else Color(0.1, 0.2, 0.2, 0.7))
			tile.content_margin_left = 6
			tile.content_margin_right = 6
			for state in ["normal", "hover", "pressed"]: buttons[i].add_theme_stylebox_override(state, tile)
	queue_redraw()

func _draw():
	if mobile and world.active:
		var origin = world.player.move_origin if world.player.move_touch >= 0 else Vector2(85, size.y - 205)
		draw_circle(origin, 57, Color(0.03, 0.12, 0.13, 0.3))
		draw_arc(origin, 57, 0, TAU, 40, Color(0.9, 1, 0.9, 0.3), 2)
		draw_circle(origin + world.player.touch_axis * 38, 23, Color(0.85, 0.95, 0.85, 0.5))
