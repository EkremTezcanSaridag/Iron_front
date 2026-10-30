extends Control

func _ready():
	# Check if save exists
	var save_exists = FileAccess.file_exists("user://savegame.json")
	$VBoxContainer/ContinueButton.disabled = not save_exists

func _on_new_game_pressed():
	get_tree().change_scene_to_file("res://scenes/CountryPicker.tscn")

func _on_continue_pressed():
	if GameManager.load_game():
		get_tree().change_scene_to_file("res://scenes/GameMap.tscn")

func _on_exit_pressed():
	get_tree().quit()
