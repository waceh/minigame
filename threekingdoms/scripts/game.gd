extends Node2D
const R = preload("res://scripts/roster.gd")
const BASE_FONT = preload("res://font.ttf")
const RecipeBook = preload("res://scripts/recipe_book.gd")
const Minimap = preload("res://scripts/minimap.gd")
const HUD_FRAME = preload("res://assets/hud-frame.png")
const Selection = preload("res://scripts/selection.gd")
const Battlefield = preload("res://scripts/battlefield.gd")
var FONT:FontVariation=make_font()
var battlefield
var selected_slots:Array=[]
var drag_start:=Vector2.ZERO
var drag_now:=Vector2.ZERO
var dragging:=false
var pending_order:=""
var hover_map:=Vector2.ZERO
func make_font() -> FontVariation:
	var f:=FontVariation.new();f.base_font=BASE_FONT;f.variation_embolden=.55;f.variation_opentype={"wght":780.0};return f
const PATH = [Vector2(94,226),Vector2(850,226),Vector2(850,684),Vector2(94,684),Vector2(94,226)]
const PATH_LENGTH = 2428.0
const SUMMON_POINT = Vector2(472,500)
const MAX_UNITS = 36
var recipes:Array=R.all_recipes()
var units:Array = []
var enemies:Array = []
var effects:Array = []
var selected := -1
var gold := 210
var lives := 30
var wave := 0
var kills := 0
var upgrade := 0
var state := "title"
var paused := false
var speed := 1
var spawn_left := 0
var spawn_timer := 0.0
var break_time := 0.0
var next_uid := 0
var best := 0
var persist := true
var elapsed := 0.0
var notice := "장수를 소환하고 방어선을 준비하세요."
var notice_time := 5.0
var ui:Control
var minimap:Control
var sell_button:Button
var portrait:TextureRect
var portrait_name:Label
var round_info:Label
var squad_icons:Array=[]
var summary:Label
var detail:Label
var tooltip:Label
var wave_button:Button
var summon_button:Button
var merge_button:Button
var recipe_button:Button
var recipe_path_button:Button
var attack_cmd_button:Button
var hold_cmd_button:Button
var upgrade_button:Button
var pause_button:Button
var speed_button:Button
var overlay:Panel
var overlay_title:Label
var overlay_body:Label
var overlay_button:Button
var codex:Panel
var codex_open := false
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	Input.emulate_mouse_from_touch=true
	rng.randomize()
	if persist and FileAccess.file_exists("user://record_v1.txt"):
		best=int(FileAccess.get_file_as_string("user://record_v1.txt"))
	battlefield=Battlefield.new();battlefield.game=self;add_child(battlefield)
	var selection:=Selection.new();selection.game=self;selection.z_index=10;add_child(selection)
	build_ui()
	refresh()

func slot_pos(index:int) -> Vector2:
	return Vector2(184+(index%7)*96,320+(index/7)*86)
func unit_at(slot:int) -> int:
	for i in range(units.size()):
		if units[i].slot==slot:return i
	return -1
func empty_slot() -> int:
	for i in range(MAX_UNITS):
		if unit_at(i)<0:return i
	return -1
func make_unit(id:int, _rank:int, slot:int) -> Dictionary:
	return {"id":id,"rank":R.data(id).rank,"slot":slot,"cooldown":.2,"hits":0,"pulse":0.0,"pos":slot_pos(slot),"target":slot_pos(slot),"ordered":false,"face":1.0,"focus_enemy":-1,"auto_enemy":-1,"order":"guard"}
func announce(message:String) -> void:
	notice=message;notice_time=4
func reset_game() -> void:
	units.clear();enemies.clear();effects.clear();selected_slots.clear();selected=-1;gold=210;lives=30;wave=0;kills=0;upgrade=0
	cancel_order();spawn_left=0;spawn_timer=0;break_time=0;paused=false;speed=1;state="build";codex_open=false;codex.hide();overlay.hide()
	announce("장수 6명 소환 → 드래그 부대 선택 → 우클릭 이동")
	refresh()
func summon_destination(slot:int) -> Vector2:
	return SUMMON_POINT+Vector2((slot%6-2.5)*26,(slot/6-2.5)*26)
func summon() -> bool:
	if state not in ["build","battle"] or paused:return false
	var slot:=empty_slot()
	if gold<35:announce("소환에는 금화 35가 필요합니다.");return false
	if slot<0:announce("진영이 가득 찼습니다. 장수를 조합해 자리를 만드세요.");return false
	gold-=35
	var id:int=R.SUMMON_IDS[rng.randi_range(0,R.SUMMON_IDS.size()-1)]
	var rank:=0
	var summoned:=make_unit(id,rank,slot)
	summoned.pos=SUMMON_POINT;summoned.target=summon_destination(slot);summoned.ordered=true;summoned.order="move"
	units.append(summoned);selected=slot;selected_slots=[slot]
	emit({"type":"summon","pos":SUMMON_POINT,"time":.65,"max":.65,"color":R.COLORS[R.data(id).faction]})
	announce("%s · %s 합류! 같은 장수 3명으로 승급"%[R.RANKS[rank],R.data(id).name])
	refresh();return true
