extends CanvasLayer
class_name SeedInputScreen

## SeedInputScreen - Tela para inserir seed customizado antes de iniciar o jogo
## Permite:
## - Digitar seed numérico ou texto
## - Gerar seed aleatório
## - Ver seeds favoritos
## - Ver seed do dia/hora

# === SIGNALS ===
signal seed_confirmed(seed_value: int, seed_string: String)
signal cancelled()
signal daily_seed_requested()

# === COMPONENTES UI ===
var main_panel: PanelContainer = null
var title_label: Label = null
var seed_input: LineEdit = null
var validation_label: Label = null
var preview_label: Label = null
var random_button: Button = null
var daily_button: Button = null
var confirm_button: Button = null
var cancel_button: Button = null
var favorites_list: ItemList = null
var favorites_container: VBoxContainer = null

# === ESTADO ===
var current_seed: int = 0
var current_seed_string: String = ""
var is_valid: bool = false

# === REFERÊNCIA AO SEED MANAGER ===
var seed_manager: SeedManager = null


func _ready() -> void:
	_create_ui()
	_connect_signals()

	# Esconde por padrão
	visible = false


func _create_ui() -> void:
	"""Cria toda a interface"""
	# Fundo escuro semi-transparente
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.8)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# Painel central
	main_panel = PanelContainer.new()
	main_panel.custom_minimum_size = Vector2(450, 400)

	# Centraliza o painel
	var center_container = CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center_container)
	center_container.add_child(main_panel)

	# Estilo do painel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18)
	style.border_color = Color(0.3, 0.5, 0.7)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	main_panel.add_theme_stylebox_override("panel", style)

	# Container principal
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	main_panel.add_child(vbox)

	# Título
	title_label = Label.new()
	title_label.text = "Enter Seed"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	vbox.add_child(title_label)

	# Separador
	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Campo de input
	var input_container = VBoxContainer.new()
	input_container.add_theme_constant_override("separation", 5)
	vbox.add_child(input_container)

	var input_label = Label.new()
	input_label.text = "Seed (number or text):"
	input_label.add_theme_font_size_override("font_size", 14)
	input_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	input_container.add_child(input_label)

	seed_input = LineEdit.new()
	seed_input.placeholder_text = "Enter seed or leave empty for random"
	seed_input.custom_minimum_size = Vector2(0, 35)
	seed_input.add_theme_font_size_override("font_size", 16)
	_style_line_edit(seed_input)
	input_container.add_child(seed_input)

	# Labels de validação e preview
	var info_container = HBoxContainer.new()
	info_container.add_theme_constant_override("separation", 20)
	input_container.add_child(info_container)

	validation_label = Label.new()
	validation_label.text = ""
	validation_label.add_theme_font_size_override("font_size", 12)
	validation_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	info_container.add_child(validation_label)

	preview_label = Label.new()
	preview_label.text = ""
	preview_label.add_theme_font_size_override("font_size", 12)
	preview_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	preview_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info_container.add_child(preview_label)

	# Botões rápidos
	var quick_buttons = HBoxContainer.new()
	quick_buttons.add_theme_constant_override("separation", 10)
	vbox.add_child(quick_buttons)

	random_button = Button.new()
	random_button.text = "Random Seed"
	random_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(random_button, Color(0.3, 0.5, 0.3))
	quick_buttons.add_child(random_button)

	daily_button = Button.new()
	daily_button.text = "Daily Seed"
	daily_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(daily_button, Color(0.5, 0.4, 0.3))
	quick_buttons.add_child(daily_button)

	# Favoritos (expandível)
	favorites_container = VBoxContainer.new()
	favorites_container.add_theme_constant_override("separation", 5)
	vbox.add_child(favorites_container)

	var fav_label = Label.new()
	fav_label.text = "Favorites:"
	fav_label.add_theme_font_size_override("font_size", 14)
	fav_label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.3))
	favorites_container.add_child(fav_label)

	favorites_list = ItemList.new()
	favorites_list.custom_minimum_size = Vector2(0, 80)
	favorites_list.max_columns = 1
	favorites_list.same_column_width = true
	favorites_list.fixed_icon_size = Vector2(0, 0)
	favorites_list.add_theme_constant_override("icon_margin", 0)
	_style_item_list(favorites_list)
	favorites_container.add_child(favorites_list)

	# Botões de ação
	var action_buttons = HBoxContainer.new()
	action_buttons.add_theme_constant_override("separation", 15)
	vbox.add_child(action_buttons)

	cancel_button = Button.new()
	cancel_button.text = "Cancel"
	cancel_button.custom_minimum_size = Vector2(100, 40)
	_style_button(cancel_button, Color(0.5, 0.3, 0.3))
	action_buttons.add_child(cancel_button)

	# Espaçador
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_buttons.add_child(spacer)

	confirm_button = Button.new()
	confirm_button.text = "Start Game"
	confirm_button.custom_minimum_size = Vector2(140, 40)
	_style_button(confirm_button, Color(0.3, 0.5, 0.7))
	action_buttons.add_child(confirm_button)


