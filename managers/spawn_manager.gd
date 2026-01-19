extends Node

# Spawn Manager - Singleton que gerencia spawn de inimigos, bosses e itens
# Controla onde e quando inimigos e bosses aparecem
# Integra com sistema de geração procedural (MapGenerator/ProceduralArena)

# === SIGNALS ===
signal enemy_spawned(enemy: Node3D)
signal boss_spawned(boss: Node3D)
signal boss_spawning(boss_number: int)
signal boss_defeated(boss_number: int, dropped_key: bool)
signal boss_warning(seconds_until_spawn: int)
signal boss_health_updated(current: float, maximum: float, boss_name: String)
signal all_bosses_defeated()
signal portal_spawned_signal(portal: Node3D)

# === BOSS SPAWN CONFIG ===
const BOSS_SPAWN_TIMES = [180, 360, 540, 720]  # 3, 6, 9, 12 minutos em segundos
const BOSS_WARNING_TIME = 10  # Aviso 10 segundos antes

# Lista de spawn points na arena
var spawn_points: Array[Node3D] = []
var boss_spawn_point: Node3D = null

# Cenas de inimigos e bosses
var zombie_scene: PackedScene
var shooter_scene: PackedScene
var raptor_scene: PackedScene
var tank_scene: PackedScene
var exploder_scene: PackedScene
var flying_drone_scene: PackedScene
var spawner_scene: PackedScene
var boss_scenes: Array[PackedScene] = []
var portal_scene: PackedScene
var key_scene: PackedScene

# Enum para tipos de inimigos
enum EnemyType {
	ZOMBIE,
	SHOOTER,
	RAPTOR,
	TANK,
	EXPLODER,
	FLYING_DRONE,
	SPAWNER
}

# Pesos de spawn por tipo (ajusta probabilidade)
# Valores mais altos = mais comum
var enemy_spawn_weights: Dictionary = {
	EnemyType.ZOMBIE: 40,       # Mais comum
	EnemyType.SHOOTER: 20,
	EnemyType.RAPTOR: 15,
	EnemyType.TANK: 5,          # Raro
	EnemyType.EXPLODER: 10,
	EnemyType.FLYING_DRONE: 8,
	EnemyType.SPAWNER: 2,       # Muito raro
}

# Controle de spawns
var enemies_alive: int = 0
var max_enemies: int = 20
var spawn_paused: bool = false  # Pausa spawn durante boss fight
var total_kills: int = 0  # Total de inimigos mortos na run

# Controle de bosses
var bosses_spawned: int = 0
var current_boss: Node3D = null
var boss_active: bool = false
var boss_warning_given: Array[bool] = [false, false, false, false]

# Portal
var portal: Node3D = null
var portal_spawned: bool = false

# Referência à arena procedural (opcional)
var procedural_arena: Node3D = null
var map_generator: Node3D = null

# Configuração de respawn
@export var min_enemies: int = 3
@export var respawn_delay: float = 2.0

# Boss spawn points (para arenas procedurais - um por boss)
var boss_arena_spawn_points: Array[Node3D] = []

func _ready() -> void:
	# Carrega todas as cenas de inimigos
	_load_enemy_scenes()

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


func _load_enemy_scenes() -> void:
	"""Carrega todas as cenas de inimigos"""
	var enemy_paths = {
		"zombie": "res://enemies/zombie.tscn",
		"shooter": "res://enemies/shooter.tscn",
		"raptor": "res://enemies/raptor.tscn",
		"tank": "res://enemies/tank.tscn",
		"exploder": "res://enemies/exploder.tscn",
		"flying_drone": "res://enemies/flying_drone.tscn",
		"spawner": "res://enemies/spawner.tscn",
	}

	for enemy_name in enemy_paths:
		var path = enemy_paths[enemy_name]
		if ResourceLoader.exists(path):
			match enemy_name:
				"zombie":
					zombie_scene = load(path)
				"shooter":
					shooter_scene = load(path)
				"raptor":
					raptor_scene = load(path)
				"tank":
					tank_scene = load(path)
				"exploder":
					exploder_scene = load(path)
				"flying_drone":
					flying_drone_scene = load(path)
				"spawner":
					spawner_scene = load(path)
		else:
			push_warning("Enemy scene not found: " + path)


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
	"""Registra o ponto de spawn do boss principal"""
	boss_spawn_point = point


func register_boss_arena_spawn_point(point: Node3D, arena_index: int = -1) -> void:
	"""Registra um spawn point de boss arena específico"""
	if arena_index >= 0:
		# Garante que o array tem tamanho suficiente
		while boss_arena_spawn_points.size() <= arena_index:
			boss_arena_spawn_points.append(null)
		boss_arena_spawn_points[arena_index] = point
	else:
		boss_arena_spawn_points.append(point)


