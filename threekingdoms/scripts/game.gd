extends Node2D
const R = preload("res://scripts/roster.gd")
const BASE_FONT = preload("res://font.ttf")
const Headquarters = preload("res://scripts/headquarters.gd")
const SelectionRecipes=preload("res://scripts/selection_recipes.gd")
var selection_recipes:Panel
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
const HQ_POINT = Vector2(40,455)
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
var luck_level := 0
var headquarters:Panel
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
var recipe_button:Button
var attack_cmd_button:Button
var hold_cmd_button:Button
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
	return {"id":id,"investment":R.material_cost(id),"rank":R.data(id).rank,"slot":slot,"cooldown":.2,"hits":0,"pulse":0.0,"pos":slot_pos(slot),"target":slot_pos(slot),"ordered":false,"face":1.0,"focus_enemy":-1,"auto_enemy":-1,"order":"guard"}
func announce(message:String) -> void:
	notice=message;notice_time=4
func reset_game() -> void:
	units.clear();enemies.clear();effects.clear();selected_slots.clear();selected=-1;gold=210;lives=30;wave=0;kills=0;upgrade=0;luck_level=0
	cancel_order();spawn_left=0;spawn_timer=0;break_time=0;paused=false;speed=1;state="build";codex_open=false;codex.hide();headquarters.hide();overlay.hide()
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
	var rank:int=R.summon_rank(rng.randi_range(0,9999),luck_level)
	var pool:Array=R.SUMMON_POOLS[rank]
	var id:int=pool[rng.randi_range(0,pool.size()-1)]
	var summoned:=make_unit(id,rank,slot)
	summoned.investment=35;summoned.pos=SUMMON_POINT;summoned.target=summon_destination(slot);summoned.ordered=true;summoned.order="move"
	units.append(summoned);selected=slot;selected_slots=[slot]
	emit({"type":"summon","pos":SUMMON_POINT,"time":.65,"max":.65,"color":R.COLORS[R.data(id).faction]})
	announce("%s · %s 합류! 조합 버튼에서 유일한 조합식 확인"%[R.RANKS[rank],R.data(id).name])
	refresh();return true
func open_crafting() -> void:
	if state not in ["build","battle"]:return
	codex.mode=0;codex.reset_filters();open_book()
func recipe_indices(recipe:Dictionary) -> Array:
	var result:Array=[]
	for material in recipe.materials:
		var found:=0
		var chosen:=unit_at(selected)
		if material[0]==recipe.base and chosen>=0 and units[chosen].id==recipe.base:
			result.append(chosen);found=1
		for i in range(units.size()):
			if found==material[1]:break
			if units[i].id==material[0] and not result.has(i):
				result.append(i);found+=1
				if found==material[1]:break
		if found!=material[1]:return []
	return result
func consume_recipe(indices:Array, result_id:int, anchor_slot:int) -> bool:
	var anchor_index:=unit_at(anchor_slot)
	if anchor_index<0 or not indices.has(anchor_index):return false
	var source:Dictionary=units[anchor_index];var point:Vector2=source.pos
	var original_name:String=R.data(source.id).name
	var investment:=0
	for i in indices:investment+=units[i].investment
	indices.sort();indices.reverse()
	for i in indices:units.remove_at(i)
	var product:=make_unit(result_id,R.data(result_id).rank,anchor_slot);product.pos=point;product.target=point;product.investment=investment
	if source.order=="hold":product.order="hold"
	units.append(product);selected=anchor_slot;selected_slots=selected_slots.filter(func(slot):return unit_at(slot)>=0)
	if not selected_slots.has(anchor_slot):selected_slots.append(anchor_slot)
	cancel_order();emit({"type":"summon","pos":point,"time":1.0,"max":1.0,"color":R.RANK_COLORS[product.rank]})
	announce("보유 재료 %d명 조합 → %s %s · %s 위치에서 합류"%[indices.size(),R.RANKS[product.rank],R.data(result_id).name,original_name])
	refresh();return true
func craft_recipe(index:int) -> bool:
	if paused or state not in ["build","battle"] or index<0 or index>=recipes.size():return false
	var recipe:Dictionary=recipes[index];var indices:=recipe_indices(recipe)
	if indices.is_empty():announce("보유 재료가 부족합니다. 조합표에서 장수의 등급과 수량을 확인하세요.");refresh();return false
	var anchor:int=unit_at(selected)
	if anchor<0 or units[anchor].id!=recipe.base:
		for i in indices:
			if units[i].id==recipe.base:anchor=i;break
	return consume_recipe(indices,recipe.result,units[anchor].slot)
