extends Node2D
var game
func _process(_dt:float) -> void:queue_redraw()
func _draw() -> void:
	if game and game.dragging and game.drag_start.distance_to(game.drag_now)>10:
		var rect:=Rect2(game.drag_start,game.drag_now-game.drag_start).abs()
		draw_rect(rect,Color(.4,.9,.5,.12));draw_rect(rect,Color("99e3a6"),false,1.5)