func set_procedural_arena(arena: Node3D) -> void:
	"""Define referência à arena procedural"""
	procedural_arena = arena
	if procedural_arena.has_method("get_node"):
		map_generator = procedural_arena.get_node_or_null("MapGenerator")


func get_boss_spawn_position(boss_index: int) -> Vector3:
	"""Retorna posição de spawn para um boss específico"""
	# Se tem arena procedural com boss arenas específicas
	if boss_index < boss_arena_spawn_points.size() and boss_arena_spawn_points[boss_index]:
		return boss_arena_spawn_points[boss_index].global_position

	# Se tem boss spawn point principal
	if boss_spawn_point:
		return boss_spawn_point.global_position

	# Se tem map_generator, usa a arena de boss correspondente
	if map_generator and map_generator.has_method("get_boss_arena_position"):
		return map_generator.get_boss_arena_position(boss_index)

	# Fallback
	return Vector3(0, 1, 15)


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
	return _spawn_enemy_of_type(EnemyType.ZOMBIE, spawn_pos)


func spawn_shooter(spawn_pos: Vector3 = Vector3.ZERO) -> Node3D:
	"""Spawna um shooter na posição especificada"""
	return _spawn_enemy_of_type(EnemyType.SHOOTER, spawn_pos)


func spawn_raptor(spawn_pos: Vector3 = Vector3.ZERO) -> Node3D:
	"""Spawna um raptor na posição especificada"""
	return _spawn_enemy_of_type(EnemyType.RAPTOR, spawn_pos)


func spawn_tank(spawn_pos: Vector3 = Vector3.ZERO) -> Node3D:
	"""Spawna um tank na posição especificada"""
	return _spawn_enemy_of_type(EnemyType.TANK, spawn_pos)


func spawn_exploder(spawn_pos: Vector3 = Vector3.ZERO) -> Node3D:
	"""Spawna um exploder na posição especificada"""
	return _spawn_enemy_of_type(EnemyType.EXPLODER, spawn_pos)


func spawn_flying_drone(spawn_pos: Vector3 = Vector3.ZERO) -> Node3D:
	"""Spawna um flying drone na posição especificada"""
	return _spawn_enemy_of_type(EnemyType.FLYING_DRONE, spawn_pos)


func spawn_spawner_enemy(spawn_pos: Vector3 = Vector3.ZERO) -> Node3D:
	"""Spawna um spawner na posição especificada"""
	return _spawn_enemy_of_type(EnemyType.SPAWNER, spawn_pos)


func _get_scene_for_type(enemy_type: EnemyType) -> PackedScene:
	"""Retorna a cena correspondente ao tipo de inimigo"""
	match enemy_type:
		EnemyType.ZOMBIE:
			return zombie_scene
		EnemyType.SHOOTER:
			return shooter_scene
		EnemyType.RAPTOR:
			return raptor_scene
		EnemyType.TANK:
			return tank_scene
		EnemyType.EXPLODER:
			return exploder_scene
		EnemyType.FLYING_DRONE:
			return flying_drone_scene
		EnemyType.SPAWNER:
			return spawner_scene
	return zombie_scene


func _spawn_enemy_of_type(enemy_type: EnemyType, spawn_pos: Vector3 = Vector3.ZERO) -> Node3D:
	"""Spawna um inimigo de tipo específico"""
	if spawn_paused:
		return null

	var scene = _get_scene_for_type(enemy_type)
	if scene == null:
		# Fallback para zombie
		scene = zombie_scene
		if scene == null:
			push_error("No enemy scene available!")
			return null

	var enemy = scene.instantiate()

	# Se não passou posição, usa um spawn point aleatório
	if spawn_pos == Vector3.ZERO:
		var spawn_point = get_random_spawn_point()
		if spawn_point:
			spawn_pos = spawn_point.global_position

	# Valida a posição usando o NavigationServer3D
	spawn_pos = _get_valid_spawn_position(spawn_pos)

	# Adiciona à cena principal
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = spawn_pos

	# Verifica se deve ser elite
	_try_make_elite(enemy)

	enemies_alive += 1
	enemy_spawned.emit(enemy)

	# Conecta ao signal de morte
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died)

	# Track para meta progression
	if MetaProgression:
		enemy.died.connect(MetaProgression.track_enemy_killed)

	return enemy


func _try_make_elite(enemy: Node3D) -> void:
	"""Tenta transformar o inimigo em elite baseado na chance atual"""
	if not GameManager:
		return

	var elite_chance = GameManager.get_elite_spawn_chance()
	if randf() < elite_chance:
		# Carrega e aplica o modificador elite
		if enemy.has_method("set_meta"):
			var elite_modifier_script = load("res://enemies/elite_modifier.gd")
			if elite_modifier_script:
				var modifier = elite_modifier_script.new()
				enemy.add_child(modifier)


