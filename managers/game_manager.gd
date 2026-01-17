extends Node

# Game Manager - Singleton que gerencia o estado global do jogo
# Controla timer, game state, e variáveis globais

# Enumeração para estados do jogo
enum GameState {
	PLAYING,
	PAUSED,
	GAME_OVER,
	VICTORY
}

# Enumeração para dificuldade
enum Difficulty {
	EASY,
	MEDIUM,
	HARD,
	MACHAO
}

# Signals
signal time_changed(seconds_remaining: int)
signal game_over()
signal victory()
signal state_changed(new_state: GameState)
signal run_reset()
signal difficulty_changed(new_difficulty: Difficulty)

# Variáveis globais
var current_state: GameState = GameState.PLAYING
var has_boss_key: bool = false
var time_remaining: int = 900  # 15 minutos = 900 segundos
var is_timer_running: bool = false

# === SISTEMA DE DIFICULDADE ===
var current_difficulty: Difficulty = Difficulty.MEDIUM

# Modificadores por dificuldade
# spawn: multiplicador de quantidade de inimigos
# damage: multiplicador de dano dos inimigos
# xp: multiplicador de XP ganho
# money: multiplicador de dinheiro ganho
const DIFFICULTY_MODIFIERS = {
	Difficulty.EASY: {"spawn": 0.5, "damage": 0.7, "xp": 1.0, "money": 1.0},
	Difficulty.MEDIUM: {"spawn": 0.7, "damage": 1.0, "xp": 1.0, "money": 1.0},
	Difficulty.HARD: {"spawn": 1.0, "damage": 1.0, "xp": 1.3, "money": 1.15},     # +30% XP, +15% dinheiro
	Difficulty.MACHAO: {"spawn": 1.0, "damage": 1.5, "xp": 1.4, "money": 1.2}    # +40% XP, +20% dinheiro
}

# === CONFIGURAÇÃO DE ARENA PROCEDURAL ===
var use_procedural_arena: bool = true
var procedural_seed: int = -1  # -1 = random
var procedural_biome: int = -1  # -1 = random
var current_run_seed: int = 0  # Seed usado na run atual

# Timer interno
var timer: Timer

func _ready() -> void:
	# Cria e configura o timer
	timer = Timer.new()
	timer.wait_time = 1.0  # 1 segundo
	timer.one_shot = false
	timer.timeout.connect(_on_timer_timeout)
	add_child(timer)

	# Inicia automaticamente em modo playing
	current_state = GameState.PLAYING

func start_timer() -> void:
	"""Inicia o countdown do timer de 15 minutos"""
	time_remaining = 900
	is_timer_running = true
	timer.start()
	time_changed.emit(time_remaining)

func stop_timer() -> void:
	"""Para o timer"""
	is_timer_running = false
	timer.stop()

func pause_game() -> void:
	"""Pausa o jogo"""
	if current_state == GameState.PLAYING:
		current_state = GameState.PAUSED
		is_timer_running = false
		timer.stop()
		get_tree().paused = true
		state_changed.emit(current_state)

func resume_game() -> void:
	"""Resume o jogo"""
	if current_state == GameState.PAUSED:
		current_state = GameState.PLAYING
		is_timer_running = true
		timer.start()
		get_tree().paused = false
		state_changed.emit(current_state)

func win_game() -> void:
	"""Chama quando o player vence"""
	current_state = GameState.VICTORY
	stop_timer()
	victory.emit()
	state_changed.emit(current_state)

func lose_game() -> void:
	"""Chama quando o player morre"""
	current_state = GameState.GAME_OVER
	stop_timer()
	game_over.emit()
	state_changed.emit(current_state)

func reset_game() -> void:
	"""Reseta o jogo para o estado inicial"""
	current_state = GameState.PLAYING
	has_boss_key = false
	time_remaining = 900
	is_timer_running = false
	timer.stop()
	get_tree().paused = false
	state_changed.emit(current_state)

func get_formatted_time() -> String:
	"""Retorna o tempo formatado como MM:SS"""
	var minutes: int = time_remaining / 60
	var seconds: int = time_remaining % 60
	return "%02d:%02d" % [minutes, seconds]


