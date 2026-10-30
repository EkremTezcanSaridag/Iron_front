extends Control

var country_buttons: Dictionary = {}

func _ready():
	populate_country_list()

func populate_country_list():
	var country_list = $VBoxContainer/ScrollContainer/CountryList
	
	# Get countries from GameManager
	var countries = GameManager.countries
	
	for country_id in countries:
		var country = countries[country_id]
		
		var button = Button.new()
		button.custom_minimum_size = Vector2(0, 100)
		button.add_theme_font_size_override("font_size", 28)
		
		# Create button text with country info
		var button_text = country["name"]
		var alliance = get_alliance(country_id)
		button_text += "\n[" + alliance + "]"
		
		button.text = button_text
		button.pressed.connect(_on_country_selected.bind(country_id))
		
		country_list.add_child(button)
		country_buttons[country_id] = button

func get_alliance(country_id: String) -> String:
	for alliance_name in GameManager.alliances:
		if country_id in GameManager.alliances[alliance_name]:
			if alliance_name == "central_powers":
				return "Merkezi Güçler"
			elif alliance_name == "entente":
				return "İtilaf"
			elif alliance_name == "neutral":
				return "Tarafsız"
	return "Tarafsız"

func _on_country_selected(country_id: String):
	GameManager.start_game(country_id)
	get_tree().change_scene_to_file("res://scenes/GameMap.tscn")

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
