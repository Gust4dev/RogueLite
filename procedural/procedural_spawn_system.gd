extends Node
class_name ProceduralSpawnSystem

## ProceduralSpawnSystem - Sistema de spawn otimizado para mapas procedurais
## Trabalha em conjunto com MapGenerator para spawnar inimigos de forma inteligente.
##
## Características:
## - Spawna fora do campo de visão do player
## - Evita spawn em obstáculos
## - Densidade aumenta com tempo
## - Suporta diferentes zonas (normal, boss arena)
## - Validação via NavigationServer3D

# === SIGNALS ===
signal enemy_spawned(enemy: Node3D, position: Vector3)
signal wave_started(wave_number: int, enemy_count: int)
signal wave_completed(wave_number: int)
signal spawn_density_changed(new_density: float)

# === CONFIGURAÇÃO DE SPAWN ===
@export_group("Spawn Configuration")
@export var base_wave_size: int = 3           # Início um pouco mais intenso
@export var wave_size_increment: float = 1.5  # Aumenta 1.5 por minuto
@export var max_wave_size: int = 25           # Caos nos minutos finais
@export var spawn_interval: float = 4.0       # Segundos entre waves (mais rápido)
@export var min_spawn_interval: float = 1.0   # Mínimo intervalo (caos total)
@export var min_spawn_distance: float = 15.0  # Distância mínima do player (mais perto!)
@export var max_spawn_distance: float = 30.0  # Distância máxima do player (mais perto!)
@export var max_enemies_alive: int = 50       # Mais inimigos simultâneos
@export var min_distance_between_spawns: float = 2.5  # Distância mínima entre spawns

@export_group("Difficulty Scaling")
@export var difficulty_scale_rate: float = 0.2  # 20% por minuto (mais agressivo)
# Sem limite de dificuldade máxima - escala infinitamente

# === REFERÊNCIAS ===
var map_generator: MapGenerator = null
var player: Node3D = null
var camera: Camera3D = null

# === ESTADO ===
var is_spawning: bool = false
var spawn_paused: bool = false
var current_wave: int = 0
var enemies_alive: int = 0
var time_elapsed: float = 0.0
var difficulty_multiplier: float = 1.0

# === SPAWN POINTS DINÂMICOS ===
var valid_spawn_positions: Array[Vector3] = []
var spawn_point_cache: Dictionary = {}  # Cache de pontos válidos por setor
var last_cache_update: float = 0.0
const CACHE_UPDATE_INTERVAL: float = 5.0

# === RECENT SPAWNS (para evitar spawn no mesmo lugar) ===
var recent_spawn_positions: Array[Vector3] = []
const MAX_RECENT_SPAWNS: int = 30
const SPAWN_POSITION_COOLDOWN: float = 3.0
var spawn_position_times: Array[float] = []

# === ENEMY SCENES ===
var enemy_scenes: Dictionary = {}  # {enemy_type: PackedScene}

# === TIMER ===
var spawn_timer: Timer = null


func _ready() -> void:
	_load_enemy_scenes()
	_setup_timer()


func _load_enemy_scenes() -> void:
	"""Carrega as cenas de inimigos disponíveis"""
	var enemy_paths = {
		"zombie": "res://enemies/zombie.tscn"
	}

	for enemy_type in enemy_paths:
		var path = enemy_paths[enemy_type]
		if ResourceLoader.exists(path):
			enemy_scenes[enemy_type] = load(path)
		else:
			push_warning("[ProceduralSpawnSystem] Cena não encontrada: " + path)


func _setup_timer() -> void:
	"""Configura o timer de spawn"""
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.one_shot = false
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)


## Inicializa o sistema com referências necessárias
func initialize(map_gen: MapGenerator, player_node: Node3D) -> void:
	map_generator = map_gen
	player = player_node

	# Tenta encontrar a câmera do player
	if player:
		camera = player.get_node_or_null("Camera3D")
		if not camera:
			camera = player.get_viewport().get_camera_3d()

	# Coleta spawn points do MapGenerator
	if map_generator:
		valid_spawn_positions = map_generator.spawn_points.duplicate()

	print("[ProceduralSpawnSystem] Inicializado com ", valid_spawn_positions.size(), " spawn points")


## Inicia o sistema de spawn
func start_spawning() -> void:
	if is_spawning:
		return

	is_spawning = true
	spawn_paused = false
	time_elapsed = 0.0
	current_wave = 0
	difficulty_multiplier = 1.0

	spawn_timer.start()
	print("[ProceduralSpawnSystem] Spawn iniciado")


