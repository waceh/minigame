extends SceneTree
func _initialize() -> void:call_deferred("run_tests")
func run_tests() -> void:
	var game=load("res://main.tscn").instantiate();game.persist=false;root.add_child(game);game.set_process(false)
	game.reset_game()
	var field=game.battlefield
	for id in game.R.DATA.keys()+[-1,-2]:
		var art:Array=field.art_for(id)
		assert(art[3]=="commanders.png" or art[3].begins_with("chibi-"),"all troops must use the cute atlas family")
		for frame in range(4):
			var texture:AtlasTexture=field.frame_texture(id,frame)
			var meta:Dictionary=field.frame_meta(id,frame)
			assert(Rect2(Vector2.ZERO,texture.atlas.get_size()).encloses(texture.region),"sprite region must stay inside the original atlas")
			assert(meta.scale_height>0 and texture.region.size.x>20 and texture.region.size.y>20)
			assert(meta.anchor[0]>=texture.region.position.x and meta.anchor[0]<=texture.region.end.x)
			assert(meta.anchor[1]>=texture.region.position.y and meta.anchor[1]<=texture.region.end.y)
		assert(field.portrait_texture(id).region.size.y>20)
	game.free();print("artwork: PASS — all 30 heroes and enemies use chibi sprites, valid regions, foot anchors and portraits");quit()