func _get_random_enemy_type() -> EnemyType:
	"""Retorna um tipo de inimigo aleatório baseado nos pesos"""
	var total_weight = 0
	for weight in enemy_spawn_weights.values():
		total_weight += weight

	var random_value = randi() % total_weight
	var current_weight = 0

	for enemy_type in enemy_spawn_weights:
		current_weight += enemy_spawn_weights[enemy_type]
		if random_value < current_weight:
			return enemy_type

	return EnemyType.ZOMBIE


func spawn_random_enemy(spawn_pos: Vector3 = Vector3.ZERO) -> Node3D:
	"""Spawna um inimigo de tipo aleatório baseado nos pesos"""
	var enemy_type = _get_random_enemy_type()
	return _spawn_enemy_of_type(enemy_type, spawn_pos)


func spawn_wave(count: int) -> void:
	"""Spawna uma wave de inimigos variados"""
	if spawn_paused:
		return

	# Aplica scaling de spawn rate
	var scaled_count = count
	if GameManager:
		scaled_count = int(count * GameManager.get_spawn_rate_scaling())

	for i in range(scaled_count):
		if enemies_alive < max_enemies:
			spawn_random_enemy()


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

	# NÃO pausa spawns normais - inimigos continuam aparecendo durante boss fight!
	# spawn_paused = true  # REMOVIDO
	boss_active = true

	# Pequeno delay para buildup
	await get_tree().create_timer(1.0).timeout

	# Instancia o boss
	var boss = boss_scenes[boss_index].instantiate()

	# Posição do boss - usa arena específica se disponível
	var spawn_pos = get_boss_spawn_position(boss_index)

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
	current_boss = null

	# Track para meta progression
	if MetaProgression:
		MetaProgression.track_boss_killed()

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

	# Posição do portal - usa arena procedural se disponível
	var portal_pos = Vector3(0, 0, -15)  # Posição padrão

	# Se tem arena procedural, usa posição definida lá
	if procedural_arena and procedural_arena.has_method("get_portal_spawn_position"):
		portal_pos = procedural_arena.get_portal_spawn_position()
	elif map_generator and "portal_position" in map_generator:
		portal_pos = map_generator.portal_position

	get_tree().current_scene.add_child(portal)
	portal.global_position = portal_pos

	# Ativa o portal
	if portal.has_method("activate"):
		portal.activate()

	portal_spawned = true
	portal_spawned_signal.emit(portal)


func _input(event: InputEvent) -> void:
	"""Debug hotkeys - só funcionam em debug builds"""
	if not OS.is_debug_build():
		return
	
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F9:
				# Spawn próximo boss imediatamente
				if bosses_spawned < boss_scenes.size() and not boss_active:
					print("[DEBUG] Spawning boss ", bosses_spawned + 1)
					spawn_boss(bosses_spawned)
					bosses_spawned += 1
				elif boss_active:
					print("[DEBUG] Boss já ativo!")
				else:
					print("[DEBUG] Todos os bosses já spawned!")
			KEY_F10:
				# Dar key ao player
				if GameManager:
					GameManager.has_boss_key = true
					print("[DEBUG] Key dada ao player!")


func clear_all_enemies() -> void:
	"""Remove todos os inimigos da cena"""
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies_alive = 0


func reset_spawn_manager() -> void:
	"""Reseta o SpawnManager para estado inicial (usado ao regenerar arena)"""
	# Limpa inimigos
	clear_all_enemies()

	# Limpa spawn points
	spawn_points.clear()
	boss_spawn_point = null
	boss_arena_spawn_points.clear()

	# Reseta estado de bosses
	bosses_spawned = 0
	current_boss = null
	boss_active = false
	boss_warning_given = [false, false, false, false]

	# Remove portal se existir
	if portal and is_instance_valid(portal):
		portal.queue_free()
	portal = null
	portal_spawned = false

	# Limpa referências procedurais
	procedural_arena = null
	map_generator = null

	# Reseta estado de spawn
	enemies_alive = 0
	spawn_paused = false
	total_kills = 0

	print("[SpawnManager] Reset completo")


func _on_enemy_died() -> void:
	"""Callback quando um inimigo morre"""
	enemies_alive = max(0, enemies_alive - 1)
	total_kills += 1
	
	# Agenda respawn se abaixo do mínimo
	if enemies_alive < min_enemies:
		get_tree().create_timer(respawn_delay).timeout.connect(_spawn_replacement)

func _spawn_replacement() -> void:
	"""Spawna um inimigo de reposição"""
	if enemies_alive < max_enemies:
		spawn_random_enemy()
