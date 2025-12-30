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

func spawn_zombie(position: Vector3 = Vector3.ZERO) -> Node3D:
	"""Spawna um zombie na posição especificada"""
	if zombie_scene == null:
		push_error("Zombie scene not loaded!")
		return null

	var zombie = zombie_scene.instantiate()

	# Se não passou posição, usa um spawn point aleatório
	if position == Vector3.ZERO:
		var spawn_point = get_random_spawn_point()
		if spawn_point:
			position = spawn_point.global_position

	zombie.global_position = position

	# Adiciona à cena principal
	get_tree().current_scene.add_child(zombie)

	enemies_alive += 1
	enemy_spawned.emit(zombie)

	# Conecta ao signal de morte para decrementar contador
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
