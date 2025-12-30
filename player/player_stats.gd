extends Node

# Player Stats - Gerencia HP, armadura e outros stats do jogador

class_name PlayerStats

# Signals
signal health_changed(current_health: float, max_health: float)
signal player_died()
signal damage_taken(amount: float)

# Stats
@export var max_health: float = 100.0
@export var current_health: float = 100.0
@export var armor: float = 0.0

# Estado
var is_alive: bool = true

func _ready() -> void:
	current_health = max_health
	is_alive = true

func take_damage(amount: float) -> void:
	"""Aplica dano ao jogador, considerando armadura"""
	if not is_alive:
		return

	# Calcula dano reduzido pela armadura
	var actual_damage = amount * (1.0 - (armor / 100.0))
	actual_damage = max(1.0, actual_damage)  # Mínimo 1 de dano

	current_health -= actual_damage
	current_health = max(0.0, current_health)

	damage_taken.emit(actual_damage)
	health_changed.emit(current_health, max_health)

	# Verifica se morreu
	if current_health <= 0.0 and is_alive:
		die()

func heal(amount: float) -> void:
	"""Cura o jogador"""
	if not is_alive:
		return

	current_health += amount
	current_health = min(current_health, max_health)
	health_changed.emit(current_health, max_health)

func add_armor(amount: float) -> void:
	"""Adiciona armadura (máximo 75%)"""
	armor += amount
	armor = min(armor, 75.0)

func reset_stats() -> void:
	"""Reseta stats para valores iniciais"""
	current_health = max_health
	armor = 0.0
	is_alive = true
	health_changed.emit(current_health, max_health)

func die() -> void:
	"""Marca o jogador como morto"""
	is_alive = false
	current_health = 0.0
	player_died.emit()

	# Notifica o GameManager
	if GameManager:
		GameManager.lose_game()

func get_health_percentage() -> float:
	"""Retorna o HP como porcentagem (0.0 a 1.0)"""
	return current_health / max_health
