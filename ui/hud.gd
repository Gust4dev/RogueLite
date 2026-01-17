extends CanvasLayer

# HUD - Interface do jogador
# Mostra HP, ammo, timer, crosshair dinâmico, hitmarker, boss health, key indicator

# Referências aos elementos UI
@onready var health_bar: ProgressBar = $Control/HealthBar
@onready var health_label: Label = $Control/HealthBar/Label
@onready var ammo_label: Label = $Control/AmmoLabel
@onready var timer_label: Label = $Control/TimerLabel
@onready var crosshair: Control = $Control/Crosshair
@onready var crosshair_container: Control = $Control/CrosshairContainer

# Boss UI
@onready var boss_health_container: VBoxContainer = $Control/BossHealthContainer
@onready var boss_name_label: Label = $Control/BossHealthContainer/BossNameLabel
@onready var boss_health_bar: ProgressBar = $Control/BossHealthContainer/BossHealthBar

# Key UI
@onready var key_indicator: HBoxContainer = $Control/KeyIndicator
@onready var key_icon: ColorRect = $Control/KeyIndicator/KeyIcon
@onready var key_label: Label = $Control/KeyIndicator/KeyLabel

# Boss Warning
@onready var boss_warning: Label = $Control/BossWarning

# Upgrade Indicator
@onready var upgrade_indicator: HBoxContainer = $Control/UpgradeIndicator

# Referências ao player e weapon
var player: Node3D = null
var player_controller: PlayerController = null
var current_weapon: Node3D = null
var camera_effects: CameraEffects = null

# === CROSSHAIR DINÂMICO ===
var crosshair_drawer: CrosshairDrawer = null

# === VIGNETTE ===
# === VIGNETTE ===
var vignette_drawer: VignetteDrawer = null

# === RADAR ===
var radar_drawer: Control = null

# === XP SYSTEM ===
var xp_bar: ProgressBar = null
var level_label: Label = null

# === DASH/STAMINA SYSTEM ===
var stamina_container: HBoxContainer = null
var stamina_bar: ProgressBar = null
var stamina_label: Label = null

# === LEVEL UP SCREEN ===
var level_up_screen: LevelUpScreen = null

# === WEAPON SPECIFIC UI ===
var weapon_info_container: VBoxContainer = null
var heat_bar: ProgressBar = null
var heat_label: Label = null
var spread_indicator: ProgressBar = null
var spin_indicator: ProgressBar = null

# Estado do boss
var boss_active: bool = false

# === MONEY SYSTEM ===
var money_label: Label = null


func _ready() -> void:
	# Conecta aos signals do GameManager
	if GameManager:
		GameManager.time_changed.connect(_on_time_changed)

	# Conecta aos signals do SpawnManager
	if SpawnManager:
		SpawnManager.boss_spawning.connect(_on_boss_spawning)
		SpawnManager.boss_health_updated.connect(_on_boss_health_updated)
		SpawnManager.boss_defeated.connect(_on_boss_defeated)
		SpawnManager.boss_warning.connect(_on_boss_warning)

	# Encontra o player
	call_deferred("_find_player")

	# Cria o drawer do crosshair
	_setup_crosshair_drawer()

	# Cria o drawer da vignette
	_setup_vignette_drawer()
	
	# Cria o radar
	_setup_radar()

	# Esconde boss UI inicialmente
	if boss_health_container:
		boss_health_container.visible = false

	# Esconde warning inicialmente
	if boss_warning:
		boss_warning.visible = false

	# Configura XP Bar e Level
	_setup_xp_ui()

	# Configura Dash Indicators
	_setup_dash_indicators()

	# Configura Level Up Screen
	_setup_level_up_screen()

	# Configura Weapon Info UI (para LMG, SMG, etc.)
	_setup_weapon_info_ui()

	# Conecta signals do XPManager
	if XPManager:
		XPManager.xp_changed.connect(_on_xp_changed)
		XPManager.level_up.connect(_on_level_up)
	
	# Configura Money UI
	_setup_money_ui()
	
	# Conecta signals do MoneyManager
	if MoneyManager:
		MoneyManager.money_changed.connect(_on_money_changed)


