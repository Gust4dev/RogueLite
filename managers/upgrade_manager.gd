extends Node

# Upgrade Manager - Singleton que gerencia o sistema de upgrades
# Controla pool de upgrades, aplicação e UI

# === SIGNALS ===
signal upgrade_screen_opened()
signal upgrade_screen_closed()
signal upgrade_selected(upgrade_id: String, level: int)
signal upgrade_applied(upgrade_id: String, level: int)

# === UPGRADE DATA ===
class UpgradeData:
	var id: String
	var name: String
	var description: String
	var icon_path: String
	var color: Color
	var max_level: int = 3
	var current_level: int = 0

	func get_level_description(_level: int) -> String:
		return description
	
	func duplicate() -> UpgradeData:
		var copy = UpgradeData.new()
		copy.id = id
		copy.name = name
		copy.description = description
		copy.icon_path = icon_path
		copy.color = color
		copy.max_level = max_level
		copy.current_level = current_level
		return copy

# === CONSTANTS ===
const MAX_ACTIVE_UPGRADES = 3
const UPGRADE_OPTIONS_COUNT = 4

# Pool de todos os upgrades disponíveis
var upgrade_pool: Dictionary = {}

# Upgrades ativos do player (id -> UpgradeData)
var active_upgrades: Dictionary = {}

# Referência à UI de upgrade
var upgrade_ui: Node = null

# Referência ao player e weapon
var player: Node3D = null
var current_weapon: Node3D = null

# Upgrade scripts carregados
var upgrade_scripts: Dictionary = {}

# Weapon Transformation System
var transformation_manager: WeaponTransformationManager = null
var visual_events: WeaponVisualEvents = null


func _ready() -> void:
	# Inicializa pool de upgrades
	_initialize_upgrade_pool()

	# Carrega scripts de upgrade
	_load_upgrade_scripts()

	# Encontra player
	call_deferred("_find_player")


func _initialize_upgrade_pool() -> void:
	"""Inicializa todos os upgrades disponíveis"""

	# Chain Lightning
	var chain_lightning = UpgradeData.new()
	chain_lightning.id = "chain_lightning"
	chain_lightning.name = "Chain Lightning"
	chain_lightning.description = "Shots chain to nearby enemies"
	chain_lightning.color = Color(0.3, 0.6, 1.0)  # Azul elétrico
	upgrade_pool["chain_lightning"] = chain_lightning

	# Ricochet
	var ricochet = UpgradeData.new()
	ricochet.id = "ricochet"
	ricochet.name = "Ricochet"
	ricochet.description = "Bullets bounce off walls and enemies"
	ricochet.color = Color(0.8, 0.8, 0.2)  # Amarelo
	upgrade_pool["ricochet"] = ricochet

	# Explosive Rounds
	var explosive = UpgradeData.new()
	explosive.id = "explosive_rounds"
	explosive.name = "Explosive Rounds"
	explosive.description = "Shots explode on impact"
	explosive.color = Color(1.0, 0.4, 0.1)  # Laranja
	upgrade_pool["explosive_rounds"] = explosive

	# Piercing Bullets
	var piercing = UpgradeData.new()
	piercing.id = "piercing_bullets"
	piercing.name = "Piercing Bullets"
	piercing.description = "Bullets pass through enemies"
	piercing.color = Color(0.7, 0.7, 0.7)  # Cinza metálico
	upgrade_pool["piercing_bullets"] = piercing

	# Fast Reload
	var fast_reload = UpgradeData.new()
	fast_reload.id = "fast_reload"
	fast_reload.name = "Fast Reload"
	fast_reload.description = "Reduced reload time"
	fast_reload.color = Color(0.2, 0.8, 0.4)  # Verde
	upgrade_pool["fast_reload"] = fast_reload

	# Burst Fire
	var burst = UpgradeData.new()
	burst.id = "burst_fire"
	burst.name = "Burst Fire"
	burst.description = "Fire multiple shots per click"
	burst.color = Color(1.0, 0.2, 0.2)  # Vermelho
	upgrade_pool["burst_fire"] = burst

	# Lifesteal
	var lifesteal = UpgradeData.new()
	lifesteal.id = "lifesteal"
	lifesteal.name = "Lifesteal"
	lifesteal.description = "Heal when damaging enemies"
	lifesteal.color = Color(0.6, 0.1, 0.6)  # Roxo
	upgrade_pool["lifesteal"] = lifesteal

	# Freeze Bullets
	var freeze = UpgradeData.new()
	freeze.id = "freeze_bullets"
	freeze.name = "Freeze Bullets"
	freeze.description = "Slow and freeze enemies"
	freeze.color = Color(0.4, 0.8, 1.0)  # Azul gelo
	upgrade_pool["freeze_bullets"] = freeze


