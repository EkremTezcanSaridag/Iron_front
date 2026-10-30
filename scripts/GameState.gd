extends Node
## Sığınak simulation, save/load, and event/expedition flow.

signal state_changed
signal event_raised(payload: Dictionary)
signal expedition_card(payload: Dictionary)
signal game_ended(won: bool, reason: String)
signal tutorial_changed

const SAVE_PATH := "user://siginak_save.json"
const PHASE_SECONDS := 11.0
const PHASE_NAMES := ["Sabah", "Öğlen", "Akşam", "Gece"]
const MAX_FLOOR := 4
const SLOTS_PER_FLOOR := 2

var rng := RandomNumberGenerator.new()
var defs_rooms: Dictionary = {}
var defs_events: Dictionary = {}
var defs_exp: Dictionary = {}
var defs_names: Dictionary = {}

var day: int = 1
var phase: int = 0
var speed: int = 1
var phase_clock: float = 0.0
var radio_progress: float = 0.0
var low_morale_days: int = 0
var ended: bool = false
var won: bool = false
var end_reason: String = ""
var tutorial_step: int = 0
var tutorial_done: bool = false
var selected_survivor: String = ""
var selected_room: String = ""
var last_save_unix: int = 0
var score: int = 0
var log_lines: Array = []

var resources: Dictionary = {
	"food": 42, "water": 40, "power": 18, "medicine": 8, "scrap": 28, "ammo": 7
}
var caps: Dictionary = {
	"food": 60, "water": 60, "power": 40, "medicine": 24, "scrap": 80, "ammo": 24
}

var survivors: Array = []
var rooms: Array = []
var expedition: Dictionary = {}
var pending_event: Dictionary = {}
var survivor_seq: int = 1
var room_seq: int = 1


func _ready() -> void:
	defs_rooms = _load_json("res://data/rooms.json")
	defs_events = _load_json("res://data/events.json")
	defs_exp = _load_json("res://data/expeditions.json")
	defs_names = _load_json("res://data/names.json")
	rng.randomize()


func _process(delta: float) -> void:
	if ended or speed <= 0:
		return
	if pending_event or expedition.get("card"):
		return
	phase_clock += delta * float(speed)
	if phase_clock >= PHASE_SECONDS:
		phase_clock = 0.0
		advance_phase()


