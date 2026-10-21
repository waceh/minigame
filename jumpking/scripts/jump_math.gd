extends RefCounted

const MAX_CHARGE := 0.85
const MIN_SPEED := 380.0
const MAX_SPEED := 690.0

static func launch_speed(seconds: float) -> float:
	return lerpf(MIN_SPEED, MAX_SPEED, clampf(seconds / MAX_CHARGE, 0.0, 1.0))