## Para o sistema de spawn
func stop_spawning() -> void:
	is_spawning = false
	spawn_timer.stop()
	print("[ProceduralSpawnSystem] Spawn parado")


## Pausa temporariamente (para boss fights)
func pause_spawning() -> void:
	spawn_paused = true
	spawn_timer.stop()


## Retoma o spawn
func resume_spawning() -> void:
	spawn_paused = false
	if is_spawning:
		spawn_timer.start()


func _process(delta: float) -> void:
	if is_spawning and not spawn_paused:
		time_elapsed += delta
		_update_difficulty()
		
		# Limpa spawns antigos
		_cleanup_old_spawns()

		# Atualiza cache de spawn points periodicamente
		if time_elapsed - last_cache_update > CACHE_UPDATE_INTERVAL:
			_update_spawn_cache()
			last_cache_update = time_elapsed


func _update_difficulty() -> void:
	"""Atualiza o multiplicador de dificuldade baseado no tempo - sem limite!"""
	var minutes_elapsed = time_elapsed / 60.0
	
	# Dificuldade escala exponencialmente para ficar caótico perto dos 15 min
	# Fórmula: 1.0 no início, ~2.0 aos 7min, ~4.0 aos 12min, ~6.0 aos 15min
	var new_multiplier = 1.0 + (minutes_elapsed * difficulty_scale_rate) + (pow(minutes_elapsed / 5.0, 2) * 0.3)
	
	if abs(new_multiplier - difficulty_multiplier) > 0.05:
		difficulty_multiplier = new_multiplier
		spawn_density_changed.emit(difficulty_multiplier)
		
		# Reduz spawn interval dinamicamente
		var new_interval = maxf(spawn_interval / sqrt(difficulty_multiplier), min_spawn_interval)
		if spawn_timer and spawn_timer.wait_time != new_interval:
			spawn_timer.wait_time = new_interval


func _on_spawn_timer_timeout() -> void:
	"""Callback do timer de spawn"""
	if spawn_paused or not is_spawning:
		return

	_spawn_wave()


## Spawna uma wave de inimigos
func _spawn_wave() -> void:
	if enemies_alive >= max_enemies_alive:
		return

	current_wave += 1

	# Calcula tamanho da wave baseado no tempo
	var minutes = time_elapsed / 60.0
	var wave_size = int(base_wave_size + (minutes * wave_size_increment * difficulty_multiplier))
	
	# Aplica multiplicador de dificuldade do GameManager
	if GameManager:
		wave_size = int(wave_size * GameManager.get_spawn_multiplier())
	
	wave_size = mini(wave_size, max_wave_size)
	wave_size = mini(wave_size, max_enemies_alive - enemies_alive)

	if wave_size <= 0:
		return

	wave_started.emit(current_wave, wave_size)
	print("[ProceduralSpawnSystem] Wave ", current_wave, ": ", wave_size, " inimigos")

	# Spawna os inimigos
	var spawned = 0
	for i in range(wave_size):
		var pos = _get_valid_spawn_position()
		if pos != Vector3.ZERO:
			var enemy = _spawn_enemy_at(pos)
			if enemy:
				spawned += 1

	if spawned == wave_size:
		wave_completed.emit(current_wave)


## Retorna uma posição válida para spawn
func _get_valid_spawn_position() -> Vector3:
	if not player:
		return _get_fallback_position()

	var player_pos = player.global_position
	var attempts = 0
	var max_attempts = 20

	while attempts < max_attempts:
		attempts += 1

		# Método 1: Usa spawn points pré-definidos
		if valid_spawn_positions.size() > 0 and randf() < 0.7:
			var spawn_point = valid_spawn_positions[randi() % valid_spawn_positions.size()]
			if _is_position_valid(spawn_point, player_pos):
				return spawn_point

		# Método 2: Gera posição aleatória ao redor do player
		var angle = randf() * TAU
		var distance = randf_range(min_spawn_distance, max_spawn_distance)
		var offset = Vector3(cos(angle), 0, sin(angle)) * distance
		var test_pos = player_pos + offset

		# Valida a posição
		if _is_position_valid(test_pos, player_pos):
			# Ajusta para posição navegável
			var nav_pos = _get_navigable_position(test_pos)
			if nav_pos != Vector3.ZERO:
				return nav_pos

	# Fallback
	return _get_fallback_position()