func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Missing " + path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func new_game() -> void:
	ended = false
	won = false
	end_reason = ""
	day = 1
	phase = 0
	speed = 1
	phase_clock = 0.0
	radio_progress = 0.0
	low_morale_days = 0
	tutorial_step = 0
	tutorial_done = false
	selected_survivor = ""
	selected_room = ""
	score = 0
	log_lines.clear()
	survivor_seq = 1
	room_seq = 1
	resources = {"food": 42, "water": 40, "power": 18, "medicine": 8, "scrap": 28, "ammo": 7}
	caps = {"food": 60, "water": 60, "power": 40, "medicine": 24, "scrap": 80, "ammo": 24}
	expedition = {}
	pending_event = {}
	rooms.clear()
	survivors.clear()
	_add_room("living", 0, 0)
	_add_room("generator", 0, 1)
	_add_room("water", 1, 0)
	_add_room("hydroponics", 1, 1)
	_add_room("storage", 2, 0)
	_add_empty(2, 1)
	_add_empty(3, 0)
	_add_empty(3, 1)
	var starters := [
		{"portrait": 0, "trait": "usta", "skills": {"tech": 3, "combat": 1, "scavenge": 1, "medical": 0, "cook": 1}},
		{"portrait": 1, "trait": "sefkatli", "skills": {"tech": 0, "combat": 0, "scavenge": 1, "medical": 3, "cook": 2}},
		{"portrait": 2, "trait": "gezgin", "skills": {"tech": 1, "combat": 2, "scavenge": 3, "medical": 0, "cook": 0}},
		{"portrait": 3, "trait": "caliskan", "skills": {"tech": 1, "combat": 0, "scavenge": 1, "medical": 1, "cook": 3}},
	]
	var used_names: Array = []
	for spec in starters:
		var s := _make_survivor(spec["portrait"], spec["trait"], spec["skills"], used_names)
		survivors.append(s)
	_assign(survivors[0]["id"], rooms[1]["id"])  # generator
	_assign(survivors[1]["id"], rooms[2]["id"])  # water
	_assign(survivors[2]["id"], rooms[3]["id"])  # hydro
	_assign(survivors[3]["id"], rooms[0]["id"])  # living
	_log("Sığınak kapısı kilitlendi. Dışarıda dünya bitti. İçeride dört kişi kaldı.")
	save_game()
	state_changed.emit()
	tutorial_changed.emit()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	last_save_unix = int(Time.get_unix_time_from_system())
	var blob := {
		"day": day, "phase": phase, "radio": radio_progress, "low_morale_days": low_morale_days,
		"ended": ended, "won": won, "end_reason": end_reason, "tutorial_step": tutorial_step,
		"tutorial_done": tutorial_done, "resources": resources, "caps": caps,
		"survivors": survivors, "rooms": rooms, "expedition": expedition,
		"survivor_seq": survivor_seq, "room_seq": room_seq, "log": log_lines.slice(-40),
		"last_save_unix": last_save_unix, "rng_state": rng.state, "score": score
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(blob))


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = parsed
	day = int(d.get("day", 1))
	phase = int(d.get("phase", 0))
	radio_progress = float(d.get("radio", 0))
	low_morale_days = int(d.get("low_morale_days", 0))
	ended = bool(d.get("ended", false))
	won = bool(d.get("won", false))
	end_reason = str(d.get("end_reason", ""))
	tutorial_step = int(d.get("tutorial_step", 0))
	tutorial_done = bool(d.get("tutorial_done", false))
	resources = d.get("resources", resources)
	caps = d.get("caps", caps)
	survivors = d.get("survivors", [])
	rooms = d.get("rooms", [])
	expedition = d.get("expedition", {})
	survivor_seq = int(d.get("survivor_seq", 8))
	room_seq = int(d.get("room_seq", 8))
	log_lines = d.get("log", [])
	score = int(d.get("score", 0))
	pending_event = {}
	speed = 0
	phase_clock = 0.0
	var saved_unix := int(d.get("last_save_unix", 0))
	if saved_unix > 0 and not ended:
		var hours := clampi(int((Time.get_unix_time_from_system() - saved_unix) / 3600.0), 0, 8)
		var ticks := hours * 2
		for i in ticks:
			_simulate_phase(true)
	save_game()
	state_changed.emit()
	return true


func set_speed(v: int) -> void:
	speed = v
	state_changed.emit()


func living_survivors() -> Array:
	var out: Array = []
	for s in survivors:
		if s.get("alive", true) and not s.get("away", false):
			out.append(s)
	return out


func survivor_by_id(id: String) -> Dictionary:
	for s in survivors:
		if s["id"] == id:
			return s
	return {}


func room_by_id(id: String) -> Dictionary:
	for r in rooms:
		if r["id"] == id:
			return r
	return {}


func room_at(floor: int, slot: int) -> Dictionary:
	for r in rooms:
		if int(r["floor"]) == floor and int(r["slot"]) == slot:
			return r
	return {}


func assign_selected_to_room(room_id: String) -> void:
	if selected_survivor == "":
		selected_room = room_id
		state_changed.emit()
		return
	_assign(selected_survivor, room_id)
	if tutorial_step == 1:
		advance_tutorial()
	save_game()
	state_changed.emit()


func select_survivor(id: String) -> void:
	selected_survivor = id
	state_changed.emit()


func select_room(id: String) -> void:
	selected_room = id
	state_changed.emit()


