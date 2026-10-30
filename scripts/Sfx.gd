extends Node
## Lightweight SFX + looping ambient player.

var _players: Dictionary = {}
var music: AudioStreamPlayer
var muted := false


func _ready() -> void:
	music = AudioStreamPlayer.new()
	music.bus = "Master"
	music.volume_db = -12.0
	add_child(music)


func play(name: String, vol_db: float = -6.0) -> void:
	if muted:
		return
	var path := "res://assets/audio/%s.ogg" % name
	if name.begins_with("jingle") or name in ["ambient", "menu_ambient"]:
		path = "res://assets/audio/%s.ogg" % name
	if not ResourceLoader.exists(path):
		if ResourceLoader.exists("res://assets/audio/%s.wav" % name):
			path = "res://assets/audio/%s.wav" % name
		else:
			return
	var p: AudioStreamPlayer = _players.get(name)
	if p == null:
		p = AudioStreamPlayer.new()
		add_child(p)
		_players[name] = p
	p.stream = load(path)
	p.volume_db = vol_db
	p.play()


func play_music(name: String) -> void:
	if muted:
		return
	var path := "res://assets/audio/%s.wav" % name
	if not ResourceLoader.exists(path):
		path = "res://assets/audio/%s.ogg" % name
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	music.stream = stream
	music.play()


func stop_music() -> void:
	music.stop()
