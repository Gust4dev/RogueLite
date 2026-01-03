extends Control

# Character Selection Screen
# Menu pre-run para escolher personagem/arma
# Mostra preview, stats e condições de unlock

signal character_confirmed(character_id: String)
signal back_pressed()

# Referências
@onready var character_list: VBoxContainer = $MarginContainer/HBoxContainer/CharacterList/VBoxContainer
@onready var preview_panel: Panel = $MarginContainer/HBoxContainer/PreviewPanel
@onready var character_name: Label = $MarginContainer/HBoxContainer/PreviewPanel/VBoxContainer/CharacterName
@onready var character_desc: Label = $MarginContainer/HBoxContainer/PreviewPanel/VBoxContainer/Description
@onready var weapon_name: Label = $MarginContainer/HBoxContainer/PreviewPanel/VBoxContainer/WeaponName
@onready var stats_container: VBoxContainer = $MarginContainer/HBoxContainer/PreviewPanel/VBoxContainer/StatsContainer
@onready var special_ability: Label = $MarginContainer/HBoxContainer/PreviewPanel/VBoxContainer/SpecialAbility
@onready var unlock_label: Label = $MarginContainer/HBoxContainer/PreviewPanel/VBoxContainer/UnlockCondition
@onready var select_button: Button = $MarginContainer/HBoxContainer/PreviewPanel/VBoxContainer/SelectButton
@onready var portrait_rect: ColorRect = $MarginContainer/HBoxContainer/PreviewPanel/VBoxContainer/PortraitRect

# Estado
var selected_character_id: String = ""
var character_manager: CharacterManager = null

# Prefab do botão de personagem
var character_button_scene: PackedScene = null


func _ready() -> void:
	# Obtém character manager
	character_manager = get_node_or_null("/root/CharacterManager")
	if not character_manager:
		push_error("CharacterManager autoload not found!")
		return

	# Conecta botões
	if select_button:
		select_button.pressed.connect(_on_select_pressed)

	# Popula lista de personagens
	_populate_character_list()

	# Seleciona o personagem atual
	selected_character_id = character_manager.selected_character_id
	_update_preview(selected_character_id)


func _populate_character_list() -> void:
	"""Cria botões para cada personagem"""
	if not character_list:
		return

	# Limpa lista existente
	for child in character_list.get_children():
		child.queue_free()

	# Cria botão para cada personagem
	var characters = character_manager.get_all_characters()
	for char_data in characters:
		var button = Button.new()
		button.text = char_data.name
		button.custom_minimum_size = Vector2(200, 50)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Estilo baseado no estado de unlock
		if char_data.unlocked:
			button.modulate = Color.WHITE
		else:
			button.modulate = Color(0.5, 0.5, 0.5)
			button.text = char_data.name + " [LOCKED]"

		# Conecta click
		button.pressed.connect(_on_character_button_pressed.bind(char_data.id))

		character_list.add_child(button)


func _on_character_button_pressed(character_id: String) -> void:
	"""Callback quando clica em um personagem"""
	selected_character_id = character_id
	_update_preview(character_id)

	# Efeito sonoro
	# TODO: AudioManager.play_sfx("ui_click")


func _update_preview(character_id: String) -> void:
	"""Atualiza o painel de preview"""
	var char_data = character_manager.get_character(character_id)
	if char_data.is_empty():
		return

	# Nome e descrição
	if character_name:
		character_name.text = char_data.name
	if character_desc:
		character_desc.text = char_data.description

	# Arma
	if weapon_name:
		weapon_name.text = "Weapon: " + char_data.weapon_name

	# Stats
	_update_stats(char_data.stats)

	# Habilidade especial
	if special_ability:
		special_ability.text = "Special: " + char_data.special_ability

	# Condição de unlock
	if unlock_label:
		if char_data.unlocked:
			unlock_label.text = ""
			unlock_label.visible = false
		else:
			unlock_label.text = "Unlock: " + char_data.unlock_condition
			unlock_label.visible = true

	# Cor do retrato
	if portrait_rect:
		portrait_rect.color = char_data.portrait_color

	# Botão de seleção
	if select_button:
		select_button.disabled = not char_data.unlocked
		select_button.text = "SELECT" if char_data.unlocked else "LOCKED"


func _update_stats(stats: Dictionary) -> void:
	"""Atualiza display de stats"""
	if not stats_container:
		return

	# Limpa stats antigos
	for child in stats_container.get_children():
		child.queue_free()

	# Cria labels de stats
	var stat_names = {
		"damage": "Damage",
		"fire_rate": "Fire Rate",
		"magazine": "Magazine",
		"dps": "DPS"
	}

	for stat_key in stats.keys():
		var label = Label.new()
		var display_name = stat_names.get(stat_key, stat_key)
		var value = stats[stat_key]

		# Formata valor
		if stat_key == "fire_rate":
			label.text = "%s: %.2fs" % [display_name, value]
		else:
			label.text = "%s: %d" % [display_name, value]

		label.add_theme_font_size_override("font_size", 14)
		stats_container.add_child(label)


func _on_select_pressed() -> void:
	"""Callback quando confirma seleção"""
	if selected_character_id.is_empty():
		return

	if character_manager.select_character(selected_character_id):
		character_confirmed.emit(selected_character_id)
		# Inicia o jogo
		_start_game()


func _start_game() -> void:
	"""Inicia o jogo com o personagem selecionado"""
	# Troca para a cena principal
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		back_pressed.emit()