func build_room(floor: int, slot: int, type: String) -> bool:
	var def: Dictionary = defs_rooms.get(type, {})
	if def.is_empty():
		return false
	if day < int(def.get("unlock_day", 1)):
		return false
	var cost := int(def.get("build_scrap", 12))
	if int(resources["scrap"]) < cost:
		return false
	var existing := room_at(floor, slot)
	if existing.is_empty() or existing.get("type") != "empty":
		return false
	resources["scrap"] -= cost
	existing["type"] = type
	existing["level"] = 1
	existing["built"] = true
	if type == "storage":
		_recompute_caps()
	_log("%s kuruldu." % def.get("title", type))
	if tutorial_step == 3:
		advance_tutorial()
	save_game()
	state_changed.emit()
	Sfx.play("confirm")
	return true


func upgrade_room(room_id: String) -> bool:
	var r := room_by_id(room_id)
	if r.is_empty() or r.get("type") == "empty":
		return false
	var def: Dictionary = defs_rooms.get(r["type"], {})
	var cost := int(def.get("upgrade_scrap", 18)) + int(r.get("level", 1)) * 6
	if int(r.get("level", 1)) >= 3:
		return false
	if int(resources["scrap"]) < cost:
		return false
	resources["scrap"] -= cost
	r["level"] = int(r["level"]) + 1
	if r["type"] == "storage":
		_recompute_caps()
	_log("%s yükseltildi (svi %d)." % [def.get("title", r["type"]), r["level"]])
	save_game()
	state_changed.emit()
	Sfx.play("confirm")
	return true


func start_expedition(dest_id: String, survivor_ids: Array, spend_ammo: int) -> bool:
	if expedition.get("active"):
		return false
	if survivor_ids.is_empty():
		return false
	var dest: Dictionary = {}
	for d in defs_exp.get("destinations", []):
		if d["id"] == dest_id:
			dest = d
			break
	if dest.is_empty():
		return false
	spend_ammo = clampi(spend_ammo, 0, int(resources["ammo"]))
	resources["ammo"] -= spend_ammo
	for sid in survivor_ids:
		var s := survivor_by_id(sid)
		if s.is_empty():
			continue
		s["away"] = true
		s["room"] = ""
	expedition = {
		"active": true,
		"dest": dest_id,
		"title": dest.get("title", dest_id),
		"left": int(dest.get("phases", 3)),
		"people": survivor_ids.duplicate(),
		"ammo": spend_ammo,
		"danger": int(dest.get("danger", 30)),
		"loot": dest.get("loot", {}),
		"log": [],
		"card": {}
	}
	_log("Sefer yola çıktı: %s (%d kişi)." % [dest.get("title"), survivor_ids.size()])
	if tutorial_step == 2:
		advance_tutorial()
	save_game()
	state_changed.emit()
	Sfx.play("door")
	return true


func resolve_event(choice_id: String) -> void:
	if pending_event.is_empty() and not expedition.get("card"):
		return
	if pending_event:
		_apply_shelter_choice(pending_event, choice_id)
		pending_event = {}
	elif expedition.get("card"):
		_apply_exp_choice(expedition["card"], choice_id)
		expedition["card"] = {}
	save_game()
	state_changed.emit()
	Sfx.play("click")


func advance_tutorial() -> void:
	if tutorial_done:
		return
	tutorial_step += 1
	if tutorial_step >= 5:
		tutorial_done = true
		tutorial_step = 5
		_log("İlk gün bitti sayılır. Bundan sonrası size kalmış.")
	tutorial_changed.emit()
	state_changed.emit()


func skip_tutorial() -> void:
	tutorial_done = true
	tutorial_step = 5
	tutorial_changed.emit()
	state_changed.emit()


func tutorial_text() -> String:
	match tutorial_step:
		0:
			return "Kapı kilitlendi. Bu bir sığınak kesiti — odalara dokun, insanları yerleştir. Kaynaklar her vakit diliminde akar."
		1:
			return "Bir kişi seç, sonra bir odaya dokun. Jeneratör, su ve hidroponik dolu olmalı; yoksa gece uzun sürer."
		2:
			return "Dışarı çıkmak gerekir. Alttaki SEFER ile yağmaya gönder. Geri dönmeyebilirler."
		3:
			return "Hurda biriktikçe boş oyuklara oda inşa et. Telsiz odası kurtuluşun anahtarı."
		4:
			return "Duraklat / 1x / 2x ile zamanı yönet. Hedef: telsizi onarıp kurtarma çağrısı yapmak, ya da 21 gün dayanmak."
		_:
			return ""


