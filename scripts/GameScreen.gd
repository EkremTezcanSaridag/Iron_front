extends Control

const RES_ICONS := {
	"food": "res://assets/art/icons/hud_food.png",
	"water": "res://assets/art/icons/hud_water.png",
	"power": "res://assets/art/icons/hud_power.png",
	"medicine": "res://assets/art/icons/hud_medicine.png",
	"scrap": "res://assets/art/icons/hud_scrap.png",
	"ammo": "res://assets/art/icons/hud_ammo.png",
}

var _floor_box: VBoxContainer
var _res_box: GridContainer
var _day_label: Label
var _phase_label: Label
var _radio_bar: ProgressBar
var _radio_label: Label
var _context: VBoxContainer
var _overlay: Control
var _speed_btns: Array = []
var _ending_shown := false


func _ready() -> void:
	theme = UiTheme.make()
	set_anchors_preset(PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.texture = load("res://assets/art/bg/game.png")
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var safe := _safe()
	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", safe.x)
	margin.add_theme_constant_override("margin_right", safe.x)
	margin.add_theme_constant_override("margin_top", safe.y)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	margin.add_child(v)

	v.add_child(_build_top())
	_res_box = GridContainer.new()
	_res_box.columns = 3
	_res_box.add_theme_constant_override("h_separation", 8)
	_res_box.add_theme_constant_override("v_separation", 8)
	v.add_child(_res_box)

	var radio_row := HBoxContainer.new()
	_radio_label = UiTheme.label("Telsiz  0%", 22, Color("cbb79a"), false, false)
	_radio_label.custom_minimum_size = Vector2(160, 0)
	radio_row.add_child(_radio_label)
	_radio_bar = ProgressBar.new()
	_radio_bar.custom_minimum_size = Vector2(0, 28)
	_radio_bar.max_value = 100
	_radio_bar.show_percentage = false
	_radio_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("e0a14a")
	fill.set_corner_radius_all(8)
	_radio_bar.add_theme_stylebox_override("fill", fill)
	var bgb := StyleBoxFlat.new()
	bgb.bg_color = Color("1a1612")
	bgb.set_corner_radius_all(8)
	_radio_bar.add_theme_stylebox_override("background", bgb)
	radio_row.add_child(_radio_bar)
	v.add_child(radio_row)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_floor_box = VBoxContainer.new()
	_floor_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_floor_box.add_theme_constant_override("separation", 14)
	scroll.add_child(_floor_box)

	var ctx_panel := PanelContainer.new()
	ctx_panel.custom_minimum_size = Vector2(0, 300)
	_context = VBoxContainer.new()
	_context.add_theme_constant_override("separation", 8)
	ctx_panel.add_child(_context)
	v.add_child(ctx_panel)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	var sefer := UiTheme.btn("Sefer")
	sefer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sefer.pressed.connect(_open_expedition)
	var insa := UiTheme.btn("İnşa")
	insa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	insa.pressed.connect(_open_build)
	var men := UiTheme.btn("Menü", 72)
	men.pressed.connect(_back_menu)
	actions.add_child(sefer)
	actions.add_child(insa)
	actions.add_child(men)
	v.add_child(actions)

	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.z_index = 80
	add_child(_overlay)

	GameState.state_changed.connect(_refresh)
	GameState.event_raised.connect(func(ev): _show_event(ev, false))
	GameState.expedition_card.connect(func(ev): _show_event(ev, true))
	GameState.game_ended.connect(_show_ending)
	GameState.tutorial_changed.connect(_maybe_tutorial)
	_refresh()
	_maybe_tutorial()


func _safe() -> Vector2i:
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if win.x <= 0:
		return Vector2i(28, 40)
	return Vector2i(maxi(24, safe.position.x + 8), maxi(36, safe.position.y + 8))


func _build_top() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var title := UiTheme.label("SIĞINAK", 36, Color("e0a14a"), true, false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var daybox := VBoxContainer.new()
	_day_label = UiTheme.label("1. GÜN", 26, Color("f2e6d0"), true, false)
	_day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_phase_label = UiTheme.label("Sabah", 20, Color("cbb79a"), false, false)
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	daybox.add_child(_day_label)
	daybox.add_child(_phase_label)
	row.add_child(daybox)
	var speed_labels := PackedStringArray(["II", "1×", "2×"])
	for spd in range(speed_labels.size()):
		var b := UiTheme.btn(speed_labels[spd], 56)
		b.custom_minimum_size = Vector2(78, 56)
		b.size_flags_horizontal = Control.SIZE_SHRINK_END
		b.pressed.connect(func() -> void:
			Sfx.play("click")
			GameState.set_speed(spd)
		)
		_speed_btns.append(b)
		row.add_child(b)
	return row


func _refresh() -> void:
	_day_label.text = "%d. GÜN" % GameState.day
	_phase_label.text = GameState.PHASE_NAMES[GameState.phase]
	_radio_bar.value = GameState.radio_progress
	_radio_label.text = "Telsiz  %d%%" % int(GameState.radio_progress)
	for i in _speed_btns.size():
		_speed_btns[i].modulate = Color("e0a14a") if GameState.speed == i else Color.WHITE
	_rebuild_resources()
	_rebuild_floors()
	_rebuild_context()
	if GameState.ended and not _ending_shown:
		_show_ending(GameState.won, GameState.end_reason)


func _rebuild_resources() -> void:
	for c in _res_box.get_children():
		c.queue_free()
	for id in GameState.resource_summary():
		var chip := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("221c18")
		sb.set_corner_radius_all(12)
		sb.content_margin_left = 8
		sb.content_margin_right = 10
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		chip.add_theme_stylebox_override("panel", sb)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var ic := TextureRect.new()
		if ResourceLoader.exists(RES_ICONS[id]):
			ic.texture = load(RES_ICONS[id])
		ic.custom_minimum_size = Vector2(40, 40)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h.add_child(ic)
		var lab := UiTheme.label(str(int(GameState.resources[id])), 28, Color("f2e6d0"), true, false)
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(lab)
		chip.add_child(h)
		_res_box.add_child(chip)


func _rebuild_floors() -> void:
	for c in _floor_box.get_children():
		c.queue_free()
	# Surface strip
	var surface := PanelContainer.new()
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color("3a2a22")
	ssb.set_corner_radius_all(12)
	surface.add_theme_stylebox_override("panel", ssb)
	var sl := UiTheme.label("  Yüzey — zehirli rüzgâr", 22, Color("c45c3e"))
	surface.add_child(sl)
	_floor_box.add_child(surface)
	for floor in range(GameState.MAX_FLOOR):
		var flab := UiTheme.label("Kat %d" % (floor + 1), 22, Color("a89880"), true)
		_floor_box.add_child(flab)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for slot in range(GameState.SLOTS_PER_FLOOR):
			row.add_child(_room_card(GameState.room_at(floor, slot)))
		_floor_box.add_child(row)


func _room_card(room: Dictionary) -> Control:
	var wrap := PanelContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.custom_minimum_size = Vector2(0, 210)
	var sb := StyleBoxFlat.new()
	var selected: bool = str(room.get("id", "")) != "" and str(room.get("id", "")) == GameState.selected_room
	sb.bg_color = Color("161310")
	sb.border_color = Color("e0a14a") if selected else Color("3a3228")
	sb.set_border_width_all(3 if selected else 1)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	wrap.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	wrap.add_child(v)
	var art := TextureRect.new()
	var type := str(room.get("type", "empty"))
	var art_path := "res://assets/art/rooms/%s.png" % (type if type != "" else "empty")
	if ResourceLoader.exists(art_path):
		art.texture = load(art_path)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.custom_minimum_size = Vector2(0, 118)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(art)
	var title := UiTheme.label(GameState.room_title(type), 24, Color("f2e6d0"), true, false)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var faces := HBoxContainer.new()
	faces.alignment = BoxContainer.ALIGNMENT_CENTER
	for s in GameState._workers_of(room):
		faces.add_child(_portrait_btn(s, 52, true))
	if faces.get_child_count() == 0:
		var empty := UiTheme.label("boş", 18, Color("8a7b68"), false, false)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		faces.add_child(empty)
	v.add_child(faces)
	wrap.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_on_room_tapped(str(room.get("id", "")))
		if ev is InputEventScreenTouch and ev.pressed:
			_on_room_tapped(str(room.get("id", "")))
	)
	return wrap


func _portrait_btn(s: Dictionary, size: int, select_on_press := true) -> Control:
	var b := TextureButton.new()
	var path := "res://assets/art/portraits/p%d.png" % int(s.get("portrait", 0))
	if ResourceLoader.exists(path):
		b.texture_normal = load(path)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_COVERED
	b.custom_minimum_size = Vector2(size, size)
	if s.get("id") == GameState.selected_survivor:
		b.modulate = Color("ffe7b0")
	if float(s.get("health", 100)) < 35.0:
		b.modulate = Color("ff8a7a")
	if select_on_press:
		b.pressed.connect(func() -> void:
			Sfx.play("click")
			GameState.select_survivor(str(s["id"]))
		)
	return b


func _on_room_tapped(room_id: String) -> void:
	Sfx.play("click")
	if GameState.selected_survivor != "":
		GameState.assign_selected_to_room(room_id)
	else:
		GameState.select_room(room_id)


func _rebuild_context() -> void:
	for c in _context.get_children():
		c.queue_free()
	var s := GameState.survivor_by_id(GameState.selected_survivor)
	var r := GameState.room_by_id(GameState.selected_room)
	if s:
		var head := HBoxContainer.new()
		head.add_child(_portrait_btn(s, 72, true))
		var names := VBoxContainer.new()
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		names.add_child(UiTheme.label(str(s["name"]), 32, Color("e0a14a"), true))
		names.add_child(UiTheme.label(GameState.trait_title(str(s.get("trait"))), 22, Color("cbb79a")))
		head.add_child(names)
		_context.add_child(head)
		_context.add_child(_stat_row("Sağlık", float(s["health"]), Color("c45c3e")))
		_context.add_child(_stat_row("Açlık", float(s["hunger"]), Color("e0a14a")))
		_context.add_child(_stat_row("Susuzluk", float(s["thirst"]), Color("5ba3b5")))
		_context.add_child(_stat_row("Moral", float(s["morale"]), Color("7d9a6a")))
		var hint := UiTheme.label("Bir odaya dokunarak görev ver.", 20, Color("8a7b68"))
		_context.add_child(hint)
		return
	if r and r.get("type") != "empty":
		_context.add_child(UiTheme.label(GameState.room_title(str(r["type"])), 30, Color("e0a14a"), true))
		var def: Dictionary = GameState.defs_rooms.get(r["type"], {})
		_context.add_child(UiTheme.label(str(def.get("blurb", "")), 22, Color("cbb79a")))
		_context.add_child(UiTheme.label("Seviye %d  ·  çalışan %d" % [int(r.get("level", 1)), GameState._workers_of(r).size()], 22, Color("f2e6d0")))
		var up := UiTheme.btn("Yükselt", 60)
		up.pressed.connect(func() -> void: GameState.upgrade_room(str(r["id"])))
		_context.add_child(up)
		return
	# idle people strip
	_context.add_child(UiTheme.label("Kişiler — dokun, sonra odaya yerleştir", 22, Color("cbb79a")))
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 8)
	for person in GameState.survivors:
		if not person.get("alive", true):
			continue
		var box := VBoxContainer.new()
		box.add_child(_portrait_btn(person, 64, true))
		var nm := UiTheme.label(str(person["name"]), 18, Color("f2e6d0"), false, false)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(nm)
		if person.get("away"):
			nm.text = str(person["name"]) + " · dışarı"
			nm.add_theme_color_override("font_color", Color("c45c3e"))
		strip.add_child(box)
	var sc := ScrollContainer.new()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, 110)
	sc.add_child(strip)
	_context.add_child(sc)


