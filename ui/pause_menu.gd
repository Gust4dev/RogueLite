extends CanvasLayer

# Pause Menu - Tela de pausa com stats de upgrades e weapon stats
# Estilo inspirado em Vampire Survivors / Mega Bonk

class_name PauseMenu

signal resume_requested()
signal reset_requested()
signal main_menu_requested()

# === UI REFERENCES ===
var background: ColorRect
var main_container: HBoxContainer
var upgrades_container: VBoxContainer
var weapon_stats_container: VBoxContainer
var buttons_container: HBoxContainer
var reset_confirm_dialog: Control

# === STATE ===
var is_showing_confirm: bool = false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	_build_ui()


func _build_ui() -> void:
	"""Constrói toda a UI do pause menu"""
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	
	# Background semi-transparente
	background = ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.0, 0.0, 0.0, 0.85)
	root.add_child(background)
	
	# Container central
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	
	# Main panel (mais largo para duas colunas)
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(900, 550)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.12, 0.95)
	panel_style.border_color = Color(0.3, 0.5, 0.8, 0.8)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)
	
	# Margins
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 25)
	margin.add_theme_constant_override("margin_right", 25)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	
	# VBox principal
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 15)
	margin.add_child(main_vbox)
	
	# Título
	var title = Label.new()
	title.text = "⏸ PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	main_vbox.add_child(title)
	
	# Separator
	var sep1 = HSeparator.new()
	sep1.add_theme_stylebox_override("separator", _create_separator_style())
	main_vbox.add_child(sep1)
	
	# === DUAS COLUNAS: Upgrades (esquerda) | Weapon Stats (direita) ===
	main_container = HBoxContainer.new()
	main_container.add_theme_constant_override("separation", 20)
	main_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(main_container)
	
	# === COLUNA ESQUERDA: Upgrades + Run Info ===
	var left_column = VBoxContainer.new()
	left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_column.add_theme_constant_override("separation", 10)
	main_container.add_child(left_column)
	
	# Upgrades Title
	var upgrades_title = Label.new()
	upgrades_title.text = "UPGRADES"
	upgrades_title.add_theme_font_size_override("font_size", 18)
	upgrades_title.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	left_column.add_child(upgrades_title)
	
	# Scroll para upgrades
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 180)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_column.add_child(scroll)
	
	upgrades_container = VBoxContainer.new()
	upgrades_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrades_container.add_theme_constant_override("separation", 6)
	scroll.add_child(upgrades_container)
	
	# Run Info Section
	var sep_left = HSeparator.new()
	sep_left.add_theme_stylebox_override("separator", _create_separator_style())
	left_column.add_child(sep_left)
	
	var info_title = Label.new()
	info_title.text = "RUN INFO"
	info_title.add_theme_font_size_override("font_size", 18)
	info_title.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	left_column.add_child(info_title)
	
	var info_container = VBoxContainer.new()
	info_container.name = "InfoContainer"
	info_container.add_theme_constant_override("separation", 4)
	left_column.add_child(info_container)
	
	# === SEPARADOR VERTICAL ===
	var vsep = VSeparator.new()
	main_container.add_child(vsep)
	
	# === COLUNA DIREITA: Weapon Stats ===
	var right_column = VBoxContainer.new()
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.add_theme_constant_override("separation", 10)
	main_container.add_child(right_column)
	
	var weapon_title = Label.new()
	weapon_title.text = "WEAPON STATS"
	weapon_title.add_theme_font_size_override("font_size", 18)
	weapon_title.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	right_column.add_child(weapon_title)
	
	weapon_stats_container = VBoxContainer.new()
	weapon_stats_container.name = "WeaponStatsContainer"
	weapon_stats_container.add_theme_constant_override("separation", 8)
	weapon_stats_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_column.add_child(weapon_stats_container)
	
	# === BOTÕES (centralizados embaixo) ===
	var sep_bottom = HSeparator.new()
	sep_bottom.add_theme_stylebox_override("separator", _create_separator_style())
	main_vbox.add_child(sep_bottom)
	
	buttons_container = HBoxContainer.new()
	buttons_container.add_theme_constant_override("separation", 15)
	buttons_container.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(buttons_container)
	
	_create_button("▶ RESUME", Color(0.3, 0.7, 0.4), _on_resume_pressed)
	_create_button("↻ RESET RUN", Color(0.8, 0.5, 0.2), _on_reset_pressed)
	_create_button("◀ MAIN MENU", Color(0.5, 0.5, 0.6), _on_main_menu_pressed)
	
	# Reset Confirm Dialog (hidden)
	_build_confirm_dialog(root)


