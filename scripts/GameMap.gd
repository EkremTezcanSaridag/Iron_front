extends Control

var selected_province: String = ""
var map_view: Node2D

func _ready():
	map_view = $MapViewport/SubViewport/MapView
	update_ui()
	GameManager.turn_ended.connect(_on_turn_ended)
	GameManager.game_over_signal.connect(_on_game_over)
	
	# Auto-save every turn
	GameManager.turn_ended.connect(func(): GameManager.save_game())
	
	# Connect map view signals
	map_view.province_selected.connect(_on_province_selected)
	
	populate_tabs()

func update_ui():
	var player_country = GameManager.player_country
	if player_country == "":
		return
	
	var country = GameManager.countries[player_country]
	
	# Update top bar
	$UI/TopBar/HBoxContainer/CountryInfo/CountryName.text = country["name"]
	$UI/TopBar/HBoxContainer/CountryInfo/TurnLabel.text = "Tur: " + str(GameManager.current_turn)
	
	$UI/TopBar/HBoxContainer/Resources/MoneyLabel.text = "Para: " + str(country["current_resources"]["money"])
	$UI/TopBar/HBoxContainer/Resources/ManpowerLabel.text = "İnsan Gücü: " + str(country["current_resources"]["manpower"])
	$UI/TopBar/HBoxContainer/Resources/IndustryLabel.text = "Sanayi: " + str(country["current_resources"]["industry"])
	
	$UI/TopBar/HBoxContainer/Status/StabilityLabel.text = "İstikrar: " + str(country["stability"])
	$UI/TopBar/HBoxContainer/Status/WarWearinessLabel.text = "Savaş Yorgunluğu: " + str(country["war_weariness"])
	
	# Update province info if selected
	if selected_province != "":
		update_province_info()

func update_province_info():
	if selected_province == "" or not GameManager.provinces.has(selected_province):
		return
	
	var province = GameManager.provinces[selected_province]
	
	$UI/RightPanel/ProvinceInfo/ProvinceName.text = province["name"]
	$UI/RightPanel/ProvinceInfo/Owner.text = "Sahip: " + GameManager.countries[province["owner"]]["name"]
	
	var unit_count = 0
	if GameManager.units.has(selected_province):
		unit_count = GameManager.units[selected_province].size()
	$UI/RightPanel/ProvinceInfo/UnitsLabel.text = "Birlikler: " + str(unit_count)
	
	var resources = province["base_resources"]
	$UI/RightPanel/ProvinceInfo/ResourcesLabel.text = "Kaynaklar:\nPara: " + str(resources["money"]) + "\nİnsan Gücü: " + str(resources["manpower"]) + "\nSanayi: " + str(resources["industry"])
	
	# Enable/disable recruit buttons
	var can_recruit = province["owner"] == GameManager.player_country
	$UI/RightPanel/ProvinceInfo/RecruitButton.disabled = not can_recruit
	$UI/RightPanel/ProvinceInfo/RecruitCavalryButton.disabled = not can_recruit
	$UI/RightPanel/ProvinceInfo/RecruitArtilleryButton.disabled = not can_recruit

func _on_province_selected(province_id: String):
	selected_province = province_id
	update_province_info()

func _on_end_turn_pressed():
	GameManager.end_turn()

func _on_turn_ended():
	update_ui()
	populate_tabs()
	map_view.queue_redraw()