func _setup_crosshair_drawer() -> void:
	"""Configura o drawer customizado do crosshair"""
	crosshair_drawer = CrosshairDrawer.new()
	crosshair_drawer.name = "CrosshairDrawer"

	# Adiciona ao container ou cria um
	var container = get_node_or_null("Control/CrosshairContainer")
	if not container:
		container = Control.new()
		container.name = "CrosshairContainer"
		# Configura para preencher toda a tela
		container.anchor_left = 0.0
		container.anchor_top = 0.0
		container.anchor_right = 1.0
		container.anchor_bottom = 1.0
		container.offset_left = 0
		container.offset_top = 0
		container.offset_right = 0
		container.offset_bottom = 0
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$Control.add_child(container)

	container.add_child(crosshair_drawer)

	# Configura CrosshairDrawer para preencher o container inteiro
	crosshair_drawer.anchor_left = 0.0
	crosshair_drawer.anchor_top = 0.0
	crosshair_drawer.anchor_right = 1.0
	crosshair_drawer.anchor_bottom = 1.0
	crosshair_drawer.offset_left = 0
	crosshair_drawer.offset_top = 0
	crosshair_drawer.offset_right = 0
	crosshair_drawer.offset_bottom = 0
	crosshair_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Esconde o crosshair antigo se existir
	if crosshair:
		crosshair.visible = false


func _setup_vignette_drawer() -> void:
	"""Configura o drawer da vignette"""
	vignette_drawer = VignetteDrawer.new()
	vignette_drawer.name = "VignetteDrawer"
	vignette_drawer.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Adiciona atrás de tudo
	$Control.add_child(vignette_drawer)
	$Control.move_child(vignette_drawer, 0)


func _setup_xp_ui() -> void:
	"""Configura barra de XP e label de level"""
	# Container para XP no canto inferior
	var xp_container = HBoxContainer.new()
	xp_container.name = "XPContainer"
	xp_container.anchor_left = 0.3
	xp_container.anchor_right = 0.7
	xp_container.anchor_top = 0.95
	xp_container.anchor_bottom = 0.98
	xp_container.offset_left = 0
	xp_container.offset_right = 0
	xp_container.offset_top = 0
	xp_container.offset_bottom = 0
	xp_container.add_theme_constant_override("separation", 10)
	$Control.add_child(xp_container)

	# Level Label
	level_label = Label.new()
	level_label.name = "LevelLabel"
	level_label.text = "Lv. 1"
	level_label.add_theme_font_size_override("font_size", 18)
	level_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	xp_container.add_child(level_label)

	# XP Bar
	xp_bar = ProgressBar.new()
	xp_bar.name = "XPBar"
	xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_bar.max_value = 100
	xp_bar.value = 0
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(0, 12)

	# Estilo da XP bar
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color(0.15, 0.15, 0.2, 0.8)
	style_bg.corner_radius_top_left = 4
	style_bg.corner_radius_top_right = 4
	style_bg.corner_radius_bottom_left = 4
	style_bg.corner_radius_bottom_right = 4
	xp_bar.add_theme_stylebox_override("background", style_bg)

	var style_fill = StyleBoxFlat.new()
	style_fill.bg_color = Color(0.3, 0.8, 1.0, 0.9)
	style_fill.corner_radius_top_left = 4
	style_fill.corner_radius_top_right = 4
	style_fill.corner_radius_bottom_left = 4
	style_fill.corner_radius_bottom_right = 4
	xp_bar.add_theme_stylebox_override("fill", style_fill)

	xp_container.add_child(xp_bar)