func _stat_row(name: String, value: float, col: Color) -> Control:
	var h := HBoxContainer.new()
	var l := UiTheme.label(name, 20, Color("cbb79a"))
	l.custom_minimum_size = Vector2(140, 0)
	h.add_child(l)
	var bar := ProgressBar.new()
	bar.max_value = 100
	bar.value = value
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0, 18)
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("fill", fill)
	h.add_child(bar)
	return h


func _open_expedition() -> void:
	Sfx.play("open")
	var sheet := _make_modal()
	var card: VBoxContainer = sheet.body
	card.add_child(UiTheme.label("Sefer", 40, Color("e0a14a"), true))
	card.add_child(UiTheme.label("Kimleri dışarı yollayacağını ve hedefi seç. Cephane pusu riskini azaltır.", 24, Color("cbb79a")))
	var chosen := {"id": "market", "people": [], "ammo": 0}
	var dest_btns: Array = []
	for d in GameState.defs_exp.get("destinations", []):
		var b := UiTheme.btn("%s  ·  %d vakit  ·  tehlike %d" % [d["title"], d["phases"], d["danger"]], 64)
		if str(d["id"]) == "market":
			b.modulate = Color("e0a14a")
		b.pressed.connect(func() -> void:
			chosen["id"] = d["id"]
			for other in dest_btns:
				other.modulate = Color.WHITE
			b.modulate = Color("e0a14a")
			Sfx.play("click")
		)
		dest_btns.append(b)
		card.add_child(b)
	card.add_child(UiTheme.label("Kadro (dokun)", 22, Color("cbb79a")))
	var people := HBoxContainer.new()
	for s in GameState.living_survivors():
		var pb := _portrait_btn(s, 64, false)
		pb.pressed.connect(func() -> void:
			var id := str(s["id"])
			if id in chosen["people"]:
				chosen["people"].erase(id)
				pb.modulate = Color.WHITE
			else:
				chosen["people"].append(id)
				pb.modulate = Color("e0a14a")
		)
		people.add_child(pb)
	card.add_child(people)
	var ammo := UiTheme.btn("Cephane ayır: 0", 56)
	ammo.pressed.connect(func() -> void:
		chosen["ammo"] = (int(chosen["ammo"]) + 1) % (mini(4, int(GameState.resources["ammo"]) + 1))
		ammo.text = "Cephane ayır: %d" % chosen["ammo"]
	)
	card.add_child(ammo)
	var go := UiTheme.btn("Yola çık")
	go.pressed.connect(func() -> void:
		if GameState.start_expedition(str(chosen["id"]), chosen["people"], int(chosen["ammo"])):
			_clear_overlay()
		else:
			Sfx.play("error")
	)
	sheet.footer.add_child(go)
	sheet.footer.add_child(_close_btn())


