


class_name Audio
extends Node

signal song_changed(song: Music_Titles)

enum Music_Titles{
	NONE
}

enum  SFX_Titles {
	NONE
}

@onready var music_player: AudioStreamPlayer = AudioStreamPlayer.new()

var music: Dictionary = {
}

var sfx: Dictionary = {
}

const SFX_POOL_SIZE: int = 12
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_next: int = 0

var master_bus: int = AudioServer.get_bus_index("Master")
var music_bus: int = AudioServer.get_bus_index("Music")
var sfx_bus: int = AudioServer.get_bus_index("SFX")

var audio_manager: Node = null:
	set(value):
		audio_manager = value
		_add_music_player()

var _last_random_key: Music_Titles = 0 as Music_Titles

var _loop: bool = false
var _random_play: bool = false

var current_song: Music_Titles

func _ready() -> void :
	_load_settings()


func _add_music_player() -> void :
	music_player.bus = &"Music"
	var playlist: AudioStreamPlaylist = AudioStreamPlaylist.new()
	playlist.stream_count = music.size()
	var i: int = 0
	for song: AudioStream in music.values():
		playlist.set_list_stream(i, song)
		i += 1
	playlist.shuffle = false
	playlist.loop = false
	music_player.stream = playlist
	music_player.finished.connect(_play_next_song)
	audio_manager.add_child(music_player)
	_setup_sfx_pool()


func set_master_volume(percent: float) -> void :
	AudioServer.set_bus_volume_db(master_bus, _percent_to_db(percent))


func set_music_volume(percent: float) -> void :
	AudioServer.set_bus_volume_db(music_bus, _percent_to_db(percent))


func set_sfx_volume(percent: float) -> void :
	AudioServer.set_bus_volume_db(sfx_bus, _percent_to_db(percent))


func get_master_volume() -> float:
	return _db_to_percent(AudioServer.get_bus_volume_db(master_bus))


func get_music_volume() -> float:
	return _db_to_percent(AudioServer.get_bus_volume_db(music_bus))


func get_sfx_volume() -> float:
	return _db_to_percent(AudioServer.get_bus_volume_db(sfx_bus))


func play_music(song: Music_Titles) -> void:
	current_song = song
	if _random_play:
		play_random_song()
		return
	_switch_stream(music[song])


func play_random_song() -> void :
	var values: Array = Music_Titles.values()
	var song_key: Music_Titles

	if values.size() <= 1:
		song_key = values[0]
	else:
		while true:
			song_key = values[randi_range(0, values.size() - 1)]
			if song_key != _last_random_key:
				break

	_last_random_key = song_key
	current_song = song_key
	_switch_stream(music[song_key])

func next_song() -> void:
	var values: Array = Music_Titles.values()
	var idx: int = values.find(current_song)
	idx = (idx + 1) % values.size()
	current_song = values[idx]
	_switch_stream(music[current_song])


func previous_song() -> void:
	var values: Array = Music_Titles.values()
	var idx: int = values.find(current_song)
	idx = (idx - 1 + values.size()) % values.size()
	current_song = values[idx]
	_switch_stream(music[current_song])


func _switch_stream(stream: AudioStream) -> void :
	music_player.stop()
	music_player.stream = stream
	await get_tree().process_frame
	music_player.play()
	song_changed.emit(current_song)


func get_current_song_name() -> String:
	return Music_Titles.keys()[current_song].to_lower()


func stop_music() -> void :
	music_player.stop()


func set_loop(should_loop: bool) -> void :
	_loop = should_loop


func set_random_play(should_random: bool) -> void :
	_random_play = should_random


func save_settings() -> void :
	var cfg: = ConfigFile.new()
	cfg.set_value("audio", "master", get_master_volume())
	cfg.set_value("audio", "music", get_music_volume())
	cfg.set_value("audio", "sfx", get_sfx_volume())
	cfg.save("user://audio.cfg")


func _load_settings() -> void :
	var cfg: = ConfigFile.new()
	var err: = cfg.load("user://audio.cfg")
	if err != OK:
		return
	
	set_master_volume(cfg.get_value("audio", "master", 100))
	set_music_volume(cfg.get_value("audio", "music", 100))
	set_sfx_volume(cfg.get_value("audio", "sfx", 100))
	
	if _random_play:
		play_random_song()
		return
	if _loop:
		music_player.play()
		return


func _percent_to_db(percent: float) -> float:
	if percent <= 0.0:
		return -80.0
	return linear_to_db(percent / 100.0)

func _db_to_percent(db: float) -> float:
	return db_to_linear(db) * 100.0


func _play_next_song() -> void :
	if _random_play:
		play_random_song()
		return
	if _loop:
		music_player.play()
		return


func _setup_sfx_pool() -> void :
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		audio_manager.add_child(p)
		_sfx_pool.append(p)


func _get_free_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_pool:
		if not player.playing:
			return player
	var player: AudioStreamPlayer = _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % SFX_POOL_SIZE
	return player


func play_sfx(title: SFX_Titles, volume_db: float = 0.0, pitch: float = 1.0) -> void :
	if title == SFX_Titles.NONE: return
	var stream: AudioStream = sfx.get(title)
	if stream == null:
		return
	var player: AudioStreamPlayer = _get_free_sfx_player()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()