func _setup_dash_indicators() -> void:
	"""Configura barra de estamina contínua (souls-like)"""
	stamina_container = HBoxContainer.new()
	stamina_container.name = "StaminaContainer"
	stamina_container.anchor_left = 0.02
	stamina_container.anchor_right = 0.18
	stamina_container.anchor_top = 0.92
	stamina_container.anchor_bottom = 0.95
	stamina_container.add_theme_constant_override("separation", 8)
	$Control.add_child(stamina_container)

	# Label "STAMINA"
	stamina_label = Label.new()
	stamina_label.text = "STAMINA"
	stamina_label.add_theme_font_size_override("font_size", 11)
	stamina_label.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
	stamina_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stamina_container.add_child(stamina_label)

	# Barra de estamina contínua
	stamina_bar = ProgressBar.new()
	stamina_bar.name = "StaminaBar"
	stamina_bar.custom_minimum_size = Vector2(120, 12)
	stamina_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stamina_bar.max_value = 100
	stamina_bar.value = 100
	stamina_bar.show_percentage = false

	# Estilo de fundo
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.15, 0.15, 0.25, 0.85)
	bg.corner_radius_top_left = 3
	bg.corner_radius_top_right = 3
	bg.corner_radius_bottom_left = 3
	bg.corner_radius_bottom_right = 3
	bg.border_width_bottom = 1
	bg.border_width_top = 1
	bg.border_width_left = 1
	bg.border_width_right = 1
	bg.border_color = Color(0.2, 0.5, 0.7, 0.5)
	stamina_bar.add_theme_stylebox_override("background", bg)

	# Estilo de preenchimento
	var fill = StyleBoxFlat.new()
	fill.bg_color = Color(0.2, 0.7, 0.9, 0.9)
	fill.corner_radius_top_left = 3
	fill.corner_radius_top_right = 3
	fill.corner_radius_bottom_left = 3
	fill.corner_radius_bottom_right = 3
	stamina_bar.add_theme_stylebox_override("fill", fill)

	stamina_container.add_child(stamina_bar)


func _setup_money_ui() -> void:
	"""Configura display de dinheiro no canto superior direito"""
	var money_container = HBoxContainer.new()
	money_container.name = "MoneyContainer"
	money_container.anchor_left = 0.85
	money_container.anchor_right = 0.98
	money_container.anchor_top = 0.02
	money_container.anchor_bottom = 0.06
	money_container.add_theme_constant_override("separation", 5)
	$Control.add_child(money_container)
	
	# Ícone de moeda
	var coin_icon = Label.new()
	coin_icon.text = "🪙"
	coin_icon.add_theme_font_size_override("font_size", 24)
	coin_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	money_container.add_child(coin_icon)
	
	# Label do valor
	money_label = Label.new()
	money_label.name = "MoneyLabel"
	money_label.text = "0"
	money_label.add_theme_font_size_override("font_size", 22)
	money_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	money_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	money_container.add_child(money_label)


func _on_money_changed(new_amount: int) -> void:
	"""Callback quando dinheiro muda"""
	if money_label:
		money_label.text = str(new_amount)
		
		# Pequena animação de pulse
		var tween = create_tween()
		tween.tween_property(money_label, "scale", Vector2(1.2, 1.2), 0.1)
		tween.tween_property(money_label, "scale", Vector2.ONE, 0.1)


func _setup_level_up_screen() -> void:
	"""Configura a tela de level up"""
	level_up_screen = LevelUpScreen.new()
	level_up_screen.name = "LevelUpScreen"
	get_tree().root.add_child.call_deferred(level_up_screen)


