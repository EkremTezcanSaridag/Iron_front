extends Node

# Game state
var current_turn: int = 0
var max_turns: int = 200  # ~4 years of war
var game_started: bool = false
var player_country: String = ""
var game_over: bool = false
var game_over_reason: String = ""

# Data structures
var countries: Dictionary = {}
var provinces: Dictionary = {}
var units: Dictionary = {}  # province_id -> array of units
var alliances: Dictionary = {
	"central_powers": ["germany", "austria_hungary", "ottoman_empire"],
	"entente": ["france", "united_kingdom", "russia", "serbia"],
	"neutral": ["italy"]
}
var wars: Array = []  # Array of {attacker_alliance, defender_alliance, start_turn}
var relations: Dictionary = {}  # country_pair -> int (-100 to 100)
var active_decisions: Dictionary = {}  # country -> array of active decisions
var completed_decisions: Dictionary = {}  # country -> array of completed decision ids
var research: Dictionary = {}  # country -> array of researched tech ids
var events: Dictionary = {}  # Special events that happened

# Technologies
var available_techs: Array = [
	{"id": "machine_guns", "name": "Makineli Tüfekler", "cost": 100, "effect": "defense_+20"},
	{"id": "tanks", "name": "Tanklar", "cost": 150, "effect": "attack_+25"},
	{"id": "poison_gas", "name": "Zehirli Gaz", "cost": 120, "effect": "attack_+15"},
	{"id": "aircraft", "name": "Uçaklar", "cost": 130, "effect": "recon_+30"},
	{"id": "artillery", "name": "Ağır Topçu", "cost": 110, "effect": "attack_+20"}
]

# Signals
signal turn_ended
signal game_over_signal(reason: String)
signal country_capitulated(country: String)

func _ready():
	load_game_data()

func load_game_data():
	# Load countries
	var countries_file = FileAccess.open("res://data/countries.json", FileAccess.READ)
	if countries_file:
		var json = JSON.new()
		var parse_result = json.parse(countries_file.get_as_text())
		if parse_result == OK:
			countries = json.data
		countries_file.close()
	
	# Load provinces
	var provinces_file = FileAccess.open("res://data/provinces.json", FileAccess.READ)
	if provinces_file:
		var json = JSON.new()
		var parse_result = json.parse(provinces_file.get_as_text())
		if parse_result == OK:
			provinces = json.data
		provinces_file.close()
	
	# Initialize countries with starting resources
	for country_id in countries:
		var country = countries[country_id]
		if not country.has("current_resources"):
			country["current_resources"] = country["starting_resources"].duplicate()
		if not country.has("stability"):
			country["stability"] = 100
		if not country.has("war_weariness"):
			country["war_weariness"] = 0
		if not country.has("is_capitulated"):
			country["is_capitulated"] = false
	
	# Initialize relations
	for country_id in countries:
		for other_id in countries:
			if country_id != other_id:
				var key = _get_relation_key(country_id, other_id)
				if not relations.has(key):
					# Same alliance = positive, different = negative
					if _are_allied(country_id, other_id):
						relations[key] = 50
					else:
						relations[key] = -20

func start_game(selected_country: String):
	player_country = selected_country
	current_turn = 0
	game_started = true
	game_over = false
	
	# Initialize starting units for all countries
	for country_id in countries:
		var country = countries[country_id]
		var core_provinces_list = country["core_provinces"]
		for prov_id in core_provinces_list:
			if provinces.has(prov_id) and provinces[prov_id]["owner"] == country_id:
				# Start with 2 infantry units in each core province
				if not units.has(prov_id):
					units[prov_id] = []
				units[prov_id].append(create_unit("infantry", country_id))
				units[prov_id].append(create_unit("infantry", country_id))
	
	# Start the initial war (Austria vs Serbia triggers WW1)
	wars.append({
		"attackers": ["austria_hungary"],
		"defenders": ["serbia"],
		"start_turn": 1
	})

