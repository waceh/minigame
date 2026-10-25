extends Control

const FONT = preload("res://fonts/NotoSansKR.ttf")
const SUITS := ["♠", "♥", "♦", "♣"]
const RANKS := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
const TEXT := Color("e8efe8")
const MUTED := Color("a0b9b6")
const GOLD := Color("f4cf86")
var endpoint := ""
var session: Dictionary = {}
var state: Dictionary = {}
var socket: WebSocketPeer
var http: HTTPRequest
var auth_sent := false
var intentional_close := false
var pending := false
var retry_count := 0
var retry_timer := -1.0
var heartbeat := 0.0
var invite_room := ""
var status_label: Label
var connection_label: Label
var nickname: LineEdit
var room_input: LineEdit
var create_button: Button
var join_button: Button
var reconnect_button: Button
var lobby: VBoxContainer
var game: VBoxContainer
var room_label: Label
var opponent_label: Label
var opponent_count: Label
var turn_label: Label
var event_label: Label
var top_card: Button
var draw_button: Button
var ready_button: Button
var my_label: Label
var hand_row: HBoxContainer
var hand_scroll: ScrollContainer
var last_phase := ""

func _ready() -> void:
	var ui_theme := Theme.new()
	var readable_font := FontVariation.new()
	readable_font.base_font = FONT
	readable_font.variation_opentype = {"wght": 550}
	readable_font.variation_embolden = 0.8
	ui_theme.default_font = readable_font
	ui_theme.default_font_size = 20
	theme = ui_theme
	build_ui()
	http = HTTPRequest.new()
	http.timeout = 15
	http.request_completed.connect(_on_http_complete)
	add_child(http)
	if OS.has_feature("web"):
		endpoint = str(JavaScriptBridge.eval("window.parent.CARD_DUEL_SERVER || ''"))
		invite_room = str(JavaScriptBridge.eval("new URL(window.parent.location.href).searchParams.get('room') || ''"))
	else:
		endpoint = OS.get_environment("CARD_DUEL_SERVER")
		if endpoint.is_empty(): endpoint = "http://127.0.0.1:8787"
	endpoint = endpoint.trim_suffix("/")
	room_input.text = invite_room
	load_session()
	if endpoint.is_empty():
		status_label.text = "대전 서버를 준비 중입니다. 잠시 후 다시 방문해 주세요."
		create_button.disabled = true
		join_button.disabled = true
	elif not session.is_empty() and (invite_room.is_empty() or invite_room == session.get("room", "")):
		lobby.hide()
		game.show()
		connect_socket()

func panel_style(color: Color, border: Color = Color("335457"), radius: int = 16) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func label(text: String, size: int = 20, color: Color = TEXT) -> Label:
	var value := Label.new()
	value.text = text
	value.add_theme_font_size_override("font_size", size)
	value.add_theme_color_override("font_color", color)
	return value

func button(text: String, callback: Callable, primary: bool = false) -> Button:
	var value := Button.new()
	value.text = text
	value.custom_minimum_size.y = 50
	value.add_theme_stylebox_override("normal", panel_style(Color("e9c57f") if primary else Color("1c393e")))
	value.add_theme_stylebox_override("hover", panel_style(Color("f7d99b") if primary else Color("305457"), GOLD))
	value.add_theme_stylebox_override("pressed", panel_style(Color("c9a669") if primary else Color("3b6264")))
	value.add_theme_stylebox_override("disabled", panel_style(Color("263c3e")))
	value.add_theme_color_override("font_color", Color("183238") if primary else TEXT)
	value.add_theme_color_override("font_hover_color", Color("183238") if primary else TEXT)
	value.pressed.connect(callback)
	return value