func matching_indices(unit:Dictionary, selected_only:bool=false) -> Array:
	var found:Array=[]
	for i in range(units.size()):
		if units[i].id==unit.id and units[i].rank==unit.rank and (not selected_only or selected_slots.has(units[i].slot)):found.append(i)
	return found
func merge_candidate() -> int:
	var candidates:Array=selected_slots.duplicate()
	if candidates.has(selected):candidates.erase(selected);candidates.push_front(selected)
	for slot in candidates:
		var index:=unit_at(slot)
		if index>=0 and R.PROMOTIONS.has(units[index].id) and matching_indices(units[index],true).size()>=3:return index
	return -1
func merge_selected() -> bool:
	if paused or codex_open or state not in ["build","battle"]:return false
	var index:=merge_candidate()
	if index<0:
		announce("선택한 부대에서 같은 1·2단계 장수 3명을 골라 주세요. 다른 조합은 조합표에서 선택합니다.");refresh();return false
	var u:Dictionary=units[index];var indices:=matching_indices(u,true)
	indices.erase(index);indices=[index,indices[0],indices[1]]
	return consume_recipe(indices,R.PROMOTIONS[u.id],u.slot)
func recipe_indices(recipe:Dictionary) -> Array:
	var result:Array=[]
	for material in recipe.materials:
		var found:=0
		for i in range(units.size()):
			if selected_slots.has(units[i].slot) and units[i].id==material[0] and not result.has(i):
				result.append(i);found+=1
				if found==material[1]:break
		if found!=material[1]:return []
	return result
func consume_recipe(indices:Array, result_id:int, anchor_slot:int) -> bool:
	var anchor_index:=unit_at(anchor_slot)
	if anchor_index<0 or not indices.has(anchor_index):return false
	var source:Dictionary=units[anchor_index];var point:Vector2=source.pos
	var original_name:String=R.data(source.id).name
	indices.sort();indices.reverse()
	for i in indices:units.remove_at(i)
	var product:=make_unit(result_id,R.data(result_id).rank,anchor_slot);product.pos=point;product.target=point
	if source.order=="hold":product.order="hold"
	units.append(product);selected=anchor_slot;selected_slots=selected_slots.filter(func(slot):return unit_at(slot)>=0)
	if not selected_slots.has(anchor_slot):selected_slots.append(anchor_slot)
	cancel_order();emit({"type":"summon","pos":point,"time":1.0,"max":1.0,"color":R.RANK_COLORS[product.rank]})
	announce("선택 재료 %d명 조합 → %s %s · %s 위치에서 합류"%[indices.size(),R.RANKS[product.rank],R.data(result_id).name,original_name])
	refresh();return true
func craft_recipe(index:int) -> bool:
	if paused or state not in ["build","battle"] or index<0 or index>=recipes.size():return false
	var recipe:Dictionary=recipes[index];var indices:=recipe_indices(recipe)
	if indices.is_empty():announce("선택한 부대의 재료가 부족합니다. 필요한 장수와 수량을 확인하세요.");refresh();return false
	return consume_recipe(indices,recipe.result,units[indices[0]].slot)
func craft_legend() -> bool:
	if paused or state not in ["build","battle"]:return false
	for i in range(recipes.size()):
		if recipes[i].result in [9,10,11] and not recipe_indices(recipes[i]).is_empty():return craft_recipe(i)
	return false
func sell_selected() -> bool:
	if paused or codex_open or state not in ["build","battle"] or not selected_slots.has(selected):return false
	var index:=unit_at(selected)
	if index<0:return false
	var unit:Dictionary=units[index];var value:int=R.sell_value(unit.id)
	units.remove_at(index);gold+=value;selected_slots.erase(selected)
	selected=selected_slots[0] if not selected_slots.is_empty() else -1
	cancel_order();announce("%s 1명 판매 · +%d 금 (재료 가치의 70%%)"%[R.data(unit.id).name,value]);refresh();return true
func inspect_selected() -> void:
	var idx:=unit_at(selected)
	if idx>=0:
		cancel_order();dragging=false;codex_open=true;codex.inspect(units[idx].id);refresh()
	else:
		open_book()
func open_book() -> void:
	cancel_order();dragging=false;codex_open=true;codex.open();refresh()
func train_army() -> bool:
	if paused or state not in ["build","battle"] or upgrade>=10:return false
	var cost:=80+upgrade*55
	if gold<cost:announce("전군 훈련에 금화 %d가 필요합니다."%cost);return false
	gold-=cost;upgrade+=1;announce("전군 훈련 %d단계 · 전체 공격력 +%d%%"%[upgrade,upgrade*12]);refresh();return true
func start_wave() -> void:
	if paused or state!="build":return
	if units.is_empty():announce("먼저 장수를 소환하세요.");return
	wave+=1;state="battle";spawn_left=12+wave*2;spawn_timer=.1;break_time=0
	announce("제 %d진 · %s"%[wave,"적장 출현! 마지막 적장을 막아내세요." if wave%5==0 else "황건군이 진격합니다."])
	refresh()