func create_unit(type: String, owner: String) -> Dictionary:
	var unit_stats = {
		"infantry": {"attack": 10, "defense": 15, "cost_money": 50, "cost_manpower": 30},
		"artillery": {"attack": 20, "defense": 8, "cost_money": 80, "cost_manpower": 20},
		"cavalry": {"attack": 15, "defense": 10, "cost_money": 60, "cost_manpower": 25}
	}
	
	var stats = unit_stats.get(type, unit_stats["infantry"])
	return {
		"type": type,
		"owner": owner,
		"attack": stats["attack"],
		"defense": stats["defense"],
		"health": 100,
		"entrenched": false
	}

func end_turn():
	current_turn += 1
	
	# Process all countries (AI and player)
	for country_id in countries:
		if countries[country_id]["is_capitulated"]:
			continue
		
		# Collect resources
		collect_resources(country_id)
		
		# Increase war weariness
		if is_at_war(country_id):
			countries[country_id]["war_weariness"] += 2
			countries[country_id]["stability"] -= 1
		
		# Process active decisions
		process_decisions(country_id)
		
		# AI turn
		if country_id != player_country:
			ai_turn(country_id)
	
	# Entrench units
	for prov_id in units:
		for unit in units[prov_id]:
			unit["entrenched"] = true
	
	# Check win/lose conditions
	check_game_over()
	
	emit_signal("turn_ended")

func collect_resources(country_id: String):
	var country = countries[country_id]
	var total_resources = {"money": 0, "manpower": 0, "industry": 0}
	
	for prov_id in provinces:
		if provinces[prov_id]["owner"] == country_id:
			var prov = provinces[prov_id]
			total_resources["money"] += prov["base_resources"]["money"]
			total_resources["manpower"] += prov["base_resources"]["manpower"]
			total_resources["industry"] += prov["base_resources"]["industry"]
	
	country["current_resources"]["money"] += total_resources["money"]
	country["current_resources"]["manpower"] += total_resources["manpower"]
	country["current_resources"]["industry"] += total_resources["industry"]

func recruit_unit(country_id: String, province_id: String, unit_type: String) -> bool:
	var country = countries[country_id]
	var unit_stats = {
		"infantry": {"cost_money": 50, "cost_manpower": 30},
		"artillery": {"cost_money": 80, "cost_manpower": 20},
		"cavalry": {"cost_money": 60, "cost_manpower": 25}
	}
	
	var cost = unit_stats.get(unit_type, unit_stats["infantry"])
	
	if country["current_resources"]["money"] >= cost["cost_money"] and \
	   country["current_resources"]["manpower"] >= cost["cost_manpower"]:
		country["current_resources"]["money"] -= cost["cost_money"]
		country["current_resources"]["manpower"] -= cost["cost_manpower"]
		
		if not units.has(province_id):
			units[province_id] = []
		units[province_id].append(create_unit(unit_type, country_id))
		return true
	return false

func move_units(from_province: String, to_province: String, unit_count: int) -> bool:
	if not units.has(from_province) or units[from_province].size() < unit_count:
		return false
	
	var from_prov = provinces[from_province]
	var to_prov = provinces[to_province]
	
	# Check if provinces are connected
	if not to_province in from_prov["connections"]:
		return false
	
	# Check if we own both provinces or are moving to attack
	var owner = units[from_province][0]["owner"]
	
	if not units.has(to_province):
		units[to_province] = []
	
	# Move units
	for i in range(unit_count):
		var unit = units[from_province].pop_back()
		unit["entrenched"] = false
		units[to_province].append(unit)
	
	# If moving to enemy province, trigger combat
	if to_prov["owner"] != owner:
		return resolve_combat(to_province)
	
	return true