func sell_selected() -> bool:
	if paused or codex_open or state not in ["build","battle"] or not selected_slots.has(selected):return false
	var index:=unit_at(selected)
	if index<0:return false
	var unit:Dictionary=units[index];var value:int=unit_sale_value(unit)
	units.remove_at(index);gold+=value;selected_slots.erase(selected)
	selected=selected_slots[0] if not selected_slots.is_empty() else -1
	cancel_order();announce("%s 1명 판매 · +%d 금 (투입 금화의 70%%)"%[R.data(unit.id).name,value]);refresh();return true
func inspect_selected() -> void:
	var idx:=unit_at(selected)
	if idx>=0:
		cancel_order();dragging=false;codex_open=true;headquarters.hide();codex.inspect(units[idx].id);codex.open();refresh()
	else:
		open_book()
func open_book() -> void:
	cancel_order();dragging=false;codex_open=true;headquarters.hide();codex.open();refresh()
func unit_sale_value(unit:Dictionary) -> int:
	return int(floor(unit.investment*.7))
func open_headquarters() -> void:
	if state not in ["build","battle"]:return
	cancel_order();dragging=false;codex.hide();codex_open=true;headquarters.open();refresh()
func close_modals() -> void:
	codex_open=false;codex.hide();headquarters.hide();refresh()
func luck_cost() -> int:
	return 60+luck_level*40
func train_luck() -> bool:
	if paused or state not in ["build","battle"] or luck_level>=R.MAX_LUCK_LEVEL:return false
	var cost:=luck_cost()
	if gold<cost:announce("소환 확률 강화에 %d금이 필요합니다."%cost);return false
	gold-=cost;luck_level+=1
	var odds:=R.summon_odds(luck_level)
	announce("소환 연구 %d단계 · 안흔함 %.1f%% · 희귀 %.1f%%"%[luck_level,odds[1]/100.0,odds[2]/100.0]);refresh();return true
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
		var radius:float=150 if unit.rank>=5 else 110 if unit.rank==4 else 85 if kind=="storm" else 58
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
	if state in ["title","won","lost"] or paused:queue_redraw();return
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
	overlay_body.text="%d / 30진   ·   처치 %d   ·   최고 기록 %d진\n\n%s"%[wave,kills,best,"난세는 끝났다. 이제 그대의 천하를 열어라." if won else "단일 조합표와 전군 훈련을 활용해 다시 도전하세요."]
	overlay_button.text="다시 출전";overlay.show();refresh()
func toggle_pause() -> void:
	if state in ["build","battle"]:cancel_order();paused=not paused;refresh();queue_redraw()
