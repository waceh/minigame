extends Panel
var game
var attack_button:Button
var luck_button:Button
var attack_info:Label
var odds_info:Label
var next_info:Label
func _ready() -> void:
	position=Vector2(330,165);size=Vector2(620,470)
	add_theme_stylebox_override("panel",game.style(Color("101d30"),Color("ffd166"),16))
	game.label_at(self,"본영 · 군사 훈련과 소환 연구",Vector2(25,18),25,Color("ffd166"))
	game.label_at(self,"창이 열려 있는 동안 전투가 정지합니다.",Vector2(26,59),16,Color("d6e2ed"))
	attack_info=game.label_at(self,"",Vector2(26,104),18,Color("f3f6f2"))
	attack_button=game.button_at(self,"",Rect2(388,106,205,60),attack,true)
	game.label_at(self,"소환 확률 연구 · 단계당 안흔함 +1%p / 특별함 +0.3%p",Vector2(26,201),17,Color("a6d8f4"))
	odds_info=game.label_at(self,"",Vector2(26,241),17,Color("f3f6f2"))
	next_info=game.label_at(self,"",Vector2(26,272),17,Color("a4dfb3"))
	luck_button=game.button_at(self,"",Rect2(26,321,567,53),luck,true)
	game.button_at(self,"전장으로 돌아가기 [Esc]",Rect2(276,405,317,42),game.close_modals)
	game.label_at(self,"높은 등급도 중앙 소환진에서 합류합니다.",Vector2(26,381),16,Color("d6e2ed"))
func open() -> void:
	show();refresh()
func attack() -> void:
	game.train_army();refresh()
func luck() -> void:
	game.train_luck();refresh()
func format_odds(values:Array) -> String:
	return "흔함 %.1f%%  ·  안흔함 %.1f%%  ·  특별함 %.1f%%"%[values[0]/100.0,values[1]/100.0,values[2]/100.0]
func refresh() -> void:
	if not attack_info:return
	attack_info.text="전군 공격력 %d / 10단계\n기본 공격력 +%d%%"%[game.upgrade,game.upgrade*12]
	attack_button.text="공격력 강화\n%d 금"%(80+game.upgrade*55) if game.upgrade<10 else "공격력 강화 완료"
	attack_button.disabled=game.paused or game.upgrade>=10 or game.gold<80+game.upgrade*55
	odds_info.text="현재: "+format_odds(game.R.summon_odds(game.luck_level))
	next_info.text="다음: "+format_odds(game.R.summon_odds(game.luck_level+1)) if game.luck_level<game.R.MAX_LUCK_LEVEL else "소환 연구 완료 · 최고 확률 적용"
	luck_button.text="소환 확률 강화 %d / 10  ·  %d 금"%[game.luck_level,game.luck_cost()] if game.luck_level<10 else "소환 확률 강화 완료"
	luck_button.disabled=game.paused or game.luck_level>=10 or game.gold<game.luck_cost()
