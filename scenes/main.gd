extends Node3D

# Main Scene - Gerencia inicialização do jogo

@onready var player: PlayerController = $Player
@onready var hud = $HUD

var pistol_scene = preload("res://weapons/pistol.tscn")

func _ready() -> void:
	# Aguarda um frame para garantir que tudo está carregado
	await get_tree().process_frame

	# Inicia o timer do jogo
	if GameManager:
		GameManager.start_timer()

	# Instanciar e equipar a arma
	var pistol = pistol_scene.instantiate()
	if player:
		player.equip_weapon(pistol)
		if hud:
			hud.set_weapon(pistol)
		# Registra arma no UpgradeManager
		if UpgradeManager:
			UpgradeManager.set_weapon(pistol)

	# Registra spawn points
	_register_spawn_points()

	# Spawna alguns zombies para teste
	_spawn_test_zombies()

func _register_spawn_points() -> void:
	"""Registra todos os spawn points da arena no SpawnManager"""
	var spawn_points = get_tree().get_nodes_in_group("spawn_points")
	for point in spawn_points:
		SpawnManager.register_spawn_point(point)
	
	# Registra boss spawn point
	var boss_points = get_tree().get_nodes_in_group("boss_spawn_point")
	if boss_points.size() > 0:
		SpawnManager.register_boss_spawn_point(boss_points[0])

func _spawn_test_zombies() -> void:
	"""Spawna alguns zombies para teste"""
	for i in range(5):
		# Aguarda um pouco entre spawns
		await get_tree().create_timer(0.2).timeout
		SpawnManager.spawn_zombie()
