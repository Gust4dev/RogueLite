extends Control
class_name SeedDisplay

## SeedDisplay - Componente de UI para exibir e interagir com o seed do mapa
## Mostra o seed atual, bioma, e permite copiar/favoritar

# === SIGNALS ===
signal copy_pressed()
signal favorite_pressed()
signal seed_input_requested()

# === CONFIGURAÇÃO ===
@export var show_biome: bool = true
@export var show_copy_button: bool = true
@export var show_favorite_button: bool = true
@export var compact_mode: bool = false

# === COMPONENTES UI ===
var container: PanelContainer = null
var vbox: VBoxContainer = null
var seed_label: Label = null
var biome_label: Label = null
var button_container: HBoxContainer = null
var copy_button: Button = null
var favorite_button: Button = null

# === ESTADO ===
var current_seed: int = 0
var current_seed_string: String = ""
var current_biome: String = ""
var is_favorite: bool = false

# === ANIMAÇÃO ===
var copy_animation_tween: Tween = null


func _ready() -> void:
	_create_ui()
	_connect_signals()


func _create_ui() -> void:
	"""Cria toda a estrutura da UI"""
	# Container principal
	container = PanelContainer.new()
	container.name = "SeedContainer"

	# Estilo do painel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.85)
	style.border_color = Color(0.3, 0.4, 0.5, 0.8)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	container.add_theme_stylebox_override("panel", style)

	add_child(container)

	# VBox para organizar elementos
	vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	container.add_child(vbox)

	# Linha superior com seed
	var seed_line = HBoxContainer.new()
	seed_line.add_theme_constant_override("separation", 8)
	vbox.add_child(seed_line)

	# Label "SEED:"
	var seed_title = Label.new()
	seed_title.text = "SEED:"
	seed_title.add_theme_font_size_override("font_size", 12)
	seed_title.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	seed_line.add_child(seed_title)

	# Valor do seed
	seed_label = Label.new()
	seed_label.text = "000.000.000"
	seed_label.add_theme_font_size_override("font_size", 14)
	seed_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	seed_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_line.add_child(seed_label)

	# Bioma (opcional)
	if show_biome:
		biome_label = Label.new()
		biome_label.text = "[Industrial]"
		biome_label.add_theme_font_size_override("font_size", 11)
		biome_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.5))
		biome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

		if compact_mode:
			seed_line.add_child(biome_label)
		else:
			vbox.add_child(biome_label)

	# Botões (opcional)
	if show_copy_button or show_favorite_button:
		button_container = HBoxContainer.new()
		button_container.add_theme_constant_override("separation", 6)
		button_container.alignment = BoxContainer.ALIGNMENT_END
		vbox.add_child(button_container)

		# Botão Copiar
		if show_copy_button:
			copy_button = Button.new()
			copy_button.text = "Copy"
			copy_button.custom_minimum_size = Vector2(50, 24)
			_style_button(copy_button, Color(0.2, 0.4, 0.6))
			button_container.add_child(copy_button)

		# Botão Favoritar
		if show_favorite_button:
			favorite_button = Button.new()
			favorite_button.text = "Fav"
			favorite_button.custom_minimum_size = Vector2(40, 24)
			_style_button(favorite_button, Color(0.5, 0.4, 0.2))
			button_container.add_child(favorite_button)


func _style_button(button: Button, color: Color) -> void:
	"""Aplica estilo a um botão"""
	button.add_theme_font_size_override("font_size", 11)

	var normal = StyleBoxFlat.new()
	normal.bg_color = color
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4
	button.add_theme_stylebox_override("normal", normal)

	var hover = StyleBoxFlat.new()
	hover.bg_color = color.lightened(0.2)
	hover.corner_radius_top_left = 4
	hover.corner_radius_top_right = 4
	hover.corner_radius_bottom_left = 4
	hover.corner_radius_bottom_right = 4
	button.add_theme_stylebox_override("hover", hover)

	var pressed = StyleBoxFlat.new()
	pressed.bg_color = color.darkened(0.2)
	pressed.corner_radius_top_left = 4
	pressed.corner_radius_top_right = 4
	pressed.corner_radius_bottom_left = 4
	pressed.corner_radius_bottom_right = 4
	button.add_theme_stylebox_override("pressed", pressed)


func _connect_signals() -> void:
	"""Conecta sinais dos botões"""
	if copy_button:
		copy_button.pressed.connect(_on_copy_pressed)

	if favorite_button:
		favorite_button.pressed.connect(_on_favorite_pressed)


## Atualiza o display com informações do seed
func update_seed(seed_value: int, seed_string: String = "", biome: String = "") -> void:
	current_seed = seed_value
	current_seed_string = seed_string if not seed_string.is_empty() else str(seed_value)
	current_biome = biome

	# Formata seed com separadores
	var formatted = _format_seed(seed_value)

	if seed_label:
		seed_label.text = formatted

	if biome_label and not biome.is_empty():
		biome_label.text = "[" + biome + "]"
		biome_label.visible = true
	elif biome_label:
		biome_label.visible = false


## Define estado de favorito
func set_favorite_state(favorited: bool) -> void:
	is_favorite = favorited

	if favorite_button:
		if is_favorite:
			favorite_button.text = "*"
			favorite_button.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
		else:
			favorite_button.text = "Fav"
			favorite_button.remove_theme_color_override("font_color")


func _format_seed(seed_value: int) -> String:
	"""Formata o seed com separadores de milhares"""
	var seed_str = str(seed_value)
	var formatted = ""
	var count = 0

	for i in range(seed_str.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			formatted = "." + formatted
		formatted = seed_str[i] + formatted
		count += 1

	return formatted


func _on_copy_pressed() -> void:
	"""Callback do botão copiar"""
	# Copia para clipboard
	DisplayServer.clipboard_set(current_seed_string)

	# Feedback visual
	_show_copy_feedback()

	copy_pressed.emit()


func _on_favorite_pressed() -> void:
	"""Callback do botão favoritar"""
	favorite_pressed.emit()


func _show_copy_feedback() -> void:
	"""Mostra feedback visual ao copiar"""
	if copy_button:
		var original_text = copy_button.text

		# Cancela tween anterior se existir
		if copy_animation_tween and copy_animation_tween.is_valid():
			copy_animation_tween.kill()

		copy_button.text = "OK!"
		copy_button.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))

		# Volta ao normal após delay
		copy_animation_tween = create_tween()
		copy_animation_tween.tween_interval(1.0)
		copy_animation_tween.tween_callback(func():
			copy_button.text = original_text
			copy_button.remove_theme_color_override("font_color")
		)


## Mostra com animação de entrada
func show_animated() -> void:
	modulate.a = 0.0
	visible = true

	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)


## Esconde com animação de saída
func hide_animated() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	await tween.finished
	visible = false


## Configura posição no canto superior direito
func position_top_right(margin: Vector2 = Vector2(10, 10)) -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -200 - margin.x
	offset_right = -margin.x
	offset_top = margin.y
	offset_bottom = margin.y + 80


## Configura posição no canto superior esquerdo
func position_top_left(margin: Vector2 = Vector2(10, 80)) -> void:
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = margin.x
	offset_right = margin.x + 200
	offset_top = margin.y
	offset_bottom = margin.y + 80
