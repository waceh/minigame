extends Control

signal changed(steer: float)

var value := 0.0
var touch_id := -1
var mouse_held := false

func steer_from_position(local_position: Vector2) -> float:
	var radius := minf(size.x, size.y) * 0.36
	if radius <= 0.0:
		return 0.0
	var horizontal := clampf((local_position.x - size.x * 0.5) / radius, -1.0, 1.0)
	return 0.0 if absf(horizontal) < 0.12 else horizontal

func _set_steer(local_position: Vector2) -> void:
	value = steer_from_position(local_position)
	changed.emit(value)
	queue_redraw()

func _release() -> void:
	value = 0.0
	changed.emit(value)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and touch_id == -1:
			touch_id = event.index
			_set_steer(event.position)
			accept_event()
		elif not event.pressed and event.index == touch_id:
			touch_id = -1
			_release()
			accept_event()
	elif event is InputEventScreenDrag and event.index == touch_id:
		_set_steer(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and touch_id == -1:
		mouse_held = event.pressed
		if mouse_held:
			_set_steer(event.position)
		else:
			_release()
		accept_event()
	elif event is InputEventMouseMotion and mouse_held:
		_set_steer(event.position)
		accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		touch_id = -1
		mouse_held = false
		_release()

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.36
	draw_circle(center, radius + 12.0, Color(0.05, 0.13, 0.27, 0.78))
	draw_arc(center, radius, 0.0, TAU, 64, Color(0.36, 0.82, 1.0, 0.75), 3.0, true)
	draw_line(center + Vector2(-radius * 0.65, 0), center + Vector2(radius * 0.65, 0), Color(0.36, 0.82, 1.0, 0.28), 2.0)
	var knob := center + Vector2(value * radius, 0)
	draw_circle(knob, radius * 0.42, Color("9eeeff"))
	draw_circle(knob, radius * 0.25, Color("2a83ad"))