func _setup_weapon_info_ui() -> void:
	"""Configura UI para informações específicas de armas"""
	# Container principal para info de arma
	weapon_info_container = VBoxContainer.new()
	weapon_info_container.name = "WeaponInfoContainer"
	weapon_info_container.anchor_left = 0.85
	weapon_info_container.anchor_right = 0.98
	weapon_info_container.anchor_top = 0.75
	weapon_info_container.anchor_bottom = 0.88
	weapon_info_container.add_theme_constant_override("separation", 5)
	weapon_info_container.visible = false  # Escondido por padrão
	$Control.add_child(weapon_info_container)

	# Heat Bar (para LMG)
	var heat_container = HBoxContainer.new()
	heat_container.name = "HeatContainer"
	weapon_info_container.add_child(heat_container)

	heat_label = Label.new()
	heat_label.text = "HEAT"
	heat_label.add_theme_font_size_override("font_size", 12)
	heat_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
	heat_label.custom_minimum_size = Vector2(50, 0)
	heat_container.add_child(heat_label)

	heat_bar = ProgressBar.new()
	heat_bar.name = "HeatBar"
	heat_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heat_bar.max_value = 100
	heat_bar.value = 0
	heat_bar.show_percentage = false
	heat_bar.custom_minimum_size = Vector2(0, 12)

	var heat_bg = StyleBoxFlat.new()
	heat_bg.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	heat_bg.corner_radius_top_left = 3
	heat_bg.corner_radius_top_right = 3
	heat_bg.corner_radius_bottom_left = 3
	heat_bg.corner_radius_bottom_right = 3
	heat_bar.add_theme_stylebox_override("background", heat_bg)

	var heat_fill = StyleBoxFlat.new()
	heat_fill.bg_color = Color(1.0, 0.3, 0.1, 0.9)
	heat_fill.corner_radius_top_left = 3
	heat_fill.corner_radius_top_right = 3
	heat_fill.corner_radius_bottom_left = 3
	heat_fill.corner_radius_bottom_right = 3
	heat_bar.add_theme_stylebox_override("fill", heat_fill)
	heat_container.add_child(heat_bar)

	# Spin Indicator (para LMG)
	var spin_container = HBoxContainer.new()
	spin_container.name = "SpinContainer"
	weapon_info_container.add_child(spin_container)

	var spin_label = Label.new()
	spin_label.text = "SPIN"
	spin_label.add_theme_font_size_override("font_size", 12)
	spin_label.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
	spin_label.custom_minimum_size = Vector2(50, 0)
	spin_container.add_child(spin_label)

	spin_indicator = ProgressBar.new()
	spin_indicator.name = "SpinIndicator"
	spin_indicator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin_indicator.max_value = 100
	spin_indicator.value = 0
	spin_indicator.show_percentage = false
	spin_indicator.custom_minimum_size = Vector2(0, 12)

	var spin_bg = StyleBoxFlat.new()
	spin_bg.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	spin_bg.corner_radius_top_left = 3
	spin_bg.corner_radius_top_right = 3
	spin_bg.corner_radius_bottom_left = 3
	spin_bg.corner_radius_bottom_right = 3
	spin_indicator.add_theme_stylebox_override("background", spin_bg)

	var spin_fill = StyleBoxFlat.new()
	spin_fill.bg_color = Color(0.3, 0.7, 1.0, 0.9)
	spin_fill.corner_radius_top_left = 3
	spin_fill.corner_radius_top_right = 3
	spin_fill.corner_radius_bottom_left = 3
	spin_fill.corner_radius_bottom_right = 3
	spin_indicator.add_theme_stylebox_override("fill", spin_fill)
	spin_container.add_child(spin_indicator)

	# Spread Indicator (para SMG)
	var spread_container = HBoxContainer.new()
	spread_container.name = "SpreadContainer"
	weapon_info_container.add_child(spread_container)

	var spread_label = Label.new()
	spread_label.text = "SPREAD"
	spread_label.add_theme_font_size_override("font_size", 12)
	spread_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.3))
	spread_label.custom_minimum_size = Vector2(50, 0)
	spread_container.add_child(spread_label)

	spread_indicator = ProgressBar.new()
	spread_indicator.name = "SpreadIndicator"
	spread_indicator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spread_indicator.max_value = 100
	spread_indicator.value = 0
	spread_indicator.show_percentage = false
	spread_indicator.custom_minimum_size = Vector2(0, 12)

	var spread_bg = StyleBoxFlat.new()
	spread_bg.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	spread_bg.corner_radius_top_left = 3
	spread_bg.corner_radius_top_right = 3
	spread_bg.corner_radius_bottom_left = 3
	spread_bg.corner_radius_bottom_right = 3
	spread_indicator.add_theme_stylebox_override("background", spread_bg)

	var spread_fill = StyleBoxFlat.new()
	spread_fill.bg_color = Color(0.8, 0.8, 0.3, 0.9)
	spread_fill.corner_radius_top_left = 3
	spread_fill.corner_radius_top_right = 3
	spread_fill.corner_radius_bottom_left = 3
	spread_fill.corner_radius_bottom_right = 3
	spread_indicator.add_theme_stylebox_override("fill", spread_fill)
	spread_container.add_child(spread_indicator)