func resolve_combat(province_id: String) -> bool:
	if not units.has(province_id) or units[province_id].size() == 0:
		return true
	
	var province = provinces[province_id]
	var defender_country = province["owner"]
	
	# Separate attackers and defenders
	var attackers = []
	var defenders = []
	
	for unit in units[province_id]:
		if unit["owner"] == defender_country:
			defenders.append(unit)
		else:
			attackers.append(unit)
	
	if attackers.size() == 0 or defenders.size() == 0:
		return true
	
	# Calculate combat power
	var attacker_power = 0
	var defender_power = 0
	
	for unit in attackers:
		attacker_power += unit["attack"]
	
	for unit in defenders:
		defender_power += unit["defense"]
		if unit["entrenched"]:
			defender_power += unit["defense"] * 0.5  # 50% bonus for entrenchment
	
	# Add some randomness
	attacker_power *= (0.8 + randf() * 0.4)
	defender_power *= (0.8 + randf() * 0.4)
	
	# Apply casualties
	var attacker_casualties = int(defender_power / 10.0)
	var defender_casualties = int(attacker_power / 10.0)
	
	# Remove destroyed units
	while attacker_casualties > 0 and attackers.size() > 0:
		attackers.pop_back()
		attacker_casualties -= 1
	
	while defender_casualties > 0 and defenders.size() > 0:
		defenders.pop_back()
		defender_casualties -= 1
	
	# Determine winner
	var attacker_won = attacker_power > defender_power
	
	if attacker_won and attackers.size() > 0:
		# Attackers win, take province
		province["owner"] = attackers[0]["owner"]
		units[province_id] = attackers
		return true
	else:
		# Defenders hold
		units[province_id] = defenders + attackers
		return false

func is_at_war(country_id: String) -> bool:
	for war in wars:
		if country_id in war["attackers"] or country_id in war["defenders"]:
			return true
	return false

func get_enemies(country_id: String) -> Array:
	var enemies = []
	for war in wars:
		if country_id in war["attackers"]:
			enemies.append_array(war["defenders"])
		elif country_id in war["defenders"]:
			enemies.append_array(war["attackers"])
	return enemies

func _are_allied(country1: String, country2: String) -> bool:
	for alliance_name in alliances:
		var alliance = alliances[alliance_name]
		if country1 in alliance and country2 in alliance:
			return true
	return false

func _get_relation_key(country1: String, country2: String) -> String:
	var sorted = [country1, country2]
	sorted.sort()
	return sorted[0] + "_" + sorted[1]

func process_decisions(country_id: String):
	if not active_decisions.has(country_id):
		return
	
	for decision in active_decisions[country_id]:
		decision["turns_remaining"] -= 1
		if decision["turns_remaining"] <= 0:
			# Decision completed
			apply_decision_effect(country_id, decision)
			if not completed_decisions.has(country_id):
				completed_decisions[country_id] = []
			completed_decisions[country_id].append(decision["id"])
	
	# Remove completed decisions
	if active_decisions.has(country_id):
		active_decisions[country_id] = active_decisions[country_id].filter(
			func(d): return d["turns_remaining"] > 0
		)

func start_decision(country_id: String, path_id: String, decision_data: Dictionary):
	if not active_decisions.has(country_id):
		active_decisions[country_id] = []
	
	var decision = decision_data.duplicate()
	decision["path_id"] = path_id
	decision["turns_remaining"] = decision["turns"]
	active_decisions[country_id].append(decision)

func apply_decision_effect(country_id: String, decision: Dictionary):
	var effect = decision["effect"]
	var country = countries[country_id]
	
	# Parse and apply effects (simplified)
	if effect.begins_with("stability_+"):
		var amount = int(effect.substr(11))
		country["stability"] += amount
	elif effect.begins_with("industry_+"):
		var amount = int(effect.substr(10))
		country["current_resources"]["industry"] += amount
	elif effect.begins_with("manpower_+"):
		var amount = int(effect.substr(10))
		country["current_resources"]["manpower"] += amount
	elif effect == "join_central_powers":
		alliances["central_powers"].append(country_id)
		if country_id in alliances["neutral"]:
			alliances["neutral"].erase(country_id)
	elif effect == "join_entente":
		alliances["entente"].append(country_id)
		if country_id in alliances["neutral"]:
			alliances["neutral"].erase(country_id)