## Verifica se uma posição é válida para spawn
func _is_position_valid(pos: Vector3, player_pos: Vector3) -> bool:
	# Verifica distância do player
	var dist_to_player = pos.distance_to(player_pos)
	if dist_to_player < min_spawn_distance or dist_to_player > max_spawn_distance:
		return false

	# Verifica se está dentro da arena
	if map_generator:
		var half_arena = map_generator.HALF_ARENA
		if abs(pos.x) > half_arena - 5 or abs(pos.z) > half_arena - 5:
			return false

		# Verifica se não está em boss arena (a menos que boss esteja ativo)
		if not SpawnManager.boss_active and map_generator.is_in_boss_arena(pos):
			return false

	# Verifica se está fora do campo de visão (opcional, mais caro)
	if camera and _is_in_camera_view(pos):
		return false
	
	# Verifica distância de spawns recentes
	if not _is_far_from_recent_spawns(pos):
		return false
	
	# Verifica distância de inimigos existentes
	if not _is_far_from_existing_enemies(pos):
		return false

	return true


## Verifica se posição está longe de spawns recentes
func _is_far_from_recent_spawns(pos: Vector3) -> bool:
	for recent_pos in recent_spawn_positions:
		if pos.distance_to(recent_pos) < min_distance_between_spawns:
			return false
	return true


## Verifica se posição está longe de inimigos existentes
func _is_far_from_existing_enemies(pos: Vector3) -> bool:
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy):
			if pos.distance_to(enemy.global_position) < min_distance_between_spawns:
				return false
	return true


## Registra uma posição de spawn recente
func _register_spawn_position(pos: Vector3) -> void:
	recent_spawn_positions.append(pos)
	spawn_position_times.append(time_elapsed)
	
	# Limita tamanho do array
	while recent_spawn_positions.size() > MAX_RECENT_SPAWNS:
		recent_spawn_positions.pop_front()
		spawn_position_times.pop_front()


## Limpa spawns antigos
func _cleanup_old_spawns() -> void:
	var current_time = time_elapsed
	var i = 0
	while i < spawn_position_times.size():
		if current_time - spawn_position_times[i] > SPAWN_POSITION_COOLDOWN:
			spawn_position_times.remove_at(i)
			recent_spawn_positions.remove_at(i)
		else:
			i += 1


## Verifica se posição está no campo de visão da câmera
func _is_in_camera_view(pos: Vector3) -> bool:
	if not camera:
		return false

	# Converte para screen space
	var screen_pos = camera.unproject_position(pos)
	var viewport_size = camera.get_viewport().get_visible_rect().size

	# Margem para não spawnar muito perto da borda da tela
	var margin = 100.0

	# Verifica se está na tela
	if screen_pos.x < -margin or screen_pos.x > viewport_size.x + margin:
		return false
	if screen_pos.y < -margin or screen_pos.y > viewport_size.y + margin:
		return false

	# Verifica se está atrás da câmera
	var to_pos = pos - camera.global_position
	var forward = -camera.global_transform.basis.z
	if to_pos.dot(forward) < 0:
		return false

	return true


## Retorna a posição navegável mais próxima
func _get_navigable_position(pos: Vector3) -> Vector3:
	var maps = NavigationServer3D.get_maps()
	if maps.is_empty():
		return pos

	var map_rid = maps[0]
	var closest = NavigationServer3D.map_get_closest_point(map_rid, pos)

	# Verifica se o ponto está muito longe (pode indicar posição inválida)
	if closest.distance_to(pos) > 5.0:
		return Vector3.ZERO

	# Ajusta altura
	closest.y += 0.5

	return closest


## Retorna posição de fallback
func _get_fallback_position() -> Vector3:
	if valid_spawn_positions.size() > 0:
		return valid_spawn_positions[randi() % valid_spawn_positions.size()]

	# Último recurso: posição fixa
	return Vector3(30, 0.5, 0)


## Spawna um inimigo em uma posição específica
func _spawn_enemy_at(pos: Vector3, enemy_type: String = "zombie") -> Node3D:
	if not enemy_scenes.has(enemy_type):
		push_error("[ProceduralSpawnSystem] Tipo de inimigo não encontrado: " + enemy_type)
		return null

	var scene = enemy_scenes[enemy_type]
	if not scene:
		return null

	var enemy = scene.instantiate()

	# Adiciona à cena
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = pos
	
	# Registra posição de spawn para evitar spawns próximos
	_register_spawn_position(pos)

	# Conecta sinais
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died)

	enemies_alive += 1
	enemy_spawned.emit(enemy, pos)

	return enemy


## Callback quando inimigo morre
func _on_enemy_died() -> void:
	enemies_alive = maxi(0, enemies_alive - 1)
	# Incrementa contador global de kills do SpawnManager
	if SpawnManager:
		SpawnManager.total_kills += 1