func _process(_delta: float) -> void:
	# Atualiza crosshair com dados do camera_effects
	if crosshair_drawer and camera_effects:
		crosshair_drawer.crosshair_size = camera_effects.get_crosshair_size()
		crosshair_drawer.hitmarker_info = camera_effects.get_hitmarker_info()
		crosshair_drawer.queue_redraw()

	# Atualiza vignette
	if vignette_drawer and camera_effects:
		vignette_drawer.intensity = camera_effects.get_vignette_intensity()
		vignette_drawer.queue_redraw()

	# Atualiza key indicator
	_update_key_indicator()

	# Atualiza upgrade indicator
	_update_upgrade_indicator()

	# Atualiza dash indicators
	_update_dash_indicators()

	# Atualiza weapon-specific info
	_update_weapon_info()


func _find_player() -> void:
	"""Encontra o player na cena"""
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

		if player is PlayerController:
			player_controller = player

			# Obtém camera_effects
			var camera = player_controller.get_camera()
			if camera:
				camera_effects = camera.get_node_or_null("CameraEffects")

		# Conecta aos signals do player stats
		if player.has_node("PlayerStats"):
			var stats = player.get_node("PlayerStats")
			stats.health_changed.connect(_on_health_changed)

			# Atualiza health inicial
			_on_health_changed(stats.current_health, stats.max_health)


func set_weapon(weapon: Node3D) -> void:
	"""Define a arma atual para tracking de ammo"""
	# Desconecta da arma anterior
	if current_weapon and current_weapon.has_signal("ammo_changed"):
		if current_weapon.ammo_changed.is_connected(_on_ammo_changed):
			current_weapon.ammo_changed.disconnect(_on_ammo_changed)

	current_weapon = weapon

	# Conecta aos signals da nova arma
	if current_weapon and current_weapon.has_signal("ammo_changed"):
		current_weapon.ammo_changed.connect(_on_ammo_changed)

		# Atualiza ammo inicial
		_on_ammo_changed(
			current_weapon.current_ammo,
			current_weapon.magazine_size
		)


func _on_health_changed(current_health: float, max_health: float) -> void:
	"""Atualiza a barra de HP"""
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

	if health_label:
		health_label.text = "%d / %d" % [int(current_health), int(max_health)]


func _on_ammo_changed(current_ammo: int, magazine_size: int) -> void:
	"""Atualiza o contador de munição (reload infinito estilo Overwatch)"""
	if ammo_label:
		ammo_label.text = "%d / %d" % [current_ammo, magazine_size]


func _on_time_changed(seconds_remaining: int) -> void:
	"""Atualiza o timer"""
	if timer_label:
		var minutes: int = seconds_remaining / 60
		var seconds: int = seconds_remaining % 60
		timer_label.text = "%02d:%02d" % [minutes, seconds]

		# Muda cor quando está acabando o tempo
		if seconds_remaining < 60:
			timer_label.add_theme_color_override("font_color", Color.RED)
		else:
			timer_label.add_theme_color_override("font_color", Color.WHITE)


# === BOSS UI ===

func _on_boss_spawning(boss_number: int) -> void:
	"""Quando um boss vai spawnar"""
	boss_active = true

	# Mostra container de boss health
	if boss_health_container:
		boss_health_container.visible = true

	# Atualiza nome
	if boss_name_label:
		var boss_names = ["The Brute", "The Ravager", "The Destroyer", "The Overlord"]
		if boss_number > 0 and boss_number <= boss_names.size():
			boss_name_label.text = boss_names[boss_number - 1]


func _on_boss_health_updated(current: float, maximum: float, boss_name: String) -> void:
	"""Atualiza a barra de vida do boss"""
	if boss_health_bar:
		boss_health_bar.max_value = maximum
		boss_health_bar.value = current

	if boss_name_label and boss_name != "":
		boss_name_label.text = boss_name


