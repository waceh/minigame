extends SceneTree
var ticks:=0
var game
func _initialize() -> void:call_deferred("prepare")
func prepare() -> void:
	game=load("res://main.tscn").instantiate();game.persist=false;root.add_child(game);game.reset_game()
	var ids:=[24,25,26,30,31,32,36,37,38]
	for i in range(ids.size()):
		var unit:Dictionary=game.make_unit(ids[i],0,i)
		unit.pos=Vector2(300+(i/3)*190,300+(i%3)*140);unit.target=unit.pos
		game.units.append(unit);game.selected_slots.append(i)
	game.selected=5;game.gold=300;game.set_process(false);game.refresh()
func _process(_dt:float) -> bool:
	ticks+=1
	if ticks==25:
		game.paused=false;game.refresh()
		root.get_texture().get_image().save_png("/private/tmp/threekingdoms-common-review.png")
	if ticks==40:
		game.selected_slots=[5];game.refresh()
	if ticks==55:
		root.get_texture().get_image().save_png("/private/tmp/threekingdoms-yuejin-review.png");quit()
	return false
