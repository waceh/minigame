extends SceneTree

const Track = preload("res://scripts/track.gd")

func _initialize() -> void:
	var track = Track.new()
	assert(track.level_count() == 3)
	assert(track.tile_at(0, 0, 2) == Track.Tile.ROAD)
	assert(track.tile_at(0, 11, 2) == Track.Tile.GAP)
	assert(track.tile_at(0, 11, 1) == Track.Tile.ROAD)
	assert(track.tile_at(0, -1, 2) == Track.Tile.GAP)
	assert(track.tile_at(0, track.length(0), 2) == Track.Tile.GAP)
	assert(track.tile_at(0, 23, 2) == Track.Tile.FUEL)
	assert(track.tile_at(1, 19, 2) == Track.Tile.OXYGEN)
	assert(track.tile_at(2, 31, 2) == Track.Tile.HAZARD)
	print("track_test: PASS")
	quit()