func _create_separator_style() -> StyleBoxLine:
	var style = StyleBoxLine.new()
	style.color = Color(0.3, 0.4, 0.5, 0.5)
	style.thickness = 1
	return style


func _create_button(text: String, color: Color, callback: Callable) -> void:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(150, 40)
	
	var style = StyleBoxFlat.new()
	style.bg_color = color.darkened(0.3)
	style.border_color = color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	btn.add_theme_stylebox_override("normal", style)
	
	var hover_style = style.duplicate()
	hover_style.bg_color = color.darkened(0.1)
	btn.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style = style.duplicate()
	pressed_style.bg_color = color
	btn.add_theme_stylebox_override("pressed", pressed_style)
	
	btn.add_theme_font_size_override("font_size", 16)
	btn.pressed.connect(callback)
	
	buttons_container.add_child(btn)


func _build_confirm_dialog(parent: Control) -> void:
	"""Constrói o dialog de confirmação de reset"""
	reset_confirm_dialog = Control.new()
	reset_confirm_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	reset_confirm_dialog.visible = false
	parent.add_child(reset_confirm_dialog)
	
	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.7)
	reset_confirm_dialog.add_child(overlay)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	reset_confirm_dialog.add_child(center)
	
	var dialog_panel = PanelContainer.new()
	dialog_panel.custom_minimum_size = Vector2(350, 180)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.15, 0.98)
	style.border_color = Color(0.9, 0.3, 0.2)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	dialog_panel.add_theme_stylebox_override("panel", style)
	center.add_child(dialog_panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	dialog_panel.add_child(vbox)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	vbox.add_child(margin)
	
	var inner_vbox = VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 20)
	margin.add_child(inner_vbox)
	
	var warning = Label.new()
	warning.text = "⚠ RESET RUN?"
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.add_theme_font_size_override("font_size", 24)
	warning.add_theme_color_override("font_color", Color(0.9, 0.3, 0.2))
	inner_vbox.add_child(warning)
	
	var desc = Label.new()
	desc.text = "All progress will be lost.\nYou will restart with the same character."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	inner_vbox.add_child(desc)
	
	var btn_container = HBoxContainer.new()
	btn_container.add_theme_constant_override("separation", 15)
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	inner_vbox.add_child(btn_container)
	
	var cancel_btn = Button.new()
	cancel_btn.text = "CANCEL"
	cancel_btn.custom_minimum_size = Vector2(100, 40)
	cancel_btn.pressed.connect(_on_confirm_cancel)
	btn_container.add_child(cancel_btn)
	
	var confirm_btn = Button.new()
	confirm_btn.text = "CONFIRM"
	confirm_btn.custom_minimum_size = Vector2(100, 40)
	var confirm_style = StyleBoxFlat.new()
	confirm_style.bg_color = Color(0.7, 0.2, 0.15)
	confirm_style.corner_radius_top_left = 5
	confirm_style.corner_radius_top_right = 5
	confirm_style.corner_radius_bottom_left = 5
	confirm_style.corner_radius_bottom_right = 5
	confirm_btn.add_theme_stylebox_override("normal", confirm_style)
	confirm_btn.pressed.connect(_on_confirm_reset)
	btn_container.add_child(confirm_btn)


func show_pause_menu() -> void:
	"""Mostra o pause menu e popula com dados atuais"""
	visible = true
	is_showing_confirm = false
	reset_confirm_dialog.visible = false
	
	_populate_upgrades()
	_populate_run_info()
	_populate_weapon_stats()


func hide_pause_menu() -> void:
	"""Esconde o pause menu"""
	visible = false


func _populate_upgrades() -> void:
	"""Popula a lista de upgrades ativos"""
	for child in upgrades_container.get_children():
		child.queue_free()
	
	if not UpgradeManager:
		_add_no_upgrades_label()
		return
	
	var active = UpgradeManager.get_active_upgrades()
	
	if active.is_empty():
		_add_no_upgrades_label()
		return
	
	for upgrade_id in active:
		var data = active[upgrade_id]
		var row = _create_upgrade_row(data)
		upgrades_container.add_child(row)


func _add_no_upgrades_label() -> void:
	var label = Label.new()
	label.text = "No upgrades yet"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	upgrades_container.add_child(label)


func _create_upgrade_row(data) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	
	var icon = ColorRect.new()
	icon.custom_minimum_size = Vector2(20, 20)
	icon.color = data.color if "color" in data else Color.WHITE
	row.add_child(icon)
	
	var name_label = Label.new()
	name_label.text = data.name if "name" in data else data.id
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	row.add_child(name_label)
	
	var level = data.current_level if "current_level" in data else 1
	var max_level = data.max_level if "max_level" in data else 3
	var percent = int((float(level) / float(max_level)) * 100)
	
	var level_label = Label.new()
	if level >= max_level:
		level_label.text = "MAX"
		level_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	else:
		level_label.text = "Lv.%d" % level
		level_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	
	level_label.add_theme_font_size_override("font_size", 13)
	row.add_child(level_label)
	
	return row


