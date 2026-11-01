extends Panel
var game
var signature:=0
var heading:Label
var recipe_buttons:Dictionary={}
var cells:Array=[]
var page:=0
var selected_id:=-1
var current:Array=[]
func _ready() -> void:
	position=Vector2(968,632);size=Vector2(312,168);clip_contents=true
	add_theme_stylebox_override("panel",game.style(Color("15212b"),Color("8d8465"),4))
	heading=Label.new() # Compatibility for selection inspection; the portrait names the selected unit.
	add_child(heading);heading.hide()
	for i in range(12):
		var button:Button=game.button_at(self,"",Rect2(10+(i%4)*74,10+(i/4)*50,70,46),func():activate(i),false,12)
		for skin_name in ["normal","hover","pressed","disabled"]:
			var skin:StyleBoxFlat=button.get_theme_stylebox(skin_name);skin.content_margin_left=3;skin.content_margin_right=3
		cells.append(button)
	cells[0].text="도감";cells[0].tooltip_text="전체 장수와 조합 조회 [Tab]"
	cells[1].text="공격 A";cells[1].tooltip_text="A → 좌클릭 공격 이동 / 지정 공격"
	cells[2].text="정지 S";cells[3].text="사수 H"
	game.attack_cmd_button=cells[1];game.hold_cmd_button=cells[3];game.recipe_button=cells[0]
func related_indices(id:int) -> Array:
	var result:Array=[]
	for i in range(game.recipes.size()):
		if game.recipes[i].base==id:result.append(i)
	return result
func activate(cell:int) -> void:
	match cell:
		0:game.open_book()
		1:game.begin_attack_order()
		2:game.command_stop()
		3:game.command_hold()
		_:
			var offset:int=cell-4
			if offset>=0 and offset<current.size():game.craft_recipe(current[offset])
func refresh() -> void:
	visible=true
	var index:int=game.unit_at(game.selected)
	var id:int=game.units[index].id if index>=0 and game.selected_slots.has(game.selected) else -1
	if id!=selected_id:page=0;selected_id=id
	var state:Array=[id,game.paused,game.state,game.codex_open,page]
	for unit in game.units:state.append([unit.id,unit.slot])
	var next_signature:=hash(state)
	if signature==next_signature:return
	signature=next_signature;recipe_buttons.clear();current=related_indices(id) if id>=0 else []
	heading.text=game.R.title(id) if id>=0 else "장수 선택"
	var blocked:bool=game.paused or game.codex_open or game.state not in ["build","battle"]
	for i in [1,2,3]:cells[i].disabled=id<0 or blocked
	cells[0].disabled=blocked
	for i in range(4,12):
		if cells[i].has_meta("recipe_bbcode"):cells[i].remove_meta("recipe_bbcode")
		cells[i].text="";cells[i].icon=null;cells[i].tooltip_text="";cells[i].disabled=true
	for offset in range(8):
		var item:int=offset
		if item>=current.size():continue
		var recipe_index:int=current[item];var recipe:Dictionary=game.recipes[recipe_index];var button:Button=cells[4+offset]
		button.icon=game.portrait_for(recipe.result);button.expand_icon=true;button.add_theme_constant_override("icon_max_width",42)
		var terms:=PackedStringArray()
		for ingredient in recipe.materials:
			terms.append(game.R.title(ingredient[0])+(" ×%d"%ingredient[1] if ingredient[1]>1 else ""))
		var text:String="기준 유닛: "+game.R.title(recipe.base)+"\n\n"+" + ".join(terms)+"\n→ "+game.R.title(recipe.result)+"\n\n재료 보유 / 필요\n"
		for ingredient in recipe.materials:
			var count:=0
			for unit in game.units:
				if unit.id==ingredient[0]:count+=1
			text+="%s  %d / %d%s\n"%[game.R.title(ingredient[0]),count,ingredient[1]," · %d명 부족"%(ingredient[1]-count) if count<ingredient[1] else " · 준비 완료"]
		var ready:bool=not game.recipe_indices(recipe).is_empty()
		button.tooltip_text=text+("클릭하여 조합" if ready else "재료 부족")
		var colored:String=button.tooltip_text
		var ids:Array=[recipe.result]
		for ingredient in recipe.materials:
			if not ids.has(ingredient[0]):ids.append(ingredient[0])
		for unit_id in ids:
			var title:String=game.R.title(unit_id);var color:Color=game.R.RANK_COLORS[game.R.data(unit_id).rank]
			colored=colored.replace(title,"[color=#%s]%s[/color]"%[color.to_html(false),title])
		button.set_meta("recipe_bbcode",colored)
		button.disabled=blocked or not ready;recipe_buttons[recipe_index]=button
