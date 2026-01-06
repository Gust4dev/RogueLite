extends Node3D
class_name ProceduralArena

## ProceduralArena - Arena gerada proceduralmente para cada run
## Substitui test_arena.tscn com geração dinâmica baseada em seed.
##
## Gerencia:
## - Geração do mapa via MapGenerator
## - Sistema de seed
## - Spawn points registrados no SpawnManager
## - Integração com sistemas existentes

# === SIGNALS ===
signal arena_ready(seed_used: int)
signal arena_generation_failed(reason: String)
signal player_positioned(position: Vector3)
signal portal_spawned(position: Vector3)

# === CONFIGURAÇÃO ===
@export_group("Generation Settings")
@export var auto_generate: bool = true
@export var use_custom_seed: bool = false
@export var custom_seed: int = 0
@export var selected_biome: int = -1  # -1 = random

@export_group("Gameplay Settings")
@export var spawn_initial_enemies: bool = true
@export var initial_enemy_count: int = 5
@export var use_procedural_spawn_system: bool = true

# === COMPONENTES ===
var map_generator: MapGenerator = null
var seed_manager: SeedManager = null
var procedural_spawn: ProceduralSpawnSystem = null

# === ESTADO ===
var is_generated: bool = false
var generation_in_progress: bool = false
var current_seed: int = 0
var current_biome: String = ""

# === REFERÊNCIAS EXTERNAS ===
var player_ref: Node3D = null


func _ready() -> void:
	print("[ProceduralArena] Inicializando...")

	# Cria componentes
	_create_components()

	# Gera automaticamente se configurado
	if auto_generate:
		call_deferred("generate_arena")


func _create_components() -> void:
	"""Cria os componentes necessários para geração"""
	# SeedManager
	seed_manager = SeedManager.new()
	seed_manager.name = "SeedManager"
	add_child(seed_manager)

	# MapGenerator
	map_generator = MapGenerator.new()
	map_generator.name = "MapGenerator"
	add_child(map_generator)

	# Conecta sinais do MapGenerator
	map_generator.generation_started.connect(_on_generation_started)
	map_generator.generation_progress.connect(_on_generation_progress)
	map_generator.generation_completed.connect(_on_generation_completed)
	map_generator.navmesh_baked.connect(_on_navmesh_baked)

	# ProceduralSpawnSystem (opcional)
	if use_procedural_spawn_system:
		procedural_spawn = ProceduralSpawnSystem.new()
		procedural_spawn.name = "ProceduralSpawnSystem"
		add_child(procedural_spawn)


## Gera a arena completa
func generate_arena(seed_value: int = -1) -> void:
	if generation_in_progress:
		push_warning("[ProceduralArena] Geração já em progresso!")
		return

	generation_in_progress = true
	is_generated = false

	print("[ProceduralArena] Iniciando geração da arena...")

	# Determina o seed a usar
	var final_seed: int
	if seed_value != -1:
		final_seed = seed_value
	elif use_custom_seed:
		final_seed = custom_seed
	else:
		final_seed = seed_manager.generate_random_seed()

	current_seed = final_seed

	# Define bioma se especificado
	if selected_biome >= 0:
		map_generator.current_biome = selected_biome

	# Gera o mapa
	await map_generator.generate_map(final_seed)


## Gera a arena com seed string (ex: "meu_mapa_favorito")
func generate_arena_from_string(seed_string: String) -> void:
	var numeric_seed = seed_manager.set_seed_from_string(seed_string)
	generate_arena(numeric_seed)


## Gera a arena do dia
func generate_daily_arena() -> void:
	var daily_seed = seed_manager.generate_daily_seed()
	generate_arena(daily_seed)


func _on_generation_started() -> void:
	"""Callback quando geração inicia"""
	print("[ProceduralArena] Geração iniciada...")


func _on_generation_progress(step: String, progress: float) -> void:
	"""Callback de progresso da geração"""
	var percent = int(progress * 100)
	print("[ProceduralArena] ", step, " (", percent, "%)")


func _on_generation_completed(seed_used: int) -> void:
	"""Callback quando geração completa"""
	print("[ProceduralArena] Geração completa! Seed: ", seed_used)

	current_seed = seed_used
	var map_info = map_generator.get_map_info()
	current_biome = map_info.biome

	# Adiciona ao histórico
	seed_manager.add_to_history(current_biome)

	# Registra spawn points no SpawnManager global
	_register_spawn_points()

	# Debug: imprime grid
	if OS.is_debug_build():
		map_generator.debug_print_grid()


func _on_navmesh_baked() -> void:
	"""Callback quando NavMesh é baked"""
	print("[ProceduralArena] NavMesh pronto!")

	is_generated = true
	generation_in_progress = false

	# Inicializa sistema de spawn procedural
	if procedural_spawn and player_ref:
		procedural_spawn.initialize(map_generator, player_ref)

	arena_ready.emit(current_seed)