## Atualiza cache de spawn points
func _update_spawn_cache() -> void:
	if not player or not map_generator:
		return

	# Divide a arena em setores e encontra pontos válidos em cada
	var player_pos = player.global_position
	spawn_point_cache.clear()

	# Define setores (N, S, E, W, NE, NW, SE, SW)
	var sectors = {
		"N": Vector3(0, 0, -1),
		"S": Vector3(0, 0, 1),
		"E": Vector3(1, 0, 0),
		"W": Vector3(-1, 0, 0),
		"NE": Vector3(1, 0, -1).normalized(),
		"NW": Vector3(-1, 0, -1).normalized(),
		"SE": Vector3(1, 0, 1).normalized(),
		"SW": Vector3(-1, 0, 1).normalized()
	}

	for sector_name in sectors:
		var direction = sectors[sector_name]
		var sector_points: Array[Vector3] = []

		for sp in valid_spawn_positions:
			var to_point = (sp - player_pos).normalized()
			var dot = direction.dot(Vector3(to_point.x, 0, to_point.z).normalized())
			if dot > 0.5:  # Ponto está neste setor
				sector_points.append(sp)

		spawn_point_cache[sector_name] = sector_points


## Spawna inimigos em um setor específico (oposto ao player looking direction)
func spawn_behind_player(count: int = 1) -> void:
	if not player or not camera:
		_spawn_wave()
		return

	# Determina direção oposta ao player
	var forward = -camera.global_transform.basis.z
	var back_sector = ""

	# Encontra setor oposto
	if abs(forward.z) > abs(forward.x):
		back_sector = "S" if forward.z < 0 else "N"
	else:
		back_sector = "W" if forward.x > 0 else "E"

	# Pega pontos do setor
	var sector_points = spawn_point_cache.get(back_sector, [])

	for i in range(count):
		var pos = Vector3.ZERO
		if sector_points.size() > 0:
			pos = sector_points[randi() % sector_points.size()]
		else:
			pos = _get_valid_spawn_position()

		if pos != Vector3.ZERO:
			_spawn_enemy_at(pos)


## Spawna uma wave de reforço (inimigos mais fortes)
func spawn_reinforcement_wave(multiplier: float = 1.5) -> void:
	var wave_size = int(base_wave_size * multiplier * difficulty_multiplier)
	wave_size = mini(wave_size, max_enemies_alive - enemies_alive)

	print("[ProceduralSpawnSystem] Spawning reinforcement wave: ", wave_size)

	for i in range(wave_size):
		var pos = _get_valid_spawn_position()
		if pos != Vector3.ZERO:
			_spawn_enemy_at(pos)


## Spawna inimigos ao redor de uma posição específica (para boss arena)
func spawn_around_position(center: Vector3, count: int, radius: float = 10.0) -> void:
	for i in range(count):
		var angle = (float(i) / count) * TAU
		var offset = Vector3(cos(angle), 0, sin(angle)) * radius
		var spawn_pos = center + offset

		var nav_pos = _get_navigable_position(spawn_pos)
		if nav_pos != Vector3.ZERO:
			_spawn_enemy_at(nav_pos)


## Limpa todos os inimigos
func clear_all_enemies() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies_alive = 0


## Retorna estatísticas do sistema
func get_stats() -> Dictionary:
	return {
		"is_spawning": is_spawning,
		"spawn_paused": spawn_paused,
		"current_wave": current_wave,
		"enemies_alive": enemies_alive,
		"max_enemies": max_enemies_alive,
		"time_elapsed": time_elapsed,
		"difficulty_multiplier": difficulty_multiplier,
		"valid_spawn_points": valid_spawn_positions.size()
	}


## Ajusta parâmetros de dificuldade dinamicamente
func set_difficulty_params(params: Dictionary) -> void:
	if params.has("base_wave_size"):
		base_wave_size = params.base_wave_size
	if params.has("max_wave_size"):
		max_wave_size = params.max_wave_size
	if params.has("spawn_interval"):
		spawn_interval = params.spawn_interval
		spawn_timer.wait_time = spawn_interval
	if params.has("max_enemies"):
		max_enemies_alive = params.max_enemies


## Debug: mostra spawn points válidos
func debug_show_spawn_points(duration: float = 5.0) -> void:
	for sp in valid_spawn_positions:
		# Cria esfera visual temporária
		var debug_sphere = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		debug_sphere.mesh = sphere

		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0, 1, 0, 0.5)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		debug_sphere.material_override = mat

		debug_sphere.position = sp
		get_tree().current_scene.add_child(debug_sphere)

		# Remove após duration
		get_tree().create_timer(duration).timeout.connect(debug_sphere.queue_free)
