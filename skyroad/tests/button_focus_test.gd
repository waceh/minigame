extends SceneTree

const Main = preload("res://main.tscn")

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var game = Main.instantiate()
	root.add_child(game)
	for action in ["brake", "fast", "jump"]:
		var button: Button = game.action_buttons[action]
		if button.focus_mode != Control.FOCUS_NONE:
			button.grab_focus()
		await process_frame
		assert(root.gui_get_focus_owner() != button, "Action buttons must leave arrow keys for steering")
	print("button_focus_test: PASS")
	quit()