func _load_upgrade_scripts() -> void:
	"""Carrega os scripts de cada upgrade"""
	var script_paths = {
		"chain_lightning": "res://upgrades/chain_lightning.gd",
		"ricochet": "res://upgrades/ricochet.gd",
		"explosive_rounds": "res://upgrades/explosive_rounds.gd",
		"piercing_bullets": "res://upgrades/piercing_bullets.gd",
		"fast_reload": "res://upgrades/fast_reload.gd",
		"burst_fire": "res://upgrades/burst_fire.gd",
		"lifesteal": "res://upgrades/lifesteal.gd",
		"freeze_bullets": "res://upgrades/freeze_bullets.gd"
	}

	for id in script_paths:
		var path = script_paths[id]
		if ResourceLoader.exists(path):
			upgrade_scripts[id] = load(path)


func _find_player() -> void:
	"""Encontra o player na cena"""
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

		# Busca a arma equipada
		var camera = player.get_node_or_null("Camera3D")
		if camera:
			for child in camera.get_children():
				if child.is_in_group("weapons"):
					current_weapon = child
					break


func set_weapon(weapon: Node3D) -> void:
	"""Define a arma atual"""
	current_weapon = weapon

	# Setup transformation system
	_setup_transformation_system()

	# Reaplica todos os upgrades ativos
	for upgrade_id in active_upgrades:
		_apply_upgrade_to_weapon(upgrade_id)


func _setup_transformation_system() -> void:
	"""Setup the weapon transformation system"""
	if not current_weapon:
		return

	# Create or get transformation manager
	transformation_manager = current_weapon.get_node_or_null("TransformationManager")
	if not transformation_manager:
		transformation_manager = WeaponTransformationManager.new()
		transformation_manager.name = "TransformationManager"
		current_weapon.add_child(transformation_manager)

	transformation_manager.setup(current_weapon)

	# Create or get visual events handler
	visual_events = current_weapon.get_node_or_null("VisualEvents")
	if not visual_events:
		visual_events = WeaponVisualEvents.new()
		visual_events.name = "VisualEvents"
		current_weapon.add_child(visual_events)

	visual_events.setup(current_weapon, transformation_manager)


func show_upgrade_screen() -> void:
	"""Mostra a tela de seleção de upgrade"""
	# Pausa o jogo
	get_tree().paused = true
	
	# Libera o cursor do mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Gera opções aleatórias
	var options = generate_upgrade_options(UPGRADE_OPTIONS_COUNT)

	# Cria/mostra UI
	if not upgrade_ui:
		_create_upgrade_ui()

	if upgrade_ui:
		if upgrade_ui.has_method("show"):
			upgrade_ui.show()
		else:
			upgrade_ui.set("visible", true)
		if upgrade_ui.has_method("show_options"):
			upgrade_ui.show_options(options)

	upgrade_screen_opened.emit()


func hide_upgrade_screen() -> void:
	"""Esconde a tela de upgrade"""
	if upgrade_ui:
		if upgrade_ui.has_method("hide"):
			upgrade_ui.hide()
		else:
			upgrade_ui.set("visible", false)

	# Resume o jogo
	get_tree().paused = false
	
	# Recaptura o cursor do mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	upgrade_screen_closed.emit()


func generate_upgrade_options(count: int) -> Array:
	"""Gera opções de upgrade aleatórias"""
	var options: Array = []
	var available: Array = []

	# Coleta upgrades disponíveis (não maxados)
	for id in upgrade_pool:
		var data = upgrade_pool[id]
		var current_level = 0

		if id in active_upgrades:
			current_level = active_upgrades[id].current_level

		# Só adiciona se não estiver no nível máximo
		if current_level < data.max_level:
			available.append(id)

	# Embaralha
	available.shuffle()

	# Pega os primeiros 'count'
	for i in range(min(count, available.size())):
		var id = available[i]
		var data = upgrade_pool[id].duplicate()

		# Adiciona nível atual
		if id in active_upgrades:
			data.current_level = active_upgrades[id].current_level
		else:
			data.current_level = 0

		options.append(data)

	return options


