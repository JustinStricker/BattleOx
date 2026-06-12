extends Node

enum Song { OVERWORLD, AMBIENT_DRONE }

var _active_player: AudioStreamPlayer
var _crossfade_player: AudioStreamPlayer
var _current_song: int = -1
var _songs: Dictionary = {}
var _drone

var _volume_db: float = -4.0
var _crossfade_tween: Tween


func _ready() -> void:
	_setup_buses()
	_active_player = AudioStreamPlayer.new()
	_active_player.bus = "Music"
	_active_player.volume_db = _volume_db
	add_child(_active_player)

	_crossfade_player = AudioStreamPlayer.new()
	_crossfade_player.bus = "Music"
	_crossfade_player.volume_db = -80.0
	add_child(_crossfade_player)

	_drone = preload("res://src/audio/ambient_drone.gd").new()
	add_child(_drone)

	_generate_all_songs()


func _setup_buses() -> void:
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")


func _generate_all_songs() -> void:
	_songs[Song.OVERWORLD] = ChiptuneGenerator.overworld_theme()


func play_song(song_id: int) -> void:
	if song_id == _current_song:
		if song_id == Song.AMBIENT_DRONE and _drone.is_playing():
			return
		elif song_id != Song.AMBIENT_DRONE and _active_player.playing:
			return

	# Stop drone if switching away from it
	if _drone.is_playing() and song_id != Song.AMBIENT_DRONE:
		_drone.stop()

	# Handle ambient drone (real-time synthesis)
	if song_id == Song.AMBIENT_DRONE:
		if _crossfade_tween and _crossfade_tween.is_valid():
			_crossfade_tween.kill()
		if _active_player.playing:
			_crossfade_tween = create_tween()
			_crossfade_tween.tween_property(_active_player, "volume_db", -80.0, 0.5).set_ease(Tween.EASE_IN)
			_crossfade_tween.chain().tween_callback(_active_player.stop)
		_drone.play()
		_current_song = song_id
		return

	# Handle pre-rendered songs
	var stream: AudioStream = _songs.get(song_id)
	if not stream:
		return

	if _crossfade_tween and _crossfade_tween.is_valid():
		_crossfade_tween.kill()

	if _active_player.playing:
		_crossfade_player.stream = _active_player.stream
		_crossfade_player.play(_active_player.get_playback_position())
		_crossfade_player.volume_db = _active_player.volume_db

		_active_player.stream = stream
		_active_player.volume_db = -80.0
		_active_player.play()

		_crossfade_tween = create_tween().set_parallel(true)
		_crossfade_tween.tween_property(_crossfade_player, "volume_db", -80.0, 0.5).set_ease(Tween.EASE_IN)
		_crossfade_tween.tween_property(_active_player, "volume_db", _volume_db, 0.5).set_ease(Tween.EASE_OUT)
		_crossfade_tween.chain().tween_callback(_crossfade_player.stop)
	else:
		_active_player.stream = stream
		_active_player.volume_db = _volume_db
		_active_player.play()

	_current_song = song_id


func stop_music() -> void:
	if _crossfade_tween and _crossfade_tween.is_valid():
		_crossfade_tween.kill()

	_drone.stop()

	if _active_player.playing:
		_crossfade_tween = create_tween()
		_crossfade_tween.tween_property(_active_player, "volume_db", -80.0, 0.3).set_ease(Tween.EASE_IN)
		_crossfade_tween.tween_callback(_active_player.stop)

	_crossfade_player.stop()
	_current_song = -1
