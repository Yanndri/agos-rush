class_name AudioUtility


static func play_sfx(parent: Node, stream: AudioStream, volume_db: float = 0.0, pitch_min: float = 0.8, pitch_max: float = 1.2, bus_name: StringName = &"SFX") -> AudioStreamPlayer:
	if parent == null or stream == null:
		return null

	var audio_player := AudioStreamPlayer.new()
	parent.add_child(audio_player)
	_setup_player(audio_player, stream, volume_db, pitch_min, pitch_max, bus_name)
	return audio_player


static func play_sfx_2d(parent: Node, stream: AudioStream, volume_db: float = 0.0, pitch_min: float = 0.8, pitch_max: float = 1.2, bus_name: StringName = &"SFX") -> AudioStreamPlayer2D:
	if parent == null or stream == null:
		return null

	var audio_player := AudioStreamPlayer2D.new()
	parent.add_child(audio_player)
	_setup_player(audio_player, stream, volume_db, pitch_min, pitch_max, bus_name)
	return audio_player


static func play_sfx_3d(parent: Node3D, stream: AudioStream, global_position: Variant = null, volume_db: float = 0.0, pitch_min: float = 0.8, pitch_max: float = 1.2, bus_name: StringName = &"SFX") -> AudioStreamPlayer3D:
	if parent == null or stream == null:
		return null

	var audio_player := AudioStreamPlayer3D.new()
	parent.add_child(audio_player)
	if global_position is Vector3:
		audio_player.global_position = global_position
	else:
		audio_player.global_position = parent.global_position
	_setup_player(audio_player, stream, volume_db, pitch_min, pitch_max, bus_name)
	return audio_player


static func add_sfx(parent: Node, stream: AudioStream) -> AudioStreamPlayer2D:
	return play_sfx_2d(parent, stream)


static func _setup_player(audio_player: Node, stream: AudioStream, volume_db: float, pitch_min: float, pitch_max: float, bus_name: StringName) -> void:
	audio_player.stream = stream
	audio_player.volume_db = volume_db
	audio_player.pitch_scale = randf_range(min(pitch_min, pitch_max), max(pitch_min, pitch_max))
	if AudioServer.get_bus_index(bus_name) != -1:
		audio_player.bus = bus_name
	audio_player.finished.connect(audio_player.queue_free)
	_play_when_ready.call_deferred(audio_player)


static func _play_when_ready(audio_player: Node) -> void:
	if audio_player == null or not is_instance_valid(audio_player):
		return
	if not audio_player.is_inside_tree():
		audio_player.queue_free()
		return

	audio_player.play()