func force_event(id: String = "stranger") -> void:
	for ev in defs_events.get("shelter", []):
		if ev["id"] == id:
			pending_event = ev.duplicate(true)
			event_raised.emit(pending_event)
			state_changed.emit()
			return


func advance_phase() -> void:
	_simulate_phase(false)
	save_game()
	state_changed.emit()


func _simulate_phase(offline: bool) -> void:
	if ended:
		return
	_tick_needs()
	_tick_power_and_rooms()
	_tick_morale_health()
	_tick_expedition(offline)
	if not offline:
		_maybe_event()
	_check_endings()
	phase += 1
	if phase >= 4:
		phase = 0
		day += 1
		_daily_roll()
	if tutorial_step == 0 and not tutorial_done:
		# stay on step 0 until they tap Next; do not auto-advance
		pass


func _tick_needs() -> void:
	for s in living_survivors():
		var ate := false
		if int(resources["food"]) > 0:
			resources["food"] -= 1
			s["hunger"] = min(100.0, float(s["hunger"]) + 10.0)
			ate = true
		else:
			s["hunger"] = max(0.0, float(s["hunger"]) - 14.0)
		if int(resources["water"]) > 0:
			resources["water"] -= 1
			s["thirst"] = min(100.0, float(s["thirst"]) + 12.0)
		else:
			s["thirst"] = max(0.0, float(s["thirst"]) - 16.0)
		if float(s["hunger"]) < 20.0:
			s["health"] = max(0.0, float(s["health"]) - 8.0)
			s["morale"] = max(0.0, float(s["morale"]) - 6.0)
		if float(s["thirst"]) < 20.0:
			s["health"] = max(0.0, float(s["health"]) - 10.0)
		if phase == 3:
			var r := room_by_id(str(s.get("room", "")))
			if r.get("type") == "living":
				s["morale"] = min(100.0, float(s["morale"]) + 7.0)
			else:
				s["morale"] = max(0.0, float(s["morale"]) - 5.0)
		if s.get("trait") == "iyimser":
			s["morale"] = min(100.0, float(s["morale"]) + 2.0)
		if not ate:
			pass


func _tick_power_and_rooms() -> void:
	var produced_power := 0
	var drain := 0
	for r in rooms:
		if not r.get("built", true) or r.get("type") in ["empty", ""]:
			continue
		var def: Dictionary = defs_rooms.get(r["type"], {})
		var workers := _workers_of(r)
		var wcount := workers.size()
		var lvl := int(r.get("level", 1))
		if r["type"] == "generator":
			var p := 0
			for s in workers:
				p += 5 + int(s["skills"].get("tech", 0))
				if s.get("trait") == "caliskan":
					p += 1
			produced_power += p * lvl
		else:
			drain += int(def.get("power", 0)) + (lvl - 1)
	resources["power"] = clampi(produced_power, 0, int(caps["power"]))
	var blackout := produced_power < drain and drain > 0
	if blackout:
		_log("Karartma: jeneratör yetişemedi.")
		for s in living_survivors():
			s["morale"] = max(0.0, float(s["morale"]) - 4.0)
		return
	resources["power"] = clampi(produced_power - drain, 0, int(caps["power"]))
	for r in rooms:
		if r.get("type") in ["empty", ""]:
			continue
		var workers := _workers_of(r)
		var lvl := int(r.get("level", 1))
		match str(r["type"]):
			"hydroponics":
				var food := 0
				for s in workers:
					food += 2 + int(s["skills"].get("cook", 0))
					if s.get("trait") == "caliskan":
						food += 1
				_add_res("food", food * lvl)
			"water":
				var wat := 0
				for s in workers:
					wat += 2 + int(s["skills"].get("tech", 0) / 2)
				_add_res("water", wat * lvl)
			"workshop":
				var scrap := 0
				var ammo := 0
				for s in workers:
					scrap += 1 + (1 if s.get("trait") == "usta" else 0)
					if int(s["skills"].get("tech", 0)) >= 2:
						ammo += 1
				_add_res("scrap", scrap * lvl)
				_add_res("ammo", ammo)
			"infirmary":
				for s in workers:
					var heal := 10 + int(s["skills"].get("medical", 0)) * 3
					if s.get("trait") == "sefkatli":
						heal += 6
					if int(resources["medicine"]) > 0:
						resources["medicine"] -= 1
						heal += 8
					_heal_lowest(heal)
			"radio":
				var add := 0.0
				for s in workers:
					add += 3.5 + float(s["skills"].get("tech", 0))
				radio_progress = min(100.0, radio_progress + add * float(lvl))
			"living":
				for s in workers:
					s["morale"] = min(100.0, float(s["morale"]) + 2.0)


