extends Node

# MoneyManager - Singleton que gerencia o dinheiro do jogador
# Controla ganho, gasto e multiplicadores

signal money_changed(new_amount: int)
signal money_gained(amount: int)
signal money_spent(amount: int)

# === ESTADO ===
var current_money: int = 0

# === MODIFICADORES ===
var deep_pockets_active: bool = false  # Bolsos Fundos upgrade (+50% dinheiro)


func _ready() -> void:
	pass


func add_money(base_amount: int) -> void:
	"""Adiciona dinheiro aplicando multiplicadores"""
	var final_amount = base_amount
	
	# Aplica multiplicador de dificuldade
	if GameManager:
		final_amount = int(final_amount * GameManager.get_money_multiplier())
	
	# Aplica Bolsos Fundos se ativo
	if deep_pockets_active:
		final_amount = int(final_amount * 1.5)
	
	current_money += final_amount
	money_gained.emit(final_amount)
	money_changed.emit(current_money)


func spend_money(amount: int) -> bool:
	"""Gasta dinheiro. Retorna true se conseguiu pagar."""
	if amount > current_money:
		return false
	
	current_money -= amount
	money_spent.emit(amount)
	money_changed.emit(current_money)
	return true


func can_afford(amount: int) -> bool:
	"""Verifica se pode pagar o valor"""
	return current_money >= amount


func get_money() -> int:
	"""Retorna dinheiro atual"""
	return current_money


func reset() -> void:
	"""Reseta o dinheiro para nova run"""
	current_money = 0
	deep_pockets_active = false
	money_changed.emit(current_money)


func activate_deep_pockets() -> void:
	"""Ativa o upgrade Bolsos Fundos"""
	deep_pockets_active = true
	print("[MoneyManager] Bolsos Fundos ativado! +50% dinheiro")


func get_coin_drop_amount(time_elapsed: float) -> int:
	"""Retorna quantidade de moedas que um inimigo deve dropar baseado no tempo"""
	# Base: 2 moedas, aumenta 0.3 por minuto
	var minutes = time_elapsed / 60.0
	var base_amount = 2 + int(minutes * 0.3)
	
	# Pequena variação aleatória
	var variation = randi_range(-1, 1)
	return maxi(1, base_amount + variation)
