extends SceneTree

func _initialize():
	call_deferred("run")

func run():
	var world = load("res://main.tscn").instantiate()
	world.save_path = "user://test_isolated_world.json"
	if FileAccess.file_exists(world.save_path): DirAccess.remove_absolute(world.save_path)
	root.add_child(world)
	world.set_process(false)
	world.player.set_physics_process(false)
	assert(world.blocks.size() > 48 * 48)
	assert(world.chunks.size() == 16)
	assert(world.blocks.has(Vector3i(0, 0, 0)))
	assert(world.chunk_of(Vector3i(-1, 3, -13)) == Vector2i(-1, -2))
	assert(not world.can_place(Vector3i(0, 0, 0)))
	assert(not world.can_place(Vector3i(24, 10, 0)))
	assert(not world.can_place(Vector3i(0, 25, 0)))
	world.player.position = Vector3(0.5, 17, 0.5)
	assert(not world.can_place(Vector3i(0, 17, 0)), "Cannot trap player inside a new block")
	var cell = Vector3i(11, 20, 11)
	var original = world.blocks.get(cell, -1)
	assert(world.can_place(cell))
	world.set_block(cell, 6)
	assert(world.blocks[cell] == 6)
	assert(world.edits["11,20,11"] == 6)
	world.set_block(cell, -1)
	assert(not world.blocks.has(cell))
	world.blocks[cell] = 6
	world.respawn()
	assert(world.player.position.y > world.terrain_height(0, 5))
	# Check generated collision by letting the character fall onto its spawn column.
	world.active = true
	for i in range(120):
		world.player._physics_process(1.0 / 60)
		await physics_frame
	assert(world.player.is_on_floor(), "Player must land on voxel collision")
	assert(world.player.position.y > 0)
	world.hud.mobile = false
	world.begin()
	world._on_pointer_lock([true, false])
	var yaw = world.player.rotation.y
	var motion = InputEventMouseMotion.new()
	motion.relative = Vector2(20, 10)
	world.player._input(motion)
	assert(not is_equal_approx(world.player.rotation.y, yaw), "Mouse motion must turn camera without a held button")
	world._on_pointer_lock([false, false])
	yaw = world.player.rotation.y
	world.player._input(motion)
	assert(is_equal_approx(world.player.rotation.y, yaw), "Paused camera must ignore mouse motion")
	assert(not world.active)
	# Crafting consumes harvested wood; failed crafts and equipping cost nothing.
	assert(not world.craft_tool(1))
	var trunk = Vector3i(-10, world.terrain_height(-10, -9) + 1, -9)
	for i in range(3): assert(not world.mine_block(trunk))
	assert(world.mine_block(trunk))
	assert(world.wood == 1)
	assert(not world.mine_block(trunk), "Removed wood cannot be harvested twice")
	world.wood = 10
	for tool in range(1, 5):
		assert(world.craft_tool(tool))
		assert(world.tools[tool] == 60)
	assert(world.wood == 0)
	assert(world.craft_tool(1))
	assert(world.wood == 0)
	assert(world.required_hits(4) == 1)
	assert(world.required_hits(2) == 6)
	world.equipped = 2
	assert(world.required_hits(5) == 1)
	world.equipped = 3
	assert(world.required_hits(1) == 1 and world.required_hits(3) == 1)
	world.equipped = 4
	assert(world.required_hits(2) == 1)
	world.tools[4] = 1
	world.blocks[cell] = 2
	assert(world.mine_block(cell))
	assert(world.tools[4] == 0 and world.equipped == 0)
	world.cycle_tool()
	assert(world.equipped == 1)
	world.save_world()
	world.wood = 999
	world.tools = [0, 0, 0, 0, 0]
	world.equipped = 0
	world.load_edits()
	assert(world.wood == 0 and world.tools[1] == 60 and world.equipped == 1)
	# Legacy saves load without granting materials or equipment.
	var legacy = FileAccess.open(world.save_path, FileAccess.WRITE)
	legacy.store_string(JSON.stringify({"version": 1, "edits": world.edits}))
	legacy.close()
	world.load_edits()
	assert(world.wood == 0 and world.equipped == 0 and world.tools == [0, 0, 0, 0, 0])
	world.save_world()
	world.edits.clear()
	world.blocks[cell] = 6
	world.load_edits()
	assert(not world.blocks.has(cell), "Deleted blocks must remain deleted after loading")
	assert(int(world.edits["11,20,11"]) == -1)
	# Restore changes and avoid modifying the player's actual save during this test.
	if original == -1: world.blocks.erase(cell)
	else: world.blocks[cell] = original
	print("PASS: terrain, chunk boundaries, building limits, player overlap, edits, collision, respawn, pause, free mouse look, harvesting, crafting, tool efficiency, durability, legacy saves, serialization")
	quit()
