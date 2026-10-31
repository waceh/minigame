extends Panel
const R=preload("res://scripts/roster.gd")
var game
var search:LineEdit
var rank_filter:OptionButton
var faction_filter:OptionButton
var ready_only:CheckBox
var heading:Label
var scroll:ScrollContainer
var list:VBoxContainer
var mode:=0
var rows:Array=[]
var previous_signature:=0
var elapsed:=0.0
func _ready() -> void:
	position=Vector2(105,48);size=Vector2(1070,704)
	add_theme_stylebox_override("panel",game.style(Color("0f172ae8"),Color("60a5fa"),16))
	heading=game.label_at(self,"장수 · 조합 도감",Vector2(22,15),23,Color("ffd166"))
	game.button_at(self,"조합표",Rect2(720,14,140,35),func():mode=0;rebuild())
	game.button_at(self,"전체 장수",Rect2(870,14,176,35),func():mode=1;rebuild())
	search=LineEdit.new();search.position=Vector2(22,65);search.size=Vector2(350,38);search.placeholder_text="장수 또는 재료 이름 검색";search.add_theme_font_override("font",game.FONT);search.add_theme_font_size_override("font_size",18);add_child(search);search.text_changed.connect(func(_text):rebuild())
	rank_filter=OptionButton.new();rank_filter.position=Vector2(384,65);rank_filter.size=Vector2(145,38);rank_filter.add_item("모든 단계")
	for rank in R.RANKS:rank_filter.add_item(rank)
	rank_filter.add_theme_font_override("font",game.FONT);rank_filter.add_theme_font_size_override("font_size",16);rank_filter.get_popup().add_theme_font_override("font",game.FONT);rank_filter.get_popup().add_theme_font_size_override("font_size",18);rank_filter.item_selected.connect(func(_index):rebuild());add_child(rank_filter)
	faction_filter=OptionButton.new();faction_filter.position=Vector2(541,65);faction_filter.size=Vector2(114,38);faction_filter.add_item("모든 진영")
	for faction in R.FACTIONS:faction_filter.add_item(faction)
	faction_filter.add_theme_font_override("font",game.FONT);faction_filter.add_theme_font_size_override("font_size",16);faction_filter.get_popup().add_theme_font_override("font",game.FONT);faction_filter.get_popup().add_theme_font_size_override("font_size",18);faction_filter.item_selected.connect(func(_index):rebuild());add_child(faction_filter)
	ready_only=CheckBox.new();ready_only.text="선택 재료로 가능";ready_only.position=Vector2(676,65);ready_only.size=Vector2(220,38);ready_only.add_theme_font_override("font",game.FONT);ready_only.toggled.connect(func(_on):rebuild());add_child(ready_only)
	game.button_at(self,"초기화",Rect2(938,65,108,38),reset_filters)
	scroll=ScrollContainer.new();scroll.position=Vector2(20,119);scroll.size=Vector2(1030,514);add_child(scroll)
	list=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list.add_theme_constant_override("separation",7);scroll.add_child(list)
	game.label_at(self,"선택 부대 재료만 사용 · 재료 클릭: 관련 경로 · M: 3명 승급",Vector2(23,646),16,Color("e2ece5"))
	game.button_at(self,"전장으로 돌아가기",Rect2(790,650,254,36),close_book)
func open() -> void:
	show();rebuild();search.grab_focus()
func close_book() -> void:
	game.codex_open=false;hide();game.refresh()
func reset_filters() -> void:
	search.text="";rank_filter.select(0);faction_filter.select(0);ready_only.button_pressed=false;rebuild()
func inspect(id:int) -> void:
	mode=0;search.text=R.data(id).name;rank_filter.select(0);faction_filter.select(0);rebuild()
func selected_count(id:int) -> int:
	var count:=0
	for u in game.units:
		if u.id==id and game.selected_slots.has(u.slot):count+=1
	return count
func matches(id:int, materials:Array=[]) -> bool:
	var h:Dictionary=R.data(id)
	if rank_filter.selected>0 and h.rank!=rank_filter.selected-1:return false
	if faction_filter.selected>0 and h.faction!=faction_filter.selected-1:return false
	var query:=search.text.strip_edges()
	if query=="" or query in h.name or query in R.RANKS[h.rank]:return true
	for ingredient in materials:
		if query in R.data(ingredient[0]).name:return true
	return false
func clear_rows() -> void:
	for child in list.get_children():list.remove_child(child);child.queue_free()
	rows.clear()
func rebuild() -> void:
	if not list:return
	clear_rows()
	if mode==0:
		for i in range(game.recipes.size()):
			var recipe:Dictionary=game.recipes[i]
			var ready:bool=not game.recipe_indices(recipe).is_empty()
			if not matches(recipe.result,recipe.materials) or (ready_only.button_pressed and not ready):continue
			add_recipe(i)
	else:
		var ids:Array=R.DATA.keys()
		ids.sort_custom(func(a,b):return R.data(a).rank<R.data(b).rank if R.data(a).rank!=R.data(b).rank else R.data(a).faction<R.data(b).faction if R.data(a).faction!=R.data(b).faction else a<b)
		for id in ids:
			if matches(id) and (not ready_only.button_pressed or selected_count(id)>0):add_hero(id)
	heading.text="%s  ·  %d종 장수 / %d개 조합  ·  선택 %d명"%["조합표" if mode==0 else "장수 도감",R.DATA.size(),game.recipes.size(),game.selected_slots.size()]
	previous_signature=inventory_signature()
