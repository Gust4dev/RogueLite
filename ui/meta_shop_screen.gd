extends CanvasLayer

# Meta Shop Screen - Tela para comprar upgrades permanentes com Souls
# Acessa MetaProgression para mostrar currency e upgrades disponíveis

class_name MetaShopScreen

signal closed()
signal upgrade_purchased(upgrade_id: String)

# Referências
var root_control: Control = null
var upgrades_container: VBoxContainer = null
var souls_label: Label = null
var close_button: Button = null

# Cores do tema
const COLOR_PURPLE = Color(0.6, 0.4, 1.0)
const COLOR_GOLD = Color(1.0, 0.85, 0.4)
const COLOR_BG = Color(0.08, 0.05, 0.12, 0.95)


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	_build_ui()


func _build_ui() -> void:
	"""Constrói a UI da loja de souls"""
	root_control = Control.new()
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root_control)
	
	# Background escuro
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = COLOR_BG
	root_control.add_child(bg)
	
	# Center container
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(center)
	
	# Main panel
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 500)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.08, 0.18, 0.98)
	panel_style.border_color = COLOR_PURPLE
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.corner_radius_top_left = 15
	panel_style.corner_radius_top_right = 15
	panel_style.corner_radius_bottom_left = 15
	panel_style.corner_radius_bottom_right = 15
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)
	
	# Margin
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 25)
	margin.add_theme_constant_override("margin_bottom", 25)
	panel.add_child(margin)
	
	# Main VBox
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 15)
	margin.add_child(main_vbox)
	
	# Header
	_build_header(main_vbox)
	
	# Separator
	var sep = HSeparator.new()
	var sep_style = StyleBoxLine.new()
	sep_style.color = COLOR_PURPLE.darkened(0.3)
	sep_style.thickness = 2
	sep.add_theme_stylebox_override("separator", sep_style)
	main_vbox.add_child(sep)
	
	# Scroll container para upgrades
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)
	
	# Container de upgrades
	upgrades_container = VBoxContainer.new()
	upgrades_container.add_theme_constant_override("separation", 10)
	upgrades_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(upgrades_container)
	
	# Separator 2
	var sep2 = HSeparator.new()
	sep2.add_theme_stylebox_override("separator", sep_style)
	main_vbox.add_child(sep2)
	
	# Close button
	close_button = Button.new()
	close_button.text = "✕ CLOSE"
	close_button.custom_minimum_size = Vector2(0, 40)
	_style_button(close_button, Color(0.4, 0.4, 0.5))
	close_button.pressed.connect(_on_close_pressed)
	main_vbox.add_child(close_button)


func _build_header(container: VBoxContainer) -> void:
	"""Constrói o cabeçalho com título e souls"""
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	container.add_child(header)
	
	# Título
	var title = Label.new()
	title.text = "✧ SOUL FORGE ✧"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", COLOR_PURPLE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	
	# Souls display
	var souls_container = HBoxContainer.new()
	souls_container.add_theme_constant_override("separation", 8)
	header.add_child(souls_container)
	
	var souls_icon = Label.new()
	souls_icon.text = "✧"
	souls_icon.add_theme_font_size_override("font_size", 24)
	souls_icon.add_theme_color_override("font_color", COLOR_GOLD)
	souls_container.add_child(souls_icon)
	
	souls_label = Label.new()
	souls_label.text = "0"
	souls_label.add_theme_font_size_override("font_size", 24)
	souls_label.add_theme_color_override("font_color", COLOR_GOLD)
	souls_container.add_child(souls_label)


func _style_button(btn: Button, color: Color) -> void:
	"""Aplica estilo a um botão"""
	var style = StyleBoxFlat.new()
	style.bg_color = color.darkened(0.4)
	style.border_color = color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", style)
	
	var hover_style = style.duplicate()
	hover_style.bg_color = color.darkened(0.2)
	btn.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style = style.duplicate()
	pressed_style.bg_color = color
	btn.add_theme_stylebox_override("pressed", pressed_style)
	
	var disabled_style = style.duplicate()
	disabled_style.bg_color = Color(0.2, 0.2, 0.2, 0.5)
	disabled_style.border_color = Color(0.3, 0.3, 0.3)
	btn.add_theme_stylebox_override("disabled", disabled_style)
	
	btn.add_theme_font_size_override("font_size", 16)


func show_shop() -> void:
	"""Mostra a loja e popula upgrades"""
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_ui()


func hide_shop() -> void:
	"""Esconde a loja"""
	visible = false
	closed.emit()


func _refresh_ui() -> void:
	"""Atualiza toda a UI"""
	_update_souls_display()
	_populate_upgrades()


