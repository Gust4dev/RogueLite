extends Control

# Main Menu - Menu principal do jogo
# Opções: Play (vai para seleção de personagem), Custom Seed, Options, Quit

@onready var play_button: Button = $VBoxContainer/PlayButton
@onready var options_button: Button = $VBoxContainer/OptionsButton
@onready var quit_button: Button = $VBoxContainer/QuitButton
@onready var character_select: Control = $CharacterSelect

var character_select_scene = preload("res://ui/character_select.tscn")

# === SISTEMA DE SEED ===
var seed_input_screen: SeedInputScreen = null
var seed_button: Button = null
var custom_seed: int = -1  # -1 = random
var use_custom_seed: bool = false


func _ready() -> void:
	# Conecta botões
	if play_button:
		play_button.pressed.connect(_on_play_pressed)
	if options_button:
		options_button.pressed.connect(_on_options_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

	# Esconde seleção de personagem inicialmente
	if character_select:
		character_select.visible = false

	# Mostra cursor
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Cria botão de seed
	_setup_seed_button()

	# Cria tela de input de seed
	_setup_seed_input_screen()


func _setup_seed_button() -> void:
	"""Cria botão para inserir seed customizado"""
	var vbox = $VBoxContainer

	# Cria botão de seed entre Play e Options
	seed_button = Button.new()
	seed_button.text = "Custom Seed"
	seed_button.custom_minimum_size = Vector2(200, 40)
	seed_button.pressed.connect(_on_seed_button_pressed)

	# Insere após o botão Play
	var play_index = play_button.get_index()
	vbox.add_child(seed_button)
	vbox.move_child(seed_button, play_index + 1)


func _setup_seed_input_screen() -> void:
	"""Cria a tela de input de seed"""
	seed_input_screen = SeedInputScreen.new()
	seed_input_screen.name = "SeedInputScreen"
	add_child(seed_input_screen)

	# Conecta sinais
	seed_input_screen.seed_confirmed.connect(_on_seed_confirmed)
	seed_input_screen.cancelled.connect(_on_seed_cancelled)


func _on_play_pressed() -> void:
	"""Mostra tela de seleção de personagem"""
	_show_character_select()


func _on_seed_button_pressed() -> void:
	"""Abre tela de input de seed"""
	if seed_input_screen:
		seed_input_screen.show_screen()


func _on_seed_confirmed(seed_value: int, seed_string: String) -> void:
	"""Callback quando seed é confirmado"""
	custom_seed = seed_value
	use_custom_seed = true

	# Passa seed para GameManager
	if GameManager:
		GameManager.set_seed_for_next_run(seed_value)

	# Atualiza texto do botão para mostrar seed atual
	if seed_button:
		var formatted = _format_seed(seed_value)
		seed_button.text = "Seed: " + formatted

	print("[MainMenu] Seed definido: ", seed_value, " (", seed_string, ")")

	# Mostra seleção de personagem automaticamente
	_show_character_select()


func _on_seed_cancelled() -> void:
	"""Callback quando input de seed é cancelado"""
	# Volta ao menu normal
	pass


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


func _on_options_pressed() -> void:
	"""Abre menu de opções"""
	# TODO: Implementar menu de opções
	print("Options not implemented yet")


func _on_quit_pressed() -> void:
	"""Sai do jogo"""
	get_tree().quit()


func _show_character_select() -> void:
	"""Mostra a tela de seleção de personagem"""
	if character_select:
		character_select.visible = true
		character_select.character_confirmed.connect(_on_character_confirmed)
		character_select.back_pressed.connect(_on_character_back)

		# Esconde botões do menu
		$VBoxContainer.visible = false


func _hide_character_select() -> void:
	"""Esconde a tela de seleção de personagem"""
	if character_select:
		character_select.visible = false
		if character_select.character_confirmed.is_connected(_on_character_confirmed):
			character_select.character_confirmed.disconnect(_on_character_confirmed)
		if character_select.back_pressed.is_connected(_on_character_back):
			character_select.back_pressed.disconnect(_on_character_back)

	# Mostra botões do menu
	$VBoxContainer.visible = true


func _on_character_confirmed(character_id: String) -> void:
	"""Callback quando personagem é selecionado"""
	print("Character selected: ", character_id)
	# Inicia o jogo (character_select já faz isso)


func _on_character_back() -> void:
	"""Callback quando volta da seleção de personagem"""
	_hide_character_select()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if character_select and character_select.visible:
			_hide_character_select()