func _on_boss_defeated(boss_number: int, dropped_key: bool) -> void:
	"""Quando um boss é derrotado"""
	boss_active = false

	# Esconde container de boss health com fade
	if boss_health_container:
		var tween = create_tween()
		tween.tween_property(boss_health_container, "modulate:a", 0.0, 0.5)
		await tween.finished
		boss_health_container.visible = false
		boss_health_container.modulate.a = 1.0

	# Mostra mensagem se dropou key
	if dropped_key:
		_show_key_dropped_message()


func _on_boss_warning(seconds_until_spawn: int) -> void:
	"""Aviso antes do boss spawnar"""
	if boss_warning:
		boss_warning.visible = true
		boss_warning.text = "BOSS INCOMING!"

		# Animação pulsante
		var tween = create_tween()
		tween.set_loops(seconds_until_spawn)
		tween.tween_property(boss_warning, "modulate:a", 0.3, 0.4)
		tween.tween_property(boss_warning, "modulate:a", 1.0, 0.4)

		await get_tree().create_timer(seconds_until_spawn).timeout
		boss_warning.visible = false


func _show_key_dropped_message() -> void:
	"""Mostra mensagem quando key é dropada"""
	if boss_warning:
		boss_warning.text = "KEY DROPPED!"
		boss_warning.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
		boss_warning.visible = true

		await get_tree().create_timer(2.0).timeout

		boss_warning.visible = false
		boss_warning.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))


# === KEY UI ===

func _update_key_indicator() -> void:
	"""Atualiza o indicador de key"""
	if not key_icon or not key_label:
		return

	if GameManager and GameManager.has_boss_key:
		key_icon.color = Color(1.0, 0.8, 0.0)  # Dourado
		key_label.text = " Key"
		key_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
	else:
		key_icon.color = Color(0.3, 0.3, 0.3)  # Cinza
		key_label.text = " No Key"
		key_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))


# === UPGRADE UI ===

func _update_upgrade_indicator() -> void:
	"""Atualiza indicadores de upgrades ativos"""
	if not upgrade_indicator:
		return

	if not UpgradeManager:
		return

	# Limpa indicadores anteriores
	for child in upgrade_indicator.get_children():
		child.queue_free()

	# Cria indicadores para cada upgrade ativo
	var active = UpgradeManager.get_active_upgrades()
	for upgrade_id in active:
		var data = active[upgrade_id]
		var indicator = _create_upgrade_indicator(data)
		upgrade_indicator.add_child(indicator)


func _create_upgrade_indicator(data) -> Control:
	"""Cria um pequeno indicador de upgrade"""
	var container = PanelContainer.new()
	container.custom_minimum_size = Vector2(40, 40)

	var style = StyleBoxFlat.new()
	style.bg_color = data.color if "color" in data else Color(0.3, 0.3, 0.3)
	style.bg_color.a = 0.7
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	container.add_theme_stylebox_override("panel", style)

	# Level label
	var level_label = Label.new()
	level_label.text = str(data.current_level) if "current_level" in data else "1"
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	container.add_child(level_label)

	return container


func update_hp(current: float, maximum: float) -> void:
	"""Método público para atualizar HP"""
	_on_health_changed(current, maximum)


func update_ammo(current: int, mag_size: int) -> void:
	"""Método público para atualizar ammo"""
	_on_ammo_changed(current, mag_size)


func update_timer(seconds: int) -> void:
	"""Método público para atualizar timer"""
	_on_time_changed(seconds)


# === XP SYSTEM UPDATES ===

func _update_dash_indicators() -> void:
	"""Atualiza a barra de estamina contínua"""
	if not stamina_bar:
		return

	if not player_controller:
		return

	var dash_sys = player_controller.get("dash_system")
	if not dash_sys:
		dash_sys = player_controller.get_node_or_null("DashSystem")

	if not dash_sys:
		return

	# Lê valores do sistema de estamina
	var current = dash_sys.get("current_stamina") if dash_sys else 100.0
	var maximum = dash_sys.get("max_stamina") if dash_sys else 100.0

	# Atualiza a barra
	stamina_bar.max_value = maximum
	stamina_bar.value = current

	# Muda cor quando estamina está baixa (não pode dar dash)
	var stamina_cost = dash_sys.get("stamina_cost") if dash_sys else 33.33
	if current < stamina_cost:
		# Estamina insuficiente - cor vermelha/laranja
		stamina_bar.self_modulate = Color(1.0, 0.5, 0.3)
	else:
		# Estamina suficiente - cor normal
		stamina_bar.self_modulate = Color.WHITE


