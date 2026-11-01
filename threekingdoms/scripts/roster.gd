extends RefCounted
# Identity is (grade, name): every non-common officer has exactly one canonical recipe.
const DATA = {
	0: {"name": "유비", "faction": 0, "rank": 2, "role": "군주", "kind": "aura", "damage": 145.0, "rate": 0.85, "range": 170.0, "skill": "인덕 · 주변 아군 공격력 +20%"},
	1: {"name": "관우", "faction": 0, "rank": 2, "role": "무장", "kind": "cleave", "damage": 190.0, "rate": 1.0, "range": 145.0, "skill": "청룡참 · 범위 베기"},
	2: {"name": "장비", "faction": 0, "rank": 1, "role": "맹장", "kind": "stun", "damage": 52.0, "rate": 1.05, "range": 135.0, "skill": "장판교 · 매 4타 기절 1초"},
	3: {"name": "조조", "faction": 1, "rank": 2, "role": "군주", "kind": "aura", "damage": 150.0, "rate": 0.8, "range": 170.0, "skill": "패도 · 주변 아군 공격력 +20%"},
	4: {"name": "하후돈", "faction": 1, "rank": 1, "role": "무장", "kind": "cleave", "damage": 55.0, "rate": 1.15, "range": 135.0, "skill": "독안의 일격 · 범위 베기"},
	5: {"name": "순욱", "faction": 1, "rank": 4, "role": "왕좌지재", "kind": "storm", "damage": 1750.0, "rate": 0.85, "range": 285.0, "skill": "천하경략 · 대범위 공격 + 둔화"},
	6: {"name": "손권", "faction": 2, "rank": 2, "role": "군주", "kind": "aura", "damage": 140.0, "rate": 0.75, "range": 180.0, "skill": "강동의 왕 · 주변 아군 공격력 +20%"},
	7: {"name": "감녕", "faction": 2, "rank": 2, "role": "궁장", "kind": "rapid", "damage": 115.0, "rate": 0.48, "range": 205.0, "skill": "금범의 화살 · 빠른 원거리 사격"},
	8: {"name": "주유", "faction": 2, "rank": 4, "role": "적벽의 지휘자", "kind": "fire", "damage": 1550.0, "rate": 0.7, "range": 285.0, "skill": "적벽대화계 · 대범위 화염 + 지속 피해"},
	9: {"name": "제갈량", "faction": 0, "rank": 3, "role": "와룡", "kind": "storm", "damage": 600.0, "rate": 0.7, "range": 245.0, "skill": "팔진도 · 광역 공격 + 둔화"},
	10: {"name": "사마의", "faction": 1, "rank": 3, "role": "총사령", "kind": "storm", "damage": 760.0, "rate": 0.9, "range": 240.0, "skill": "귀모 · 광역 공격 + 둔화"},
	11: {"name": "육손", "faction": 2, "rank": 3, "role": "대도독", "kind": "fire", "damage": 650.0, "rate": 0.75, "range": 240.0, "skill": "이릉화계 · 광역 화염 + 지속 피해"},
	15: {"name": "조운", "faction": 0, "rank": 4, "role": "무쌍의 창", "kind": "cleave", "damage": 1450.0, "rate": 0.65, "range": 205.0, "skill": "용담무쌍 · 넓은 범위 연속 베기"},
	16: {"name": "황충", "faction": 0, "rank": 1, "role": "노장", "kind": "rapid", "damage": 32.0, "rate": 0.55, "range": 200.0, "skill": "백보천양 · 빠른 장거리 사격"},
	17: {"name": "마초", "faction": 0, "rank": 1, "role": "금마초", "kind": "cleave", "damage": 48.0, "rate": 0.9, "range": 145.0, "skill": "서량의 창 · 범위 베기"},
	18: {"name": "장료", "faction": 1, "rank": 2, "role": "선봉장", "kind": "cleave", "damage": 175.0, "rate": 0.85, "range": 150.0, "skill": "합비 돌파 · 범위 베기"},
	19: {"name": "허저", "faction": 1, "rank": 1, "role": "호위장", "kind": "stun", "damage": 58.0, "rate": 1.15, "range": 130.0, "skill": "호치 · 매 4타 기절"},
	20: {"name": "전위", "faction": 1, "rank": 1, "role": "악래", "kind": "cleave", "damage": 44.0, "rate": 0.8, "range": 135.0, "skill": "쌍극 · 빠른 범위 베기"},
	21: {"name": "태사자", "faction": 2, "rank": 1, "role": "선봉장", "kind": "rapid", "damage": 36.0, "rate": 0.6, "range": 180.0, "skill": "쌍창 · 빠른 원거리 공격"},
	22: {"name": "황개", "faction": 2, "rank": 1, "role": "노장", "kind": "fire", "damage": 40.0, "rate": 1.1, "range": 165.0, "skill": "고육계 · 작은 범위 화염"},
	23: {"name": "능통", "faction": 2, "rank": 1, "role": "돌격장", "kind": "stun", "damage": 43.0, "rate": 0.8, "range": 135.0, "skill": "강동의 칼 · 매 4타 기절"},
	24: {"name": "관평", "faction": 0, "rank": 0, "role": "창병", "kind": "melee", "damage": 17.0, "rate": 1.0, "range": 130.0, "skill": "근접전 · 단일 대상 공격"},
	25: {"name": "주창", "faction": 0, "rank": 0, "role": "보조 무장", "kind": "melee", "damage": 17.0, "rate": 1.0, "range": 130.0, "skill": "근접전 · 단일 대상 공격"},
	26: {"name": "미축", "faction": 0, "rank": 0, "role": "책사", "kind": "slow", "damage": 10.0, "rate": 1.0, "range": 165.0, "skill": "견제 · 적 이동 속도 35% 감소"},
	30: {"name": "조홍", "faction": 1, "rank": 0, "role": "방패 무장", "kind": "melee", "damage": 17.0, "rate": 1.0, "range": 130.0, "skill": "근접전 · 단일 대상 공격"},
	31: {"name": "이전", "faction": 1, "rank": 0, "role": "쇠뇌병", "kind": "rapid", "damage": 11.0, "rate": 0.68, "range": 180.0, "skill": "쇠뇌 사격 · 빠른 원거리 공격"},
	32: {"name": "악진", "faction": 1, "rank": 0, "role": "무장", "kind": "melee", "damage": 17.0, "rate": 1.0, "range": 130.0, "skill": "선봉검 · 근접 단일 대상 공격"},
	36: {"name": "주태", "faction": 2, "rank": 0, "role": "보조 무장", "kind": "melee", "damage": 17.0, "rate": 1.0, "range": 130.0, "skill": "근접전 · 단일 대상 공격"},
	37: {"name": "한당", "faction": 2, "rank": 0, "role": "궁병", "kind": "rapid", "damage": 11.0, "rate": 0.68, "range": 180.0, "skill": "사격 · 빠른 원거리 공격"},
	38: {"name": "정보", "faction": 2, "rank": 0, "role": "노장", "kind": "melee", "damage": 17.0, "rate": 1.0, "range": 130.0, "skill": "근접전 · 단일 대상 공격"},
	100: {"name": "조조", "faction": 1, "rank": 4, "role": "패왕", "kind": "storm", "damage": 1600.0, "rate": 0.75, "range": 270.0, "skill": "패왕천명 · 광역 위압과 둔화", "art": 3},
	101: {"name": "관우", "faction": 0, "rank": 4, "role": "무성", "kind": "cleave", "damage": 1500.0, "rate": 0.8, "range": 215.0, "skill": "청룡무쌍 · 대범위 베기", "art": 1},
	102: {"name": "손권", "faction": 2, "rank": 4, "role": "강동의 왕", "kind": "aura", "damage": 1100.0, "rate": 0.6, "range": 250.0, "skill": "왕도지휘 · 주변 아군 공격력 +20%", "art": 6},
	200: {"name": "조운", "faction": 0, "rank": 5, "role": "상산의 용", "kind": "cleave", "damage": 3600.0, "rate": 0.48, "range": 240.0, "skill": "진 용담무쌍 · 초광역 연속 베기", "art": 15},
	201: {"name": "관우", "faction": 0, "rank": 5, "role": "천하의 무성", "kind": "cleave", "damage": 4200.0, "rate": 0.65, "range": 250.0, "skill": "천룡참 · 초광역 청룡 베기", "art": 1},
	202: {"name": "제갈량", "faction": 0, "rank": 5, "role": "천명의 와룡", "kind": "storm", "damage": 4000.0, "rate": 0.6, "range": 320.0, "skill": "천지팔진 · 초광역 공격과 둔화", "art": 9},
	203: {"name": "조조", "faction": 1, "rank": 5, "role": "난세의 패왕", "kind": "storm", "damage": 3800.0, "rate": 0.55, "range": 310.0, "skill": "천하패도 · 초광역 위압과 둔화", "art": 3},
	204: {"name": "순욱", "faction": 1, "rank": 5, "role": "왕좌의 설계자", "kind": "storm", "damage": 3600.0, "rate": 0.55, "range": 325.0, "skill": "왕좌천략 · 초광역 공격과 둔화", "art": 5},
	205: {"name": "사마의", "faction": 1, "rank": 5, "role": "천하의 귀모", "kind": "storm", "damage": 4600.0, "rate": 0.7, "range": 330.0, "skill": "천하귀모 · 초광역 공격과 둔화", "art": 10},
	206: {"name": "주유", "faction": 2, "rank": 5, "role": "적벽의 화신", "kind": "fire", "damage": 3800.0, "rate": 0.5, "range": 320.0, "skill": "진 적벽대화계 · 초광역 화염과 지속 피해", "art": 8},
	207: {"name": "손권", "faction": 2, "rank": 5, "role": "강동의 황제", "kind": "aura", "damage": 3200.0, "rate": 0.5, "range": 300.0, "skill": "강동천명 · 지휘 공격과 주변 아군 공격력 +20%", "art": 6},
	208: {"name": "육손", "faction": 2, "rank": 5, "role": "불꽃의 대도독", "kind": "fire", "damage": 4400.0, "rate": 0.65, "range": 330.0, "skill": "홍련이릉 · 초광역 화염과 지속 피해", "art": 11},
	40: {"name": "관평", "faction": 0, "rank": 1, "role": "창병", "kind": "melee", "damage": 48, "rate": 0.95, "range": 145.0, "skill": "근접전 · 단일 대상 공격", "art": 24},
	41: {"name": "주창", "faction": 0, "rank": 1, "role": "보조 무장", "kind": "melee", "damage": 48, "rate": 0.95, "range": 145.0, "skill": "근접전 · 단일 대상 공격", "art": 25},
	42: {"name": "미축", "faction": 0, "rank": 1, "role": "책사", "kind": "slow", "damage": 28, "rate": 0.95, "range": 180.0, "skill": "견제 · 적 이동 속도 35% 감소", "art": 26},
	43: {"name": "조홍", "faction": 1, "rank": 1, "role": "방패 무장", "kind": "melee", "damage": 48, "rate": 0.95, "range": 145.0, "skill": "근접전 · 단일 대상 공격", "art": 30},
	44: {"name": "이전", "faction": 1, "rank": 1, "role": "쇠뇌병", "kind": "rapid", "damage": 31, "rate": 0.65, "range": 195.0, "skill": "쇠뇌 사격 · 빠른 원거리 공격", "art": 31},
	45: {"name": "악진", "faction": 1, "rank": 1, "role": "무장", "kind": "melee", "damage": 48, "rate": 0.95, "range": 145.0, "skill": "선봉검 · 근접 단일 대상 공격", "art": 32},
	46: {"name": "주태", "faction": 2, "rank": 1, "role": "보조 무장", "kind": "melee", "damage": 48, "rate": 0.95, "range": 145.0, "skill": "근접전 · 단일 대상 공격", "art": 36},
	47: {"name": "한당", "faction": 2, "rank": 1, "role": "궁병", "kind": "rapid", "damage": 31, "rate": 0.65, "range": 195.0, "skill": "사격 · 빠른 원거리 공격", "art": 37},
	48: {"name": "정보", "faction": 2, "rank": 1, "role": "노장", "kind": "melee", "damage": 48, "rate": 0.95, "range": 145.0, "skill": "근접전 · 단일 대상 공격", "art": 38},
	300: {"name": "황충", "faction": 0, "rank": 2, "role": "노장", "kind": "rapid", "damage": 99, "rate": 0.52, "range": 225.0, "skill": "백보천양 · 빠른 장거리 사격", "art": 16},
	301: {"name": "마초", "faction": 0, "rank": 2, "role": "금마초", "kind": "cleave", "damage": 149, "rate": 0.85, "range": 170.0, "skill": "서량의 창 · 범위 베기", "art": 17},
	302: {"name": "장비", "faction": 0, "rank": 2, "role": "맹장", "kind": "stun", "damage": 161, "rate": 1.0, "range": 160.0, "skill": "장판교 · 매 4타 기절 1초", "art": 2},
	303: {"name": "하후돈", "faction": 1, "rank": 2, "role": "무장", "kind": "cleave", "damage": 170, "rate": 1.09, "range": 160.0, "skill": "독안의 일격 · 범위 베기", "art": 4},
	304: {"name": "허저", "faction": 1, "rank": 2, "role": "호위장", "kind": "stun", "damage": 180, "rate": 1.09, "range": 155.0, "skill": "호치 · 매 4타 기절", "art": 19},
	305: {"name": "전위", "faction": 1, "rank": 2, "role": "악래", "kind": "cleave", "damage": 136, "rate": 0.76, "range": 160.0, "skill": "쌍극 · 빠른 범위 베기", "art": 20},
	306: {"name": "태사자", "faction": 2, "rank": 2, "role": "선봉장", "kind": "rapid", "damage": 112, "rate": 0.57, "range": 205.0, "skill": "쌍창 · 빠른 원거리 공격", "art": 21},
	307: {"name": "황개", "faction": 2, "rank": 2, "role": "노장", "kind": "fire", "damage": 124, "rate": 1.04, "range": 190.0, "skill": "고육계 · 작은 범위 화염", "art": 22},
	308: {"name": "능통", "faction": 2, "rank": 2, "role": "돌격장", "kind": "stun", "damage": 133, "rate": 0.76, "range": 160.0, "skill": "강동의 칼 · 매 4타 기절", "art": 23},
}
const FACTIONS = ["촉", "위", "오"]
const COLORS = [Color("72bc96"), Color("82a9de"), Color("ed9a75")]
const RANKS = ["흔함", "안흔함", "희귀", "전설", "히든", "초월"]
const RANK_COLORS = [Color("f8f9fa"), Color("52b788"), Color("48cae4"), Color("c77dff"), Color("ffb703"), Color("ff728b")]
const SUMMON_IDS = [24,25,26,30,31,32,36,37,38]
const SUMMON_POOLS = [[24,25,26,30,31,32,36,37,38],[2,4,16,17,19,20,21,22,23,40,41,42,43,44,45,46,47,48],[0,1,3,6,7,18,300,301,302,303,304,305,306,307,308]]
const MAX_LUCK_LEVEL = 10
# Each recipe is shown only on its explicit base officer, never on support ingredients.
# ORD 4.1 reference: two early branches, repeated-unit growth, mixed-grade support recipes.
const RECIPES = [
	{"result":16,"base":24,"materials":[[24,1],[26,1],[37,1]]},
	{"result":17,"base":25,"materials":[[25,1],[24,1]]},
	{"result":2,"base":38,"materials":[[38,1],[25,1]]},
	{"result":4,"base":36,"materials":[[36,1],[30,1]]},
	{"result":19,"base":30,"materials":[[30,1],[38,1]]},
	{"result":20,"base":32,"materials":[[32,1],[31,1]]},
	{"result":21,"base":37,"materials":[[37,1],[36,1]]},
	{"result":22,"base":26,"materials":[[26,1],[38,1]]},
	{"result":23,"base":31,"materials":[[31,1],[36,1]]},
	{"result":40,"base":24,"materials":[[24,3]]},
	{"result":41,"base":25,"materials":[[25,3]]},
	{"result":42,"base":26,"materials":[[26,3]]},
	{"result":43,"base":30,"materials":[[30,3]]},
	{"result":44,"base":31,"materials":[[31,3]]},
	{"result":45,"base":32,"materials":[[32,3]]},
	{"result":46,"base":36,"materials":[[36,3]]},
	{"result":47,"base":37,"materials":[[37,3]]},
	{"result":48,"base":38,"materials":[[38,3]]},
	{"result":0,"base":16,"materials":[[16,1],[2,1],[26,1]]},
	{"result":1,"base":17,"materials":[[17,1],[2,1],[25,1]]},
	{"result":3,"base":4,"materials":[[4,1],[19,1],[32,1]]},
	{"result":18,"base":19,"materials":[[20,1],[19,1],[31,1]]},
	{"result":6,"base":21,"materials":[[21,1],[22,1],[38,1]]},
	{"result":7,"base":23,"materials":[[23,1],[22,1],[37,1]]},
	{"result":300,"base":40,"materials":[[40,1],[16,1],[30,1]]},
	{"result":301,"base":41,"materials":[[41,1],[17,1],[31,1]]},
	{"result":302,"base":42,"materials":[[42,1],[2,1],[32,1]]},
	{"result":303,"base":43,"materials":[[43,1],[4,1],[36,1]]},
	{"result":304,"base":44,"materials":[[44,1],[19,1],[37,1]]},
	{"result":305,"base":45,"materials":[[45,1],[20,1],[38,1]]},
	{"result":306,"base":46,"materials":[[46,1],[21,1],[24,1]]},
	{"result":307,"base":47,"materials":[[47,1],[22,1],[25,1]]},
	{"result":308,"base":48,"materials":[[48,1],[23,1],[26,1]]},
	{"result":9,"base":0,"materials":[[0,1],[1,1],[300,1]]},
	{"result":10,"base":3,"materials":[[3,1],[18,1],[303,1]]},
	{"result":11,"base":6,"materials":[[6,1],[7,1],[306,1]]},
	{"result":15,"base":9,"materials":[[9,1],[301,1],[302,1]]},
	{"result":5,"base":304,"materials":[[10,1],[304,1],[305,1]]},
	{"result":8,"base":11,"materials":[[11,1],[307,1],[308,1]]},
	{"result":100,"base":18,"materials":[[18,1],[10,1],[303,1]]},
	{"result":101,"base":1,"materials":[[1,1],[9,1],[300,1]]},
	{"result":102,"base":7,"materials":[[7,1],[11,1],[306,1]]},
	{"result":200,"base":15,"materials":[[15,1],[9,1],[16,1]]},
	{"result":201,"base":101,"materials":[[101,1],[9,1],[302,1]]},
	{"result":202,"base":9,"materials":[[9,2],[15,1],[26,1]]},
	{"result":203,"base":100,"materials":[[100,1],[10,1],[19,1]]},
	{"result":204,"base":5,"materials":[[5,1],[10,1],[304,1]]},
	{"result":205,"base":10,"materials":[[10,2],[100,1],[31,1]]},
	{"result":206,"base":8,"materials":[[8,1],[11,1],[22,1]]},
	{"result":207,"base":102,"materials":[[102,1],[11,1],[306,1]]},
	{"result":208,"base":11,"materials":[[11,2],[8,1],[38,1]]},
]
static func all_recipes() -> Array:
	return RECIPES.duplicate(true)
