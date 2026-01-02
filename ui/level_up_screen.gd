extends CanvasLayer

# Level Up Screen - Tela de seleção de upgrades ao subir de nível
# Mostra 4 opções de upgrade com chance de aparecer upgrades de boss

class_name LevelUpScreen

# === SIGNALS ===
signal upgrade_selected(upgrade_data: Dictionary)
signal screen_closed()

# === CONFIGURAÇÃO ===
const UPGRADE_OPTIONS: int = 4
const BOSS_UPGRADE_CHANCE: float = 0.10  # 10%

# Pools de upgrades
var stat_upgrades_weapon: Array[Dictionary] = []
var stat_upgrades_player: Array[Dictionary] = []

# UI References
var background: ColorRect = null
var container: VBoxContainer = null
var title_label: Label = null
var cards_container: HBoxContainer = null
var option_cards: Array[Control] = []

# Estado
var is_showing: bool = false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_initialize_stat_pools()
	_create_ui()
	hide()


func _initialize_stat_pools() -> void:
	"""Define todos os upgrades de stats possíveis"""
	
	# === WEAPON STAT UPGRADES ===
	stat_upgrades_weapon = [
		{
			"id": "damage_up",
			"name": "Damage +",
			"description": "+15% weapon damage",
			"stat": "damage",
			"value": 0.15,
			"type": "weapon",
			"icon_color": Color(1.0, 0.3, 0.3),
			"stackable": true
		},
		{
			"id": "fire_rate_up",
			"name": "Rapid Fire",
			"description": "-10% fire rate (faster shots)",
			"stat": "fire_rate",
			"value": -0.10,
			"type": "weapon",
			"icon_color": Color(1.0, 0.6, 0.2),
			"stackable": true
		},
		{
			"id": "reload_speed_up",
			"name": "Quick Hands",
			"description": "-15% reload time",
			"stat": "reload_time",
			"value": -0.15,
			"type": "weapon",
			"icon_color": Color(0.3, 0.9, 0.4),
			"stackable": true
		},
		{
			"id": "magazine_up",
			"name": "Extended Mag",
			"description": "+4 magazine size",
			"stat": "magazine_size",
			"value": 4,
			"type": "weapon",
			"icon_color": Color(1.0, 0.9, 0.2),
			"stackable": true
		},
		{
			"id": "accuracy_up",
			"name": "Steady Aim",
			"description": "-20% recoil",
			"stat": "camera_recoil_vertical",
			"value": -0.20,
			"type": "weapon",
			"icon_color": Color(0.3, 0.8, 1.0),
			"stackable": true
		}
	]
	
	# === PLAYER STAT UPGRADES ===
	stat_upgrades_player = [
		{
			"id": "max_health_up",
			"name": "Vitality",
			"description": "+25 max health",
			"stat": "max_health",
			"value": 25,
			"type": "player",
			"icon_color": Color(1.0, 0.3, 0.3),
			"stackable": true
		},
		{
			"id": "armor_up",
			"name": "Tough Skin",
			"description": "+10% damage reduction",
			"stat": "armor",
			"value": 10,
			"type": "player",
			"icon_color": Color(0.6, 0.6, 0.8),
			"stackable": true
		},
		{
			"id": "speed_up",
			"name": "Swift Feet",
			"description": "+10% movement speed",
			"stat": "walk_speed",
			"value": 0.10,
			"type": "player",
			"icon_color": Color(0.3, 1.0, 0.5),
			"stackable": true
		},
		{
			"id": "dash_cooldown",
			"name": "Flash Step",
			"description": "-1s dash cooldown",
			"stat": "charge_cooldown",
			"value": -1.0,
			"type": "dash",
			"icon_color": Color(0.3, 0.8, 1.0),
			"stackable": true
		},
		{
			"id": "xp_gain_up",
			"name": "Quick Learner",
			"description": "+15% XP gain",
			"stat": "xp_multiplier",
			"value": 0.15,
			"type": "xp",
			"icon_color": Color(0.8, 0.3, 1.0),
			"stackable": true
		},
		{
			"id": "sprint_speed_up",
			"name": "Marathon Runner",
			"description": "+15% sprint speed",
			"stat": "sprint_speed",
			"value": 0.15,
			"type": "player",
			"icon_color": Color(0.2, 0.9, 0.7),
			"stackable": true
		}
	]