func _on_xp_changed(current: int, required: int) -> void:
	"""Callback quando XP muda"""
	if xp_bar:
		xp_bar.max_value = required
		xp_bar.value = current

		# Animação suave (opcional)
		var tween = create_tween()
		tween.tween_property(xp_bar, "value", current, 0.2).set_ease(Tween.EASE_OUT)


func _on_level_up(new_level: int) -> void:
	"""Callback quando sobe de level"""
	# Atualiza label
	if level_label:
		level_label.text = "Lv. " + str(new_level)

		# Animação de destaque
		var tween = create_tween()
		tween.tween_property(level_label, "scale", Vector2(1.3, 1.3), 0.15).set_ease(Tween.EASE_OUT)
		tween.tween_property(level_label, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_IN)

	# Mostra tela de level up
	if level_up_screen:
		level_up_screen.show_level_up_options()


# === WEAPON SPECIFIC INFO ===

func _update_weapon_info() -> void:
	"""Atualiza UI de informações específicas de arma"""
	if not current_weapon or not weapon_info_container:
		return

	# Detecta tipo de arma
	var weapon_type = ""
	if current_weapon.has_method("get_weapon_type"):
		weapon_type = current_weapon.get_weapon_type()

	# LMG: mostra heat e spin
	if weapon_type == "lmg":
		weapon_info_container.visible = true

		# Heat
		if heat_bar and current_weapon.has_method("get_heat_percentage"):
			heat_bar.value = current_weapon.get_heat_percentage() * 100
			heat_bar.get_parent().visible = true

			# Muda cor quando overheat
			var is_overheated = current_weapon.get("is_overheated")
			if is_overheated:
				heat_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
			else:
				heat_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))

		# Spin
		if spin_indicator and current_weapon.has_method("get_spin_percentage"):
			spin_indicator.value = current_weapon.get_spin_percentage() * 100
			spin_indicator.get_parent().visible = true

		# Esconde spread
		if spread_indicator:
			spread_indicator.get_parent().visible = false

	# SMG: mostra spread
	elif weapon_type == "smg":
		weapon_info_container.visible = true

		# Spread
		if spread_indicator and current_weapon.has_method("get_spread_percentage"):
			spread_indicator.value = current_weapon.get_spread_percentage() * 100
			spread_indicator.get_parent().visible = true

		# Esconde heat e spin
		if heat_bar:
			heat_bar.get_parent().visible = false
		if spin_indicator:
			spin_indicator.get_parent().visible = false

	else:
		# Outras armas: esconde tudo
		weapon_info_container.visible = false


func _configure_weapon_ui(weapon_type: String) -> void:
	"""Configura visibilidade da UI baseada no tipo de arma"""
	if not weapon_info_container:
		return

	match weapon_type:
		"lmg":
			weapon_info_container.visible = true
			heat_bar.get_parent().visible = true
			spin_indicator.get_parent().visible = true
			spread_indicator.get_parent().visible = false
		"smg":
			weapon_info_container.visible = true
			heat_bar.get_parent().visible = false
			spin_indicator.get_parent().visible = false
			spread_indicator.get_parent().visible = true
		_:
			weapon_info_container.visible = false


# === CLASSES INTERNAS PARA DESENHO ===

