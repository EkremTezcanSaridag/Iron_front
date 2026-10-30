extends Node
## Dev-only: run with --rendering-method gl_compatibility to dump UI screenshots.

const OUT_DIR := "/opt/cursor/artifacts"

func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	await get_tree().process_frame
	await _shot("res://scenes/MainMenu.tscn", "screenshot-main-menu.png")
	await _shot("res://scenes/CountryPicker.tscn", "screenshot-country-picker.png")
	GameManager.start_game("ottoman_empire")
	await _shot("res://scenes/GameMap.tscn", "screenshot-game-map.png")
	print("SCREENSHOTS_DONE")
	get_tree().quit()

func _shot(scene_path: String, filename: String) -> void:
	var packed: PackedScene = load(scene_path)
	var scene: Node = packed.instantiate()
	add_child(scene)
	# Let layout and MapView draw.
	for _i in range(8):
		await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	var img: Image = get_viewport().get_texture().get_image()
	var path := OUT_DIR.path_join(filename)
	img.save_png(path)
	print("Wrote ", path)
	scene.queue_free()
	await get_tree().process_frame
