extends Node

# Spawn Manager - Singleton que gerencia spawn de inimigos, bosses e itens
# Controla onde e quando inimigos e bosses aparecem

# === SIGNALS ===
signal enemy_spawned(enemy: Node3D)
signal boss_spawned(boss: Node3D)
signal boss_spawning(boss_number: int)
signal boss_defeated(boss_number: int, dropped_key: bool)
signal boss_warning(seconds_until_spawn: int)
signal boss_health_updated(current: float, maximum: float, boss_name: String)
signal all_bosses_defeated()

# === BOSS SPAWN CONFIG ===
const BOSS_SPAWN_TIMES = [180, 360, 540, 720]  # 3, 6, 9, 12 minutos em segundos
const BOSS_WARNING_TIME = 10  # Aviso 10 segundos antes

# Lista de spawn points na arena
var spawn_points: Array[Node3D] = []
var boss_spawn_point: Node3D = null

# Cenas de inimigos e bosses
var zombie_scene: PackedScene
var boss_scenes: Array[PackedScene] = []
var portal_scene: PackedScene
var key_scene: PackedScene

# Controle de spawns
var enemies_alive: int = 0
var max_enemies: int = 20
var spawn_paused: bool = false  # Pausa spawn durante boss fight

# Controle de bosses
var bosses_spawned: int = 0
var current_boss: Node3D = null
var boss_active: bool = false
var boss_warning_given: Array[bool] = [false, false, false, false]

# Portal
var portal: Node3D = null
var portal_spawned: bool = false


# Configuração de respawn
@export var min_enemies: int = 3
@export var respawn_delay: float = 2.0

func _ready() -> void:
	# Carrega as cenas de inimigos
	if ResourceLoader.exists("res://enemies/zombie.tscn"):
		zombie_scene = load("res://enemies/zombie.tscn")

	# Carrega cenas de bosses
	_load_boss_scenes()

	# Carrega portal
	if ResourceLoader.exists("res://items/portal.tscn"):
		portal_scene = load("res://items/portal.tscn")

	# Carrega key
	if ResourceLoader.exists("res://items/key_item.tscn"):
		key_scene = load("res://items/key_item.tscn")

	# Conecta ao GameManager para monitorar o tempo
	if GameManager:
		GameManager.time_changed.connect(_on_time_changed)


func _load_boss_scenes() -> void:
	"""Carrega todas as cenas de boss"""
	var boss_paths = [
		"res://enemies/mini_boss_1.tscn",
		"res://enemies/mini_boss_2.tscn",
		"res://enemies/mini_boss_3.tscn",
		"res://enemies/mini_boss_4.tscn"
	]

	for path in boss_paths:
		if ResourceLoader.exists(path):
			boss_scenes.append(load(path))
		else:
			push_warning("Boss scene not found: " + path)


func _on_time_changed(seconds_remaining: int) -> void:
	"""Monitora o tempo e spawna bosses nos momentos corretos"""
	if not GameManager or GameManager.current_state != GameManager.GameState.PLAYING:
		return

	# Calcula tempo decorrido
	var time_elapsed = 900 - seconds_remaining  # 15 min = 900s

	# Verifica se deve spawnar próximo boss
	if bosses_spawned < BOSS_SPAWN_TIMES.size():
		var next_boss_time = BOSS_SPAWN_TIMES[bosses_spawned]

		# Aviso antes do boss
		if not boss_warning_given[bosses_spawned]:
			if time_elapsed >= next_boss_time - BOSS_WARNING_TIME:
				boss_warning_given[bosses_spawned] = true
				boss_warning.emit(BOSS_WARNING_TIME)

		# Spawn do boss
		if time_elapsed >= next_boss_time and not boss_active:
			spawn_boss(bosses_spawned)
			bosses_spawned += 1


func register_spawn_point(point: Node3D) -> void:
	"""Registra um spawn point na arena"""
	if point not in spawn_points:
		spawn_points.append(point)


func register_boss_spawn_point(point: Node3D) -> void:
	"""Registra o ponto de spawn do boss"""
	boss_spawn_point = point


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
	if spawn_paused:
		return null

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
	if spawn_paused:
		return

	for i in range(count):
		if enemies_alive < max_enemies:
			spawn_zombie()


func spawn_boss(boss_index: int) -> void:
	"""Spawna um boss específico"""
	if boss_index >= boss_scenes.size():
		push_error("Invalid boss index: " + str(boss_index))
		return

	if boss_scenes[boss_index] == null:
		push_error("Boss scene not loaded for index: " + str(boss_index))
		return

	# Emite signal de aviso
	boss_spawning.emit(boss_index + 1)

	# Pausa spawns normais
	spawn_paused = true
	boss_active = true

	# Pequeno delay para buildup
	await get_tree().create_timer(1.0).timeout

	# Instancia o boss
	var boss = boss_scenes[boss_index].instantiate()

	# Posição do boss
	var spawn_pos = Vector3(0, 1, 15)  # Posição padrão
	if boss_spawn_point:
		spawn_pos = boss_spawn_point.global_position

	# Adiciona à cena
	get_tree().current_scene.add_child(boss)
	boss.global_position = spawn_pos

	current_boss = boss
	boss_spawned.emit(boss)

	# Conecta signals do boss
	if boss.has_signal("boss_died"):
		boss.boss_died.connect(_on_boss_died)

	if boss.has_signal("boss_health_changed"):
		boss.boss_health_changed.connect(_on_boss_health_changed)


func _on_boss_died(boss_number: int, dropped_key: bool) -> void:
	"""Callback quando um boss morre"""
	boss_active = false
	spawn_paused = false
	current_boss = null

	# Emite signal
	boss_defeated.emit(boss_number, dropped_key)

	# Spawna portal após primeiro boss
	if boss_number == 1 and not portal_spawned:
		_spawn_portal()

	# Mostra tela de upgrade
	if UpgradeManager:
		UpgradeManager.show_upgrade_screen()

	# Verifica se todos os bosses foram derrotados
	if bosses_spawned >= BOSS_SPAWN_TIMES.size():
		all_bosses_defeated.emit()


func _on_boss_health_changed(current: float, maximum: float) -> void:
	"""Callback quando HP do boss muda - para atualizar UI"""
	var boss_name = ""
	if current_boss and current_boss.has_method("get_boss_info"):
		var info = current_boss.get_boss_info()
		boss_name = info.get("name", "Boss")
	boss_health_updated.emit(current, maximum, boss_name)


func _spawn_portal() -> void:
	"""Spawna o portal de saída"""
	if not portal_scene:
		push_warning("Portal scene not loaded!")
		return

	portal = portal_scene.instantiate()

	# Posição do portal (pode ser configurada)
	var portal_pos = Vector3(0, 0, -15)  # Lado oposto do boss

	get_tree().current_scene.add_child(portal)
	portal.global_position = portal_pos

	# Ativa o portal
	if portal.has_method("activate"):
		portal.activate()

	portal_spawned = true


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
