extends Control

# Main Menu - Menu principal do jogo
# Opções: Play (vai para seleção de personagem), Options, Quit

@onready var play_button: Button = $VBoxContainer/PlayButton
@onready var options_button: Button = $VBoxContainer/OptionsButton
@onready var quit_button: Button = $VBoxContainer/QuitButton
@onready var character_select: Control = $CharacterSelect

var character_select_scene = preload("res://ui/character_select.tscn")


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


func _on_play_pressed() -> void:
	"""Mostra tela de seleção de personagem"""
	_show_character_select()


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
