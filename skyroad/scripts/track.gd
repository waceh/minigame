extends RefCounted

enum Tile { GAP, ROAD, FUEL, OXYGEN, HAZARD, BOOST }

const LENGTHS = [384, 432, 480]
const NAMES = ["성운 산책로", "유성 지대", "푸른 성단"]
const GRAVITY = [18.0, 21.0, 24.0]
const LAUNCH_ROWS = [24, 38, 40]
const LANDING_ROWS = [92, 96, 90]
const OLD_LANDING_ROWS = [44, 54, 56]
const SKY_GAP_ENDS = [91, 95, 89]

func level_count() -> int:
	return LENGTHS.size()

func length(level: int) -> int:
	return LENGTHS[clampi(level, 0, LENGTHS.size() - 1)]

func tile_at(level: int, row: int, lane: int) -> int:
	if level < 0 or level >= level_count() or row < 0 or row >= length(level) or lane < 0 or lane > 4:
		return Tile.GAP
	if row < 7 or row >= length(level) - 5:
		return Tile.ROAD
	if row == LAUNCH_ROWS[level]:
		return Tile.BOOST
	if row >= LAUNCH_ROWS[level] + 2 and row <= SKY_GAP_ENDS[level]:
		return Tile.GAP
	if row >= LANDING_ROWS[level] and row <= LANDING_ROWS[level] + 5:
		return Tile.ROAD
	var challenge_start: int = LANDING_ROWS[level] + 32
	if row >= challenge_start and row < length(level) - 8:
		return _challenge_tile(level, row - challenge_start, lane)
	if row > LANDING_ROWS[level] + 5:
		row -= LANDING_ROWS[level] - OLD_LANDING_ROWS[level]
	if level == 0:
		if row in [11, 12] and lane in [2, 3]:
			return Tile.GAP
		if row in [17, 18] and lane in [0, 1, 4]:
			return Tile.GAP
		if row == 23 and lane == 2:
			return Tile.FUEL
		if row == 52 and lane == 1:
			return Tile.OXYGEN
		if row in [20, 53] and lane == 3:
			return Tile.HAZARD
	elif level == 1:
		if row in [12, 13, 31, 32] and lane in [1, 2, 3]:
			return Tile.GAP
		if row in [22, 23, 59, 60] and lane in [0, 4]:
			return Tile.GAP
		if row == 19 and lane == 2:
			return Tile.OXYGEN
		if row == 37 and lane == 2:
			return Tile.FUEL
		if row in [25, 63] and lane in [1, 3]:
			return Tile.HAZARD
	else:
		if row in [13, 14, 34, 35] and lane in [0, 1, 2, 3, 4]:
			return Tile.GAP
		if row in [24, 25, 66, 67] and lane in [0, 1, 4]:
			return Tile.GAP
		if row in [20, 64] and lane == 2:
			return Tile.FUEL
		if row in [29, 63] and lane == 2:
			return Tile.OXYGEN
		if row in [31, 71] and lane == 2:
			return Tile.HAZARD
	return Tile.ROAD

func _challenge_tile(level: int, offset: int, lane: int) -> int:
	var section := int(offset / 24)
	var section_row := offset % 24
	var span: int = length(level) - 8 - LANDING_ROWS[level] - 32
	var difficulty := mini(2, int(offset * 3 / span))
	if section_row == 20:
		return Tile.FUEL if section % 2 == 0 else Tile.OXYGEN
	if section_row >= 5 and section_row <= 6 + int(difficulty > 0):
		if difficulty == 2:
			return Tile.GAP
		if difficulty == 1 and lane != section % 5 and lane != (section + 1) % 5:
			return Tile.GAP
		if difficulty == 0 and lane in [(section + 1) % 5, (section + 3) % 5]:
			return Tile.GAP
	if section_row == 14 or (difficulty > 0 and section_row == 15):
		if difficulty == 0 and lane == (section + 2) % 5:
			return Tile.HAZARD
		if difficulty == 1 and lane in [(section + 1) % 5, (section + 3) % 5]:
			return Tile.HAZARD
		if difficulty == 2 and lane != section % 5 and lane != (section + 1) % 5:
			return Tile.HAZARD
	return Tile.ROAD
