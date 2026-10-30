extends Control


func _ready() -> void:
	theme = UiTheme.make()
	set_anchors_preset(PRESET_FULL_RECT)
	Sfx.play_music("menu_ambient")
	var bg := TextureRect.new()
	bg.texture = load("res://assets/art/bg/menu.png")
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.03, 0.42)
	dim.set_anchors_preset(PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var safe := _safe_margin()
	var root := MarginContainer.new()
	root.set_anchors_preset(PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", safe.x)
	root.add_theme_constant_override("margin_right", safe.x)
	root.add_theme_constant_override("margin_top", safe.y)
	root.add_theme_constant_override("margin_bottom", safe.y)
	add_child(root)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	root.add_child(v)

	var icon := TextureRect.new()
	icon.texture = load("res://assets/icon/app_192.png")
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(180, 180)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	v.add_child(icon)

	var title := UiTheme.label("SIĞINAK", 86, Color("e0a14a"), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := UiTheme.label("Felaketten sonra. Kapının ardında.", 30, Color("cbb79a"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)

	v.add_child(_spacer(28))
	var newb := UiTheme.btn("Yeni Oyun")
	newb.pressed.connect(_on_new)
	v.add_child(newb)
	var cont := UiTheme.btn("Devam Et")
	cont.disabled = not GameState.has_save()
	cont.pressed.connect(_on_continue)
	v.add_child(cont)
	var quitb := UiTheme.btn("Çıkış", 64)
	quitb.pressed.connect(func() -> void: get_tree().quit())
	v.add_child(quitb)
	v.add_child(_spacer(24))
	var cred := UiTheme.label("Kenney.cc0  ·  Barlow (OFL)  ·  v0.2.1", 20, Color("8a7b68"))
	cred.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cred)


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _safe_margin() -> Vector2i:
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if win.x == 0:
		return Vector2i(36, 48)
	var left := maxi(36, safe.position.x)
	var top := maxi(48, safe.position.y)
	return Vector2i(left, top)


func _on_new() -> void:
	Sfx.play("confirm")
	Sfx.stop_music()
	Sfx.play_music("ambient")
	GameState.new_game()
	get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _on_continue() -> void:
	Sfx.play("confirm")
	Sfx.stop_music()
	Sfx.play_music("ambient")
	GameState.load_game()
	get_tree().change_scene_to_file("res://scenes/Game.tscn")