static func recipe_for(id:int) -> Dictionary:
	for recipe in RECIPES:
		if recipe.result==id:return recipe
	return {}
static func title(id:int) -> String:
	return RANKS[data(id).rank]+" "+data(id).name
static func art_id(id:int) -> int:
	return data(id).get("art",id)
static func summon_odds(luck_level:int=0) -> Array:
	var level:=clampi(luck_level,0,MAX_LUCK_LEVEL)
	return [8000-level*130,1700+level*100,300+level*30]
static func summon_rank(roll:int, luck_level:int=0) -> int:
	var odds:=summon_odds(luck_level)
	if roll<odds[0]:return 0
	if roll<odds[0]+odds[1]:return 1
	return 2
static func data(id:int) -> Dictionary:
	return DATA[id]
static func stats(unit:Dictionary, upgrade:int) -> Dictionary:
	var base:Dictionary=data(unit.id)
	return {"damage":base.damage*(1.0+upgrade*.12),"range":base.range,"rate":base.rate,"kind":base.kind}
static func material_cost(id:int) -> int:
	if data(id).rank==0:return 35
	var cost:=0
	for material in recipe_for(id).materials:cost+=material_cost(material[0])*material[1]
	return cost
static func sell_value(id:int) -> int:
	return int(floor(material_cost(id)*.7))
