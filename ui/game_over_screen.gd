extends CanvasLayer

# Game Over Screen - Tela simples quando o player morre
# Mostra tempo da run, inimigos mortos e level

class_name GameOverScreen

signal reset_requested()
signal main_menu_requested()

# === STATS ===
var run_time: int = 0  # Segundos
var enemies_killed: int = 0
var player_level: int = 1


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	_build_ui()
	
	# Conecta ao GameManager para detectar game over
	if GameManager:
		GameManager.game_over.connect(_on_game_over)


func _build_ui() -> void:
	"""Constrói a UI da tela de game over"""
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	
	# Background
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.0, 0.0, 0.9)
	root.add_child(bg)
	
	# Center container
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	
	# Main panel
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 350)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.05, 0.05, 0.95)
	panel_style.border_color = Color(0.8, 0.2, 0.2, 0.8)
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)
	
	# Margin
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)
	
	# Main VBox
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)
	
	# Título
	var title = Label.new()
	title.name = "Title"
	title.text = "☠ YOU DIED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	vbox.add_child(title)
	
	# Separator
	var sep = HSeparator.new()
	var sep_style = StyleBoxLine.new()
	sep_style.color = Color(0.5, 0.2, 0.2, 0.5)
	sep_style.thickness = 2
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)
	
	# Stats container
	var stats_vbox = VBoxContainer.new()
	stats_vbox.name = "StatsContainer"
	stats_vbox.add_theme_constant_override("separation", 15)
	vbox.add_child(stats_vbox)
	
	# Separator 2
	var sep2 = HSeparator.new()
	sep2.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep2)
	
	# Buttons
	var btn_container = VBoxContainer.new()
	btn_container.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_container)
	
	_create_button(btn_container, "↻ TRY AGAIN", Color(0.8, 0.3, 0.2), _on_reset_pressed)
	_create_button(btn_container, "◀ MAIN MENU", Color(0.4, 0.4, 0.5), _on_main_menu_pressed)


func _create_button(container: Control, text: String, color: Color, callback: Callable) -> void:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 45)
	
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
	
	btn.add_theme_font_size_override("font_size", 18)
	btn.pressed.connect(callback)
	
	container.add_child(btn)


func _on_game_over() -> void:
	"""Callback quando o jogo termina (player morreu)"""
	# Coleta stats
	if GameManager:
		run_time = 900 - GameManager.time_remaining
	
	if XPManager:
		player_level = XPManager.current_level
	
	if SpawnManager:
		enemies_killed = SpawnManager.total_kills
	
	# Mostra a tela
	show_game_over()


func show_game_over() -> void:
	"""Mostra a tela de game over com os stats"""
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Popula stats
	_populate_stats()


func hide_game_over() -> void:
	"""Esconde a tela de game over"""
	visible = false


func _populate_stats() -> void:
	"""Popula os stats da run"""
	var stats_container = find_child("StatsContainer", true, false)
	if not stats_container:
		return
	
	# Limpa stats anteriores
	for child in stats_container.get_children():
		child.queue_free()
	
	# Tempo
	var time_min = run_time / 60
	var time_sec = run_time % 60
	_add_stat_row(stats_container, "⏱ Time Survived", "%02d:%02d" % [time_min, time_sec])
	
	# Inimigos mortos
	_add_stat_row(stats_container, "💀 Enemies Killed", str(enemies_killed))
	
	# Level
	_add_stat_row(stats_container, "📈 Level Reached", str(player_level))


func _add_stat_row(container: Control, label_text: String, value_text: String) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	
	var label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	row.add_child(label)
	
	var value = Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 20)
	value.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	row.add_child(value)
	
	container.add_child(row)


func _on_reset_pressed() -> void:
	hide_game_over()
	reset_requested.emit()
	GameManager.reset_run()


func _on_main_menu_pressed() -> void:
	hide_game_over()
	main_menu_requested.emit()
	GameManager.reset_game()
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")


func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	# Enter para reiniciar
	if event.is_action_pressed("ui_accept"):
		_on_reset_pressed()
		get_viewport().set_input_as_handled()
