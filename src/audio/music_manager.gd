extends Node

enum Song { OVERWORLD }

var _player: AudioStreamPlayer
var _current_song: int = -1
var _songs: Dictionary = {}

var _volume_db: float = -4.0


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player.volume_db = _volume_db
	add_child(_player)
	_generate_all_songs()


func _generate_all_songs() -> void:
	_songs[Song.OVERWORLD] = ChiptuneGenerator.overworld_theme()


func play_song(song_id: int) -> void:
	if song_id == _current_song and _player.playing:
		return
	var stream: AudioStream = _songs.get(song_id)
	if not stream:
		return
	_player.stream = stream
	_player.play()
	_current_song = song_id


func stop_music() -> void:
	_player.stop()
	_current_song = -1