func select_upgrade(upgrade_id: String) -> void:
	"""Seleciona e aplica um upgrade"""
	if not upgrade_id in upgrade_pool:
		push_error("Invalid upgrade ID: " + upgrade_id)
		return

	var new_level = 1

	# Verifica se já tem o upgrade
	if upgrade_id in active_upgrades:
		var current = active_upgrades[upgrade_id]
		if current.current_level >= current.max_level:
			push_warning("Upgrade already at max level: " + upgrade_id)
			return

		# Level up
		current.current_level += 1
		new_level = current.current_level
	else:
		# Novo upgrade
		if active_upgrades.size() >= MAX_ACTIVE_UPGRADES:
			# Verifica se é um upgrade que já existe (level up)
			push_warning("Max upgrades reached!")
			return

		# Adiciona novo upgrade
		var data = upgrade_pool[upgrade_id].duplicate()
		data.current_level = 1
		active_upgrades[upgrade_id] = data
		new_level = 1

	# Aplica o upgrade
	_apply_upgrade_to_weapon(upgrade_id)

	# Atualiza visual da arma
	_update_weapon_visual()

	# Registra no XPManager para aparecer no level up
	if XPManager:
		XPManager.register_boss_upgrade(upgrade_id)

	# Emite signals
	upgrade_selected.emit(upgrade_id, new_level)
	upgrade_applied.emit(upgrade_id, new_level)

	# Fecha tela de upgrade
	hide_upgrade_screen()


func _apply_upgrade_to_weapon(upgrade_id: String) -> void:
	"""Aplica um upgrade específico à arma"""
	if not current_weapon:
		_find_player()
		if not current_weapon:
			return

	if not upgrade_id in active_upgrades:
		return

	var upgrade_data = active_upgrades[upgrade_id]
	var level = upgrade_data.current_level

	# Verifica se o script existe
	if not upgrade_id in upgrade_scripts:
		return

	# Verifica se já tem o nó de upgrade
	var upgrade_node = current_weapon.get_node_or_null("Upgrade_" + upgrade_id)

	if not upgrade_node:
		# Cria novo nó de upgrade
		var script = upgrade_scripts[upgrade_id]
		upgrade_node = Node.new()
		upgrade_node.name = "Upgrade_" + upgrade_id
		upgrade_node.set_script(script)
		current_weapon.add_child(upgrade_node)

	# Atualiza nível
	if upgrade_node.has_method("set_level"):
		upgrade_node.set_level(level)

	# Aplica efeitos
	if upgrade_node.has_method("apply"):
		upgrade_node.apply(current_weapon, player)


func _update_weapon_visual() -> void:
	"""Atualiza visual da arma baseado nos upgrades usando o sistema de transformacao"""
	if not current_weapon:
		return

	# Ensure transformation system is setup
	if not transformation_manager:
		_setup_transformation_system()

	if not transformation_manager:
		# Fallback to old system
		_update_weapon_visual_legacy()
		return

	# Apply transformations for all active upgrades
	for upgrade_id in active_upgrades:
		var data = active_upgrades[upgrade_id]
		var level = data.current_level

		# Apply or update visual transformation
		if transformation_manager.has_transformation(upgrade_id):
			transformation_manager.update_upgrade_level(upgrade_id, level)
		else:
			transformation_manager.apply_upgrade_visual(upgrade_id, level)


func _update_weapon_visual_legacy() -> void:
	"""Legacy visual update (fallback)"""
	# Determina cor principal baseada no upgrade mais forte
	var primary_color = Color.WHITE
	var total_intensity = 0.0

	for upgrade_id in active_upgrades:
		var data = active_upgrades[upgrade_id]
		var intensity = data.current_level * 0.5

		if intensity > total_intensity:
			total_intensity = intensity
			primary_color = upgrade_pool[upgrade_id].color

	# Aplica glow à arma
	_apply_weapon_glow(primary_color, total_intensity)


func _apply_weapon_glow(color: Color, intensity: float) -> void:
	"""Aplica efeito de glow à arma"""
	if not current_weapon:
		return

	# Busca mesh da arma
	var mesh: Node3D = null
	for child in current_weapon.get_children():
		if child is MeshInstance3D or (child is Node3D and child.name.contains("Mesh")):
			mesh = child
			break

	if not mesh:
		return

	# Busca MeshInstance3D
	var mesh_instance: MeshInstance3D = null
	if mesh is MeshInstance3D:
		mesh_instance = mesh
	else:
		mesh_instance = mesh.find_child("*", true, false) as MeshInstance3D
		if not mesh_instance:
			for child in mesh.get_children():
				if child is MeshInstance3D:
					mesh_instance = child
					break

	if not mesh_instance:
		return

	# Aplica material com glow
	var material = mesh_instance.get_surface_override_material(0)
	if not material or not material is StandardMaterial3D:
		material = StandardMaterial3D.new()
		mesh_instance.set_surface_override_material(0, material)

	if material is StandardMaterial3D:
		material.emission_enabled = intensity > 0
		material.emission = color
		material.emission_energy_multiplier = intensity


