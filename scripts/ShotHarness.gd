extends Node
## Headless screenshot pass: menu, tutorial, shelter, expedition, event.


func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1080, 1920))
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
	DirAccess.make_dir_recursive_absolute("/tmp/siginak-shots")
	await get_tree().process_frame
	await _shot_packed("res://scenes/MainMenu.tscn", "screenshot-main-menu.png")
	GameState.new_game()
	GameState.speed = 0
	await _shot_packed("res://scenes/Game.tscn", "screenshot-tutorial.png")
	GameState.skip_tutorial()
	var game: Node = await _mount("res://scenes/Game.tscn")
	await _wait()
	await _grab("screenshot-shelter.png")
	if game.has_method("_open_expedition"):
		game._open_expedition()
		await _wait()
		await _grab("screenshot-expedition.png")
		game._clear_overlay()
	GameState.force_event("stranger")
	if game.has_method("_show_event"):
		game._show_event(GameState.pending_event, false)
	await _wait()
	await _grab("screenshot-event.png")
	print("SCREENSHOTS_DONE")
	get_tree().quit()


func _shot_packed(path: String, filename: String) -> void:
	var scene := await _mount(path)
	await _wait()
	await _grab(filename)
	scene.queue_free()
	await get_tree().process_frame


func _mount(path: String) -> Node:
	var packed: PackedScene = load(path)
	var scene: Node = packed.instantiate()
	add_child(scene)
	return scene


func _wait() -> void:
	for _i in range(12):
		await get_tree().process_frame
	await get_tree().create_timer(0.45).timeout
	await RenderingServer.frame_post_draw


func _grab(filename: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("/opt/cursor/artifacts/%s" % filename)
	img.save_png("/tmp/siginak-shots/%s" % filename)
	print("Wrote ", filename, " ", img.get_width(), "x", img.get_height())
