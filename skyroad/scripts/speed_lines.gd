extends Control

var intensity := 0.0
var motion := 0.0

func _draw() -> void:
	if intensity <= 0.01:
		return
	var center := size * Vector2(0.5, 0.48)
	var radius := size.length()
	for i in range(44):
		var angle := TAU * (float(i) + 0.23 * sin(float(i) * 13.1)) / 44.0
		var direction := Vector2(cos(angle), sin(angle))
		var phase := fposmod(motion * (0.6 + float(i % 5) * 0.13) + float(i) * 91.7, radius * 0.55)
		var start := center + direction * (radius * 0.18 + phase)
		var finish := start + direction * (32.0 + 95.0 * intensity)
		draw_line(start, finish, Color(0.55, 0.9, 1.0, 0.12 + 0.31 * intensity), 1.0 + 2.0 * intensity, true)
