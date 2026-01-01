extends Node

# Base Upgrade - Classe base para todos os upgrades
# Define interface e funcionalidades comuns

class_name BaseUpgrade

# Informações do upgrade
var upgrade_id: String = ""
var upgrade_name: String = ""
var level: int = 0
var max_level: int = 3

# Referências
var weapon: Node3D = null
var player: Node3D = null
var player_stats: Node = null

# Conexões de signals
var _connected_signals: Array = []


func set_level(new_level: int) -> void:
	"""Define o nível do upgrade"""
	level = clamp(new_level, 1, max_level)
	_on_level_changed()


func apply(target_weapon: Node3D, target_player: Node3D) -> void:
	"""Aplica o upgrade à arma e player"""
	weapon = target_weapon
	player = target_player

	# Busca PlayerStats
	if player:
		player_stats = player.get_node_or_null("PlayerStats")

	# Conecta aos signals necessários
	_connect_signals()

	# Aplica efeitos iniciais
	_apply_effects()


func remove() -> void:
	"""Remove o upgrade"""
	_disconnect_signals()
	_remove_effects()


func _connect_signals() -> void:
	"""Conecta aos signals da arma/player - sobrescrever nas classes filhas"""
	pass


func _disconnect_signals() -> void:
	"""Desconecta todos os signals"""
	for connection in _connected_signals:
		if connection.signal_obj.is_connected(connection.callable):
			connection.signal_obj.disconnect(connection.callable)
	_connected_signals.clear()


func _apply_effects() -> void:
	"""Aplica os efeitos do upgrade - sobrescrever nas classes filhas"""
	pass


func _remove_effects() -> void:
	"""Remove os efeitos do upgrade - sobrescrever nas classes filhas"""
	pass


func _on_level_changed() -> void:
	"""Chamado quando o nível muda - sobrescrever nas classes filhas"""
	pass


func _safe_connect(sig: Signal, callable: Callable) -> void:
	"""Conecta um signal de forma segura e rastreia a conexão"""
	if not sig.is_connected(callable):
		sig.connect(callable)
		_connected_signals.append({
			"signal_obj": sig,
			"callable": callable
		})


func get_description_for_level(lvl: int) -> String:
	"""Retorna descrição para um nível específico - sobrescrever"""
	return ""


func get_current_description() -> String:
	"""Retorna descrição do nível atual"""
	return get_description_for_level(level)