func _create_ui() -> void:
	"""Cria a interface da tela de level up"""
	# Background escuro
	background = ColorRect.new()
	background.name = "Background"
	background.color = Color(0, 0, 0, 0.85)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)
	
	# Container principal
	container = VBoxContainer.new()
	container.name = "Container"
	container.set_anchors_preset(Control.PRESET_CENTER)
	container.anchor_left = 0.1
	container.anchor_right = 0.9
	container.anchor_top = 0.15
	container.anchor_bottom = 0.85
	container.offset_left = 0
	container.offset_right = 0
	container.offset_top = 0
	container.offset_bottom = 0
	container.add_theme_constant_override("separation", 30)
	add_child(container)
	
	# Título
	title_label = Label.new()
	title_label.name = "Title"
	title_label.text = "LEVEL UP!"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 64)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	container.add_child(title_label)
	
	# Subtítulo
	var subtitle = Label.new()
	subtitle.text = "Choose your upgrade"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	container.add_child(subtitle)
	
	# Espaçador
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	container.add_child(spacer)
	
	# Container dos cards
	cards_container = HBoxContainer.new()
	cards_container.name = "CardsContainer"
	cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_container.add_theme_constant_override("separation", 20)
	cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_child(cards_container)


func show_level_up_options() -> void:
	"""Mostra a tela com 4 opções de upgrade"""
	if is_showing:
		return
	
	is_showing = true
	
	# Pausa o jogo
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Gera 4 opções
	var options = _generate_options()
	
	# Limpa cards anteriores
	for child in cards_container.get_children():
		child.queue_free()
	option_cards.clear()
	
	await get_tree().process_frame
	
	# Cria UI para cada opção
	for i in range(options.size()):
		var card = _create_option_card(options[i], i)
		cards_container.add_child(card)
		option_cards.append(card)
	
	# Animação de entrada
	_animate_entrance()
	
	show()


func _generate_options() -> Array[Dictionary]:
	"""Gera 4 opções de upgrade semi-aleatórias"""
	var options: Array[Dictionary] = []
	var used_ids: Array[String] = []
	
	for i in range(UPGRADE_OPTIONS):
		var option = _pick_random_upgrade(used_ids)
		if option.size() > 0:
			options.append(option)
			used_ids.append(option.id)
	
	return options


func _pick_random_upgrade(exclude_ids: Array) -> Dictionary:
	"""Escolhe um upgrade aleatório"""
	
	# 10% de chance de ser upgrade de boss (se tiver algum)
	if randf() < BOSS_UPGRADE_CHANCE:
		var boss_upgrade = _try_get_boss_upgrade(exclude_ids)
		if boss_upgrade.size() > 0:
			return boss_upgrade
	
	# Junta todos os upgrades disponíveis
	var all_upgrades: Array[Dictionary] = []
	all_upgrades.append_array(stat_upgrades_weapon)
	all_upgrades.append_array(stat_upgrades_player)
	
	# Remove já usados
	var available = all_upgrades.filter(func(u): return u.id not in exclude_ids)
	
	if available.is_empty():
		return {}
	
	available.shuffle()
	return available[0].duplicate()


func _try_get_boss_upgrade(exclude_ids: Array) -> Dictionary:
	"""Tenta retornar um upgrade de boss que o player já obteve"""
	if not XPManager:
		return {}
	
	var acquired = XPManager.get_acquired_boss_upgrades()
	if acquired.is_empty():
		return {}
	
	# Filtra upgrades já oferecidos nesta tela
	var available = acquired.filter(func(id): return id not in exclude_ids)
	if available.is_empty():
		return {}
	
	available.shuffle()
	var upgrade_id = available[0]
	
	# Busca dados do upgrade no UpgradeManager
	if UpgradeManager and upgrade_id in UpgradeManager.upgrade_pool:
		var data = UpgradeManager.upgrade_pool[upgrade_id]
		return {
			"id": upgrade_id,
			"name": data.name,
			"description": data.description,
			"type": "boss_upgrade",
			"icon_color": data.color,
			"is_rare": true
		}
	
	return {}