func _on_menu_pressed():
	var popup = AcceptDialog.new()
	popup.dialog_text = "Ana menüye dönmek istiyor musunuz?"
	popup.add_button("Evet", true, "confirm")
	popup.custom_action.connect(func(action):
		if action == "confirm":
			get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
	add_child(popup)
	popup.popup_centered()

func _on_recruit_pressed(unit_type: String):
	if selected_province != "":
		if GameManager.recruit_unit(GameManager.player_country, selected_province, unit_type):
			update_ui()
			map_view.queue_redraw()

func _on_panel_toggle_pressed():
	$UI/BottomPanel.visible = not $UI/BottomPanel.visible

func populate_tabs():
	# Clear existing content
	for child in $UI/BottomPanel/TabContainer/Eyaletler/ProvinceList.get_children():
		child.queue_free()
	for child in $UI/BottomPanel/TabContainer/Diplomasi/DiplomacyList.get_children():
		child.queue_free()
	var kader_tab = $UI/BottomPanel/TabContainer.get_node("Kader Yolları")
	for child in kader_tab.get_node("KaderList").get_children():
		child.queue_free()
	for child in $UI/BottomPanel/TabContainer/Araştırma/ResearchList.get_children():
		child.queue_free()
	
	populate_provinces_tab()
	populate_diplomacy_tab()
	populate_kader_tab()
	populate_research_tab()

func populate_provinces_tab():
	var province_list = $UI/BottomPanel/TabContainer/Eyaletler/ProvinceList
	
	var player_country = GameManager.player_country
	var provinces = GameManager.provinces
	
	var label = Label.new()
	label.add_theme_font_size_override("font_size", 28)
	label.text = "Eyaletleriniz"
	province_list.add_child(label)
	
	for prov_id in provinces:
		var prov = provinces[prov_id]
		if prov["owner"] == player_country:
			var prov_button = Button.new()
			prov_button.custom_minimum_size = Vector2(0, 60)
			prov_button.add_theme_font_size_override("font_size", 20)
			var unit_count = 0
			if GameManager.units.has(prov_id):
				unit_count = GameManager.units[prov_id].size()
			prov_button.text = prov["name"] + " (Birlikler: " + str(unit_count) + ")"
			prov_button.pressed.connect(func(): _on_province_selected(prov_id))
			province_list.add_child(prov_button)

func populate_diplomacy_tab():
	var diplomacy_list = $UI/BottomPanel/TabContainer/Diplomasi/DiplomacyList
	
	var label = Label.new()
	label.add_theme_font_size_override("font_size", 28)
	label.text = "Diplomasi"
	diplomacy_list.add_child(label)
	
	var info = Label.new()
	info.add_theme_font_size_override("font_size", 20)
	info.text = "Diğer ülkelerle ilişkiler ve ittifaklar"
	diplomacy_list.add_child(info)
	
	# Show alliances
	var alliance_label = Label.new()
	alliance_label.add_theme_font_size_override("font_size", 24)
	alliance_label.text = "\nİttifakınız:"
	diplomacy_list.add_child(alliance_label)
	
	var player_alliance = ""
	for alliance_name in GameManager.alliances:
		if GameManager.player_country in GameManager.alliances[alliance_name]:
			player_alliance = alliance_name
			break
	
	if player_alliance != "":
		for country_id in GameManager.alliances[player_alliance]:
			if country_id != GameManager.player_country:
				var ally_label = Label.new()
				ally_label.add_theme_font_size_override("font_size", 20)
				ally_label.text = "- " + GameManager.countries[country_id]["name"]
				diplomacy_list.add_child(ally_label)

func populate_kader_tab():
	var kader_tab = $UI/BottomPanel/TabContainer.get_node("Kader Yolları")
	var kader_list = kader_tab.get_node("KaderList")
	
	var label = Label.new()
	label.add_theme_font_size_override("font_size", 28)
	label.text = "Kader Yolları"
	kader_list.add_child(label)
	
	var info = Label.new()
	info.add_theme_font_size_override("font_size", 18)
	info.text = "Ülkenizin geleceğini şekillendirecek önemli kararlar"
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	kader_list.add_child(info)
	
	var country = GameManager.countries[GameManager.player_country]
	var paths = country.get("kader_paths", {})
	
	for path_id in paths:
		var path = paths[path_id]
		
		# Check requirements
		if path.has("requires"):
			var req = path["requires"]
			if not GameManager.events.has(req):
				continue
		
		var hsep = HSeparator.new()
		kader_list.add_child(hsep)
		
		var path_label = Label.new()
		path_label.add_theme_font_size_override("font_size", 24)
		path_label.text = path["name"]
		kader_list.add_child(path_label)
		
		var desc_label = Label.new()
		desc_label.add_theme_font_size_override("font_size", 18)
		desc_label.text = path["description"]
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		kader_list.add_child(desc_label)
		
		# Show decisions
		for decision in path["decisions"]:
			var decision_id = decision["id"]
			
			# Check if already completed
			var completed = false
			if GameManager.completed_decisions.has(GameManager.player_country):
				completed = decision_id in GameManager.completed_decisions[GameManager.player_country]
			
			# Check if currently active
			var active = false
			if GameManager.active_decisions.has(GameManager.player_country):
				for active_dec in GameManager.active_decisions[GameManager.player_country]:
					if active_dec["id"] == decision_id:
						active = true
						break
			
			var dec_button = Button.new()
			dec_button.custom_minimum_size = Vector2(0, 50)
			dec_button.add_theme_font_size_override("font_size", 18)
			
			if completed:
				dec_button.text = "✓ " + decision["name"]
				dec_button.disabled = true
			elif active:
				dec_button.text = "⏳ " + decision["name"] + " (Kalan: " + str(decision.get("turns_remaining", decision["turns"])) + " tur)"
				dec_button.disabled = true
			else:
				dec_button.text = decision["name"] + " (" + str(decision["turns"]) + " tur)"
				dec_button.pressed.connect(func(): start_decision(path_id, decision))
			
			kader_list.add_child(dec_button)

func start_decision(path_id: String, decision: Dictionary):
	GameManager.start_decision(GameManager.player_country, path_id, decision)
	populate_tabs()

func populate_research_tab():
	var research_list = $UI/BottomPanel/TabContainer/Araştırma/ResearchList
	
	var label = Label.new()
	label.add_theme_font_size_override("font_size", 28)
	label.text = "Teknoloji Araştırması"
	research_list.add_child(label)
	
	var info = Label.new()
	info.add_theme_font_size_override("font_size", 18)
	info.text = "Yeni teknolojiler geliştir"
	research_list.add_child(info)
	
	for tech in GameManager.available_techs:
		var researched = false
		if GameManager.research.has(GameManager.player_country):
			researched = tech["id"] in GameManager.research[GameManager.player_country]
		
		var tech_button = Button.new()
		tech_button.custom_minimum_size = Vector2(0, 60)
		tech_button.add_theme_font_size_override("font_size", 20)
		
		if researched:
			tech_button.text = "✓ " + tech["name"]
			tech_button.disabled = true
		else:
			tech_button.text = tech["name"] + " (Maliyet: " + str(tech["cost"]) + " Sanayi)"
			tech_button.pressed.connect(func(): research_tech(tech))
		
		research_list.add_child(tech_button)

func research_tech(tech: Dictionary):
	var country = GameManager.countries[GameManager.player_country]
	if country["current_resources"]["industry"] >= tech["cost"]:
		country["current_resources"]["industry"] -= tech["cost"]
		if not GameManager.research.has(GameManager.player_country):
			GameManager.research[GameManager.player_country] = []
		GameManager.research[GameManager.player_country].append(tech["id"])
		update_ui()
		populate_tabs()

func _on_game_over(reason: String):
	var popup = AcceptDialog.new()
	popup.dialog_text = reason
	popup.confirmed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	add_child(popup)
	popup.popup_centered()