func ai_turn(country_id: String):
	var country = countries[country_id]
	
	# Simple AI: recruit units, move to frontlines, attack enemies
	# 1. Recruit units in capital if resources available
	var capital = country["capital"]
	if country["current_resources"]["money"] > 100 and \
	   country["current_resources"]["manpower"] > 50:
		recruit_unit(country_id, capital, "infantry")
	
	# 2. Find enemy border provinces and attack
	if is_at_war(country_id):
		var enemies = get_enemies(country_id)
		for prov_id in provinces:
			var prov = provinces[prov_id]
			if prov["owner"] == country_id and units.has(prov_id):
				# Check for enemy neighbors
				for conn_id in prov["connections"]:
					if provinces[conn_id]["owner"] in enemies:
						# Attack with half of units
						var unit_count = int(units[prov_id].size() / 2.0)
						if unit_count > 0:
							move_units(prov_id, conn_id, unit_count)
						break

func check_game_over():
	# Check if player capitulated
	if countries[player_country]["is_capitulated"]:
		game_over = true
		game_over_reason = "Ülkeniz yenildi!"
		emit_signal("game_over_signal", game_over_reason)
		return
	
	# Check if all enemies capitulated
	var enemies = get_enemies(player_country)
	var all_defeated = true
	for enemy in enemies:
		if not countries[enemy]["is_capitulated"]:
			all_defeated = false
			break
	
	if all_defeated and enemies.size() > 0:
		game_over = true
		game_over_reason = "Zafer! Tüm düşmanları yendiniz!"
		emit_signal("game_over_signal", game_over_reason)
		return
	
	# Check max turns
	if current_turn >= max_turns:
		game_over = true
		game_over_reason = "Savaş sona erdi. Ayakta kaldınız!"
		emit_signal("game_over_signal", game_over_reason)
		return
	
	# Check capitulation conditions for all countries
	for country_id in countries:
		if countries[country_id]["is_capitulated"]:
			continue
		
		var country = countries[country_id]
		var core_provinces_list = country["core_provinces"]
		var controlled = 0
		for prov_id in core_provinces_list:
			if provinces.has(prov_id) and provinces[prov_id]["owner"] == country_id:
				controlled += 1
		
		# Capitulate if lost more than 75% of core provinces or stability collapsed
		if controlled < core_provinces_list.size() * 0.25 or country["stability"] <= 0:
			country["is_capitulated"] = true
			emit_signal("country_capitulated", country_id)

func save_game():
	var save_data = {
		"current_turn": current_turn,
		"player_country": player_country,
		"countries": countries,
		"provinces": provinces,
		"units": units,
		"alliances": alliances,
		"wars": wars,
		"relations": relations,
		"active_decisions": active_decisions,
		"completed_decisions": completed_decisions,
		"research": research,
		"events": events
	}
	
	var save_file = FileAccess.open("user://savegame.json", FileAccess.WRITE)
	if save_file:
		save_file.store_string(JSON.stringify(save_data))
		save_file.close()
		return true
	return false

func load_game() -> bool:
	var save_file = FileAccess.open("user://savegame.json", FileAccess.READ)
	if not save_file:
		return false
	
	var json = JSON.new()
	var parse_result = json.parse(save_file.get_as_text())
	save_file.close()
	
	if parse_result != OK:
		return false
	
	var save_data = json.data
	current_turn = save_data["current_turn"]
	player_country = save_data["player_country"]
	countries = save_data["countries"]
	provinces = save_data["provinces"]
	units = save_data["units"]
	alliances = save_data["alliances"]
	wars = save_data["wars"]
	relations = save_data["relations"]
	active_decisions = save_data["active_decisions"]
	completed_decisions = save_data["completed_decisions"]
	research = save_data["research"]
	events = save_data["events"]
	game_started = true
	
	return true