func _tick_morale_health() -> void:
	var huysuz := false
	for s in living_survivors():
		if s.get("trait") == "huysuz":
			huysuz = true
	for s in living_survivors():
		if huysuz and s.get("trait") != "huysuz":
			s["morale"] = max(0.0, float(s["morale"]) - 1.5)
		if float(s["health"]) <= 0.0:
			s["alive"] = false
			s["away"] = false
			s["room"] = ""
			_log("%s hayatını kaybetti." % s["name"])
			Sfx.play("fail")


func _tick_expedition(offline: bool) -> void:
	if not expedition.get("active"):
		return
	expedition["left"] = int(expedition.get("left", 1)) - 1
	if not offline and rng.randf() < 0.42 and defs_events.get("expedition"):
		var cards: Array = defs_events["expedition"]
		expedition["card"] = cards[rng.randi_range(0, cards.size() - 1)].duplicate(true)
		expedition_card.emit(expedition["card"])
		return
	if int(expedition["left"]) <= 0:
		_resolve_expedition_return()


func _resolve_expedition_return() -> void:
	var dest_loot: Dictionary = expedition.get("loot", {})
	var people: Array = expedition.get("people", [])
	var danger := int(expedition.get("danger", 30)) - int(expedition.get("ammo", 0)) * 4
	var loot_txt: PackedStringArray = PackedStringArray()
	for sid in people:
		var s := survivor_by_id(sid)
		if s.is_empty():
			continue
		s["away"] = false
		var skill := int(s["skills"].get("scavenge", 0)) + int(s["skills"].get("combat", 0))
		if s.get("trait") == "cesur":
			danger -= 8
		if s.get("trait") == "gezgin":
			skill += 2
		var hit := rng.randi_range(0, 100)
		if hit < clampi(danger - skill * 6, 6, 75):
			var dmg := rng.randi_range(12, 40)
			s["health"] = max(0.0, float(s["health"]) - dmg)
			s["morale"] = max(0.0, float(s["morale"]) - 10.0)
			_log("%s seferde yaralandı (−%d sağlık)." % [s["name"], dmg])
			if float(s["health"]) <= 0.0:
				s["alive"] = false
				_log("%s geri dönemedi." % s["name"])
	for res_name in dest_loot.keys():
		var pair: Array = dest_loot[res_name]
		var amt := rng.randi_range(int(pair[0]), int(pair[1]))
		if amt > 0:
			_add_res(str(res_name), amt)
			loot_txt.append("%s +%d" % [_res_label(str(res_name)), amt])
	_log("Sefer döndü: %s. %s" % [expedition.get("title", ""), ", ".join(loot_txt) if loot_txt else "Boş eller."])
	expedition = {}
	Sfx.play("door")


func _maybe_event() -> void:
	if pending_event:
		return
	if day == 1 and phase < 1:
		return
	if tutorial_done == false and tutorial_step < 4:
		return
	var chance := 0.22
	if phase == 3:
		chance += 0.08
	if rng.randf() > chance:
		return
	var list: Array = defs_events.get("shelter", [])
	if list.is_empty():
		return
	pending_event = list[rng.randi_range(0, list.size() - 1)].duplicate(true)
	event_raised.emit(pending_event)
	Sfx.play("question")