func spawn_enemy() -> void:
	var boss:bool=wave%5==0 and spawn_left==1
	var hp:float=(40*pow(1.185,wave-1)+wave*6)*(14 if boss else 1)
	var elite:bool=not boss and wave>=8 and spawn_left%7==0
	if elite:hp*=2.1
	next_uid+=1
	enemies.append({"uid":next_uid,"distance":0.0,"hp":hp,"max_hp":hp,"speed":(43+wave*.9)*(.67 if boss else 1.0),"boss":boss,"elite":elite,"slow":0.0,"stun":0.0,"burn":0.0,"burn_damage":0.0,"flash":0.0})
	spawn_left-=1
func path_pos(distance:float) -> Vector2:
	var d:=clampf(distance,0,PATH_LENGTH)
	for i in range(4):
		var length:float=PATH[i].distance_to(PATH[i+1])
		if d<=length:return PATH[i].lerp(PATH[i+1],d/length)
		d-=length
	return PATH[4]
func attack(unit:Dictionary) -> void:
	var stats:=R.stats(unit,upgrade)
	var origin:Vector2=unit.pos
	var target:Dictionary={}
	var furthest:=-1.0
	for e in enemies:
		var priority:float=e.distance+(100000 if e.uid==unit.focus_enemy or e.uid==unit.auto_enemy else 0)
		if e.hp>0 and priority>furthest and origin.distance_to(path_pos(e.distance))<=(48.0 if stats.kind in ["melee","cleave","stun"] else stats.range):
			target=e;furthest=priority
	if target.is_empty():return
	unit.cooldown=stats.rate;unit.hits+=1;unit.pulse=.32
	unit.face=1.0 if path_pos(target.distance).x>origin.x else -1.0
	var damage:float=stats.damage
	for ally in units:
		if ally!=unit and R.data(ally.id).kind=="aura" and origin.distance_to(ally.pos)<185:
			damage*=1.2;break
	var impact:=path_pos(target.distance)
	var kind:String=stats.kind
	var color:Color=R.COLORS[R.data(unit.id).faction]
	if unit.rank>=3:color=R.RANK_COLORS[unit.rank]
	emit({"type":"shot","from":origin+Vector2(0,-15),"pos":impact,"time":.22,"max":.22,"color":color})
	if kind in ["cleave","fire","storm"]:
		var radius:float=110 if unit.rank==4 else 85 if kind=="storm" else 58
		emit({"type":"blast","pos":impact,"time":.35,"max":.35,"color":color,"radius":radius})
		for e in enemies:
			if path_pos(e.distance).distance_to(impact)<=radius:
				e.hp-=damage;e.flash=.14
				if kind=="fire":e.burn=3.0;e.burn_damage=damage*.20
				if kind=="storm":e.slow=2.0
	else:
		target.hp-=damage;target.flash=.14
		if kind=="slow":target.slow=2.5
		if kind=="stun" and unit.hits%4==0:target.stun=1.0
func _process(dt:float) -> void:
	if state in ["title","won","lost"] or paused or codex_open:queue_redraw();return
	step(dt*speed)
func step(dt:float) -> void:
	elapsed+=dt;notice_time=maxf(0,notice_time-dt)
	move_army(dt)
	for effect in effects:effect.time-=dt
	effects=effects.filter(func(e):return e.time>0)
	if state=="battle":
		spawn_timer-=dt
		if spawn_left>0 and spawn_timer<=0:spawn_enemy();spawn_timer=.7 if wave<10 else .5
		for e in enemies:
			e.slow=maxf(0,e.slow-dt);e.stun=maxf(0,e.stun-dt);e.flash=maxf(0,e.flash-dt)
			if e.burn>0:e.burn=maxf(0,e.burn-dt);e.hp-=e.burn_damage*dt
			if e.hp>0 and e.stun<=0:e.distance+=e.speed*dt*(.65 if e.slow>0 else 1.0)
		for u in units:
			u.cooldown=maxf(0,u.cooldown-dt)
			if u.cooldown<=0:attack(u)
		for i in range(enemies.size()-1,-1,-1):
			var e:Dictionary=enemies[i]
			if e.hp<=0:
				gold+=25 if e.boss else 4 if e.elite else 2;kills+=1;enemies.remove_at(i)
			elif e.distance>=PATH_LENGTH:
				lives-=5 if e.boss else 1;enemies.remove_at(i)
		if lives<=0:end_game(false)
		elif spawn_left==0 and enemies.is_empty():
			gold+=65+wave*5
			if wave>=30:end_game(true)
			else:state="build";break_time=12;announce("제 %d진 방어 성공 · 군자금 +%d · 12초 뒤 다음 진격"%[wave,65+wave*5])
	elif state=="build" and wave>0 and break_time>0:
		break_time=maxf(0,break_time-dt)
		if break_time<=0:start_wave()
	refresh();queue_redraw()
func end_game(won:bool) -> void:
	state="won" if won else "lost"
	best=maxi(best,wave if won else maxi(0,wave-1))
	if persist:
		var save:=FileAccess.open("user://record_v1.txt",FileAccess.WRITE)
		if save:save.store_string(str(best))
	overlay_title.text="천하를 지켜냈다" if won else "방어선이 무너졌다"
	overlay_body.text="%d / 30진   ·   처치 %d   ·   최고 기록 %d진\n\n%s"%[wave,kills,best,"난세는 끝났다. 이제 그대의 천하를 열어라." if won else "장수 승급과 전군 훈련을 활용해 다시 도전하세요."]
	overlay_button.text="다시 출전";overlay.show();refresh()
