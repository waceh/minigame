extends SceneTree

const Track = preload("res://scripts/track.gd")

func _initialize() -> void:
	var track = Track.new()
	assert(track.level_count() == 3)
	assert(track.length(0) == 384)
	assert(track.length(1) == 432)
	assert(track.length(2) == 480)
	assert(track.tile_at(0, 0, 2) == Track.Tile.ROAD)
	assert(track.tile_at(0, 11, 2) == Track.Tile.GAP)
	assert(track.tile_at(0, 11, 1) == Track.Tile.ROAD)
	assert(track.tile_at(0, -1, 2) == Track.Tile.GAP)
	assert(track.tile_at(0, track.length(0), 2) == Track.Tile.GAP)
	assert(track.tile_at(0, 23, 2) == Track.Tile.FUEL)
	assert(track.tile_at(0, 100, 1) == Track.Tile.OXYGEN)
	assert(track.tile_at(1, 19, 2) == Track.Tile.OXYGEN)
	assert(track.tile_at(2, 31, 2) == Track.Tile.HAZARD)
	for level in range(track.level_count()):
		var launch_row: int = Track.LAUNCH_ROWS[level]
		for lane in range(5):
			assert(track.tile_at(level, launch_row, lane) == Track.Tile.BOOST)
			assert(track.tile_at(level, launch_row + 3, lane) == Track.Tile.GAP)
			assert(track.tile_at(level, Track.LANDING_ROWS[level] - 1, lane) == Track.Tile.GAP)
			assert(track.tile_at(level, Track.LANDING_ROWS[level], lane) == Track.Tile.ROAD)
		var challenge_start: int = Track.LANDING_ROWS[level] + 32
		var challenge_span: int = track.length(level) - 8 - challenge_start
		var middle_row: int = challenge_start + int(challenge_span / 48) * 24 + 5
		var late_row: int = challenge_start + int(challenge_span * 5 / 144) * 24 + 5
		var early_gaps := 0
		var middle_gaps := 0
		var late_gaps := 0
		for lane in range(5):
			early_gaps += int(track.tile_at(level, challenge_start + 5, lane) == Track.Tile.GAP)
			middle_gaps += int(track.tile_at(level, middle_row, lane) == Track.Tile.GAP)
			late_gaps += int(track.tile_at(level, late_row, lane) == Track.Tile.GAP)
			assert(track.tile_at(level, challenge_start + 20, lane) == Track.Tile.FUEL)
			assert(track.tile_at(level, challenge_start + 44, lane) == Track.Tile.OXYGEN)
			assert(track.tile_at(level, late_row + 1, lane) == Track.Tile.GAP)
			assert(track.tile_at(level, late_row + 2, lane) == Track.Tile.GAP)
		assert(early_gaps == 2)
		assert(middle_gaps == 3)
		assert(late_gaps == 5)
	print("track_test: PASS")
	quit()