func build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 14)
	scroll.add_child(page)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	page.add_child(header)
	var home := button("← 목록", go_home)
	home.add_theme_font_size_override("font_size", 16)
	header.add_child(home)
	var title := label("카드 맞추기", 26, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	connection_label = label("1 : 1", 16, MUTED)
	header.add_child(connection_label)
	status_label = label("닉네임을 입력하고 친구를 초대하세요.", 17, MUTED)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(status_label)
	reconnect_button = button("다시 연결", func(): retry_count = 0; connect_socket())
	reconnect_button.hide()
	page.add_child(reconnect_button)
	lobby = VBoxContainer.new()
	lobby.add_theme_constant_override("separation", 16)
	page.add_child(lobby)
	lobby.add_child(label("친구와 한 판", 38))
	var lead := label("같은 무늬나 숫자의 카드를 내세요.\n손패를 먼저 비우면 승리!", 21, MUTED)
	lobby.add_child(lead)
	lobby.add_child(label("내 닉네임", 17))
	nickname = LineEdit.new()
	nickname.placeholder_text = "1~16자"
	nickname.max_length = 16
	nickname.custom_minimum_size.y = 54
	lobby.add_child(nickname)
	create_button = button("새 방 만들기", func(): request_room(true), true)
	lobby.add_child(create_button)
	lobby.add_child(label("초대받았다면", 17, MUTED))
	room_input = LineEdit.new()
	room_input.placeholder_text = "8자리 방 코드"
	room_input.max_length = 12
	room_input.custom_minimum_size.y = 54
	lobby.add_child(room_input)
	join_button = button("방 코드로 입장", func(): request_room(false))
	lobby.add_child(join_button)
	var rules := label("각자 7장으로 시작합니다.\n낼 카드가 없으면 한 장을 받고 차례를 넘기세요.\n특수 카드 없이 무늬·숫자만 맞추는 규칙입니다.", 16, MUTED)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lobby.add_child(rules)
	game = VBoxContainer.new()
	game.add_theme_constant_override("separation", 12)
	game.hide()
	page.add_child(game)
	var room_row := HBoxContainer.new()
	room_label = label("방 연결 중", 23, GOLD)
	room_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room_row.add_child(room_label)
	room_row.add_child(button("초대", share_invite))
	room_row.add_child(button("나가기", func(): send_action("leave")))
	game.add_child(room_row)
	var opponent_panel := PanelContainer.new()
	opponent_panel.add_theme_stylebox_override("panel", panel_style(Color("132c32")))
	var opponent_row := HBoxContainer.new()
	opponent_label = label("친구를 기다리는 중", 19)
	opponent_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opponent_count = label("", 18, MUTED)
	opponent_row.add_child(opponent_label)
	opponent_row.add_child(opponent_count)
	opponent_panel.add_child(opponent_row)
	game.add_child(opponent_panel)
	var table := PanelContainer.new()
	table.add_theme_stylebox_override("panel", panel_style(Color("153e3e"), Color("416761"), 24))
	var table_column := VBoxContainer.new()
	table_column.add_theme_constant_override("separation", 14)
	turn_label = label("둘 다 준비하면 시작합니다.", 24, GOLD)
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	table_column.add_child(turn_label)
	var card_center := CenterContainer.new()
	var card_row := HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 24)
	top_card = card_button(-1, false)
	top_card.custom_minimum_size = Vector2(100, 130)
	top_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_card.focus_mode = Control.FOCUS_NONE
	card_row.add_child(top_card)
	draw_button = button("덱\n1장 받기", func(): send_action("draw"))
	draw_button.custom_minimum_size = Vector2(112, 130)
	card_row.add_child(draw_button)
	card_center.add_child(card_row)
	table_column.add_child(card_center)
	event_label = label("", 16, MUTED)
	event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	table_column.add_child(event_label)
	table.add_child(table_column)
	game.add_child(table)
	my_label = label("내 손패", 20)
	game.add_child(my_label)
	hand_scroll = ScrollContainer.new()
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_scroll.custom_minimum_size.y = 150
	hand_scroll.follow_focus = true
	hand_row = HBoxContainer.new()
	hand_row.add_theme_constant_override("separation", 10)
	hand_scroll.add_child(hand_row)
	game.add_child(hand_scroll)
	ready_button = button("준비하기", func(): send_action("ready"), true)
	game.add_child(ready_button)

func card_text(card: int) -> String:
	return "CARD" if card < 0 else "%s\n%s" % [SUITS[card / 13], RANKS[card % 13]]

func card_button(card: int, playable: bool) -> Button:
	var value := Button.new()
	value.text = card_text(card)
	value.custom_minimum_size = Vector2(86, 122)
	value.add_theme_font_size_override("font_size", 30)
	var red := card >= 13 and card < 39
	var ink := Color("b84950") if red else Color("203a45")
	value.add_theme_color_override("font_color", ink)
	value.add_theme_color_override("font_hover_color", ink)
	value.add_theme_color_override("font_disabled_color", ink.darkened(0.1))
	value.add_theme_stylebox_override("normal", panel_style(Color("f1eddf"), GOLD if playable else Color("738b88"), 12))
	value.add_theme_stylebox_override("hover", panel_style(Color("fff7dc"), GOLD, 12))
	value.add_theme_stylebox_override("pressed", panel_style(Color("dfc98b"), GOLD, 12))
	value.add_theme_stylebox_override("disabled", panel_style(Color("a9b7ad"), Color("718b85"), 12))
	value.disabled = not playable
	if card >= 0: value.pressed.connect(func(): send_action("play", {"cardId": card}))
	return value