func toggle_pause() -> void:
	if state in ["build","battle"]:cancel_order();paused=not paused;refresh();queue_redraw()
func _notification(what:int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and state in ["build","battle"]:cancel_order();paused=true;refresh()
func emit(effect:Dictionary) -> void:
	effects.append(effect)
	if battlefield:battlefield.emit_effect(effect)
func enemy_by_id(uid:int) -> Dictionary:
	for enemy in enemies:
		if enemy.uid==uid and enemy.hp>0:return enemy
	return {}
func attack_reach(unit:Dictionary) -> float:
	return 42.0 if R.data(unit.id).kind in ["melee","cleave","stun"] else R.stats(unit,upgrade).range*.9
func move_army(dt:float) -> void:
	for u in units:
		u.pulse=maxf(0,u.pulse-dt)
		if u.order=="hold":continue
		var desired:Vector2=u.target
		if u.ordered and u.pos.distance_to(u.target)<5:u.ordered=false
		var kind:String=R.data(u.id).kind
		if u.order=="attack_move" and state=="battle":
			var enemy:=enemy_by_id(u.auto_enemy)
			if enemy.is_empty():
				var nearest:=maxf(130,R.stats(u,upgrade).range)
				for e in enemies:
					var distance:float=u.pos.distance_to(path_pos(e.distance))
					if e.hp>0 and distance<nearest:nearest=distance;enemy=e
				u.auto_enemy=-1 if enemy.is_empty() else enemy.uid
			if not enemy.is_empty():
				var point:=path_pos(enemy.distance)
				desired=u.pos if u.pos.distance_to(point)<attack_reach(u) else point
		elif not u.ordered and kind in ["melee","cleave","stun"] and state=="battle" and u.order!="attack":
			var nearest:Dictionary={};var distance:=INF
			for e in enemies:
				var point:=path_pos(e.distance);var d:float=u.pos.distance_to(point)
				if e.hp>0 and point.distance_to(u.target)<R.stats(u,upgrade).range and d<distance:nearest=e;distance=d
			if not nearest.is_empty():
				var point:=path_pos(nearest.distance)
				desired=u.pos if distance<39 else point
		if u.focus_enemy>=0:
			var focused:=enemy_by_id(u.focus_enemy)
			if focused.is_empty():
				u.focus_enemy=-1;u.order="guard";u.target=u.pos;u.ordered=false;desired=u.pos
			else:
				var point:=path_pos(focused.distance)
				desired=u.pos if u.pos.distance_to(point)<attack_reach(u) else point
		var delta:Vector2=desired-u.pos
		if delta.length()>2:
			u.pos=u.pos.move_toward(desired,78*dt);u.face=1.0 if delta.x>0 else -1.0
	# Holding heroes remain anchored; moving heroes avoid them.
	for i in range(units.size()):
		for j in range(i+1,units.size()):
			var offset:Vector2=units[i].pos-units[j].pos;var distance:=offset.length()
			if distance<25 and distance>.01:
				var push:=offset.normalized()*minf((25-distance)*.5,dt*40)
				if units[i].order=="hold" and units[j].order=="hold":continue
				elif units[i].order=="hold":units[j].pos-=push*2
				elif units[j].order=="hold":units[i].pos+=push*2
				else:units[i].pos+=push;units[j].pos-=push
	for u in units:u.pos=Vector2(clampf(u.pos.x,110,834),clampf(u.pos.y,240,670))
func cancel_order() -> void:
	pending_order="";Input.set_default_cursor_shape(Input.CURSOR_ARROW)
func begin_attack_order() -> void:
	if paused or codex_open or state not in ["build","battle"] or selected_slots.is_empty():return
	pending_order="attack";dragging=false;Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	announce("공격 명령 · 적 클릭: 집중 공격 / 지면 클릭: 공격 이동 / 우클릭·Esc: 취소")
	refresh()
func command_hold() -> void:
	if paused or codex_open or state not in ["build","battle"]:return
	cancel_order();dragging=false
	for slot in selected_slots:
		var index:=unit_at(slot)
		if index<0:continue
		var u:Dictionary=units[index]
		u.order="hold";u.target=u.pos;u.ordered=false;u.focus_enemy=-1;u.auto_enemy=-1
	announce("%d명 위치 사수 · 이동·추격 없이 사거리 안의 적만 공격"%selected_slots.size());refresh()
func command_move(point:Vector2) -> void:
	if selected_slots.is_empty():return
	cancel_order()
	var count:int=selected_slots.size();var columns:int=int(ceil(sqrt(count)))
	for i in range(count):
		var idx:=unit_at(selected_slots[i])
		if idx<0:continue
		var offset:=Vector2((i%columns-(columns-1)*.5)*33,(i/columns-(ceil(float(count)/columns)-1)*.5)*33)
		units[idx].target=Vector2(clampf(point.x+offset.x,110,834),clampf(point.y+offset.y,240,670));units[idx].ordered=true;units[idx].focus_enemy=-1;units[idx].auto_enemy=-1;units[idx].order="move"
	battlefield.move_marker(point)
	announce("%d명 이동 · 자동 교전"%count)
func command_at(screen:Vector2, attack_ground:bool=false) -> void:
	var target_id:=-1;var nearest:=32.0
	for e in enemies:
		var distance:float=battlefield.screen_pos(path_pos(e.distance),.9).distance_to(screen)
		if distance<nearest:nearest=distance;target_id=e.uid
	command_move(battlefield.ground_point(screen))
	if target_id>=0:
		for slot in selected_slots:
			var idx:=unit_at(slot)
			if idx>=0:units[idx].focus_enemy=target_id;units[idx].order="attack"
		announce("%d명 · 지정한 적 집중 공격"%selected_slots.size())
	elif attack_ground:
		for slot in selected_slots:
			var idx:=unit_at(slot)
			if idx>=0:units[idx].order="attack_move"
		announce("%d명 공격 이동 · 적 발견 시 교전 후 목적지로 계속 이동"%selected_slots.size())
func pick_unit(screen:Vector2) -> int:
	var best_slot:=-1;var distance:=44.0
	for u in units:
		var p:Vector2=battlefield.screen_pos(u.pos,1.1);var d:=p.distance_to(screen)
		if d<distance:distance=d;best_slot=u.slot
	return best_slot
func select_same_type(screen:Vector2) -> bool:
	var slot:=pick_unit(screen)
	var index:=unit_at(slot)
	if index<0:return false
	var id:int=units[index].id
	selected=slot;selected_slots.clear()
	for u in units:
		if u.id==id:selected_slots.append(u.slot)
	dragging=false
	announce("%s 전체 선택 · %d명 (모든 등급)"%[R.data(id).name,selected_slots.size()])
	refresh();queue_redraw();return true
func select_at(screen:Vector2, additive:bool=false) -> void:
	var slot:=pick_unit(screen)
	if slot>=0:
		selected=slot
		if not additive:selected_slots=[slot]
		elif selected_slots.has(slot):selected_slots.erase(slot)
		else:selected_slots.append(slot)
	else:command_at(screen)
	refresh();queue_redraw()
func _unhandled_input(event:InputEvent) -> void:
	if codex_open:
		if event is InputEventKey and event.pressed and event.physical_keycode==KEY_ESCAPE:codex_open=false;codex.hide()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SPACE:summon()
			KEY_M:merge_selected()
			KEY_DELETE, KEY_BACKSPACE:sell_selected()
			KEY_N:start_wave()
			KEY_R:inspect_selected()
			KEY_U:train_army()
			KEY_TAB, KEY_F8:open_book()
			KEY_ESCAPE:
				if pending_order!="":cancel_order();announce("공격 명령 취소");refresh()
				else:toggle_pause()
			KEY_A:
				if event.ctrl_pressed or event.meta_pressed:
					cancel_order();selected_slots.clear()
					for u in units:selected_slots.append(u.slot)
					if not selected_slots.is_empty():selected=selected_slots[0]
					refresh()
				else:begin_attack_order()
			KEY_H:command_hold()
	if paused or state not in ["build","battle"]:return
	if event is InputEventKey and event.pressed and event.physical_keycode==KEY_HOME:battlefield.focus=Vector3.ZERO;battlefield.zoom=24;battlefield.set_camera()
	if event is InputEventMouseButton:
		if not Rect2(battlefield.position,battlefield.size).has_point(event.position):return
		if event.button_index==MOUSE_BUTTON_WHEEL_UP and event.pressed:battlefield.zoom=maxf(16,battlefield.zoom-2);battlefield.set_camera()
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN and event.pressed:battlefield.zoom=minf(42,battlefield.zoom+2);battlefield.set_camera()
		elif event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
			if pending_order!="":cancel_order();announce("공격 명령 취소")
			else:command_at(event.position)
			refresh()
		elif event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed:
				if pending_order=="attack":command_at(event.position,true);dragging=false;refresh();get_viewport().set_input_as_handled();return
				if event.double_click and select_same_type(event.position):get_viewport().set_input_as_handled();return
				dragging=true;drag_start=event.position;drag_now=event.position
			elif dragging:
				dragging=false
				if drag_start.distance_to(event.position)<10:select_at(event.position,event.shift_pressed)
				else:
					var rect:=Rect2(drag_start,event.position-drag_start).abs()
					if not event.shift_pressed:selected_slots.clear()
					for u in units:
						if rect.has_point(battlefield.screen_pos(u.pos,1)) and not selected_slots.has(u.slot):selected_slots.append(u.slot)
					if not selected_slots.is_empty():selected=selected_slots[0]
					refresh()
				queue_redraw()
	if event is InputEventMouseMotion and dragging:drag_now=event.position;queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(0,0,1280,800),Color("0d1b2a"))
	draw_line(Vector2(32,127),Vector2(1247,127),Color("415a77"),1)
	if dragging and drag_start.distance_to(drag_now)>10:
		var rect:=Rect2(drag_start,drag_now-drag_start).abs()
		draw_rect(rect,Color(.2,.8,.4,.15));draw_rect(rect,Color("52b788"),false,2.0)
