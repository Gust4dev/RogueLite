extends Node

# ShopManager - Gerencia itens da loja e mercador
# Controla upgrades disponíveis, preços e limites de compra

signal item_purchased(item_id: String)
signal shop_opened()
signal shop_closed()

# === ESTADO ===
var purchases_this_map: int = 0
const MAX_PURCHASES_PER_MAP: int = 2
var base_price: int = 50
var price_multiplier: float = 2.5

# === UPGRADES COMPRADOS (únicos) ===
var has_second_chance: bool = false
var has_radar: bool = false
var has_deep_pockets: bool = false

# === UPGRADES TEMPORÁRIOS ===

var frenzy_active: bool = false
var frenzy_timer: float = 0.0
var magnetism_multiplier: float = 1.0
var has_shield_hit: bool = false


# === DEFINIÇÃO DOS ITENS ===
const SHOP_ITEMS = {
	# === CONSUMÍVEIS ===
	"health_potion": {
		"name": "Poção de Vida",
		"description": "Recupera 50% do HP máximo",
		"icon": "❤️",
		"type": "consumable",
		"max_purchases": -1  # Ilimitado
	},
	"shield": {
		"name": "Escudo de Impacto",
		"description": "Bloqueia completamente o próximo dano recebido",
		"icon": "🛡️",
		"type": "consumable",
		"max_purchases": -1
	},
	"frenzy": {
		"name": "Frenesi",
		"description": "Dobra fire rate por 30 segundos",
		"icon": "🔥",
		"type": "consumable",
		"max_purchases": -1
	},
	"magnetism": {
		"name": "Magnetismo Permanente",
		"description": "Aumenta permanentemente o raio de coleta (+50%)",
		"icon": "🧲",
		"type": "consumable",
		"max_purchases": -1
	},
	"xp_magnet": {
		"name": "Ímã de XP",
		"description": "Puxa TODO o XP do mapa instantaneamente",
		"icon": "⚡",
		"type": "consumable",
		"max_purchases": -1
	},
	
	# === ÚNICOS ===
	"second_chance": {
		"name": "Segunda Chance",
		"description": "Revive com 25% HP (uma vez por run)",
		"icon": "💀",
		"type": "unique",
		"max_purchases": 1
	},
	"radar": {
		"name": "Radar",
		"description": "Mostra inimigos e bosses no HUD",
		"icon": "📡",
		"type": "unique",
		"max_purchases": 1
	},
	"deep_pockets": {
		"name": "Bolsos Fundos",
		"description": "+50% de dinheiro ganho",
		"icon": "💰",
		"type": "unique",
		"max_purchases": 1
	}
}

# Histórico de compras únicas
var unique_purchases: Dictionary = {}


func _ready() -> void:
	pass


func _process(delta: float) -> void:
	# Processa timers de buffs temporários
	if frenzy_active:
		frenzy_timer -= delta
		if frenzy_timer <= 0:
			_deactivate_frenzy()


func get_available_items() -> Array:
	"""Retorna lista de itens disponíveis para compra"""
	var available = []
	
	for item_id in SHOP_ITEMS:
		var item = SHOP_ITEMS[item_id]
		
		# Verifica se item único já foi comprado
		if item.type == "unique" and unique_purchases.get(item_id, 0) >= item.max_purchases:
			continue
		
		available.append({
			"id": item_id,
			"name": item.name,
			"description": item.description,
			"icon": item.icon,
			"type": item.type,
			"price": get_item_price()
		})
	
	return available


func get_item_price() -> int:
	"""Retorna preço do próximo item (escala com compras)"""
	var total_purchases = 0
	for item_id in unique_purchases:
		total_purchases += unique_purchases[item_id]
	
	return int(base_price * pow(price_multiplier, total_purchases))


func can_purchase() -> bool:
	"""Verifica se ainda pode comprar neste mapa"""
	return purchases_this_map < MAX_PURCHASES_PER_MAP


func purchase_item(item_id: String) -> bool:
	"""Tenta comprar um item. Retorna true se conseguiu."""
	if not SHOP_ITEMS.has(item_id):
		return false
	
	if not can_purchase():
		print("[ShopManager] Limite de compras atingido neste mapa")
		return false
	
	var price = get_item_price()
	if not MoneyManager.can_afford(price):
		print("[ShopManager] Dinheiro insuficiente")
		return false
	
	var item = SHOP_ITEMS[item_id]
	
	# Verifica limite de compras pra únicos
	if item.type == "unique":
		var purchases = unique_purchases.get(item_id, 0)
		if item.max_purchases > 0 and purchases >= item.max_purchases:
			print("[ShopManager] Item único já comprado")
			return false
	
	# Gasta dinheiro
	MoneyManager.spend_money(price)
	
	# Registra compra
	purchases_this_map += 1
	if item.type == "unique":
		unique_purchases[item_id] = unique_purchases.get(item_id, 0) + 1
	
	# Aplica efeito
	_apply_item_effect(item_id)
	
	item_purchased.emit(item_id)
	print("[ShopManager] Comprou: ", item.name, " por ", price)
	
	return true