func request_room(create: bool) -> void:
	if nickname.text.strip_edges().is_empty():
		status_label.text = "닉네임을 먼저 입력해 주세요."
		return
	var code := room_input.text.strip_edges().to_upper().replace(" ", "").replace("-", "")
	if not create and code.length() != 8:
		status_label.text = "8자리 방 코드를 입력해 주세요."
		return
	create_button.disabled = true
	join_button.disabled = true
	status_label.text = "방을 만들고 있어요…" if create else "친구의 방에 입장하고 있어요…"
	var path := "/api/rooms" if create else "/api/rooms/%s/join" % code
	var err := http.request(endpoint + path, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify({"name": nickname.text.strip_edges()}))
	if err != OK:
		create_button.disabled = false
		join_button.disabled = false
		status_label.text = "서버에 연결하지 못했어요. 잠시 후 다시 시도해 주세요."

func _on_http_complete(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	create_button.disabled = false
	join_button.disabled = false
	var data = JSON.parse_string(body.get_string_from_utf8())
	if result != HTTPRequest.RESULT_SUCCESS or not data is Dictionary:
		status_label.text = "서버에 연결하지 못했어요. 인터넷 연결을 확인해 주세요."
		return
	if response_code != 201:
		status_label.text = str(data.get("message", "입장하지 못했어요. 다시 시도해 주세요."))
		return
	session = data
	store_session()
	state = {}
	retry_count = 0
	lobby.hide()
	game.show()
	connect_socket()

func connect_socket() -> void:
	if session.is_empty(): return
	if socket: socket.close()
	intentional_close = false
	auth_sent = false
	pending = false
	retry_timer = -1.0
	reconnect_button.hide()
	connection_label.text = "연결 중"
	status_label.text = "대전 테이블에 연결하고 있어요…"
	socket = WebSocketPeer.new()
	socket.inbound_buffer_size = 32768
	var url := endpoint.replace("https://", "wss://").replace("http://", "ws://") + "/api/rooms/%s/socket" % session["room"]
	var err := socket.connect_to_url(url)
	if err != OK:
		socket = null
		schedule_retry()

func _process(delta: float) -> void:
	if retry_timer >= 0.0:
		retry_timer -= delta
		if retry_timer < 0.0: connect_socket()
	if not socket: return
	socket.poll()
	var connection := socket.get_ready_state()
	if connection == WebSocketPeer.STATE_OPEN:
		if not auth_sent:
			socket.send_text(JSON.stringify({"type": "auth", "token": session.get("token", "")}))
			auth_sent = true
			pending = true
		heartbeat += delta
		if heartbeat >= 25.0:
			heartbeat = 0.0
			socket.send_text("ping")
		while socket.get_available_packet_count() > 0:
			var raw := socket.get_packet().get_string_from_utf8()
			if raw == "pong": continue
			var message = JSON.parse_string(raw)
			if message is Dictionary: handle_message(message)
	elif connection == WebSocketPeer.STATE_CLOSED:
		var code := socket.get_close_code()
		socket = null
		if intentional_close: return
		if code == 1008 or code == 4004:
			clear_session()
			game.hide()
			lobby.show()
			status_label.text = "입장 정보가 만료됐어요. 방을 다시 만들거나 입장해 주세요."
			connection_label.text = "연결 종료"
		elif code == 4001:
			connection_label.text = "다른 창에서 연결됨"
			status_label.text = "다른 창에서 이어서 플레이 중입니다. 이 창은 닫아도 됩니다."
			pending = true
			render_state()
		else: schedule_retry()

func schedule_retry() -> void:
	pending = true
	connection_label.text = "재연결 중"
	status_label.text = "연결이 잠시 끊겼어요. 같은 손패로 다시 연결하고 있어요…"
	retry_count += 1
	if retry_count <= 6: retry_timer = minf(15.0, pow(2.0, retry_count - 1))
	else:
		reconnect_button.show()
		status_label.text = "연결하지 못했어요. 인터넷을 확인하고 ‘다시 연결’을 눌러 주세요."
	render_state()

func handle_message(message: Dictionary) -> void:
	match message.get("type", ""):
		"state":
			state = message
			pending = false
			retry_count = 0
			connection_label.text = "● 연결됨"
			status_label.text = "같은 무늬 또는 숫자 · 먼저 손패를 비우면 승리"
			render_state()
		"error":
			pending = false
			status_label.text = str(message.get("message", "다시 선택해 주세요."))
			render_state()
		"left":
			intentional_close = true
			if socket: socket.close()
			clear_session()
			state = {}
			game.hide()
			lobby.show()
			connection_label.text = "1 : 1"
			status_label.text = "방에서 나왔어요. 새 친구와 다시 시작해 보세요."

func send_action(kind: String, extra: Dictionary = {}) -> void:
	if pending or state.is_empty() or not socket or socket.get_ready_state() != WebSocketPeer.STATE_OPEN: return
	var action := extra.duplicate()
	action["type"] = kind
	action["revision"] = int(state.get("revision", 0))
	action["requestId"] = Crypto.new().generate_random_bytes(16).hex_encode()
	socket.send_text(JSON.stringify(action))
	pending = true
	render_state()

func render_state() -> void:
	if state.is_empty():
		ready_button.disabled = true
		draw_button.disabled = true
		return
	var me: Dictionary = {}
	var opponent: Dictionary = {}
	for p in state.get("players", []):
		if p.get("id") == state.get("you"): me = p
		else: opponent = p
	var phase: String = state.get("phase", "waiting")
	room_label.text = "방 %s" % state.get("room", "")
	var opponent_status := " · 준비 완료" if opponent.get("ready", false) else ""
	if not opponent.is_empty() and not opponent.get("connected", false): opponent_status = " · 연결 대기"
	if opponent.get("left", false): opponent_status = " · 나감"
	opponent_label.text = str(opponent.get("name", "친구를 기다리는 중")) + opponent_status
	opponent_count.text = "%d장" % int(opponent.get("cardCount", 0)) if not opponent.is_empty() else ""
	var my_turn: bool = phase == "playing" and state.get("turn") == state.get("you")
	turn_label.text = "내 차례" if my_turn else "상대방 차례"
	if phase == "waiting": turn_label.text = "둘 다 준비하면 시작합니다."
	if phase == "finished":
		if state.get("winnerId") == null: turn_label.text = "무승부!"
		else: turn_label.text = "승리했어요!" if state.get("winnerId") == state.get("you") else "아쉽게 졌어요"
	event_label.text = str(state.get("lastEvent", ""))
	var card := -1 if state.get("topCard") == null else int(state.get("topCard"))
	top_card.text = card_text(card)
	var red := card >= 13 and card < 39
	top_card.add_theme_color_override("font_disabled_color", Color("b84950") if red else Color("203a45"))
	top_card.add_theme_stylebox_override("disabled", panel_style(Color("f1eddf"), GOLD, 12))
	draw_button.text = "1장 받기\n덱 %d장" % int(state.get("deckCount", 0))
	draw_button.disabled = not my_turn or pending
	ready_button.visible = phase != "playing"
	ready_button.disabled = pending or opponent.get("left", false)
	ready_button.text = "준비 취소" if me.get("ready", false) else "다시 대전 준비" if phase == "finished" else "준비하기"
	my_label.text = "%s · 내 손패 %d장" % [me.get("name", "나"), state.get("hand", []).size()]
	var previous_scroll := hand_scroll.scroll_horizontal
	for child in hand_row.get_children():
		hand_row.remove_child(child)
		child.queue_free()
	for id in state.get("hand", []):
		var card_id := int(id)
		var legal: bool = card >= 0 and (card_id / 13 == card / 13 or card_id % 13 == card % 13)
		hand_row.add_child(card_button(card_id, my_turn and legal and not pending))
	hand_scroll.set_deferred("scroll_horizontal", previous_scroll)
	last_phase = phase

func store_session() -> void:
	var raw := JSON.stringify(session)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("sessionStorage.setItem('cardduel-session', %s)" % JSON.stringify(raw))
	else:
		var file := FileAccess.open("user://session.json", FileAccess.WRITE)
		if file: file.store_string(raw)

func load_session() -> void:
	var raw := ""
	if OS.has_feature("web"): raw = str(JavaScriptBridge.eval("sessionStorage.getItem('cardduel-session') || ''"))
	elif FileAccess.file_exists("user://session.json"): raw = FileAccess.get_file_as_string("user://session.json")
	if raw.is_empty(): return
	var parsed = JSON.parse_string(raw)
	if parsed is Dictionary and parsed.has("room") and parsed.has("token"): session = parsed

func clear_session() -> void:
	session = {}
	store_session()

func share_invite() -> void:
	if OS.has_feature("web"):
		var code := JSON.stringify(str(session.get("room", "")))
		JavaScriptBridge.eval("window.parent.postMessage({type:'cardduel-invite',room:%s}, window.location.origin)" % code)
		status_label.text = "초대 링크를 확인하고 친구에게 보내 주세요."
	else:
		DisplayServer.clipboard_set(str(session.get("room", "")))
		status_label.text = "방 코드를 복사했어요. 친구에게 보내 주세요."

func go_home() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.parent.location.href = new URL('index.html', window.parent.location.href).href")
	else: get_tree().quit()
