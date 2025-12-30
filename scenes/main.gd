extends Node3D

# Main Scene - Gerencia inicialização do jogo

@onready var player: PlayerController = $Player
@onready var hud = $HUD
@onready var pistol = $Player/Camera3D/Pistol

func _ready() -> void:
	# Aguarda um frame para garantir que tudo está carregado
	await get_tree().process_frame

	# Inicia o timer do jogo
	if GameManager:
		GameManager.start_timer()

	# Conecta a arma ao HUD
	if hud and pistol:
		hud.set_weapon(pistol)

	# Registra spawn points
	_register_spawn_points()

	# Spawna alguns zombies para teste
	_spawn_test_zombies()

func _register_spawn_points() -> void:
	"""Registra todos os spawn points da arena no SpawnManager"""
	var spawn_points = get_tree().get_nodes_in_group("spawn_points")
	for point in spawn_points:
		SpawnManager.register_spawn_point(point)

func _spawn_test_zombies() -> void:
	"""Spawna alguns zombies para teste"""
	for i in range(5):
		# Aguarda um pouco entre spawns
		await get_tree().create_timer(0.2).timeout
		SpawnManager.spawn_zombie()