func _daily_roll() -> void:
	var avg := _avg_morale()
	if avg < 18.0:
		low_morale_days += 1
	else:
		low_morale_days = 0
	if rng.randf() < 0.12:
		_maybe_join()
	_log("%d. gün başladı. Moral ort. %d." % [day, int(avg)])


func _maybe_join() -> void:
	if living_survivors().size() >= 8:
		return
	if rng.randf() < 0.45:
		var used: Array = []
		for s in survivors:
			used.append(s["name"])
		var s := _make_survivor(rng.randi_range(0, 5), "", {}, used)
		s["health"] = rng.randi_range(45, 80)
		s["morale"] = rng.randi_range(35, 70)
		survivors.append(s)
		_log("Kapıya biri vurdu: %s sığınağa katıldı." % s["name"])


func _check_endings() -> void:
	var alive := 0
	for s in survivors:
		if s.get("alive", true):
			alive += 1
	if alive == 0:
		_end(false, "Sığınakta kimse kalmadı.")
		return
	if low_morale_days >= 3:
		_end(false, "Umut bitti. Kapılar içeriden açılmadı.")
		return
	if radio_progress >= 100.0:
		_end(true, "Telsiz cevap verdi. Kuzey barajından bir konvoy yola çıktı.")
		return
	if day > 21:
		_end(true, "Yirmi bir gün. Dışarı hâlâ zehir, ama siz durdunuz.")


func _end(win: bool, reason: String) -> void:
	if ended:
		return
	ended = true
	won = win
	end_reason = reason
	speed = 0
	score = day * 12 + int(radio_progress) + living_survivors().size() * 40
	for k in resources.keys():
		score += int(resources[k])
	_log(reason)
	save_game()
	game_ended.emit(win, reason)
	Sfx.play("jingle_win" if win else "jingle_lose")


func _apply_shelter_choice(ev: Dictionary, choice_id: String) -> void:
	var ch := _choice(ev, choice_id)
	if not _can_afford(ch):
		Sfx.play("error")
		return
	_pay(ch)
	match str(ev.get("id")) + ":" + choice_id:
		"raiders:fight":
			_hurt_random(18)
			_add_res("ammo", -0)  # already paid
			_log("Yağmacılar püskürtüldü. Biri kanadı.")
		"raiders:bribe":
			_log("Kapıya bir sandık bırakıldı. Ayak sesleri uzaklaştı.")
		"raiders:hide":
			if rng.randf() < 0.45:
				_add_res("food", -6)
				_hurt_random(10)
				_log("Kapıyı zorladılar. Bir şeyler eksik.")
			else:
				_log("Nefesler tutuldu. Geçtiler.")
		"stranger:accept":
			_maybe_join()
			_log("Yabancı içeri alındı.")
		"stranger:refuse":
			for s in living_survivors():
				s["morale"] = max(0.0, float(s["morale"]) - 4.0)
			_log("Kapı kapanırken dışarıda bir küfür.")
		"stranger:share":
			for s in living_survivors():
				s["morale"] = min(100.0, float(s["morale"]) + 3.0)
		"blackout:fix":
			_add_res("power", 8)
			_log("Jeneratör yeniden öksürerek çalıştı.")
		"blackout:ration":
			_log("Sadece revir ışığı yandı.")
		"blackout:ignore":
			_hurt_random(6)
			_log("Karanlık uzadı.")
		"sickness:meds":
			_heal_all(18)
		"sickness:quarantine":
			_hurt_random(8)
		"sickness:work":
			_hurt_random(16)
			_hurt_random(10)
		"radio_ping:focus":
			radio_progress = min(100.0, radio_progress + 8.0)
		"radio_ping:hope":
			for s in living_survivors():
				s["morale"] = min(100.0, float(s["morale"]) + 6.0)
		"leak:patch":
			_add_res("water", 4)
		"leak:bucket":
			_add_res("water", 2)
		"leak:cut":
			_add_res("water", -3)
		"dream:sing":
			for s in living_survivors():
				s["morale"] = min(100.0, float(s["morale"]) + 8.0)
		"dream:record":
			radio_progress = min(100.0, radio_progress + 4.0)
		"fight:mediate":
			for s in living_survivors():
				s["morale"] = min(100.0, float(s["morale"]) + 2.0)
		"fight:punish":
			_hurt_random(4)
			for s in living_survivors():
				s["morale"] = max(0.0, float(s["morale"]) - 3.0)
		"cavein:brace":
			_log("Kiriş yerine oturdu. Toz durdu.")
		"cavein:move":
			_hurt_random(6)
		"cavein:pray":
			if rng.randf() < 0.4:
				_hurt_random(22)
				_log("Tavan bir köşeden çöktü.")
		"garden:cheer":
			for s in living_survivors():
				s["morale"] = min(100.0, float(s["morale"]) + 5.0)
			_add_res("food", 2)
		"ammo_cache:take":
			_add_res("ammo", rng.randi_range(4, 9))
		"ammo_cache:share":
			_add_res("ammo", 5)
			for s in living_survivors():
				s["morale"] = min(100.0, float(s["morale"]) + 3.0)
		"night_noise:listen":
			radio_progress = min(100.0, radio_progress + 3.0)
		"night_noise:patrol":
			if int(resources["ammo"]) >= 1:
				resources["ammo"] -= 1
	_log("Karar: %s" % ch.get("label", choice_id))


