extends SceneTree
func _initialize() -> void:call_deferred("run_tests")
func run_tests() -> void:
	var game=load("res://main.tscn").instantiate();game.persist=false;root.add_child(game);game.set_process(false)
	game.reset_game()
	var field=game.battlefield
	var common_frames:Array=[]
	for id in game.R.SUMMON_IDS:
		var art:Array=field.art_for(id)
		var key:String=art[3]+":"+str(art[1])
		assert(not common_frames.has(key),"common officers must each have a unique face and equipment row")
		common_frames.append(key)
	assert(game.R.data(32).role=="무장" and game.R.data(32).kind=="melee","Yue Jin must be a military melee warrior")
	for id in game.R.DATA.keys()+[-1,-2]:
		var art:Array=field.art_for(id)
		assert(art[3]=="commanders.png" or art[3].begins_with("chibi-"),"all troops must use the cute atlas family")
		for frame in range(4):
			var texture:Texture2D=field.frame_texture(id,frame)
			var meta:Dictionary=field.frame_meta(id,frame)
			var r:Array=meta.rect
			var region:=Rect2(r[0],r[1],r[2],r[3])
			assert(Rect2(Vector2.ZERO,art[0].get_size()).encloses(region),"sprite region must stay inside the original atlas")
			assert(texture.get_size()==region.size and texture.get_image().has_mipmaps(),"each frame needs isolated mipmaps to avoid neighboring frame bleed")
			assert(meta.scale_height>0 and region.size.x>20 and region.size.y>20)
			assert(meta.anchor[0]>=region.position.x and meta.anchor[0]<=region.end.x)
			assert(meta.anchor[1]>=region.position.y and meta.anchor[1]<=region.end.y)
		assert(field.portrait_texture(id).region.size.y>20)
	game.free();print("artwork: PASS — all 60 grade-specific heroes and enemies use chibi sprites, valid regions, foot anchors and portraits");quit()
