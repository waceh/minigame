extends Control
var game: Node3D
func _process(_dt: float) -> void:queue_redraw()
func _draw() -> void:
	if not is_instance_valid(game) or game.state in ["menu","finished"]:return
	var rect:=Rect2(Vector2(5,5),size-Vector2(10,10))
	draw_style_box(_panel(),Rect2(Vector2.ZERO,size))
	draw_rect(rect,Color(.55,.7,.72,.5),false,1)
	var center:=size/2
	draw_line(Vector2(center.x,5),Vector2(center.x,size.y-5),Color(.6,.75,.75,.35),1)
	draw_arc(center,rect.size.y*.13,0,TAU,24,Color(.6,.75,.75,.35),1)
	for p in game.players:
		var point:=rect.position+Vector2((p.position.x+52.5)/105,(p.position.z+34)/68)*rect.size
		draw_circle(point,2.4,Color("5db9ff") if p.team==0 else Color("f48780"))
		if p==game.players[game.controlled]:draw_arc(point,4.3,0,TAU,12,Color("eff9ff"),1.2)
	var ball:Vector3=game.ball_position
	draw_circle(rect.position+Vector2((ball.x+52.5)/105,(ball.z+34)/68)*rect.size,2,Color.WHITE)
func _panel() -> StyleBoxFlat:
	var s:=StyleBoxFlat.new();s.bg_color=Color(.025,.06,.09,.82);s.set_corner_radius_all(4);return s
