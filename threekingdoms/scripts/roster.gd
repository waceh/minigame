extends RefCounted
# A historical name is assigned to exactly one tier. Stats are absolute, not rank multipliers.
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
	24: {"name": "관평", "faction": 0, "rank": 0, "role": "보조 무장", "kind": "melee", "damage": 17.0, "rate": 1.0, "range": 130.0, "skill": "근접전 · 단일 대상 공격"},
	25: {"name": "주창", "faction": 0, "rank": 0, "role": "보조 무장", "kind": "melee", "damage": 17.0, "rate": 1.0, "range": 130.0, "skill": "근접전 · 단일 대상 공격"},
	26: {"name": "미축", "faction": 0, "rank": 0, "role": "책사", "kind": "slow", "damage": 10.0, "rate": 1.0, "range": 165.0, "skill": "견제 · 적 이동 속도 35% 감소"},
	27: {"name": "간옹", "faction": 0, "rank": 0, "role": "책사", "kind": "slow", "damage": 10.0, "rate": 1.0, "range": 165.0, "skill": "견제 · 적 이동 속도 35% 감소"},
	28: {"name": "요화", "faction": 0, "rank": 0, "role": "보조 무장", "kind": "melee", "damage": 17.0, "rate": 1.0, "range": 130.0, "skill": "근접전 · 단일 대상 공격"},
	29: {"name": "마대", "faction": 0, "rank": 0, "role": "보조 무장", "kind": "melee", "damage": 17.0, "rate": 1.0, "range": 130.0, "skill": "근접전 · 단일 대상 공격"},
	30: {"name": "조홍", "faction": 1, "rank": 0, "role": "보조 무장", "kind": "melee", "damage": 17.0, "rate": 1.0, "range": 130.0, "skill": "근접전 · 단일 대상 공격"},
	31: {"name": "이전", "faction": 1, "rank": 0, "role": "궁병", "kind": "rapid", "damage": 11.0, "rate": 0.68, "range": 180.0, "skill": "사격 · 빠른 원거리 공격"},
	32: {"name": "악진", "faction": 1, "rank": 0, "role": "책사", "kind": "slow", "damage": 10.0, "rate": 1.0, "range": 165.0, "skill": "견제 · 적 이동 속도 35% 감소"},
	33: {"name": "우금", "faction": 1, "rank": 0, "role": "보조 무장", "kind": "melee", "damage": 17.0, "rate": 1.0, "range": 130.0, "skill": "근접전 · 단일 대상 공격"},
	34: {"name": "문빙", "faction": 1, "rank": 0, "role": "보조 무장", "kind": "melee", "damage": 17.0, "rate": 1.0, "range": 130.0, "skill": "근접전 · 단일 대상 공격"},
	35: {"name": "만총", "faction": 1, "rank": 0, "role": "책사", "kind": "slow", "damage": 10.0, "rate": 1.0, "range": 165.0, "skill": "견제 · 적 이동 속도 35% 감소"},
	36: {"name": "주태", "faction": 2, "rank": 0, "role": "보조 무장", "kind": "melee", "damage": 17.0, "rate": 1.0, "range": 130.0, "skill": "근접전 · 단일 대상 공격"},
	37: {"name": "한당", "faction": 2, "rank": 0, "role": "궁병", "kind": "rapid", "damage": 11.0, "rate": 0.68, "range": 180.0, "skill": "사격 · 빠른 원거리 공격"},
	38: {"name": "정보", "faction": 2, "rank": 0, "role": "보조 무장", "kind": "melee", "damage": 17.0, "rate": 1.0, "range": 130.0, "skill": "근접전 · 단일 대상 공격"},
	39: {"name": "서성", "faction": 2, "rank": 0, "role": "보조 무장", "kind": "melee", "damage": 17.0, "rate": 1.0, "range": 130.0, "skill": "근접전 · 단일 대상 공격"},
	40: {"name": "반장", "faction": 2, "rank": 0, "role": "보조 무장", "kind": "melee", "damage": 17.0, "rate": 1.0, "range": 130.0, "skill": "근접전 · 단일 대상 공격"},
	41: {"name": "진무", "faction": 2, "rank": 0, "role": "보조 무장", "kind": "melee", "damage": 17.0, "rate": 1.0, "range": 130.0, "skill": "근접전 · 단일 대상 공격"},
}
const FACTIONS = ["촉", "위", "오"]
const COLORS = [Color("72bc96"), Color("82a9de"), Color("ed9a75")]
const RANKS = ["흔함", "안흔함", "희귀", "전설", "신화"]
const RANK_COLORS = [Color("f8f9fa"), Color("52b788"), Color("48cae4"), Color("c77dff"), Color("ffb703")]
const SUMMON_IDS = [24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41]
const PROMOTIONS = {24: 16, 25: 16, 26: 17, 27: 17, 28: 2, 29: 2, 30: 4, 31: 4, 32: 19, 33: 19, 34: 20, 35: 20, 36: 21, 37: 21, 38: 22, 39: 22, 40: 23, 41: 23, 16: 0, 17: 1, 2: 1, 4: 3, 19: 18, 20: 18, 21: 6, 22: 7, 23: 7}
const CRAFTS = [
	{"result":9,"materials":[[0,1],[1,1]]},
	{"result":10,"materials":[[3,1],[18,1]]},
	{"result":11,"materials":[[6,1],[7,1]]},
	{"result":15,"materials":[[9,1],[0,1],[16,2],[29,1]]},
	{"result":5,"materials":[[10,1],[3,1],[4,2],[30,1]]},
	{"result":8,"materials":[[11,1],[6,1],[22,2],[36,1]]},
]
static func all_recipes() -> Array:
	var result:Array=[]
	for id in PROMOTIONS:
		result.append({"result":PROMOTIONS[id],"materials":[[id,3]],"type":"승급"})
	for start in [24,30,36]:
		for pair in range(3):
			var a:int=start+pair*2;var b:int=a+1
			result.append({"result":PROMOTIONS[a],"materials":[[a,2],[b,1]],"type":"혼합"})
			result.append({"result":PROMOTIONS[b],"materials":[[a,1],[b,2]],"type":"혼합"})
	for recipe in [
		{"result":0,"materials":[[16,1],[2,1],[24,2]]},
		{"result":1,"materials":[[17,1],[2,1],[25,2]]},
		{"result":3,"materials":[[4,1],[19,1],[30,2]]},
		{"result":18,"materials":[[20,1],[19,1],[32,2]]},
		{"result":6,"materials":[[21,1],[22,1],[36,2]]},
		{"result":7,"materials":[[23,1],[22,1],[37,2]]},
		{"result":9,"materials":[[0,1],[17,2],[26,1]]},
		{"result":10,"materials":[[3,1],[19,2],[35,1]]},
		{"result":11,"materials":[[6,1],[21,2],[41,1]]},
		{"result":15,"materials":[[9,1],[1,1],[17,1],[2,1],[24,1]]},
		{"result":5,"materials":[[10,1],[18,1],[19,1],[20,1],[35,1]]},
		{"result":8,"materials":[[11,1],[7,1],[21,1],[23,1],[41,1]]}
	]:result.append(recipe)
	result.append_array(CRAFTS)
	return result
static func data(id:int) -> Dictionary:
	return DATA[id]
static func stats(unit:Dictionary, upgrade:int) -> Dictionary:
	var base:Dictionary=data(unit.id)
	return {"damage":base.damage*(1.0+upgrade*.12),"range":base.range,"rate":base.rate,"kind":base.kind}
static func material_cost(id:int) -> int:
	var rank:int=data(id).rank
	return [35,105,315,630,1190][rank]
static func sell_value(id:int) -> int:
	return int(floor(material_cost(id)*.7))
