extends Node

# Spawn Manager - Singleton que gerencia spawn de inimigos e itens
# Controla onde e quando inimigos aparecem

signal enemy_spawned(enemy: Node3D)
signal boss_spawned(boss: Node3D)

# Lista de spawn points na arena
var spawn_points: Array[Node3D] = []

# Cenas de inimigos (serão carregadas depois)
var zombie_scene: PackedScene

# Controle de spawns
var enemies_alive: int = 0
var max_enemies: int = 20

# Configuração de respawn
@export var min_enemies: int = 3
@export var respawn_delay: float = 2.0

func _ready() -> void:
	# Carrega as cenas de inimigos
	if ResourceLoader.exists("res://enemies/zombie.tscn"):
		zombie_scene = load("res://enemies/zombie.tscn")

func register_spawn_point(point: Node3D) -> void:
	"""Registra um spawn point na arena"""
	if point not in spawn_points:
		spawn_points.append(point)

func unregister_spawn_point(point: Node3D) -> void:
	"""Remove um spawn point"""
	if point in spawn_points:
		spawn_points.erase(point)

func get_random_spawn_point() -> Node3D:
	"""Retorna um spawn point aleatório"""
	if spawn_points.is_empty():
		return null
	return spawn_points[randi() % spawn_points.size()]

func _get_valid_spawn_position(desired_pos: Vector3) -> Vector3:
	"""Retorna uma posição navegável próxima à desejada"""
	var maps = NavigationServer3D.get_maps()
	if maps.is_empty():
		# Sem mapa de navegação, retorna posição original com offset Y
		return Vector3(desired_pos.x, desired_pos.y + 1.0, desired_pos.z)
	
	var map_rid = maps[0]
	var closest_point = NavigationServer3D.map_get_closest_point(map_rid, desired_pos)
	
	# Adiciona offset vertical para não spawnar dentro do chão
	return Vector3(closest_point.x, closest_point.y + 0.5, closest_point.z)

func spawn_zombie(spawn_pos: Vector3 = Vector3.ZERO) -> Node3D:
	"""Spawna um zombie na posição especificada"""
	if zombie_scene == null:
		push_error("Zombie scene not loaded!")
		return null

	var zombie = zombie_scene.instantiate()

	# Se não passou posição, usa um spawn point aleatório
	if spawn_pos == Vector3.ZERO:
		var spawn_point = get_random_spawn_point()
		if spawn_point:
			spawn_pos = spawn_point.global_position

	# Valida a posição usando o NavigationServer3D
	spawn_pos = _get_valid_spawn_position(spawn_pos)

	# Adiciona à cena principal
	get_tree().current_scene.add_child(zombie)
	zombie.global_position = spawn_pos

	enemies_alive += 1
	enemy_spawned.emit(zombie)

	# Conecta ao signal de morte para decrementar contador e respawnar
	if zombie.has_signal("died"):
		zombie.died.connect(_on_enemy_died)

	return zombie

func spawn_wave(count: int) -> void:
	"""Spawna uma wave de inimigos"""
	for i in range(count):
		if enemies_alive < max_enemies:
			spawn_zombie()

func clear_all_enemies() -> void:
	"""Remove todos os inimigos da cena"""
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		enemy.queue_free()
	enemies_alive = 0

func _on_enemy_died() -> void:
	"""Callback quando um inimigo morre"""
	enemies_alive = max(0, enemies_alive - 1)
	
	# Agenda respawn se abaixo do mínimo
	if enemies_alive < min_enemies:
		get_tree().create_timer(respawn_delay).timeout.connect(_spawn_replacement)

func _spawn_replacement() -> void:
	"""Spawna um inimigo de reposição"""
	if enemies_alive < max_enemies:
		spawn_zombie()