func _open_build() -> void:
	Sfx.play("open")
	var sheet := _make_modal()
	var card: VBoxContainer = sheet.body
	card.add_child(UiTheme.label("İnşa", 40, Color("e0a14a"), true))
	card.add_child(UiTheme.label("Boş bir oyuk seç, sonra oda tipi. Hurda: %d" % int(GameState.resources["scrap"]), 24, Color("cbb79a")))
	var empty_slots: Array = []
	for r in GameState.rooms:
		if r.get("type") == "empty":
			empty_slots.append(r)
	if empty_slots.is_empty():
		card.add_child(UiTheme.label("Boş oyuk yok.", 24, Color("c45c3e")))
	var chosen := {"room": "", "type": ""}
	for r in empty_slots:
		var b := UiTheme.btn("Kat %d · oyuk %d" % [int(r["floor"]) + 1, int(r["slot"]) + 1], 56)
		b.pressed.connect(func() -> void:
			chosen["room"] = r["id"]
			b.modulate = Color("e0a14a")
		)
		card.add_child(b)
	var types := GridContainer.new()
	types.columns = 2
	for type in ["living", "hydroponics", "water", "generator", "storage", "infirmary", "workshop", "radio"]:
		var def: Dictionary = GameState.defs_rooms.get(type, {})
		var lab := "%s  (%d hurda)" % [def.get("title", type), def.get("build_scrap", 0)]
		var b := UiTheme.btn(lab, 60)
		b.pressed.connect(func() -> void:
			chosen["type"] = type
			b.modulate = Color("e0a14a")
		)
		types.add_child(b)
	card.add_child(types)
	var go := UiTheme.btn("Kur")
	go.pressed.connect(func() -> void:
		var slot_room := GameState.room_by_id(str(chosen["room"]))
		if slot_room and GameState.build_room(int(slot_room["floor"]), int(slot_room["slot"]), str(chosen["type"])):
			_clear_overlay()
		else:
			Sfx.play("error")
	)
	sheet.footer.add_child(go)
	sheet.footer.add_child(_close_btn())


