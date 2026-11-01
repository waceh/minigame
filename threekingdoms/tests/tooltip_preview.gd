extends SceneTree
var game
var ticks:=0
func _initialize() -> void:call_deferred("prepare")
func prepare() -> void:
	game=load("res://main.tscn").instantiate();game.persist=false;root.add_child(game);game.set_process(false);game.reset_game()
	game.units=[game.make_unit(24,0,0),game.make_unit(24,0,1),game.make_unit(24,0,2)];game.selected=0;game.selected_slots=[0];game.refresh()
	var button:Button=game.selection_recipes.cells[5]
	var tooltip:Control=button._make_custom_tooltip(button.tooltip_text);game.ui.add_child(tooltip);tooltip.position=Vector2(790,328)
func _process(_dt:float) -> bool:
	ticks+=1
	if ticks==25:root.get_texture().get_image().save_png("/private/tmp/threekingdoms-tooltip.png");quit()
	return false