func _apply_exp_choice(ev: Dictionary, choice_id: String) -> void:
	var ch := _choice(ev, choice_id)
	if not _can_afford(ch):
		Sfx.play("error")
		return
	_pay(ch)
	match choice_id:
		"grab", "search":
			_add_res("food", rng.randi_range(1, 4))
			_add_res("scrap", rng.randi_range(0, 3))
		"ambush":
			_add_res("ammo", rng.randi_range(1, 3))
			_hurt_away(10)
		"descend", "sample":
			_add_res("water", rng.randi_range(2, 6))
		"trade":
			radio_progress = min(100.0, radio_progress + 10.0)
		"rob":
			if rng.randf() < 0.5:
				_add_res("medicine", 2)
			else:
				_hurt_away(20)
		_:
			pass
	_log("Sefer kararı: %s" % ch.get("label", choice_id))


func _choice(ev: Dictionary, id: String) -> Dictionary:
	for c in ev.get("choices", []):
		if c.get("id") == id:
			return c
	return {}


func _can_afford(ch: Dictionary) -> bool:
	for k in ["need_ammo", "need_food", "need_water", "need_scrap", "need_medicine"]:
		var key := str(k)
		var res: String = key.replace("need_", "")
		if int(ch.get(key, 0)) > int(resources.get(res, 0)):
			return false
	return true


func _pay(ch: Dictionary) -> void:
	for k in ["need_ammo", "need_food", "need_water", "need_scrap", "need_medicine"]:
		var key := str(k)
		var res: String = key.replace("need_", "")
		var n := int(ch.get(key, 0))
		if n > 0:
			resources[res] = int(resources[res]) - n


func _add_res(name: String, amt: int) -> void:
	if not resources.has(name):
		return
	resources[name] = clampi(int(resources[name]) + amt, 0, int(caps.get(name, 99)))


func _heal_lowest(amount: int) -> void:
	var best: Dictionary = {}
	var hp := 999.0
	for s in living_survivors():
		if float(s["health"]) < hp:
			hp = float(s["health"])
			best = s
	if best:
		best["health"] = min(100.0, float(best["health"]) + amount)


func _heal_all(amount: int) -> void:
	for s in living_survivors():
		s["health"] = min(100.0, float(s["health"]) + amount)


func _hurt_random(amount: int) -> void:
	var live := living_survivors()
	if live.is_empty():
		return
	var s: Dictionary = live[rng.randi_range(0, live.size() - 1)]
	s["health"] = max(0.0, float(s["health"]) - amount)


func _hurt_away(amount: int) -> void:
	for sid in expedition.get("people", []):
		var s := survivor_by_id(sid)
		if s:
			s["health"] = max(0.0, float(s["health"]) - amount)