func label_at(parent:Control, value:String, pos:Vector2, size:int, color:Color) -> Label:
	var l:=Label.new();l.text=value;l.position=pos;l.add_theme_font_override("font",FONT);l.add_theme_font_size_override("font_size",maxi(16,size));l.add_theme_color_override("font_color",color);l.add_theme_color_override("font_outline_color",Color("14213d"));l.add_theme_constant_override("outline_size",3);l.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(l);return l
func style(color:Color, border:Color=Color("3d5a80"), radius:int=10) -> StyleBoxFlat:
	var s:=StyleBoxFlat.new();s.bg_color=color;s.border_color=border;s.set_border_width_all(2);s.set_corner_radius_all(radius);s.content_margin_left=12;s.content_margin_right=12;s.shadow_color=Color(0,0,0,.25);s.shadow_size=3;s.shadow_offset=Vector2(0,2);return s
func button_at(parent:Control, value:String, rect:Rect2, callback:Callable, accent:bool=false) -> Button:
	var b:=Button.new();b.text=value;b.position=rect.position;b.size=rect.size;b.focus_mode=Control.FOCUS_NONE
	b.add_theme_font_override("font",FONT);b.add_theme_font_size_override("font_size",16)
	b.add_theme_color_override("font_color",Color("14213d") if accent else Color("f8f9fa"))
	b.add_theme_color_override("font_disabled_color",Color("6c757d"))
	b.add_theme_stylebox_override("normal",style(Color("ffb703") if accent else Color("1d3557"),Color("fb8500") if accent else Color("457b9d"),10))
	b.add_theme_stylebox_override("hover",style(Color("ffd166") if accent else Color("2a4a75"),Color("ffb703") if accent else Color("64b5f6"),10))
	b.add_theme_stylebox_override("pressed",style(Color("f77f00") if accent else Color("132438"),Color("d62828") if accent else Color("1d3557"),10))
	b.add_theme_stylebox_override("disabled",style(Color("162231"),Color("253548"),10))
	b.add_theme_color_override("font_outline_color",Color("ffffff") if accent else Color("0b131f"));b.add_theme_constant_override("outline_size",0 if accent else 2);b.pressed.connect(callback);parent.add_child(b);return b