## Registra spawn points no SpawnManager global
func _register_spawn_points() -> void:
	"""Registra todos os spawn points gerados no SpawnManager"""
	# Reseta SpawnManager se necessário
	SpawnManager.spawn_points.clear()
	SpawnManager.boss_arena_spawn_points.clear()

	# Define referência à arena procedural
	SpawnManager.set_procedural_arena(self)

	# Registra spawn points normais
	var spawn_point_nodes = get_tree().get_nodes_in_group("spawn_points")
	for point in spawn_point_nodes:
		SpawnManager.register_spawn_point(point)

	# Registra boss spawn points (um por arena de boss)
	var boss_spawn_nodes = get_tree().get_nodes_in_group("boss_spawn_point")

	# Ordena por nome para garantir ordem correta (BossSpawnPoint_1, _2, etc)
	boss_spawn_nodes.sort_custom(func(a, b): return a.name < b.name)

	for i in range(boss_spawn_nodes.size()):
		var point = boss_spawn_nodes[i]
		# Registra como spawn point específico da arena
		SpawnManager.register_boss_arena_spawn_point(point, i)

		# O primeiro também é o principal (fallback)
		if i == 0:
			SpawnManager.register_boss_spawn_point(point)

	print("[ProceduralArena] Registrados ", spawn_point_nodes.size(), " spawn points e ", boss_spawn_nodes.size(), " boss spawn points")


## Posiciona o player na arena
func position_player(player: Node3D) -> void:
	if not is_generated:
		push_warning("[ProceduralArena] Arena não gerada ainda!")
		return

	player_ref = player

	var spawn_pos = map_generator.player_spawn_position
	player.global_position = spawn_pos

	print("[ProceduralArena] Player posicionado em: ", spawn_pos)
	player_positioned.emit(spawn_pos)

	# Inicializa sistema de spawn procedural se ainda não foi
	if procedural_spawn:
		procedural_spawn.initialize(map_generator, player)


## Retorna a posição onde o portal deve spawnar
func get_portal_spawn_position() -> Vector3:
	if map_generator:
		return map_generator.portal_position
	return Vector3(0, 0.5, -40)


## Retorna posição da boss arena por índice (0-3)
func get_boss_arena_position(index: int) -> Vector3:
	if map_generator and index < map_generator.boss_arena_centers.size():
		return map_generator.boss_arena_centers[index]
	return Vector3.ZERO


## Retorna informações completas da arena
func get_arena_info() -> Dictionary:
	var info = {
		"is_generated": is_generated,
		"seed": current_seed,
		"seed_formatted": seed_manager.get_formatted_seed() if seed_manager else str(current_seed),
		"biome": current_biome
	}

	if map_generator:
		info.merge(map_generator.get_map_info())

	return info


## Retorna o seed atual formatado para display
func get_display_seed() -> String:
	if seed_manager:
		return seed_manager.get_formatted_seed()
	return str(current_seed)


## Verifica se uma posição está em área segura (boss arena)
func is_safe_zone(pos: Vector3) -> bool:
	if map_generator:
		return map_generator.is_in_boss_arena(pos)
	return false


## Inicia o sistema de spawn de inimigos
func start_enemy_spawning() -> void:
	if procedural_spawn:
		procedural_spawn.start_spawning()
	elif spawn_initial_enemies:
		# Fallback para sistema antigo
		_spawn_initial_enemies_legacy()


## Para o spawn de inimigos
func stop_enemy_spawning() -> void:
	if procedural_spawn:
		procedural_spawn.stop_spawning()


## Pausa spawn (para boss fights)
func pause_enemy_spawning() -> void:
	if procedural_spawn:
		procedural_spawn.pause_spawning()


## Retoma spawn
func resume_enemy_spawning() -> void:
	if procedural_spawn:
		procedural_spawn.resume_spawning()


## Spawna inimigos iniciais (fallback)
func _spawn_initial_enemies_legacy() -> void:
	for i in range(initial_enemy_count):
		await get_tree().create_timer(0.3).timeout
		SpawnManager.spawn_zombie()


## Regenera a arena com novo seed
func regenerate(new_seed: int = -1) -> void:
	if generation_in_progress:
		return

	# Limpa a geração anterior
	is_generated = false

	# Gera nova arena
	generate_arena(new_seed)


## Copia seed atual para clipboard
func copy_seed() -> void:
	if seed_manager:
		seed_manager.copy_seed_to_clipboard()
		print("[ProceduralArena] Seed copiado: ", current_seed)


## Adiciona seed atual aos favoritos
func favorite_current_seed(name: String = "") -> bool:
	if seed_manager:
		return seed_manager.add_to_favorites(name, current_biome)
	return false


## Debug: mostra informações da arena
func debug_info() -> void:
	print("\n=== PROCEDURAL ARENA DEBUG ===")
	print("Generated: ", is_generated)
	print("Seed: ", current_seed)
	print("Biome: ", current_biome)

	if map_generator:
		var info = map_generator.get_map_info()
		print("Player Spawn: ", info.player_spawn)
		print("Portal Position: ", info.portal_position)
		print("Boss Arenas: ", info.boss_arenas.size())
		print("Spawn Points: ", info.spawn_points_count)
		print("Obstacles: ", info.obstacles_count)

	if procedural_spawn:
		var stats = procedural_spawn.get_stats()
		print("\nSpawn System:")
		print("  Enemies Alive: ", stats.enemies_alive)
		print("  Current Wave: ", stats.current_wave)
		print("  Difficulty: ", stats.difficulty_multiplier)

	print("==============================\n")


## Debug: visualiza spawn points
func debug_show_spawn_points() -> void:
	if procedural_spawn:
		procedural_spawn.debug_show_spawn_points()


# === INPUT HANDLING (DEBUG) ===
func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F11:
				# Regenera arena com novo seed
				print("[DEBUG] Regenerando arena...")
				regenerate()
			KEY_F12:
				# Mostra info de debug
				debug_info()
