extends SceneTree
var ticks:=0
var game
func _initialize() -> void:call_deferred("prepare")
func prepare() -> void:
	game=load("res://main.tscn").instantiate();game.persist=false;root.add_child(game);game.reset_game();game.rng.seed=245
	var ids:=[24,25,26,30,31,32,36,37,38,16,17,2,4,19,20,21,22,23,0,1,3,18,6,7,9,10,11,15,5,8]
	for i in range(ids.size()):
		var u:Dictionary=game.make_unit(ids[i],0,i);u.pos=Vector2(170+(i%6)*115+sin(i)*12,290+(i/6)*76+cos(i)*9);u.target=u.pos;game.units.append(u)
	game.selected=27;game.selected_slots=[27,28,29];game.gold=265;game.wave=14;game.start_wave();game.spawn_left=20
	for i in range(20):
		game.spawn_enemy();game.enemies[-1].distance=i*115.0
	game.spawn_left=5;game.set_process(false);game.refresh();game.queue_redraw()
func _process(_dt:float) -> bool:
	ticks+=1
	if ticks==25:
		root.get_texture().get_image().save_png("/private/tmp/threekingdoms-preview.png")
		game.open_book();game.codex.search.text="사마의";game.codex.rebuild()
	if ticks==50:
		root.get_texture().get_image().save_png("/private/tmp/threekingdoms-book.png");quit()
	return false
