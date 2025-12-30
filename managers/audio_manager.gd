extends Node

# Audio Manager - Singleton para gerenciar sons e música do jogo
# Fornece métodos convenientes para tocar SFX e música

# Audio players
var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var max_sfx_players: int = 16

# Volumes
@export var master_volume: float = 1.0
@export var music_volume: float = 0.7
@export var sfx_volume: float = 0.8

func _ready() -> void:
	# Cria o music player
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)

	# Cria pool de SFX players
	for i in range(max_sfx_players):
		var player = AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		sfx_players.append(player)

func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	"""Toca um efeito sonoro"""
	if stream == null:
		return

	# Encontra um player disponível
	var available_player: AudioStreamPlayer = null
	for player in sfx_players:
		if not player.playing:
			available_player = player
			break

	# Se não achou, usa o primeiro (interrompe o som anterior)
	if available_player == null:
		available_player = sfx_players[0]

	available_player.stream = stream
	available_player.volume_db = volume_db
	available_player.play()

func play_sfx_at_position(stream: AudioStream, position: Vector3, volume_db: float = 0.0) -> void:
	"""Toca um efeito sonoro 3D em uma posição específica"""
	if stream == null:
		return

	# Cria um AudioStreamPlayer3D temporário
	var player_3d = AudioStreamPlayer3D.new()
	player_3d.stream = stream
	player_3d.volume_db = volume_db
	player_3d.global_position = position
	player_3d.max_distance = 50.0
	player_3d.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE

	# Adiciona à cena
	get_tree().current_scene.add_child(player_3d)
	player_3d.play()

	# Remove quando terminar
	player_3d.finished.connect(func(): player_3d.queue_free())

func play_music(stream: AudioStream, fade_in: bool = false) -> void:
	"""Toca música de fundo"""
	if stream == null:
		return

	if fade_in:
		# TODO: Implementar fade in
		pass

	music_player.stream = stream
	music_player.volume_db = linear_to_db(music_volume)
	music_player.play()

func stop_music(fade_out: bool = false) -> void:
	"""Para a música"""
	if fade_out:
		# TODO: Implementar fade out
		pass

	music_player.stop()

func set_master_volume(volume: float) -> void:
	"""Define o volume master (0.0 a 1.0)"""
	master_volume = clamp(volume, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(master_volume))

func set_music_volume(volume: float) -> void:
	"""Define o volume da música (0.0 a 1.0)"""
	music_volume = clamp(volume, 0.0, 1.0)
	music_player.volume_db = linear_to_db(music_volume)

func set_sfx_volume(volume: float) -> void:
	"""Define o volume dos SFX (0.0 a 1.0)"""
	sfx_volume = clamp(volume, 0.0, 1.0)
	for player in sfx_players:
		player.volume_db = linear_to_db(sfx_volume)