func _show_event(ev: Dictionary, is_exp: bool) -> void:
	Sfx.play("question")
	var sheet := _make_modal()
	var card: VBoxContainer = sheet.body
	var kicker := UiTheme.label("Sefer notu" if is_exp else "Sığınak olayı", 20, Color("c45c3e"), true)
	card.add_child(kicker)
	card.add_child(UiTheme.label(str(ev.get("title", "")), 36, Color("e0a14a"), true))
	var body := UiTheme.label(str(ev.get("body", "")), 26, Color("f2e6d0"))
	card.add_child(body)
	for ch in ev.get("choices", []):
		var extra := ""
		var need_tr := {
			"need_ammo": "cephane", "need_food": "yiyecek", "need_water": "su",
			"need_scrap": "hurda", "need_medicine": "ilaç"
		}
		for k in ["need_ammo", "need_food", "need_water", "need_scrap", "need_medicine"]:
			if int(ch.get(k, 0)) > 0:
				extra += "  ·  %s %d" % [need_tr[k], ch[k]]
		var b := UiTheme.btn(str(ch.get("label", "")) + extra, 70)
		var cid := str(ch.get("id"))
		b.pressed.connect(func() -> void:
			GameState.resolve_event(cid)
			_clear_overlay()
		)
		sheet.footer.add_child(b)


