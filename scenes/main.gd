extends Node3D

# Main Scene - Gerencia inicialização do jogo
# Suporta tanto arena estática (test_arena) quanto procedural

@onready var player: PlayerController = $Player
@onready var hud = $HUD

# Preload de armas (fallback se CharacterManager não disponível)
var pistol_scene = preload("res://weapons/pistol/pistol.tscn")

# === CONFIGURAÇÃO PROCEDURAL ===
@export var use_procedural_arena: bool = true
@export var procedural_seed: int = -1  # -1 = random
@export var procedural_biome: int = -1  # -1 = random

# === REFERÊNCIAS PROCEDURAIS ===
var procedural_arena: ProceduralArena = null
var seed_display: SeedDisplay = null

# === ESTADO ===
var arena_ready: bool = false


func _ready() -> void:
	# Aguarda um frame para garantir que tudo está carregado
	await get_tree().process_frame

	# Verifica se vai usar arena procedural
	if use_procedural_arena:
		await _setup_procedural_arena()
	else:
		# Arena estática - fluxo original
		_setup_static_arena()


func _setup_static_arena() -> void:
	"""Configuração para arena estática (test_arena)"""
	# Inicia o timer do jogo
	if GameManager:
		GameManager.start_timer()

	# Spawna a arma do personagem selecionado
	_spawn_character_weapon()

	# Registra spawn points
	_register_spawn_points()

	# Spawna alguns zombies para teste
	_spawn_test_zombies()

	arena_ready = true


func _setup_procedural_arena() -> void:
	"""Configuração para arena procedural"""
	print("[Main] Configurando arena procedural...")

	# Remove arena estática se existir
	var static_arena = get_node_or_null("TestArena")
	if static_arena:
		static_arena.queue_free()
		await get_tree().process_frame

	# Obtém seed do GameManager se disponível
	var seed_to_use = procedural_seed
	var biome_to_use = procedural_biome

	if GameManager:
		if GameManager.procedural_seed != -1:
			seed_to_use = GameManager.procedural_seed
		if GameManager.procedural_biome != -1:
			biome_to_use = GameManager.procedural_biome

	# Cria a arena procedural
	procedural_arena = ProceduralArena.new()
	procedural_arena.name = "ProceduralArena"
	procedural_arena.auto_generate = false  # Vamos controlar manualmente
	procedural_arena.use_custom_seed = seed_to_use != -1
	procedural_arena.custom_seed = seed_to_use
	procedural_arena.selected_biome = biome_to_use
	add_child(procedural_arena)

	# Conecta sinais
	procedural_arena.arena_ready.connect(_on_procedural_arena_ready)

	# Gera a arena
	procedural_arena.generate_arena(seed_to_use)

	# Aguarda geração completar
	await procedural_arena.arena_ready

	print("[Main] Arena procedural pronta!")


func _on_procedural_arena_ready(seed_used: int) -> void:
	"""Callback quando arena procedural está pronta"""
	print("[Main] Arena gerada com seed: ", seed_used)

	# Registra o seed no GameManager
	if GameManager:
		GameManager.set_current_run_seed(seed_used)
		# Limpa seed customizado após uso
		GameManager.clear_seed()

	# Posiciona o player no spawn point da arena
	if player and procedural_arena:
		procedural_arena.position_player(player)

	# Inicia o timer do jogo
	if GameManager:
		GameManager.start_timer()

	# Spawna a arma do personagem selecionado
	_spawn_character_weapon()

	# Configura HUD com seed display
	_setup_seed_display()

	# Spawna inimigos iniciais
	if procedural_arena:
		procedural_arena.start_enemy_spawning()
	else:
		_spawn_test_zombies()

	arena_ready = true