func panel_at(parent:Control, rect:Rect2) -> Panel:
	var p:=Panel.new();p.position=rect.position;p.size=rect.size;p.add_theme_stylebox_override("panel",style(Color("14213de8"),Color("457b9d"),12));parent.add_child(p);return p
func stone_panel(rect:Rect2) -> Panel:
	var p:=Panel.new();p.position=rect.position;p.size=rect.size;p.add_theme_stylebox_override("panel",style(Color("14213df4"),Color("3d5a80"),12));ui.add_child(p)
	var frame:=NinePatchRect.new();frame.texture=HUD_FRAME;frame.size=rect.size*6;frame.scale=Vector2.ONE/6;frame.mouse_filter=Control.MOUSE_FILTER_IGNORE;frame.modulate=Color(1.1,1.1,1.15,.45)
	frame.patch_margin_left=120;frame.patch_margin_top=120;frame.patch_margin_right=120;frame.patch_margin_bottom=120;p.add_child(frame)
	return p
func portrait_for(id:int) -> AtlasTexture:
	return battlefield.portrait_texture(id)
func focus_squad_icon(index:int) -> void:
	if index>=selected_slots.size():return
	selected=selected_slots[index];selected_slots=[selected];refresh()
func build_ui() -> void:
	var layer:=CanvasLayer.new();add_child(layer);ui=Control.new();ui.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(ui)
	var theme:=Theme.new();theme.default_font=FONT;theme.default_font_size=16;ui.theme=theme
	var names:=Control.new();names.name="Nameplates";names.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(names)
	var top:=ColorRect.new();top.size=Vector2(1280,36);top.color=Color("14213d");top.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(top)
	label_at(ui,"삼국지 · 난세의 수호자",Vector2(15,6),16,Color("ffd166"))
	pause_button=button_at(ui,"일시정지",Rect2(235,4,94,28),toggle_pause)
	speed_button=button_at(ui,"속도 ×1",Rect2(335,4,86,28),func():speed=2 if speed==1 else 1;refresh())
	pause_button.add_theme_font_size_override("font_size",14);speed_button.add_theme_font_size_override("font_size",14)
	var attack_button:=button_at(ui,"A",Rect2(428,4,35,28),begin_attack_order);attack_button.tooltip_text="공격 [A] · 적 클릭: 집중 공격 / 지면 클릭: 공격 이동"
	var hold_button:=button_at(ui,"H",Rect2(469,4,35,28),command_hold);hold_button.tooltip_text="위치 사수 [H] · 이동·추격 없이 사거리 안의 적만 공격"
	summary=label_at(ui,"",Vector2(510,6),16,Color("e0e1dd"))
	var round_panel:=panel_at(ui,Rect2(1036,49,228,84));round_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	round_info=label_at(round_panel,"",Vector2(12,9),14,Color("ffd166"))
	var notice_bg:=ColorRect.new();notice_bg.position=Vector2(0,568);notice_bg.size=Vector2(1280,28);notice_bg.color=Color(.08,.13,.2,.88);notice_bg.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(notice_bg)
	tooltip=label_at(ui,"",Vector2(16,570),16,Color("fff3b0"))
	var pause_message:=label_at(ui,"일시정지 · 계속하기 또는 Esc",Vector2(444,270),26,Color("f5dfac"));pause_message.name="PauseMessage";pause_message.hide()
	var map_frame:=stone_panel(Rect2(0,596,234,204))
	minimap=Minimap.new();minimap.game=self;minimap.position=Vector2(18,18);minimap.size=Vector2(198,164);map_frame.add_child(minimap)
	var face_panel:=stone_panel(Rect2(234,596,156,204))
	portrait_name=label_at(face_panel,"선택 장수",Vector2(22,13),18,Color("f3f6f2"))
	portrait=TextureRect.new();portrait.position=Vector2(18,41);portrait.size=Vector2(120,110);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE;face_panel.add_child(portrait)
	sell_button=button_at(face_panel,"판매",Rect2(18,157,120,26),sell_selected);sell_button.add_theme_font_size_override("font_size",14)
	var info_panel:=stone_panel(Rect2(390,596,428,204))
	detail=label_at(info_panel,"",Vector2(20,15),16,Color("f3f6f2"))
	for i in range(MAX_UNITS):
		var icon:=button_at(info_panel,"",Rect2(22+(i%9)*42,46+(i/9)*34,38,31),func():focus_squad_icon(i))
		var image:=TextureRect.new();image.position=Vector2(2,2);image.size=Vector2(34,27);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.mouse_filter=Control.MOUSE_FILTER_IGNORE;icon.add_child(image)
		icon.hide();squad_icons.append(icon)
	var command_panel:=stone_panel(Rect2(818,596,462,204))
	summon_button=button_at(command_panel,"소환 [Space]\n35 금",Rect2(11,16,104,80),summon,true)
	merge_button=button_at(command_panel,"승급 [M]",Rect2(123,16,104,80),merge_selected)
	recipe_path_button=button_at(command_panel,"조합법 [R]\n선택 경로",Rect2(235,16,104,80),inspect_selected)
	recipe_button=button_at(command_panel,"도감 [Tab]\n전체 조합표",Rect2(347,16,104,80),open_book)
	attack_cmd_button=button_at(command_panel,"공격 [A]\n집중/이동",Rect2(11,108,104,80),begin_attack_order)
	hold_cmd_button=button_at(command_panel,"사수 [H]\n위치 고정",Rect2(123,108,104,80),command_hold)
	upgrade_button=button_at(command_panel,"",Rect2(235,108,104,80),train_army)
	wave_button=button_at(command_panel,"진격 [N]",Rect2(347,108,104,80),start_wave,true)
	for button in [summon_button,merge_button,recipe_path_button,recipe_button,attack_cmd_button,hold_cmd_button,upgrade_button,wave_button]:
		button.add_theme_font_size_override("font_size",14)
	codex=RecipeBook.new();codex.game=self;ui.add_child(codex);codex.hide()
	overlay=panel_at(ui,Rect2(280,225,720,365))
	overlay_title=label_at(overlay,"난세의 수호자 · 삼국지 ORD",Vector2(34,28),36,Color("edcf92"))
	overlay_body=label_at(overlay,"원피스 랜덤 디펜스(ORD) 감성을 담은 삼국지 RTS 디펜스입니다.\n\n[Space] 랜덤 장수 소환 → [M] 동일 3명 승급 → [R] 상위 조합 경로 탐색\n장수 클릭 · 드래그 부대 선택 · 우클릭 이동 · [A] 어택땅 / [H] 위치사수\n단축키: Space 소환 / M 승급 / R 조합법 / Tab 전체도감 / Del 판매\n30번의 진격 · 5진마다 적장 출현 · 성문 내구도 30",Vector2(36,95),17,Color("c7d3c8"))
	overlay_button=button_at(overlay,"출전 · 방어선 준비",Rect2(35,282,650,56),reset_game,true)