func _setup_radar() -> void:
	"""Configura o radar"""
	var RadarScript = load("res://ui/radar_drawer.gd")
	if not RadarScript:
		return
		
	radar_drawer = RadarScript.new()
	$Control.add_child(radar_drawer)
	
	# Posiciona no canto inferior direito usando offsets explícitos
	radar_drawer.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	radar_drawer.grow_horizontal = Control.GROW_DIRECTION_BEGIN # Cresce para a Esquerda
	radar_drawer.grow_vertical = Control.GROW_DIRECTION_BEGIN   # Cresce para Cima
	
	# Margem de 20px da borda, tamanho ~160px
	radar_drawer.offset_left = -180
	radar_drawer.offset_top = -180
	radar_drawer.offset_right = -20
	radar_drawer.offset_bottom = -20
	
	print("[HUD] Radar criado e posicionado.")


class CrosshairDrawer extends Control:
	"""Drawer customizado para crosshair dinâmico e hitmarker"""

	## crosshair_size agora controla o GAP (distância do centro)
	var crosshair_size: float = 2.0
	var crosshair_color: Color = Color.WHITE
	var crosshair_thickness: float = 2.0
	## Comprimento fixo das linhas (não muda com precisão)
	var crosshair_line_length: float = 6.0

	var hitmarker_info: Dictionary = {"active": false}

	func _draw() -> void:
		var center = size / 2.0

		# Desenha crosshair dinâmico
		_draw_crosshair(center)

		# Desenha hitmarker se ativo
		if hitmarker_info.get("active", false):
			_draw_hitmarker(center)

	func _draw_crosshair(center: Vector2) -> void:
		"""Desenha o crosshair em formato de '+' simples"""
		# Gap é controlado pelo crosshair_size (precisão)
		var gap: float = crosshair_size
		# Comprimento das linhas é FIXO
		var length: float = crosshair_line_length

		# Linha superior (do gap até gap + length)
		draw_line(
			center + Vector2(0, -gap),
			center + Vector2(0, -gap - length),
			crosshair_color, crosshair_thickness
		)

		# Linha inferior
		draw_line(
			center + Vector2(0, gap),
			center + Vector2(0, gap + length),
			crosshair_color, crosshair_thickness
		)

		# Linha esquerda
		draw_line(
			center + Vector2(-gap, 0),
			center + Vector2(-gap - length, 0),
			crosshair_color, crosshair_thickness
		)

		# Linha direita
		draw_line(
			center + Vector2(gap, 0),
			center + Vector2(gap + length, 0),
			crosshair_color, crosshair_thickness
		)

	func _draw_hitmarker(center: Vector2) -> void:
		"""Desenha o hitmarker (X)"""
		var hit_size = hitmarker_info.get("size", 15.0)
		var hit_color = hitmarker_info.get("color", Color.WHITE)
		var alpha = hitmarker_info.get("alpha", 1.0)

		hit_color.a = alpha

		var offset = hit_size * 0.5
		var thickness = 2.5

		# Linha diagonal 1 (\)
		draw_line(
			center + Vector2(-offset, -offset),
			center + Vector2(-offset * 0.3, -offset * 0.3),
			hit_color, thickness
		)
		draw_line(
			center + Vector2(offset, offset),
			center + Vector2(offset * 0.3, offset * 0.3),
			hit_color, thickness
		)

		# Linha diagonal 2 (/)
		draw_line(
			center + Vector2(offset, -offset),
			center + Vector2(offset * 0.3, -offset * 0.3),
			hit_color, thickness
		)
		draw_line(
			center + Vector2(-offset, offset),
			center + Vector2(-offset * 0.3, offset * 0.3),
			hit_color, thickness
		)


class VignetteDrawer extends Control:
	"""Drawer para efeito de vignette"""

	var intensity: float = 0.0
	var base_color: Color = Color(0.8, 0.1, 0.1)  # Vermelho escuro

	func _draw() -> void:
		if intensity <= 0.01:
			return

		var center = size / 2.0
		var max_radius = size.length() / 2.0

		# Desenha gradiente radial (simulado com círculos)
		var steps = 20
		for i in range(steps, 0, -1):
			var t = float(i) / float(steps)
			var radius = max_radius * t

			# Alpha aumenta nas bordas
			var edge_factor = 1.0 - t
			var alpha = edge_factor * edge_factor * intensity * 0.8

			var color = base_color
			color.a = alpha

			draw_circle(center, radius, color)
