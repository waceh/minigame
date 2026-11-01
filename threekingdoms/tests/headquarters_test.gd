extends SceneTree
func _initialize() -> void:call_deferred("run_tests")
func click(point:Vector2) -> void:
	var physical:Vector2=root.get_screen_transform()*point
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.position=physical;event.global_position=physical;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;Input.parse_input_event(event);await process_frame
func click_button(button:Button) -> void:
	await click(button.global_position+button.size/2)
func run_tests() -> void:
	var game=load("res://main.tscn").instantiate();game.persist=false;root.add_child(game);game.set_process(false);game.reset_game()
	assert(game.R.SUMMON_POOLS.map(func(pool):return pool.size())==[9,9,6])
	for level in [0,1,10]:
		var counts:=[0,0,0]
		for roll in range(10000):counts[game.R.summon_rank(roll,level)]+=1
		assert(counts==game.R.summon_odds(level) and counts.reduce(func(a,b):return a+b)==10000)
	assert(game.R.summon_odds(0)==[8000,1700,300] and game.R.summon_odds(10)==[6700,2700,600])
	game.gold=10000
	await process_frame;await process_frame
	await click(game.battlefield.screen_pos(game.HQ_POINT,1.6))
	assert(game.codex_open and game.headquarters.visible and not game.codex.visible)
	var gold:int=game.gold
	await click_button(game.headquarters.attack_button)
	assert(game.upgrade==1 and game.gold==gold-80)
	gold=game.gold
	await click_button(game.headquarters.luck_button)
	assert(game.luck_level==1 and game.gold==gold-60 and "18.0%" in game.headquarters.odds_info.text)
	assert("3.6%" in game.headquarters.next_info.text)
	for i in range(9):assert(game.train_luck())
	gold=game.gold;assert(not game.train_luck() and game.gold==gold and game.luck_level==10)
	game.close_modals();assert(not game.codex_open and not game.headquarters.visible)
	var key:=InputEventKey.new();key.physical_keycode=KEY_U;key.pressed=true;Input.parse_input_event(key);await process_frame
	assert(game.codex_open and game.headquarters.visible)
	key=InputEventKey.new();key.physical_keycode=KEY_ESCAPE;key.pressed=true;Input.parse_input_event(key);await process_frame
	assert(not game.codex_open and not game.headquarters.visible)
	game.gold=100000;game.rng.seed=2026
	var rarity_counts:=[0,0,0]
	for i in range(100):
		game.units.clear();assert(game.summon())
		var u:Dictionary=game.units[0];rarity_counts[u.rank]+=1
		assert(game.R.SUMMON_POOLS[u.rank].has(u.id) and u.rank<=2 and u.pos==game.SUMMON_POINT)
		assert(game.unit_sale_value(u)==24,"rare summons must not generate a sell/reroll money loop")
	assert(rarity_counts[0]>rarity_counts[1] and rarity_counts[1]>rarity_counts[2] and rarity_counts[2]>0)
	# Crafted resale follows actual invested gold, including cheap rare summons.
	game.units=[game.make_unit(4,1,0),game.make_unit(4,1,1),game.make_unit(4,1,2)]
	for u in game.units:u.investment=35
	game.selected=0;game.selected_slots=[0,1,2];assert(game.merge_selected())
	assert(game.units.size()==1 and game.units[0].id==3 and game.unit_sale_value(game.units[0])==73)
	game.paused=true;game.luck_level=0;gold=game.gold;assert(not game.train_luck() and game.gold==gold)
	game.paused=false;game.reset_game();assert(game.upgrade==0 and game.luck_level==0)
	game.free();print("headquarters: PASS — clickable building/U/Esc, attack upgrade, exact 80/17/3 to 67/27/6 odds, upgrade costs/cap, three-tier summons, actual-investment resale, reset/pause");quit()
