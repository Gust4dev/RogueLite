extends CanvasLayer

# Upgrade Screen - Tela de seleção de upgrades pós-boss
# Mostra 4 cards de upgrade para escolha

class_name UpgradeScreen

signal upgrade_selected(upgrade_id: String)

# Referências
@onready var background: ColorRect = $Background
@onready var container: VBoxContainer = $Container
@onready var title_label: Label = $Container/Title
@onready var cards_container: HBoxContainer = $Container/CardsContainer

# Config
var card_hover_scale: float = 1.05
var card_normal_scale: float = 1.0

# Estado
var options: Array = []
var selected: bool = false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func show_options(upgrade_options: Array) -> void:
	"""Mostra as opções de upgrade"""
	options = upgrade_options
	selected = false
	visible = true

	# Limpa cards anteriores
	for child in cards_container.get_children():
		child.queue_free()

	# Cria novos cards
	for opt in options:
		var card = _create_upgrade_card(opt)
		cards_container.add_child(card)

	# Animação de entrada
	_animate_entrance()


func _create_upgrade_card(data) -> Control:
	"""Cria um card de upgrade"""
	var card = PanelContainer.new()
	card.name = "Card_" + data.id
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(200, 300)

	# Style do card
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_color = data.color
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	card.add_theme_stylebox_override("panel", style)

	# Container de conteúdo
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	card.add_child(vbox)

	# Nome do upgrade
	var name_label = Label.new()
	name_label.text = data.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", data.color)
	vbox.add_child(name_label)

	# Ícone (placeholder colorido)
	var icon_container = CenterContainer.new()
	var icon = ColorRect.new()
	icon.color = data.color
	icon.custom_minimum_size = Vector2(80, 80)
	icon_container.add_child(icon)
	vbox.add_child(icon_container)

	# Descrição
	var desc = Label.new()
	desc.text = _get_level_description(data)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(desc)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Level indicator
	var level_label = Label.new()
	if data.current_level > 0:
		level_label.text = "Level %d -> %d" % [data.current_level, data.current_level + 1]
		level_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		level_label.text = "NEW"
		level_label.add_theme_color_override("font_color", Color.YELLOW)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(level_label)

	# Botão invisível para seleção
	var button = Button.new()
	button.flat = true
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.modulate.a = 0
	button.mouse_entered.connect(_on_card_hover.bind(card, true))
	button.mouse_exited.connect(_on_card_hover.bind(card, false))
	button.pressed.connect(_on_card_selected.bind(data.id))
	card.add_child(button)

	# Guarda referência ao style para hover
	card.set_meta("style", style)
	card.set_meta("original_border", data.color)

	return card


func _get_level_description(data) -> String:
	"""Retorna descrição apropriada para o nível"""
	var next_level = data.current_level + 1

	# Descrições específicas por upgrade e nível
	var descriptions = {
		"chain_lightning": {
			1: "Shots chain to 1 nearby enemy",
			2: "Shots chain to 2 nearby enemies",
			3: "Shots chain to 3 enemies with +20% damage"
		},
		"ricochet": {
			1: "Bullets ricochet 1 time",
			2: "Bullets ricochet 2 times",
			3: "Bullets ricochet 3 times and seek enemies"
		},
		"explosive_rounds": {
			1: "Explosions: 3m radius, 50% damage",
			2: "Explosions: 5m radius, 75% damage",
			3: "Explosions: 7m radius, 100% damage"
		},
		"piercing_bullets": {
			1: "Pierce through 1 enemy (70% damage)",
			2: "Pierce through 2 enemies (70% damage)",
			3: "Pierce infinitely with no damage loss"
		},
		"fast_reload": {
			1: "-25% reload time",
			2: "-50% reload time",
			3: "-75% reload time + auto reload"
		},
		"burst_fire": {
			1: "Fire 3 shots per click (small spread)",
			2: "Fire 4 shots per click (reduced spread)",
			3: "Fire 5 shots per click (no spread)"
		},
		"lifesteal": {
			1: "Heal 5% of damage dealt",
			2: "Heal 10% of damage dealt",
			3: "Heal 15% of damage + overheal as shield"
		},
		"freeze_bullets": {
			1: "Slow enemies by 30% for 2 seconds",
			2: "Slow enemies by 50% for 3 seconds",
			3: "Completely freeze enemies for 2 seconds"
		}
	}

	if data.id in descriptions:
		if next_level in descriptions[data.id]:
			return descriptions[data.id][next_level]

	return data.description


func _on_card_hover(card: Control, hovering: bool) -> void:
	"""Efeito de hover no card"""
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	if hovering:
		tween.tween_property(card, "scale", Vector2.ONE * card_hover_scale, 0.1)

		# Brilho na borda
		var style = card.get_meta("style") as StyleBoxFlat
		if style:
			style.border_color = Color.WHITE
	else:
		tween.tween_property(card, "scale", Vector2.ONE * card_normal_scale, 0.1)

		# Restaura borda
		var style = card.get_meta("style") as StyleBoxFlat
		var original = card.get_meta("original_border") as Color
		if style and original:
			style.border_color = original


func _on_card_selected(upgrade_id: String) -> void:
	"""Quando um card é selecionado"""
	if selected:
		return

	selected = true

	# Efeito de seleção
	_animate_selection(upgrade_id)

	# Emite signal
	upgrade_selected.emit(upgrade_id)


func _animate_entrance() -> void:
	"""Animação de entrada da tela"""
	# Fade in do background
	background.modulate.a = 0
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(background, "modulate:a", 1.0, 0.3)

	# Cards entram de baixo
	for i in range(cards_container.get_child_count()):
		var card = cards_container.get_child(i)
		var target_pos = card.position
		card.position.y += 100
		card.modulate.a = 0

		var card_tween = create_tween()
		card_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		card_tween.set_parallel(true)
		card_tween.tween_property(card, "position:y", target_pos.y, 0.3).set_delay(i * 0.1)
		card_tween.tween_property(card, "modulate:a", 1.0, 0.3).set_delay(i * 0.1)


func _animate_selection(selected_id: String) -> void:
	"""Animação quando um upgrade é selecionado"""
	for child in cards_container.get_children():
		var card_id = child.name.replace("Card_", "")
		var tween = create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

		if card_id == selected_id:
			# Card selecionado: pulsa e some
			tween.tween_property(child, "scale", Vector2.ONE * 1.2, 0.15)
			tween.tween_property(child, "scale", Vector2.ONE * 1.0, 0.1)
			tween.tween_property(child, "modulate:a", 0.0, 0.2)
		else:
			# Outros cards: fade out
			tween.tween_property(child, "modulate:a", 0.0, 0.2)

	# Fade out background
	await get_tree().create_timer(0.4).timeout
	var bg_tween = create_tween()
	bg_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	bg_tween.tween_property(background, "modulate:a", 0.0, 0.2)

	await bg_tween.finished
	visible = false


func _input(event: InputEvent) -> void:
	"""Permite seleção por teclado"""
	if not visible or selected:
		return

	# Teclas 1-4 para seleção rápida
	if event is InputEventKey and event.pressed:
		var index = -1
		match event.keycode:
			KEY_1:
				index = 0
			KEY_2:
				index = 1
			KEY_3:
				index = 2
			KEY_4:
				index = 3

		if index >= 0 and index < options.size():
			_on_card_selected(options[index].id)