func reset_run() -> void:
	"""Reseta a run completamente (como se iniciasse uma nova com o mesmo personagem)"""
	# Reset state
	reset_game()
	
	# Clear upgrades
	if UpgradeManager:
		UpgradeManager.reset_upgrades()
	
	# Clear XP
	if XPManager:
		XPManager.reset()
	
	# Clear enemies
	if SpawnManager:
		SpawnManager.clear_all_enemies()

	# Clear Shop and Money
	if ShopManager:
		ShopManager.reset()
	if MoneyManager:
		MoneyManager.reset()
	
	# Emit signal
	run_reset.emit()
	
	# Reload main scene
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_timer_timeout() -> void:
	"""Callback do timer - decrementa 1 segundo"""
	if is_timer_running and current_state == GameState.PLAYING:
		time_remaining -= 1
		time_changed.emit(time_remaining)

		# Verifica se o tempo acabou
		if time_remaining <= 0:
			time_remaining = 0
			lose_game()


# === FUNÇÕES DE SEED ===

func set_seed_for_next_run(seed_value: int, biome: int = -1) -> void:
	"""Define o seed para a próxima run"""
	procedural_seed = seed_value
	procedural_biome = biome
	print("[GameManager] Seed definido para próxima run: ", seed_value)


func get_seed_for_run() -> int:
	"""Retorna o seed a ser usado na run atual"""
	if procedural_seed == -1:
		randomize()
		return randi()
	return procedural_seed


func clear_seed() -> void:
	"""Limpa o seed customizado (volta para random)"""
	procedural_seed = -1
	procedural_biome = -1


func set_current_run_seed(seed_value: int) -> void:
	"""Registra o seed usado na run atual"""
	current_run_seed = seed_value


func get_current_run_seed() -> int:
	"""Retorna o seed da run atual"""
	return current_run_seed


# === FUNÇÕES DE DIFICULDADE ===

func set_difficulty(difficulty: Difficulty) -> void:
	"""Define a dificuldade do jogo"""
	current_difficulty = difficulty
	difficulty_changed.emit(difficulty)
	print("[GameManager] Dificuldade: ", get_difficulty_name())


func get_spawn_multiplier() -> float:
	"""Retorna multiplicador de quantidade de spawns"""
	return DIFFICULTY_MODIFIERS[current_difficulty]["spawn"]


func get_damage_multiplier() -> float:
	"""Retorna multiplicador de dano dos inimigos"""
	return DIFFICULTY_MODIFIERS[current_difficulty]["damage"]


func get_difficulty_name() -> String:
	"""Retorna nome da dificuldade atual"""
	match current_difficulty:
		Difficulty.EASY:
			return "Fácil"
		Difficulty.MEDIUM:
			return "Médio"
		Difficulty.HARD:
			return "Difícil"
		Difficulty.MACHAO:
			return "Machão"
	return "Desconhecido"


func get_xp_multiplier() -> float:
	"""Retorna multiplicador de XP ganho"""
	return DIFFICULTY_MODIFIERS[current_difficulty]["xp"]


func get_money_multiplier() -> float:
	"""Retorna multiplicador de dinheiro ganho"""
	return DIFFICULTY_MODIFIERS[current_difficulty]["money"]


func get_difficulty_description(difficulty: Difficulty) -> String:
	"""Retorna descrição da dificuldade para UI"""
	var mods = DIFFICULTY_MODIFIERS[difficulty]
	var desc = ""
	
	# Spawn info
	var spawn_pct = int(mods["spawn"] * 100)
	desc += "Inimigos: %d%%\n" % spawn_pct
	
	# Damage info
	var dmg_pct = int(mods["damage"] * 100)
	desc += "Dano: %d%%\n" % dmg_pct
	
	# Rewards
	var xp_bonus = int((mods["xp"] - 1.0) * 100)
	var money_bonus = int((mods["money"] - 1.0) * 100)
	
	if xp_bonus > 0 or money_bonus > 0:
		desc += "\n[color=gold]BÔNUS:[/color]\n"
		if xp_bonus > 0:
			desc += "+%d%% XP\n" % xp_bonus
		if money_bonus > 0:
			desc += "+%d%% Dinheiro" % money_bonus
	
	return desc
