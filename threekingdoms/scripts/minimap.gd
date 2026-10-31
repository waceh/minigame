extends Control
var game
func _process(_dt:float) -> void:queue_redraw()
func map_point(point:Vector2) -> Vector2:
	return Vector2(10,8)+(point-Vector2(52,180))*Vector2((size.x-20)/840.0,(size.y-16)/570.0)
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("122c25"))
	for i in range(7):
		var x:float=14+i*27
		draw_line(Vector2(x,8),Vector2(x-8,size.y-8),Color(.25,.4,.25,.25),4)
	var route:=PackedVector2Array()
	for p in game.PATH:route.append(map_point(p))
	draw_polyline(route,Color("94815b"),7,true)
	draw_polyline(route,Color("b4a477"),1,true)
	for e in game.enemies:draw_circle(map_point(game.path_pos(e.distance)),3.3 if e.boss else 1.8,Color("f18065"))
	for u in game.units:
		var p:=map_point(u.pos)
		draw_rect(Rect2(p-Vector2(2,2),Vector2(4,4)),Color("b8f388") if game.selected_slots.has(u.slot) else game.R.COLORS[game.R.data(u.id).faction])
	var field=game.battlefield
	var corners:=PackedVector2Array()
	for p in [field.position,field.position+Vector2(field.size.x,0),field.position+field.size,field.position+Vector2(0,field.size.y),field.position]:
		var point:=map_point(field.ground_point(p));point=point.clamp(Vector2(1,1),size-Vector2.ONE);corners.append(point)
	draw_polyline(corners,Color(.9,.89,.69,.75),1,true)
	draw_rect(Rect2(Vector2.ZERO,size),Color("6b7561"),false,1)
func _gui_input(event:InputEvent) -> void:
	if game.paused or game.codex_open or game.state not in ["build","battle"]:return
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		var point:Vector2=Vector2(52,180)+(event.position-Vector2(10,8))/Vector2((size.x-20)/840.0,(size.y-16)/570.0)
		var world:Vector3=game.battlefield.to_world(point)
		game.battlefield.focus=Vector3(clampf(world.x,-10,10),0,clampf(world.z,-8,8));game.battlefield.set_camera();accept_event()