func _setup_seed_display() -> void:
	"""Configura o display de seed na HUD"""
	if not hud or not procedural_arena:
		return

	# Cria o seed display
	seed_display = SeedDisplay.new()
	seed_display.name = "SeedDisplay"
	seed_display.show_biome = true
	seed_display.show_copy_button = true
	seed_display.show_favorite_button = true

	# Adiciona ao HUD
	var control = hud.get_node_or_null("Control")
	if control:
		control.add_child(seed_display)
		seed_display.position_top_left(Vector2(10, 80))

	# Atualiza com info da arena
	var info = procedural_arena.get_arena_info()
	seed_display.update_seed(info.seed, str(info.seed), info.biome)

	# Conecta sinal de copiar
	seed_display.copy_pressed.connect(_on_seed_copied)
	seed_display.favorite_pressed.connect(_on_seed_favorited)


func _on_seed_copied() -> void:
	"""Callback quando seed é copiado"""
	print("[Main] Seed copiado para clipboard")


func _on_seed_favorited() -> void:
	"""Callback quando seed é favoritado"""
	if procedural_arena:
		var success = procedural_arena.favorite_current_seed()
		if success:
			print("[Main] Seed adicionado aos favoritos")
			if seed_display:
				seed_display.set_favorite_state(true)


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


# === FUNÇÕES DE UTILIDADE ===

## Regenera a arena procedural com novo seed
func regenerate_arena(new_seed: int = -1) -> void:
	if not use_procedural_arena or not procedural_arena:
		print("[Main] Arena procedural não está ativa")
		return

	print("[Main] Regenerando arena...")

	# Para spawn de inimigos
	procedural_arena.stop_enemy_spawning()

	# Limpa inimigos existentes
	SpawnManager.clear_all_enemies()

	# Reposiciona player no centro temporariamente
	if player:
		player.global_position = Vector3(0, 2, 0)

	# Regenera a arena
	procedural_arena.regenerate(new_seed)


## Retorna informações da arena atual
func get_arena_info() -> Dictionary:
	if procedural_arena:
		return procedural_arena.get_arena_info()
	return {"type": "static", "name": "test_arena"}


## Pausa o spawn de inimigos (para eventos especiais)
func pause_enemy_spawn() -> void:
	if procedural_arena:
		procedural_arena.pause_enemy_spawning()
	SpawnManager.spawn_paused = true


## Retoma o spawn de inimigos
func resume_enemy_spawn() -> void:
	if procedural_arena:
		procedural_arena.resume_enemy_spawning()
	SpawnManager.spawn_paused = false


# === DEBUG INPUT ===

func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F7:
				# Toggle entre arena procedural e estática
				print("[DEBUG] Toggle procedural arena")
				use_procedural_arena = not use_procedural_arena
				print("  use_procedural_arena = ", use_procedural_arena)

			KEY_F8:
				# Mostra info da arena
				print("\n=== ARENA INFO ===")
				var info = get_arena_info()
				for key in info:
					print("  ", key, ": ", info[key])
				print("==================\n")

			KEY_F11:
				# Regenera arena (só funciona se procedural)
				if use_procedural_arena:
					regenerate_arena()
				else:
					print("[DEBUG] Arena estática não pode ser regenerada")

			KEY_F12:
				# Debug completo
				_debug_full_info()


func _debug_full_info() -> void:
	"""Mostra informações completas de debug"""
	print("\n========== DEBUG COMPLETO ==========")

	# Info da arena
	print("\n--- Arena ---")
	if procedural_arena:
		procedural_arena.debug_info()
	else:
		print("Arena estática (test_arena)")

	# Info do player
	print("\n--- Player ---")
	if player:
		print("  Position: ", player.global_position)
		print("  Has weapon: ", player.current_weapon != null)

	# Info do SpawnManager
	print("\n--- Spawn Manager ---")
	print("  Enemies alive: ", SpawnManager.enemies_alive)
	print("  Spawn points: ", SpawnManager.spawn_points.size())
	print("  Boss active: ", SpawnManager.boss_active)
	print("  Spawn paused: ", SpawnManager.spawn_paused)

	# Info do GameManager
	print("\n--- Game Manager ---")
	if GameManager:
		print("  State: ", GameManager.current_state)
		print("  Has key: ", GameManager.has_boss_key)
		print("  Time: ", GameManager.get_formatted_time())

	print("\n=====================================\n")