func _apply_item_effect(item_id: String) -> void:
	"""Aplica o efeito do item comprado"""
	match item_id:
		"health_potion":
			_use_health_potion()
		"shield":
			_activate_shield()
		"frenzy":
			_activate_frenzy()
		"magnetism":
			_activate_magnetism()
		"xp_magnet":
			_use_xp_magnet()
		"second_chance":
			has_second_chance = true
		"radar":
			has_radar = true
		"deep_pockets":
			has_deep_pockets = true
			MoneyManager.activate_deep_pockets()


func _use_health_potion() -> void:
	"""Recupera 50% do HP"""
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		var stats = player.get_node_or_null("PlayerStats")
		if stats:
			var heal_amount = stats.max_health * 0.5
			stats.heal(heal_amount)
			print("[ShopManager] Curou ", heal_amount, " HP")


func _activate_shield() -> void:
	"""Ativa escudo de 1 hit"""
	has_shield_hit = true
	print("[ShopManager] Escudo ativado (bloqueia 1 hit)")


func use_shield() -> bool:
	"""Consome o escudo se ativo. Retorna true se bloqueou."""
	if has_shield_hit:
		has_shield_hit = false
		print("[ShopManager] Escudo bloqueou o dano!")
		# Efeito visual/sonoro poderia ser tocado aqui
		return true
	return false


func _activate_frenzy() -> void:
	"""Dobra fire rate por 30 segundos"""
	frenzy_active = true
	frenzy_timer = 30.0
	print("[ShopManager] Frenesi ativado por 30s")


func _deactivate_frenzy() -> void:
	frenzy_active = false
	print("[ShopManager] Frenesi desativado")


func _activate_magnetism() -> void:
	"""Aumenta raio de coleta permanentemente"""
	magnetism_multiplier += 0.5
	print("[ShopManager] Magnetismo aumentado para: ", magnetism_multiplier)


func _use_xp_magnet() -> void:
	"""Puxa todo XP do mapa instantaneamente"""
	var xp_orbs = get_tree().get_nodes_in_group("xp_orbs")
	
	# Fallback: busca todos os XPOrb na cena
	if xp_orbs.is_empty():
		for node in get_tree().current_scene.get_children():
			if node is XPOrb:
				xp_orbs.append(node)
	
	# Também busca pela classe
	for node in get_tree().get_nodes_in_group(""):
		if node is XPOrb and node not in xp_orbs:
			xp_orbs.append(node)
	
	var count = 0
	for orb in xp_orbs:
		if is_instance_valid(orb) and orb.has_method("force_attract"):
			orb.force_attract()
			count += 1
		elif is_instance_valid(orb):
			# Fallback: força atração manualmente
			orb.is_attracted = true
			orb.attraction_speed = 50.0
			orb.max_speed = 80.0
			count += 1
	
	print("[ShopManager] Ímã de XP: atraindo ", count, " orbs")


func get_frenzy_multiplier() -> float:
	"""Retorna multiplicador de fire rate do frenzy"""
	return 2.0 if frenzy_active else 1.0


func get_magnetism_multiplier() -> float:
	"""Retorna multiplicador de raio de coleta"""
	return magnetism_multiplier


func use_second_chance() -> bool:
	"""Usa segunda chance (revive). Retorna true se usou."""
	if has_second_chance:
		has_second_chance = false
		print("[ShopManager] Segunda Chance usada!")
		return true
	return false


func reset_for_new_map() -> void:
	"""Reseta contador de compras para novo mapa"""
	purchases_this_map = 0
	print("[ShopManager] Reset para novo mapa")


func reset() -> void:
	"""Reset completo para nova run"""
	purchases_this_map = 0
	unique_purchases.clear()
	
	has_second_chance = false
	has_radar = false
	has_deep_pockets = false
	
	frenzy_active = false
	frenzy_timer = 0.0
	magnetism_multiplier = 1.0
	has_shield_hit = false
	
	print("[ShopManager] Reset completo")
