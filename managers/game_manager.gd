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

# Signals
signal time_changed(seconds_remaining: int)
signal game_over()
signal victory()
signal state_changed(new_state: GameState)

# Variáveis globais
var current_state: GameState = GameState.PLAYING
var has_boss_key: bool = false
var time_remaining: int = 900  # 15 minutos = 900 segundos
var is_timer_running: bool = false

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