func _update_souls_display() -> void:
	"""Atualiza o display de souls"""
	if souls_label and MetaProgression:
		souls_label.text = str(MetaProgression.get_meta_currency())


func _populate_upgrades() -> void:
	"""Popula a lista de upgrades"""
	# Limpa anteriores
	for child in upgrades_container.get_children():
		child.queue_free()
	
	if not MetaProgression:
		return
	
	# Obtém todos os upgrades
	var upgrades = MetaProgression.get_all_upgrades()
	
	for upgrade in upgrades:
		var card = _create_upgrade_card(upgrade)
		upgrades_container.add_child(card)


func _create_upgrade_card(upgrade: Dictionary) -> PanelContainer:
	"""Cria um card de upgrade"""
	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.15, 0.1, 0.2, 0.9)
	card_style.border_color = COLOR_PURPLE.darkened(0.3)
	card_style.border_width_left = 1
	card_style.border_width_right = 1
	card_style.border_width_top = 1
	card_style.border_width_bottom = 1
	card_style.corner_radius_top_left = 8
	card_style.corner_radius_top_right = 8
	card_style.corner_radius_bottom_left = 8
	card_style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", card_style)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)
	card.add_child(hbox)
	
	# Info column
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 5)
	hbox.add_child(info_vbox)
	
	# Margin interno
	var info_margin = MarginContainer.new()
	info_margin.add_theme_constant_override("margin_left", 15)
	info_margin.add_theme_constant_override("margin_right", 15)
	info_margin.add_theme_constant_override("margin_top", 10)
	info_margin.add_theme_constant_override("margin_bottom", 10)
	info_vbox.add_child(info_margin)
	
	var inner_vbox = VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 3)
	info_margin.add_child(inner_vbox)
	
	# Nome do upgrade
	var name_label = Label.new()
	name_label.text = upgrade.name
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	inner_vbox.add_child(name_label)
	
	# Descrição
	var desc_label = Label.new()
	desc_label.text = upgrade.description
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	inner_vbox.add_child(desc_label)
	
	# Nível atual
	var level_label = Label.new()
	var level_text = "Level: %d / %d" % [upgrade.current_level, upgrade.max_level]
	if upgrade.current_level >= upgrade.max_level:
		level_text = "✓ MAX"
		level_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	else:
		level_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	level_label.text = level_text
	level_label.add_theme_font_size_override("font_size", 14)
	inner_vbox.add_child(level_label)
	
	# Botão de compra
	var btn_container = VBoxContainer.new()
	btn_container.custom_minimum_size = Vector2(100, 0)
	hbox.add_child(btn_container)
	
	# Margin pro botão
	var btn_margin = MarginContainer.new()
	btn_margin.add_theme_constant_override("margin_right", 10)
	btn_margin.add_theme_constant_override("margin_top", 15)
	btn_margin.add_theme_constant_override("margin_bottom", 15)
	btn_container.add_child(btn_margin)
	
	var buy_btn = Button.new()
	
	if upgrade.current_level >= upgrade.max_level:
		buy_btn.text = "MAX"
		buy_btn.disabled = true
		_style_button(buy_btn, Color(0.3, 0.3, 0.3))
	elif upgrade.cost < 0:
		buy_btn.text = "MAX"
		buy_btn.disabled = true
		_style_button(buy_btn, Color(0.3, 0.3, 0.3))
	else:
		buy_btn.text = "✧ " + str(upgrade.cost)
		buy_btn.disabled = not upgrade.can_purchase
		if upgrade.can_purchase:
			_style_button(buy_btn, COLOR_PURPLE)
		else:
			_style_button(buy_btn, Color(0.4, 0.3, 0.5))
	
	buy_btn.custom_minimum_size = Vector2(90, 40)
	buy_btn.pressed.connect(_on_upgrade_pressed.bind(upgrade.id))
	btn_margin.add_child(buy_btn)
	
	return card


func _on_upgrade_pressed(upgrade_id: String) -> void:
	"""Tenta comprar um upgrade"""
	if not MetaProgression:
		return
	
	if MetaProgression.purchase_upgrade(upgrade_id):
		# Sucesso!
		upgrade_purchased.emit(upgrade_id)
		_refresh_ui()
		
		# Efeito visual/sonoro aqui se quiser
		print("[MetaShop] Upgrade comprado: ", upgrade_id)
	else:
		print("[MetaShop] Falha ao comprar: ", upgrade_id)


func _on_close_pressed() -> void:
	hide_shop()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	if event.is_action_pressed("ui_cancel"):
		hide_shop()
		get_viewport().set_input_as_handled()