func _style_line_edit(line_edit: LineEdit) -> void:
	"""Aplica estilo ao LineEdit"""
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12)
	style.border_color = Color(0.3, 0.4, 0.5)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 10
	style.content_margin_right = 10
	line_edit.add_theme_stylebox_override("normal", style)

	var focus = style.duplicate()
	focus.border_color = Color(0.4, 0.6, 0.8)
	line_edit.add_theme_stylebox_override("focus", focus)


func _style_button(button: Button, color: Color) -> void:
	"""Aplica estilo a um botão"""
	button.add_theme_font_size_override("font_size", 14)

	var normal = StyleBoxFlat.new()
	normal.bg_color = color
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	button.add_theme_stylebox_override("normal", normal)

	var hover = normal.duplicate()
	hover.bg_color = color.lightened(0.15)
	button.add_theme_stylebox_override("hover", hover)

	var pressed = normal.duplicate()
	pressed.bg_color = color.darkened(0.15)
	button.add_theme_stylebox_override("pressed", pressed)


func _style_item_list(list: ItemList) -> void:
	"""Aplica estilo ao ItemList"""
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.06, 0.1)
	bg.border_color = Color(0.2, 0.3, 0.4)
	bg.border_width_left = 1
	bg.border_width_right = 1
	bg.border_width_top = 1
	bg.border_width_bottom = 1
	bg.corner_radius_top_left = 4
	bg.corner_radius_top_right = 4
	bg.corner_radius_bottom_left = 4
	bg.corner_radius_bottom_right = 4
	list.add_theme_stylebox_override("panel", bg)

	list.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	list.add_theme_color_override("font_selected_color", Color(1.0, 1.0, 1.0))


func _connect_signals() -> void:
	"""Conecta sinais"""
	seed_input.text_changed.connect(_on_seed_text_changed)
	seed_input.text_submitted.connect(_on_seed_submitted)
	random_button.pressed.connect(_on_random_pressed)
	daily_button.pressed.connect(_on_daily_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	favorites_list.item_selected.connect(_on_favorite_selected)


## Mostra a tela
func show_screen(manager: SeedManager = null) -> void:
	seed_manager = manager

	# Gera seed aleatório inicial
	if seed_manager:
		current_seed = seed_manager.generate_random_seed()
		current_seed_string = str(current_seed)
	else:
		randomize()
		current_seed = randi()
		current_seed_string = str(current_seed)

	# Limpa input
	seed_input.text = ""
	_update_preview()

	# Carrega favoritos
	_load_favorites()

	# Mostra com animação
	modulate.a = 0.0
	visible = true

	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)

	# Foca no input
	seed_input.grab_focus()


## Esconde a tela
func hide_screen() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	await tween.finished
	visible = false