func _create_option_card(option: Dictionary, index: int) -> Control:
	"""Cria um card visual para uma opção de upgrade"""
	var card = PanelContainer.new()
	card.name = "Card_" + str(index)
	card.custom_minimum_size = Vector2(250, 350)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Estilo do card
	var style = StyleBoxFlat.new()
	var is_rare = option.get("is_rare", false)
	
	if is_rare:
		style.bg_color = Color(0.15, 0.1, 0.2, 0.95)
		style.border_color = Color(1.0, 0.8, 0.2)  # Dourado
		style.border_width_left = 4
		style.border_width_right = 4
		style.border_width_top = 4
		style.border_width_bottom = 4
	else:
		style.bg_color = Color(0.12, 0.12, 0.18, 0.95)
		style.border_color = option.get("icon_color", Color.WHITE)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
	
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	card.add_theme_stylebox_override("panel", style)
	
	# Conteúdo do card
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 15
	vbox.offset_right = -15
	vbox.offset_top = 20
	vbox.offset_bottom = -20
	card.add_child(vbox)
	
	# Tag RARE se for de boss
	if is_rare:
		var rare_label = Label.new()
		rare_label.text = "★ RARE ★"
		rare_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rare_label.add_theme_font_size_override("font_size", 14)
		rare_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
		vbox.add_child(rare_label)
	
	# Ícone (cor representativa)
	var icon_container = CenterContainer.new()
	icon_container.custom_minimum_size = Vector2(0, 80)
	vbox.add_child(icon_container)
	
	var icon = ColorRect.new()
	icon.custom_minimum_size = Vector2(70, 70)
	icon.color = option.get("icon_color", Color.WHITE)
	icon_container.add_child(icon)
	
	# Nome
	var name_label = Label.new()
	name_label.text = option.get("name", "Unknown")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", option.get("icon_color", Color.WHITE))
	vbox.add_child(name_label)
	
	# Descrição
	var desc_label = Label.new()
	desc_label.text = option.get("description", "")
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.add_theme_font_size_override("font_size", 16)
	desc_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_label)
	
	# Tipo do upgrade
	var type_label = Label.new()
	var type_text = ""
	match option.get("type", ""):
		"weapon": type_text = "[WEAPON]"
		"player": type_text = "[PLAYER]"
		"dash": type_text = "[DASH]"
		"xp": type_text = "[XP]"
		"boss_upgrade": type_text = "[SPECIAL]"
	type_label.text = type_text
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.add_theme_font_size_override("font_size", 12)
	type_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	vbox.add_child(type_label)
	
	# Botão invisível para clique
	var button = Button.new()
	button.flat = true
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.self_modulate.a = 0
	button.pressed.connect(func(): _select_option(option))
	button.mouse_entered.connect(func(): _on_card_hover(card, true))
	button.mouse_exited.connect(func(): _on_card_hover(card, false))
	card.add_child(button)
	
	return card


func _on_card_hover(card: Control, hovering: bool) -> void:
	"""Efeito de hover no card"""
	var tween = create_tween()
	if hovering:
		tween.tween_property(card, "scale", Vector2(1.05, 1.05), 0.1)
		tween.parallel().tween_property(card, "modulate", Color(1.2, 1.2, 1.2), 0.1)
	else:
		tween.tween_property(card, "scale", Vector2.ONE, 0.1)
		tween.parallel().tween_property(card, "modulate", Color.WHITE, 0.1)


func _animate_entrance() -> void:
	"""Animação de entrada dos cards"""
	for i in range(option_cards.size()):
		var card = option_cards[i]
		card.modulate.a = 0
		card.position.y += 50
		
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BACK)
		tween.tween_property(card, "modulate:a", 1.0, 0.3).set_delay(i * 0.1)
		tween.parallel().tween_property(card, "position:y", card.position.y - 50, 0.4).set_delay(i * 0.1)


func _select_option(option: Dictionary) -> void:
	"""Callback quando uma opção é selecionada"""
	upgrade_selected.emit(option)
	
	# Aplica o upgrade
	_apply_upgrade(option)
	
	# Fecha a tela
	_close()