func refresh() -> void:
	if not summary:return
	var mob_count:int=enemies.size()+spawn_left
	summary.text="💰 %d 금   🏰 성문 %d / 30   👥 병력 %d / 36   👾 몬스터: %d마리   🚩 제 %02d진 / 30"%[gold,maxi(0,lives),units.size(),mob_count,wave]
	if mob_count>=45:
		summary.add_theme_color_override("font_color",Color("ff4d6d"))
	else:
		summary.add_theme_color_override("font_color",Color("e0e1dd"))
	round_info.text="🚩 제 %02d진 / 30   %s\n⏱️ 준비: %s\n💀 처치 %d · 🏆 최고 %d진"%[
		wave,
		"적장 출현!" if wave>0 and wave%5==0 else "황건군 진격" if state=="battle" else "전투 대기",
		("%d초"%int(ceil(break_time))) if break_time>0 else ("진격 중 (%d마리)"%mob_count),
		kills,best
	]
	pause_button.text="계속하기" if paused else "일시정지"
	ui.get_node("PauseMessage").visible=paused and not codex_open and not overlay.visible
	speed_button.text="속도 ×%d"%speed
	wave_button.text="전투 중\n남은 적 %d"%mob_count if state=="battle" else "다음 진격 [N]\n%d초"%int(ceil(break_time)) if break_time>0 else "진격 시작 [N]"
	wave_button.disabled=state!="build" or paused
	summon_button.disabled=gold<35 or empty_slot()<0 or paused or state not in ["build","battle"]
	upgrade_button.text="전군 훈련 %d/10\n%d 금"%[upgrade,80+upgrade*55] if upgrade<10 else "전군 훈련 완료\n+120%"
	upgrade_button.disabled=gold<80+upgrade*55 or upgrade>=10 or paused
	selected_slots=selected_slots.filter(func(slot):return unit_at(slot)>=0)
	var idx:=unit_at(selected)
	merge_button.disabled=true
	if idx>=0:
		var u:Dictionary=units[idx];var h:Dictionary=R.data(u.id);var stats:=R.stats(u,upgrade)
		var bonus_dmg:int=int(stats.damage-h.damage)
		detail.text="👑 [%s] %s · %s (%s)\n⚔️ 공격력 %d (+%d)  🎯 사거리 %d  ⏱️ 공속 %.2f초\n🛡️ 명령: %s  |  🌟 %s\n📦 승급 현황: 동일 장수 %d / 3명 (M: 승급 / R: 조합 경로)"%[
			R.FACTIONS[h.faction],h.name,R.RANKS[u.rank],h.role,
			int(stats.damage),bonus_dmg,int(48 if stats.kind in ["melee","cleave","stun"] else stats.range),stats.rate,
			{"guard":"경계","move":"이동","attack":"집중 공격","attack_move":"공격 이동","hold":"위치 사수"}.get(u.order,"경계"),
			h.skill,matching_indices(u,true).size()
		]
		detail.add_theme_color_override("font_color",R.RANK_COLORS[u.rank])
	else:
		detail.text=""
	var candidate:=merge_candidate()
	merge_button.disabled=candidate<0 or paused or codex_open or state not in ["build","battle"]
	merge_button.add_theme_color_override("font_color",R.RANK_COLORS[R.data(R.PROMOTIONS[units[candidate].id]).rank] if candidate>=0 else Color("f3f6f2"))
	if candidate>=0:
		var ready:Dictionary=units[candidate]
		merge_button.text="%s 승급 [M]\n%s → %s"%[R.data(ready.id).name,R.RANKS[ready.rank],R.data(R.PROMOTIONS[ready.id]).name]
	elif idx>=0 and not R.PROMOTIONS.has(units[idx].id):merge_button.text="혼합 조합 대상\n[R] 조합표 확인"
	elif idx>=0:merge_button.text="%s 승급 [M]\n같은 등급 %d/3"%[R.data(units[idx].id).name,matching_indices(units[idx],true).size()]
	else:merge_button.text="승급 [M]\n같은 등급 3명"
	recipe_path_button.disabled=idx<0 or paused or codex_open
	sell_button.disabled=idx<0 or not selected_slots.has(selected) or paused or codex_open or state not in ["build","battle"]
	sell_button.text="판매 +%d 금"%R.sell_value(units[idx].id) if idx>=0 else "선택 후 판매"
	sell_button.tooltip_text="현재 대표 선택 장수 1명 판매 [Delete]"
	portrait.visible=idx>=0
	portrait_name.text=R.data(units[idx].id).name if idx>=0 else "장수 선택"
	portrait_name.add_theme_color_override("font_color",R.RANK_COLORS[units[idx].rank] if idx>=0 else Color("f3f6f2"))
	if idx>=0:portrait.texture=portrait_for(units[idx].id)
	for i in range(squad_icons.size()):
		squad_icons[i].visible=selected_slots.size()>1 and i<selected_slots.size()
		if squad_icons[i].visible:
			var unit_index:=unit_at(selected_slots[i])
			if unit_index>=0:
				var member:Dictionary=units[unit_index]
				squad_icons[i].get_child(0).texture=portrait_for(member.id)
				squad_icons[i].tooltip_text="%s · %s"%[R.data(member.id).name,R.RANKS[member.rank]]
	if selected_slots.size()>1:detail.text="선택 부대 %d명 · 더블클릭: 동일 장수 전체 선택\nA: 공격 이동 · H: 위치 사수 · M: 승급"%selected_slots.size();detail.add_theme_color_override("font_color",Color("f3f6f2"))
	elif idx<0:
		detail.add_theme_color_override("font_color",Color("f3f6f2"))
		detail.text="[원랜디 스타일 삼국지 RTS 디펜스]\nSpace 소환 · M 승급 · R 조합 경로 · Tab 전체 도감\nA+클릭: 집중 공격 / 어택땅 · H: 위치 사수\n우클릭 이동 · Del 장수 판매 · N 다음 웨이브\n더블클릭: 동일 장수 전체 선택 · Ctrl+A: 전군 선택"
	tooltip.text="공격 명령 [A] · 적 클릭: 집중 공격 / 지면 클릭: 공격 이동 / 우클릭·Esc: 취소" if pending_order=="attack" else notice if notice_time>0 else "Space 소환 · M 승급 · R 조합법 · Tab 도감 · A 공격 · H 위치사수 · Del 판매 · 우클릭 이동"