func _workers_of(room: Dictionary) -> Array:
	var out: Array = []
	for s in survivors:
		if s.get("alive", true) and not s.get("away", false) and s.get("room") == room.get("id"):
			out.append(s)
	return out


func _assign(sid: String, room_id: String) -> void:
	var s := survivor_by_id(sid)
	var r := room_by_id(room_id)
	if s.is_empty() or r.is_empty():
		return
	if r.get("type") in ["empty", ""]:
		return
	var cap := int(defs_rooms.get(r["type"], {}).get("workers", 2)) + int(r.get("level", 1)) - 1
	if _workers_of(r).size() >= cap and s.get("room") != room_id:
		Sfx.play("error")
		return
	s["room"] = room_id
	selected_survivor = ""
	Sfx.play("switch")


func _add_room(type: String, floor: int, slot: int) -> void:
	rooms.append({
		"id": "r%d" % room_seq, "type": type, "floor": floor, "slot": slot,
		"level": 1, "built": true
	})
	room_seq += 1


func _add_empty(floor: int, slot: int) -> void:
	rooms.append({
		"id": "r%d" % room_seq, "type": "empty", "floor": floor, "slot": slot,
		"level": 0, "built": false
	})
	room_seq += 1


func _make_survivor(portrait: int, trait_id: String, skills: Dictionary, used_names: Array) -> Dictionary:
	var names: Array = defs_names.get("first", ["Ada", "Ege"])
	var n := "Kişi %d" % survivor_seq
	for attempt in range(12):
		var cand: String = names[rng.randi_range(0, names.size() - 1)]
		if not used_names.has(cand):
			n = cand
			break
	used_names.append(n)
	if trait_id == "":
		var traits: Array = defs_names.get("traits", [])
		if traits:
			trait_id = str(traits[rng.randi_range(0, traits.size() - 1)].get("id", "caliskan"))
	if skills.is_empty():
		skills = {
			"tech": rng.randi_range(0, 3), "combat": rng.randi_range(0, 3),
			"scavenge": rng.randi_range(0, 3), "medical": rng.randi_range(0, 3),
			"cook": rng.randi_range(0, 3)
		}
	var s := {
		"id": "s%d" % survivor_seq, "name": n, "portrait": portrait % 6,
		"trait": trait_id, "skills": skills, "health": 100.0, "hunger": 78.0,
		"thirst": 74.0, "morale": 70.0, "alive": true, "away": false, "room": ""
	}
	survivor_seq += 1
	return s


func _recompute_caps() -> void:
	var bonus := 0
	for r in rooms:
		if r.get("type") == "storage":
			bonus += 18 * int(r.get("level", 1))
	caps = {
		"food": 60 + bonus, "water": 60 + bonus, "power": 40 + bonus / 2,
		"medicine": 24 + bonus / 3, "scrap": 80 + bonus, "ammo": 24 + bonus / 3
	}


func _avg_morale() -> float:
	var live := living_survivors()
	if live.is_empty():
		return 0.0
	var t := 0.0
	for s in live:
		t += float(s["morale"])
	return t / float(live.size())


func _log(msg: String) -> void:
	log_lines.append("G%d %s — %s" % [day, PHASE_NAMES[phase], msg])
	if log_lines.size() > 80:
		log_lines = log_lines.slice(-80)


func _res_label(id: String) -> String:
	match id:
		"food": return "Yiyecek"
		"water": return "Su"
		"power": return "Elektrik"
		"medicine": return "İlaç"
		"scrap": return "Hurda"
		"ammo": return "Cephane"
		_: return id


func trait_title(id: String) -> String:
	for t in defs_names.get("traits", []):
		if t.get("id") == id:
			return str(t.get("title", id))
	return id


func room_title(type: String) -> String:
	return str(defs_rooms.get(type, {}).get("title", "Boş Oyuk" if type == "empty" else type))


func resource_summary() -> Array:
	return ["food", "water", "power", "medicine", "scrap", "ammo"]