func _apply_upgrade(option: Dictionary) -> void:
	"""Aplica o upgrade selecionado"""
	var option_type = option.get("type", "")
	
	match option_type:
		"weapon":
			_apply_weapon_upgrade(option)
		"player":
			_apply_player_upgrade(option)
		"dash":
			_apply_dash_upgrade(option)
		"xp":
			_apply_xp_upgrade(option)
		"boss_upgrade":
			# Usa o sistema existente do UpgradeManager
			if UpgradeManager:
				UpgradeManager.select_upgrade(option.id)


func _apply_weapon_upgrade(option: Dictionary) -> void:
	"""Aplica upgrade de stats à arma"""
	var weapon = _get_current_weapon()
	if not weapon:
		print("[LevelUp] Weapon not found!")
		return
	
	var stat_name = option.get("stat", "")
	var value = option.get("value", 0)
	
	if stat_name in weapon:
		var current = weapon.get(stat_name)
		if typeof(value) == TYPE_FLOAT and abs(value) < 1.0:
			# Valor percentual
			weapon.set(stat_name, current * (1.0 + value))
		else:
			# Valor absoluto
			weapon.set(stat_name, current + value)
		
		print("[LevelUp] Weapon %s: %s -> %s" % [stat_name, current, weapon.get(stat_name)])


func _apply_player_upgrade(option: Dictionary) -> void:
	"""Aplica upgrade de stats ao player"""
	var player = _get_player()
	if not player:
		print("[LevelUp] Player not found!")
		return
	
	var stat_name = option.get("stat", "")
	var value = option.get("value", 0)
	
	# Stats do PlayerStats
	if player.has_node("PlayerStats"):
		var stats = player.get_node("PlayerStats")
		if stat_name in stats:
			var current = stats.get(stat_name)
			stats.set(stat_name, current + value)
			
			# Cura se aumentou max_health
			if stat_name == "max_health" and stats.has_method("heal"):
				stats.heal(value)
			
			print("[LevelUp] Player %s: %s -> %s" % [stat_name, current, stats.get(stat_name)])
			return
	
	# Stats do PlayerController
	if stat_name in player:
		var current = player.get(stat_name)
		if typeof(value) == TYPE_FLOAT and abs(value) < 1.0:
			player.set(stat_name, current * (1.0 + value))
		else:
			player.set(stat_name, current + value)
		
		print("[LevelUp] Player %s: %s -> %s" % [stat_name, current, player.get(stat_name)])


func _apply_dash_upgrade(option: Dictionary) -> void:
	"""Aplica upgrade ao sistema de dash"""
	var player = _get_player()
	if not player:
		return
	
	var dash_system = player.get("dash_system")
	if not dash_system:
		dash_system = player.get_node_or_null("DashSystem")
	
	if not dash_system:
		print("[LevelUp] DashSystem not found!")
		return
	
	var stat_name = option.get("stat", "")
	var value = option.get("value", 0)
	
	if stat_name in dash_system:
		var current = dash_system.get(stat_name)
		dash_system.set(stat_name, max(1.0, current + value))  # Mínimo de 1s cooldown
		print("[LevelUp] Dash %s: %s -> %s" % [stat_name, current, dash_system.get(stat_name)])


func _apply_xp_upgrade(option: Dictionary) -> void:
	"""Aplica upgrade de XP"""
	if not XPManager:
		return
	
	var stat_name = option.get("stat", "")
	var value = option.get("value", 0)
	
	if stat_name in XPManager:
		var current = XPManager.get(stat_name)
		XPManager.set(stat_name, current + value)
		print("[LevelUp] XP %s: %s -> %s" % [stat_name, current, XPManager.get(stat_name)])


func _close() -> void:
	"""Fecha a tela de level up"""
	is_showing = false
	
	# Animação de saída usando o background
	if background:
		var tween = create_tween()
		tween.tween_property(background, "modulate:a", 0.0, 0.2)
		await tween.finished
		background.modulate.a = 1.0
	
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	hide()
	screen_closed.emit()


func _get_player() -> Node:
	var players = get_tree().get_nodes_in_group("player")
	return players[0] if players.size() > 0 else null


func _get_current_weapon() -> Node:
	var player = _get_player()
	if not player:
		return null
	return player.get("current_weapon")