func _populate_run_info() -> void:
	var info_container = main_container.find_child("InfoContainer", true, false)
	if not info_container:
		return
	
	for child in info_container.get_children():
		child.queue_free()
	
	if GameManager:
		var elapsed = 900 - GameManager.time_remaining
		var elapsed_min = elapsed / 60
		var elapsed_sec = elapsed % 60
		_add_info_row(info_container, "⏱", "Time: %02d:%02d / 15:00" % [elapsed_min, elapsed_sec])
		
		# Dificuldade
		_add_info_row(info_container, "⚔", "Difficulty: %s" % GameManager.get_difficulty_name())
	
	if XPManager:
		_add_info_row(info_container, "📈", "Level: %d" % XPManager.current_level)
	
	if CharacterManager:
		var char_data = CharacterManager.get_selected_character()
		_add_info_row(info_container, "🎯", char_data.get("name", "Unknown"))
	
	# === MULTIPLIERS ===
	var sep = HSeparator.new()
	sep.add_theme_stylebox_override("separator", _create_separator_style())
	info_container.add_child(sep)
	
	var mult_title = Label.new()
	mult_title.text = "MULTIPLIERS"
	mult_title.add_theme_font_size_override("font_size", 14)
	mult_title.add_theme_color_override("font_color", Color(0.8, 0.7, 0.3))
	info_container.add_child(mult_title)
	
	if GameManager:
		# XP Multiplier
		var xp_mult = GameManager.get_xp_multiplier()
		var xp_color = Color(0.5, 1.0, 0.5) if xp_mult > 1.0 else Color(0.7, 0.7, 0.7)
		_add_multiplier_row(info_container, "XP", xp_mult, xp_color)
		
		# Damage Multiplier (do inimigo - maior = pior)
		var dmg_mult = GameManager.get_damage_multiplier()
		var dmg_color = Color(1.0, 0.5, 0.5) if dmg_mult > 1.0 else Color(0.5, 1.0, 0.5) if dmg_mult < 1.0 else Color(0.7, 0.7, 0.7)
		_add_multiplier_row(info_container, "Enemy Dmg", dmg_mult, dmg_color)
		
		# Money Multiplier
		var money_mult = GameManager.get_money_multiplier()
		var money_color = Color(1.0, 0.85, 0.3) if money_mult > 1.0 else Color(0.7, 0.7, 0.7)
		_add_multiplier_row(info_container, "Money", money_mult, money_color)


func _add_multiplier_row(container: Control, name: String, mult: float, color: Color) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	
	var name_label = Label.new()
	name_label.text = name + ":"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	row.add_child(name_label)
	
	var value_label = Label.new()
	var pct = int(mult * 100)
	value_label.text = "%d%%" % pct
	value_label.add_theme_font_size_override("font_size", 12)
	value_label.add_theme_color_override("font_color", color)
	row.add_child(value_label)
	
	container.add_child(row)


