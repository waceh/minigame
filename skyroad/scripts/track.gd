extends RefCounted

enum Tile { GAP, ROAD, FUEL, OXYGEN, HAZARD, BOOST }

const LENGTHS = [64, 72, 80]
const NAMES = ["성운 산책로", "유성 지대", "푸른 성단"]
const GRAVITY = [18.0, 21.0, 24.0]

func level_count() -> int:
	return LENGTHS.size()

func length(level: int) -> int:
	return LENGTHS[clampi(level, 0, LENGTHS.size() - 1)]

func tile_at(level: int, row: int, lane: int) -> int:
	if level < 0 or level >= level_count() or row < 0 or row >= length(level) or lane < 0 or lane > 4:
		return Tile.GAP
	if row < 7 or row >= length(level) - 5:
		return Tile.ROAD
	if level == 0:
		if row in [11, 12, 29, 30, 47, 48] and lane in [2, 3]:
			return Tile.GAP
		if row in [17, 18, 38, 39] and lane in [0, 1, 4]:
			return Tile.GAP
		if row == 23 and lane == 2:
			return Tile.FUEL
		if row == 43 and lane == 1:
			return Tile.OXYGEN
		if row in [20, 35, 53] and lane == 3:
			return Tile.HAZARD
		if row == 56 and lane == 2:
			return Tile.BOOST
	elif level == 1:
		if row in [12, 13, 31, 32, 50, 51] and lane in [1, 2, 3]:
			return Tile.GAP
		if row in [22, 23, 41, 42, 59, 60] and lane in [0, 4]:
			return Tile.GAP
		if row == 19 and lane == 2:
			return Tile.OXYGEN
		if row == 37 and lane == 2:
			return Tile.FUEL
		if row in [25, 46, 63] and lane in [1, 3]:
			return Tile.HAZARD
		if row == 55 and lane == 2:
			return Tile.BOOST
	else:
		if row in [13, 14, 34, 35, 57, 58] and lane in [0, 1, 2, 3, 4]:
			return Tile.GAP
		if row in [24, 25, 45, 46, 66, 67] and lane in [0, 1, 4]:
			return Tile.GAP
		if row in [20, 49] and lane == 2:
			return Tile.FUEL
		if row in [29, 62] and lane == 2:
			return Tile.OXYGEN
		if row in [31, 52, 71] and lane == 2:
			return Tile.HAZARD
		if row == 40 and lane == 2:
			return Tile.BOOST
	return Tile.ROAD