func _notification(what:int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and state in ["build","battle"]:cancel_order();dragging=false;refresh()
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
		if delta.length()>1:
			u.pos=u.pos.move_toward(desired,78*dt)
			if absf(delta.x)>4:u.face=1.0 if delta.x>0 else -1.0
		else:
			u.pos=desired
	# Holding heroes remain anchored; moving heroes avoid them.
	for i in range(units.size()):
		for j in range(i+1,units.size()):
			var offset:Vector2=units[i].pos-units[j].pos;var distance:=offset.length()
			var resting_i:bool=units[i].order=="hold" or (not units[i].ordered and units[i].pos.distance_to(units[i].target)<2)
			var resting_j:bool=units[j].order=="hold" or (not units[j].ordered and units[j].pos.distance_to(units[j].target)<2)
			if resting_i and resting_j:continue
			if distance<20 and distance>.01:
				var push:=offset.normalized()*minf((20-distance)*.35,dt*40)
				if units[i].order=="hold" and units[j].order=="hold":continue
				elif resting_i:units[j].pos-=push*2
				elif resting_j:units[i].pos+=push*2
				else:units[i].pos+=push;units[j].pos-=push
	for u in units:u.pos=Vector2(clampf(u.pos.x,110,834),clampf(u.pos.y,240,670))
func cancel_order() -> void:
	pending_order="";Input.set_default_cursor_shape(Input.CURSOR_ARROW)
func begin_attack_order() -> void:
	if paused or codex_open or state not in ["build","battle"] or selected_slots.is_empty():return
	pending_order="attack";dragging=false;Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	announce("공격 명령 · 좌클릭 적: 집중 공격 / 좌클릭 지면: 공격 이동 / Esc: 취소")
	refresh()
func command_stop() -> void:
	if paused or codex_open or state not in ["build","battle"]:return
	cancel_order();dragging=false
	for slot in selected_slots:
		var index:=unit_at(slot)
		if index<0:continue
		var u:Dictionary=units[index]
		u.order="guard";u.target=u.pos;u.ordered=false;u.focus_enemy=-1;u.auto_enemy=-1
	announce("정지 · 현재 위치에서 자동 교전");refresh()
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
	var half:=Vector2((columns-1)*16.5,(ceil(float(count)/columns)-1)*16.5)
	point=point.clamp(Vector2(110,240)+half,Vector2(834,670)-half)
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
	else:
		selected=-1;selected_slots.clear()
	refresh();queue_redraw()
func _input(event:InputEvent) -> void:
	if not dragging or not event is InputEventMouseButton:return
	if event.button_index!=MOUSE_BUTTON_LEFT or event.pressed:return
	if not Rect2(battlefield.position,battlefield.size).has_point(event.position):
		dragging=false;refresh();queue_redraw();get_viewport().set_input_as_handled()
func _unhandled_input(event:InputEvent) -> void:
	if codex_open:
		if event is InputEventKey and event.pressed and event.physical_keycode==KEY_ESCAPE:close_modals()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SPACE:summon()
			KEY_M:open_crafting()
			KEY_DELETE, KEY_BACKSPACE:sell_selected()
			KEY_N:start_wave()
			KEY_U:open_headquarters()
			KEY_TAB, KEY_F8:open_book()
			KEY_ESCAPE:
				if pending_order!="":cancel_order();announce("공격 명령 취소");refresh()
				else:selected=-1;selected_slots.clear();refresh()
			KEY_A:
				if event.ctrl_pressed or event.meta_pressed:
					cancel_order();selected_slots.clear()
					for u in units:selected_slots.append(u.slot)
					if not selected_slots.is_empty():selected=selected_slots[0]
					refresh()
				else:begin_attack_order()
			KEY_H:command_hold()
			KEY_S:command_stop()
	if paused or state not in ["build","battle"]:return
	if event is InputEventKey and event.pressed and event.physical_keycode==KEY_HOME:battlefield.focus=Vector3.ZERO;battlefield.zoom=24;battlefield.set_camera()
	if event is InputEventMouseButton:
		if not Rect2(battlefield.position,battlefield.size).has_point(event.position):return
		if event.button_index==MOUSE_BUTTON_WHEEL_UP and event.pressed:battlefield.zoom=maxf(16,battlefield.zoom-2);battlefield.set_camera()
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN and event.pressed:battlefield.zoom=minf(42,battlefield.zoom+2);battlefield.set_camera()
		elif event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
			command_at(event.position,pending_order=="attack")
			refresh()
		elif event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed:
				if pending_order=="attack":
					dragging=false;command_at(event.position,true);refresh();get_viewport().set_input_as_handled();return
				if battlefield.headquarters_hit(event.position):open_headquarters();get_viewport().set_input_as_handled();return
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
	var l:=Label.new();l.text=value;l.position=pos;l.add_theme_font_override("font",FONT);l.add_theme_font_size_override("font_size",maxi(12,size));l.add_theme_color_override("font_color",color);l.add_theme_color_override("font_outline_color",Color("14213d"));l.add_theme_constant_override("outline_size",3);l.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(l);return l
func style(color:Color, border:Color=Color("3d5a80"), radius:int=10) -> StyleBoxFlat:
	var s:=StyleBoxFlat.new();s.bg_color=color;s.border_color=border;s.set_border_width_all(2);s.set_corner_radius_all(radius);s.content_margin_left=12;s.content_margin_right=12;s.shadow_color=Color(0,0,0,.25);s.shadow_size=3;s.shadow_offset=Vector2(0,2);return s
func button_at(parent:Control, value:String, rect:Rect2, callback:Callable, accent:bool=false, font_size:int=16) -> Button:
	var b:=preload("res://scripts/tooltip_button.gd").new();b.focus_mode=Control.FOCUS_NONE;b.clip_text=true
	b.add_theme_font_override("font",FONT);b.add_theme_font_size_override("font_size",font_size)
	b.add_theme_color_override("font_color",Color("14213d") if accent else Color("f8f9fa"))
	b.add_theme_color_override("font_disabled_color",Color("6c757d"))
	b.add_theme_stylebox_override("normal",style(Color("ffb703") if accent else Color("1d3557"),Color("fb8500") if accent else Color("457b9d"),10))
	b.add_theme_stylebox_override("hover",style(Color("ffd166") if accent else Color("2a4a75"),Color("ffb703") if accent else Color("64b5f6"),10))
	b.add_theme_stylebox_override("pressed",style(Color("f77f00") if accent else Color("132438"),Color("d62828") if accent else Color("1d3557"),10))
	b.add_theme_stylebox_override("disabled",style(Color("162231"),Color("253548"),10))
	b.add_theme_color_override("font_outline_color",Color("ffffff") if accent else Color("0b131f"));b.add_theme_constant_override("outline_size",0 if accent else 2);b.pressed.connect(callback)
	if rect.size.y<=42:
		for state_name in ["normal","hover","pressed","disabled"]:
			var skin:StyleBoxFlat=b.get_theme_stylebox(state_name)
			skin.shadow_size=1;skin.shadow_offset=Vector2(0,1)
	# Measure only after the final font, styles and inherited theme are applied.
	b.text=value;parent.add_child(b);b.position=rect.position;b.size=rect.size
	b.set_meta("layout_rect",rect)
	return b
func panel_at(parent:Control, rect:Rect2) -> Panel:
	var p:=Panel.new();p.position=rect.position;p.size=rect.size;p.add_theme_stylebox_override("panel",style(Color("14213de8"),Color("457b9d"),12));parent.add_child(p);return p
func stone_panel(rect:Rect2) -> Panel:
	var p:=Panel.new();p.position=rect.position;p.size=rect.size;p.add_theme_stylebox_override("panel",style(Color("172c39fa"),Color("ad9870"),6));ui.add_child(p)
	var frame:=NinePatchRect.new();frame.texture=HUD_FRAME;frame.size=rect.size*12;frame.scale=Vector2.ONE/12;frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
	frame.patch_margin_left=120;frame.patch_margin_top=120;frame.patch_margin_right=120;frame.patch_margin_bottom=120;frame.modulate=Color(1.05,1.1,1.05,.78);p.add_child(frame)
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
	var top:=ColorRect.new();top.size=Vector2(1280,32);top.color=Color("14213d");top.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(top)
	label_at(ui,"삼국지 · 난세의 수호자",Vector2(15,6),16,Color("ffd166"))
	speed_button=button_at(ui,"속도 ×1",Rect2(235,2,86,28),func():speed=2 if speed==1 else 1;refresh(),false,14)
	summary=label_at(ui,"",Vector2(335,7),14,Color("e0e1dd"))
	var round_panel:=panel_at(ui,Rect2(1080,42,190,68));round_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	round_info=label_at(round_panel,"",Vector2(9,6),12,Color("ffd166"))
	var notice_bg:=ColorRect.new();notice_bg.position=Vector2(0,610);notice_bg.size=Vector2(1280,22);notice_bg.color=Color(.08,.13,.2,.88);notice_bg.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(notice_bg)
	tooltip=label_at(ui,"",Vector2(14,613),12,Color("fff3b0"))
	var map_frame:=stone_panel(Rect2(0,632,240,168))
	minimap=Minimap.new();minimap.game=self;minimap.position=Vector2(12,10);minimap.size=Vector2(216,148);map_frame.add_child(minimap)
	var face_panel:=stone_panel(Rect2(240,632,168,168))
	portrait_name=label_at(face_panel,"장수 선택",Vector2(10,116),14,Color("f3f6f2"))
	portrait=TextureRect.new();portrait.position=Vector2(10,10);portrait.size=Vector2(144,100);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE;face_panel.add_child(portrait)
	sell_button=button_at(face_panel,"판매",Rect2(76,122,82,34),sell_selected,false,11);sell_button.add_theme_font_size_override("font_size",11)
	var info_panel:=stone_panel(Rect2(408,632,560,168))
	detail=label_at(info_panel,"",Vector2(12,10),13,Color("f3f6f2"));detail.size=Vector2(536,112);detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail.clip_text=true
	for i in range(18):
		var icon:=button_at(info_panel,"",Rect2(12+(i%9)*46,48+(i/9)*50,42,44),func():focus_squad_icon(i),false,12)
		var image:=TextureRect.new();image.position=Vector2(2,2);image.size=Vector2(38,40);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.mouse_filter=Control.MOUSE_FILTER_IGNORE;icon.add_child(image)
		icon.hide();squad_icons.append(icon)
	summon_button=button_at(info_panel,"소환 · 35금",Rect2(444,126,104,30),summon,true,12)
	wave_button=button_at(ui,"전투 시작 [N]",Rect2(1090,2,180,28),start_wave,true,12)
	selection_recipes=SelectionRecipes.new();selection_recipes.game=self;ui.add_child(selection_recipes)
	codex=RecipeBook.new();codex.game=self;ui.add_child(codex);codex.hide()
	headquarters=Headquarters.new();headquarters.game=self;ui.add_child(headquarters);headquarters.hide()
	overlay=panel_at(ui,Rect2(280,225,720,365))
	overlay_title=label_at(overlay,"난세의 수호자 · 삼국지 ORD",Vector2(34,28),36,Color("edcf92"))
	overlay_body=label_at(overlay,"원피스 랜덤 디펜스(ORD) 감성을 담은 삼국지 RTS 디펜스입니다.\n\n[Space] 랜덤 장수 소환 → [M] 단일 조합표 → 선택 유닛의 조합 아이콘\n장수 클릭 · 드래그 부대 선택 · 우클릭 이동 · [A]+좌클릭 공격 이동 / [H] 사수\n단축키: Space 소환 / M 조합표 / Tab 전체도감 / U 업그레이드 / Del 판매\n30번의 진격 · 5진마다 적장 출현 · 성문 내구도 30",Vector2(36,95),17,Color("c7d3c8"))
	overlay_button=button_at(overlay,"출전 · 방어선 준비",Rect2(35,282,650,56),reset_game,true)
func refresh() -> void:
	if not summary:return
	if headquarters.visible:headquarters.refresh()
	var odds:=R.summon_odds(luck_level)
	summon_button.tooltip_text="흔함 %.1f%% · 안흔함 %.1f%% · 희귀 %.1f%%\n업그레이드 [U]에서 소환 확률 강화"%[odds[0]/100.0,odds[1]/100.0,odds[2]/100.0]
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
	speed_button.text="속도 ×%d"%speed
	wave_button.text="전투 중 · 남은 적 %d"%mob_count if state=="battle" else "다음 진격 [N] · %d초"%int(ceil(break_time)) if break_time>0 else "진격 시작 [N]"
	wave_button.disabled=state!="build" or paused
	summon_button.disabled=gold<35 or empty_slot()<0 or paused or state not in ["build","battle"]
	selected_slots=selected_slots.filter(func(slot):return unit_at(slot)>=0)
	var idx:=unit_at(selected)
	if idx>=0:
		var u:Dictionary=units[idx];var h:Dictionary=R.data(u.id);var stats:=R.stats(u,upgrade)
		var bonus_dmg:int=int(stats.damage-h.damage)
		detail.text="[%s] %s · %s / %s\n명령: %s · 공격 %d (+%d)\n사거리 %d · %.2f초 / %s"%[
			R.FACTIONS[h.faction],h.name,R.RANKS[u.rank],h.role,
			{"guard":"경계","move":"이동","attack":"집중 공격","attack_move":"공격 이동","hold":"위치 사수"}.get(u.order,"경계"),
			int(stats.damage),bonus_dmg,int(48 if stats.kind in ["melee","cleave","stun"] else stats.range),stats.rate,h.skill
		]
		detail.add_theme_color_override("font_color",R.RANK_COLORS[u.rank])
	else:
		detail.text=""
	sell_button.disabled=idx<0 or not selected_slots.has(selected) or paused or codex_open or state not in ["build","battle"]
	sell_button.text="판매 +%d"%unit_sale_value(units[idx]) if idx>=0 else "선택 후 판매"
	sell_button.tooltip_text="대표 선택 장수 1명 · 실제 투입 금화의 70% 환급 [Delete]"
	portrait.visible=idx>=0
	portrait_name.text=R.RANKS[units[idx].rank]+"\n"+R.data(units[idx].id).name if idx>=0 else "장수 선택"
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
	if selected_slots.size()>1:detail.text="선택 %d명 · 더블클릭: 같은 장수 선택"%selected_slots.size();detail.add_theme_color_override("font_color",Color("f3f6f2"))
	elif idx<0:
		detail.add_theme_color_override("font_color",Color("f3f6f2"))
		detail.text="Space 소환 · M 조합표\n좌클릭 선택 · 우클릭 이동\nU 업그레이드 · N 진격 · Tab 도감\nA+좌클릭 공격 이동 · H 사수"
	selection_recipes.refresh()
	tooltip.text="공격 명령 [A] · 좌클릭: 집중 공격/공격 이동 · Esc: 취소" if pending_order=="attack" else notice if notice_time>0 else "Space 소환 · M 조합표 · U 업그레이드 · 좌클릭 선택 · 우클릭 이동"