func _populate_weapon_stats() -> void:
	"""Popula os stats da arma atual"""
	for child in weapon_stats_container.get_children():
		child.queue_free()
	
	# Busca a arma atual do player
	var weapon = _get_current_weapon()
	if not weapon:
		var no_weapon = Label.new()
		no_weapon.text = "No weapon equipped"
		no_weapon.add_theme_font_size_override("font_size", 14)
		no_weapon.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		weapon_stats_container.add_child(no_weapon)
		return
	
	# Stats base da arma
	var base_damage = weapon.get("damage") if weapon.get("damage") else 10.0
	var base_fire_rate = weapon.get("fire_rate") if weapon.get("fire_rate") else 0.2
	var base_reload_time = weapon.get("reload_time") if weapon.get("reload_time") else 1.5
	var magazine_size = weapon.get("magazine_size") if weapon.get("magazine_size") else 12
	
	# Calcula DPS
	var dps = base_damage / base_fire_rate if base_fire_rate > 0 else 0
	
	# Calcula modificadores de upgrade (se houver)
	var damage_mult = 1.0
	var fire_rate_mult = 1.0
	var reload_mult = 1.0
	
	# Verifica upgrades aplicados
	if UpgradeManager:
		var active = UpgradeManager.get_active_upgrades()
		
		# Fast Reload aumenta velocidade de reload
		if active.has("fast_reload"):
			var level = active["fast_reload"].current_level
			reload_mult = 1.0 - (level * 0.15)  # 15% por nível
		
		# Burst Fire afeta dano efetivo
		if active.has("burst_fire"):
			var level = active["burst_fire"].current_level
			damage_mult += level * 0.25  # +25% por nível
		
		# Explosive rounds aumenta dano
		if active.has("explosive_rounds"):
			var level = active["explosive_rounds"].current_level
			damage_mult += level * 0.3  # +30% por nível
	
	# Adiciona stats com cor baseada em bônus
	_add_weapon_stat("Damage", base_damage, damage_mult, "/hit")
	_add_weapon_stat("Fire Rate", 1.0 / base_fire_rate, fire_rate_mult, "/s")
	_add_weapon_stat("Reload Time", base_reload_time * reload_mult, 1.0, "s", true)
	_add_weapon_stat("Magazine", magazine_size, 1.0, "")
	_add_weapon_stat("DPS", dps * damage_mult, 1.0, "")
	
	# Separador
	var sep = HSeparator.new()
	sep.add_theme_stylebox_override("separator", _create_separator_style())
	weapon_stats_container.add_child(sep)
	
	# Player stats
	var player_section = Label.new()
	player_section.text = "PLAYER STATS"
	player_section.add_theme_font_size_override("font_size", 16)
	player_section.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	weapon_stats_container.add_child(player_section)
	
	# Speed
	var player = _get_player()
	if player:
		var speed_mult = player.get("speed_multiplier") if player.get("speed_multiplier") else 1.0
		_add_player_stat("Move Speed", speed_mult * 100, "%")
		
		# Armor
		var stats = player.get_node_or_null("PlayerStats")
		if stats:
			var armor = stats.get("armor") if stats.get("armor") else 0.0
			_add_player_stat("Armor", armor, "%")
		
		# Dash info
		var dash_sys = player.get_node_or_null("DashSystem")
		if dash_sys:
			var stamina = dash_sys.get("current_stamina") if dash_sys.get("current_stamina") else 100.0
			var max_stam = dash_sys.get("max_stamina") if dash_sys.get("max_stamina") else 100.0
			_add_player_stat("Stamina", (stamina / max_stam) * 100, "%")


func _add_weapon_stat(stat_name: String, value: float, multiplier: float, suffix: String, invert: bool = false) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	
	var name_label = Label.new()
	name_label.text = stat_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	row.add_child(name_label)
	
	var value_label = Label.new()
	if suffix == "s":
		value_label.text = "%.2f%s" % [value, suffix]
	else:
		value_label.text = "%.1f%s" % [value, suffix]
	value_label.add_theme_font_size_override("font_size", 14)
	
	# Cor baseada no multiplicador
	var is_buffed = multiplier > 1.0 if not invert else multiplier < 1.0
	if is_buffed:
		value_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))  # Verde
	elif multiplier != 1.0:
		value_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))  # Vermelho
	else:
		value_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	
	row.add_child(value_label)
	weapon_stats_container.add_child(row)


func _add_player_stat(stat_name: String, value: float, suffix: String) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	
	var name_label = Label.new()
	name_label.text = stat_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	row.add_child(name_label)
	
	var value_label = Label.new()
	value_label.text = "%.0f%s" % [value, suffix]
	value_label.add_theme_font_size_override("font_size", 14)
	
	# Cor verde se acima de 100% ou tem bônus
	if value > 100.0 or (stat_name == "Armor" and value > 0):
		value_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	elif value < 100.0 and stat_name == "Move Speed":
		value_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
	else:
		value_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	
	row.add_child(value_label)
	weapon_stats_container.add_child(row)


func _add_info_row(container: Control, icon: String, text: String) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	
	var icon_label = Label.new()
	icon_label.text = icon
	icon_label.add_theme_font_size_override("font_size", 13)
	row.add_child(icon_label)
	
	var text_label = Label.new()
	text_label.text = text
	text_label.add_theme_font_size_override("font_size", 13)
	text_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	row.add_child(text_label)
	
	container.add_child(row)


func _get_current_weapon() -> Node3D:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0].get("current_weapon")
	return null


func _get_player() -> Node3D:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null


# === CALLBACKS ===

func _on_resume_pressed() -> void:
	resume_requested.emit()


func _on_reset_pressed() -> void:
	is_showing_confirm = true
	reset_confirm_dialog.visible = true


func _on_main_menu_pressed() -> void:
	main_menu_requested.emit()


func _on_confirm_cancel() -> void:
	is_showing_confirm = false
	reset_confirm_dialog.visible = false


func _on_confirm_reset() -> void:
	reset_requested.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	if event.is_action_pressed("ui_cancel"):
		if is_showing_confirm:
			_on_confirm_cancel()
		else:
			resume_requested.emit()
		get_viewport().set_input_as_handled()