func _on_seed_text_changed(new_text: String) -> void:
	"""Callback quando texto muda"""
	if new_text.is_empty():
		# Usa seed aleatório
		if seed_manager:
			current_seed = seed_manager.get_current_seed()
		validation_label.text = "Using random seed"
		validation_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5))
		is_valid = true
	else:
		# Valida o input
		if seed_manager:
			var result = seed_manager.validate_seed_input(new_text)
			is_valid = result.valid
			current_seed = result.seed
			current_seed_string = new_text

			if is_valid:
				validation_label.text = result.message
				validation_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
			else:
				validation_label.text = result.message
				validation_label.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))

			if result.is_special:
				validation_label.text += " [" + result.special_type.to_upper() + "]"
		else:
			# Validação simples sem seed manager
			if new_text.is_valid_int():
				current_seed = int(new_text)
				validation_label.text = "Valid number"
				validation_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
			else:
				current_seed = new_text.hash()
				validation_label.text = "Text hash: " + str(current_seed)
				validation_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.8))
			current_seed_string = new_text
			is_valid = true

	_update_preview()


func _on_seed_submitted(_text: String) -> void:
	"""Callback quando Enter é pressionado"""
	if is_valid:
		_on_confirm_pressed()


func _on_random_pressed() -> void:
	"""Gera novo seed aleatório"""
	if seed_manager:
		current_seed = seed_manager.generate_random_seed()
	else:
		randomize()
		current_seed = randi()

	current_seed_string = str(current_seed)
	seed_input.text = current_seed_string
	_update_preview()


func _on_daily_pressed() -> void:
	"""Usa o seed do dia"""
	if seed_manager:
		current_seed = seed_manager.generate_daily_seed()
		current_seed_string = seed_manager.get_seed_string()
	else:
		var date = Time.get_date_dict_from_system()
		var date_string = "%04d%02d%02d" % [date.year, date.month, date.day]
		current_seed = date_string.hash()
		current_seed_string = date_string

	seed_input.text = current_seed_string
	validation_label.text = "Daily seed"
	validation_label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.3))
	_update_preview()
	daily_seed_requested.emit()


func _on_confirm_pressed() -> void:
	"""Confirma o seed e inicia"""
	# Se input vazio, usa o seed atual (aleatório)
	if seed_input.text.is_empty():
		current_seed_string = str(current_seed)

	seed_confirmed.emit(current_seed, current_seed_string)
	hide_screen()


func _on_cancel_pressed() -> void:
	"""Cancela e volta"""
	cancelled.emit()
	hide_screen()


func _on_favorite_selected(index: int) -> void:
	"""Seleciona um seed favorito"""
	if seed_manager:
		var favorites = seed_manager.get_favorites()
		if index < favorites.size():
			var fav = favorites[index]
			current_seed = fav.seed
			current_seed_string = fav.get("string", str(fav.seed))
			seed_input.text = current_seed_string
			_update_preview()


func _update_preview() -> void:
	"""Atualiza preview do seed"""
	var formatted = _format_seed(current_seed)
	preview_label.text = "Seed: " + formatted


func _format_seed(seed_value: int) -> String:
	"""Formata seed com separadores"""
	var seed_str = str(seed_value)
	var formatted = ""
	var count = 0

	for i in range(seed_str.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			formatted = "." + formatted
		formatted = seed_str[i] + formatted
		count += 1

	return formatted


func _load_favorites() -> void:
	"""Carrega lista de favoritos"""
	favorites_list.clear()

	if not seed_manager:
		favorites_container.visible = false
		return

	var favorites = seed_manager.get_favorites()
	if favorites.is_empty():
		favorites_container.visible = false
		return

	favorites_container.visible = true

	for fav in favorites:
		var name = fav.get("name", "Seed " + str(fav.seed))
		var biome = fav.get("biome", "")
		var display = name
		if not biome.is_empty():
			display += " [" + biome + "]"
		favorites_list.add_item(display)


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		_on_cancel_pressed()
		get_viewport().set_input_as_handled()