func _maybe_tutorial() -> void:
	if GameState.tutorial_done:
		return
	if GameState.pending_event:
		return
	var sheet := _make_modal()
	var card: VBoxContainer = sheet.body
	card.add_child(UiTheme.label("İlk gün", 34, Color("e0a14a"), true))
	card.add_child(UiTheme.label(GameState.tutorial_text(), 26, Color("f2e6d0")))
	var next := UiTheme.btn("Devam")
	next.pressed.connect(func() -> void:
		Sfx.play("click")
		GameState.advance_tutorial()
		_clear_overlay()
		_maybe_tutorial()
	)
	var skip := UiTheme.btn("Atla", 64)
	skip.pressed.connect(func() -> void:
		GameState.skip_tutorial()
		_clear_overlay()
	)
	sheet.footer.add_child(next)
	sheet.footer.add_child(skip)


func _show_ending(won: bool, reason: String) -> void:
	_ending_shown = true
	var sheet := _make_modal()
	var card: VBoxContainer = sheet.body
	card.add_child(UiTheme.label("Kurtuluş" if won else "Sessizlik", 44, Color("7d9a6a") if won else Color("c45c3e"), true))
	card.add_child(UiTheme.label(reason, 26, Color("f2e6d0")))
	card.add_child(UiTheme.label("Skor  %d" % GameState.score, 32, Color("e0a14a"), true))
	var b := UiTheme.btn("Ana menü")
	b.pressed.connect(_back_menu)
	sheet.footer.add_child(b)


func _make_modal() -> Dictionary:
	_clear_overlay()
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.02, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	var shell := VBoxContainer.new()
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.add_theme_constant_override("separation", 0)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(spacer)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color("1a1612f2")
	ps.border_color = Color("e0a14a")
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(22)
	ps.corner_radius_bottom_left = 0
	ps.corner_radius_bottom_right = 0
	ps.content_margin_left = 28
	ps.content_margin_right = 28
	ps.content_margin_top = 28
	ps.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", ps)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 420)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(body)
	var footer := VBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(sc)
	col.add_child(footer)
	panel.add_child(col)
	shell.add_child(panel)
	dim.add_child(shell)
	_overlay.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return {"body": body, "footer": footer}


func _close_btn() -> Button:
	var b := UiTheme.btn("Kapat", 60)
	b.pressed.connect(_clear_overlay)
	return b


func _clear_overlay() -> void:
	for c in _overlay.get_children():
		c.queue_free()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _back_menu() -> void:
	GameState.save_game()
	Sfx.stop_music()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
