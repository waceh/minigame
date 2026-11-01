extends SceneTree
var checked:=0
func _initialize() -> void:call_deferred("run_tests")
func check_buttons(node:Node) -> void:
	if node is Button and node.has_meta("layout_rect"):
		var intended:Rect2=node.get_meta("layout_rect")
		assert(node.size.is_equal_approx(intended.size),"button expanded beyond its assigned rectangle: "+node.text)
		assert(node.position.is_equal_approx(intended.position),"button moved outside its assigned rectangle: "+node.text)
		checked+=1
	for child in node.get_children():check_buttons(child)
func check_hud(game) -> void:
	var buttons:Array=[game.summon_button,game.recipe_button,game.attack_cmd_button,game.hold_cmd_button]
	for i in range(buttons.size()):
		var button:Button=buttons[i]
		assert(Rect2(Vector2.ZERO,button.get_parent().size).grow(-8).encloses(button.get_rect()),"command must stay inside the frame with padding")
		for j in range(i):assert(not button.get_global_rect().intersects(buttons[j].get_global_rect()),"HUD commands must not overlap")
		var text_size:Vector2=button.get_theme_font("font").get_multiline_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,button.get_theme_font_size("font_size"))
		var available:Vector2=button.size-button.get_theme_stylebox("normal").get_minimum_size()
		assert(text_size.x<=available.x+1 and text_size.y<=available.y+1,"command label must fit without clipping: "+button.text)
	check_buttons(game.ui)
func run_tests() -> void:
	var game=load("res://main.tscn").instantiate();game.persist=false;root.add_child(game);game.set_process(false);game.reset_game()
	await process_frame;await process_frame
	check_hud(game)
	game.units=[game.make_unit(203,5,0)];game.selected=0;game.selected_slots=[0];game.gold=100000;game.upgrade=10;game.luck_level=10;game.refresh()
	await process_frame
	check_hud(game)
	game.start_wave();game.refresh();await process_frame;check_hud(game)
	game.open_crafting();await process_frame;check_buttons(game.codex)
	game.codex.mode=1;game.codex.rebuild();await process_frame;check_buttons(game.codex)
	game.close_modals();game.open_headquarters();await process_frame;check_buttons(game.headquarters)
	game.free();print("HUD layout: PASS — %d button rectangles, no overlaps or frame overflow, labels fit, changing states, crafting, codex and upgrades"%checked);quit()