func icon(parent:Control, id:int, pos:Vector2, size:Vector2) -> void:
	var image:=TextureRect.new();image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.texture=game.portrait_for(id);image.position=pos;image.size=size;image.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(image)
func add_recipe(index:int) -> void:
	var recipe:Dictionary=game.recipes[index];var h:Dictionary=R.data(recipe.result)
	var row:=Panel.new();row.clip_contents=true;row.custom_minimum_size=Vector2(1005,88);row.add_theme_stylebox_override("panel",game.style(Color("1e293be0"),R.RANK_COLORS[h.rank].darkened(.25),10));list.add_child(row)
	icon(row,recipe.result,Vector2(8,8),Vector2(52,71))
	var title:Button=game.button_at(row,"%s %s\n%s"%[R.FACTIONS[h.faction],h.name,R.RANKS[h.rank]],Rect2(66,13,127,62),inspect.bind(recipe.result));title.add_theme_font_size_override("font_size",16);title.add_theme_color_override("font_color",R.RANK_COLORS[h.rank]);title.add_theme_color_override("font_hover_color",R.RANK_COLORS[h.rank])
	var ingredients:=HFlowContainer.new();ingredients.position=Vector2(204,10);ingredients.size=Vector2(632,70);ingredients.add_theme_constant_override("h_separation",5);ingredients.add_theme_constant_override("v_separation",4);row.add_child(ingredients)
	for material in recipe.materials:
		var data:Dictionary=R.data(material[0]);var count:=selected_count(material[0])
		var button:=Button.new();button.text="%s %s %d/%d%s"%[R.RANKS[data.rank],data.name,count,material[1]," ✓" if count>=material[1] else ""];button.add_theme_font_override("font",game.FONT);button.add_theme_font_size_override("font_size",16);button.add_theme_color_override("font_color",R.RANK_COLORS[data.rank]);button.add_theme_color_override("font_hover_color",R.RANK_COLORS[data.rank]);button.add_theme_stylebox_override("normal",game.style(Color("0f172a"),R.RANK_COLORS[data.rank].darkened(.4),8));button.add_theme_stylebox_override("hover",game.style(Color("334155"),R.RANK_COLORS[data.rank],8));button.add_theme_constant_override("outline_size",2);button.add_theme_color_override("font_outline_color",Color("050a0d"));button.pressed.connect(inspect.bind(material[0]));button.tooltip_text="현재 선택한 부대 / 필요 수량 · 클릭하면 이 장수의 조합 경로 표시";ingredients.add_child(button)
	var ready:bool=not game.recipe_indices(recipe).is_empty()
	var craft_button:Button=game.button_at(row,"조합하기" if ready else "선택 재료 부족",Rect2(852,20,139,48),craft.bind(index),ready);craft_button.add_theme_font_size_override("font_size",16);craft_button.disabled=not ready or game.paused or game.state not in ["build","battle"]
	rows.append({"index":index,"button":craft_button})
func add_hero(id:int) -> void:
	var h:Dictionary=R.data(id);var row:=Panel.new();row.clip_contents=true;row.custom_minimum_size=Vector2(1005,93);row.add_theme_stylebox_override("panel",game.style(Color("1e293be0"),R.RANK_COLORS[h.rank].darkened(.25),10));list.add_child(row)
	icon(row,id,Vector2(10,6),Vector2(66,79))
	game.label_at(row,"%s · %s %s"%[R.RANKS[h.rank],R.FACTIONS[h.faction],h.name],Vector2(90,8),18,R.RANK_COLORS[h.rank])
	game.label_at(row,"%s   /   공격력 %d · 간격 %.2f초   /   판매 %d금"%[h.role,int(h.damage),h.rate,R.sell_value(id)],Vector2(92,37),13,Color("ecf2ec"))
	game.label_at(row,h.skill,Vector2(92,63),13,Color("d4e3d7"))
	var show_button:Button=game.button_at(row,"획득 · 재료 경로",Rect2(818,24,174,44),inspect.bind(id));show_button.add_theme_font_size_override("font_size",16)
func craft(index:int) -> void:
	game.craft_recipe(index);rebuild()
func inventory_signature() -> int:
	var state:Array=[game.selected_slots.duplicate(),game.paused]
	for u in game.units:state.append([u.id,u.slot])
	return hash(state)
func _process(dt:float) -> void:
	if not visible:return
	elapsed+=dt
	if elapsed>.2:
		elapsed=0
		if inventory_signature()!=previous_signature:rebuild()
