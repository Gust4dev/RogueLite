extends Node3D

# Main Scene - Gerencia inicialização do jogo

@onready var player: PlayerController = $Player
@onready var hud = $HUD

# Preload de armas (fallback se CharacterManager não disponível)
var pistol_scene = preload("res://weapons/pistol.tscn")


func _ready() -> void:
	# Aguarda um frame para garantir que tudo está carregado
	await get_tree().process_frame

	# Inicia o timer do jogo
	if GameManager:
		GameManager.start_timer()

	# Spawna a arma do personagem selecionado
	_spawn_character_weapon()

	# Registra spawn points
	_register_spawn_points()

	# Spawna alguns zombies para teste
	_spawn_test_zombies()


func _spawn_character_weapon() -> void:
	"""Spawna a arma baseada no personagem selecionado"""
	var weapon: Node3D = null

	# Remove arma existente da cena (se houver)
	var existing_weapon = player.get_node_or_null("Camera3D/Pistol")
	if existing_weapon:
		existing_weapon.queue_free()
		await get_tree().process_frame

	# Usa CharacterManager se disponível
	if CharacterManager:
		weapon = CharacterManager.spawn_selected_weapon()

	# Fallback para pistol
	if not weapon:
		weapon = pistol_scene.instantiate()

	if weapon and player:
		# Adiciona arma à câmera
		player.get_node("Camera3D").add_child(weapon)
		weapon.position = Vector3(0.3, -0.3, -0.5)  # Posição padrão FPS

		# Registra como arma atual
		player.current_weapon = weapon

		# Configura HUD
		if hud:
			hud.set_weapon(weapon)

		# Registra arma no UpgradeManager
		if UpgradeManager:
			UpgradeManager.set_weapon(weapon)

		print("[Main] Arma equipada: ", weapon.name)


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