func _create_upgrade_ui() -> void:
	"""Cria a UI de upgrade"""
	# A UI será carregada como cena
	if ResourceLoader.exists("res://ui/upgrade_screen.tscn"):
		var ui_scene = load("res://ui/upgrade_screen.tscn")
		upgrade_ui = ui_scene.instantiate()
		
		# IMPORTANTE: Define process_mode ANTES de adicionar à árvore
		# Isso garante que a UI funcione mesmo quando o jogo está pausado
		upgrade_ui.process_mode = Node.PROCESS_MODE_ALWAYS
		
		get_tree().current_scene.add_child(upgrade_ui)

		# Conecta signals
		if upgrade_ui.has_signal("upgrade_selected"):
			upgrade_ui.upgrade_selected.connect(select_upgrade)
	else:
		# Cria UI básica se não houver cena
		upgrade_ui = _create_basic_upgrade_ui()
		upgrade_ui.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().current_scene.add_child(upgrade_ui)


func _create_basic_upgrade_ui() -> CanvasLayer:
	"""Cria uma UI básica de upgrade (fallback)"""
	var canvas = CanvasLayer.new()
	canvas.layer = 100

	var panel = Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)

	canvas.add_child(panel)

	# Adiciona script básico
	var script = GDScript.new()
	script.source_code = """
extends Control

signal upgrade_selected(upgrade_id: String)

var options: Array = []

func show_options(upgrade_options: Array):
	options = upgrade_options
	_build_ui()

func _build_ui():
	# Limpa filhos anteriores
	for child in get_children():
		child.queue_free()

	# Background escuro
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.8)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Container principal
	var container = VBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_CENTER)
	container.anchor_left = 0.1
	container.anchor_right = 0.9
	container.anchor_top = 0.2
	container.anchor_bottom = 0.8
	container.offset_left = 0
	container.offset_right = 0
	container.offset_top = 0
	container.offset_bottom = 0
	add_child(container)

	# Título
	var title = Label.new()
	title.text = \"CHOOSE YOUR UPGRADE\"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(\"font_size\", 48)
	container.add_child(title)

	# Espaço
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	container.add_child(spacer)

	# Cards container
	var cards = HBoxContainer.new()
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override(\"separation\", 20)
	container.add_child(cards)

	# Cria cards para cada opção
	for opt in options:
		var card = _create_card(opt)
		cards.add_child(card)

func _create_card(data) -> Control:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.9)
	style.border_color = data.color
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	card.add_theme_stylebox_override(\"panel\", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override(\"separation\", 10)
	card.add_child(vbox)

	# Nome
	var name_label = Label.new()
	name_label.text = data.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override(\"font_size\", 24)
	name_label.add_theme_color_override(\"font_color\", data.color)
	vbox.add_child(name_label)

	# Ícone (placeholder colorido)
	var icon = ColorRect.new()
	icon.color = data.color
	icon.custom_minimum_size = Vector2(80, 80)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(icon)

	# Descrição
	var desc = Label.new()
	desc.text = data.description
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_font_size_override(\"font_size\", 16)
	vbox.add_child(desc)

	# Level
	var level_label = Label.new()
	if data.current_level > 0:
		level_label.text = \"Level \" + str(data.current_level) + \" -> \" + str(data.current_level + 1)
	else:
		level_label.text = \"NEW\"
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override(\"font_size\", 18)
	level_label.add_theme_color_override(\"font_color\", Color.YELLOW if data.current_level == 0 else Color.GREEN)
	vbox.add_child(level_label)

	# Botão invisível
	var button = Button.new()
	button.flat = true
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.modulate.a = 0
	button.pressed.connect(func(): upgrade_selected.emit(data.id))
	card.add_child(button)

	return card
"""
	panel.set_script(script)

	return canvas


func get_active_upgrades() -> Dictionary:
	"""Retorna dicionário de upgrades ativos"""
	return active_upgrades


func get_upgrade_level(upgrade_id: String) -> int:
	"""Retorna o nível de um upgrade específico"""
	if upgrade_id in active_upgrades:
		return active_upgrades[upgrade_id].current_level
	return 0


func has_upgrade(upgrade_id: String) -> bool:
	"""Verifica se tem um upgrade específico"""
	return upgrade_id in active_upgrades


func reset_upgrades() -> void:
	"""Reseta todos os upgrades"""
	# Remove nós de upgrade da arma
	if current_weapon:
		for upgrade_id in active_upgrades:
			var node = current_weapon.get_node_or_null("Upgrade_" + upgrade_id)
			if node:
				node.queue_free()

	active_upgrades.clear()

	# Clear transformation system
	if transformation_manager:
		transformation_manager.clear_all_transformations()

	# Cleanup visual events
	if visual_events:
		visual_events.cleanup()

	# Remove glow da arma (legacy fallback)
	_apply_weapon_glow(Color.WHITE, 0.0)
