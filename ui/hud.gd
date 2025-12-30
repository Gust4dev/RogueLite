extends CanvasLayer

# HUD - Interface do jogador
# Mostra HP, ammo, timer e crosshair

# Referências aos elementos UI (serão definidos na cena)
@onready var health_bar: ProgressBar = $Control/HealthBar
@onready var health_label: Label = $Control/HealthBar/Label
@onready var ammo_label: Label = $Control/AmmoLabel
@onready var timer_label: Label = $Control/TimerLabel
@onready var crosshair: Control = $Control/Crosshair

# Referências ao player e weapon
var player: Node3D = null
var current_weapon: Node3D = null

func _ready() -> void:
	# Conecta aos signals do GameManager
	if GameManager:
		GameManager.time_changed.connect(_on_time_changed)

	# Encontra o player
	call_deferred("_find_player")

func _find_player() -> void:
	"""Encontra o player na cena"""
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

		# Conecta aos signals do player stats
		if player.has_node("PlayerStats"):
			var stats = player.get_node("PlayerStats")
			stats.health_changed.connect(_on_health_changed)

		# Atualiza health inicial
		if player.has_node("PlayerStats"):
			var stats = player.get_node("PlayerStats")
			_on_health_changed(stats.current_health, stats.max_health)

func set_weapon(weapon: Node3D) -> void:
	"""Define a arma atual para tracking de ammo"""
	# Desconecta da arma anterior
	if current_weapon and current_weapon.has_signal("ammo_changed"):
		current_weapon.ammo_changed.disconnect(_on_ammo_changed)

	current_weapon = weapon

	# Conecta aos signals da nova arma
	if current_weapon and current_weapon.has_signal("ammo_changed"):
		current_weapon.ammo_changed.connect(_on_ammo_changed)

		# Atualiza ammo inicial
		if current_weapon.has_method("_ready"):
			_on_ammo_changed(
				current_weapon.current_ammo,
				current_weapon.magazine_size,
				current_weapon.reserve_ammo
			)

func _on_health_changed(current_health: float, max_health: float) -> void:
	"""Atualiza a barra de HP"""
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

	if health_label:
		health_label.text = "%d / %d" % [int(current_health), int(max_health)]

func _on_ammo_changed(current_ammo: int, magazine_size: int, reserve_ammo: int) -> void:
	"""Atualiza o contador de munição"""
	if ammo_label:
		ammo_label.text = "%d / %d | %d" % [current_ammo, magazine_size, reserve_ammo]

func _on_time_changed(seconds_remaining: int) -> void:
	"""Atualiza o timer"""
	if timer_label:
		var minutes: int = seconds_remaining / 60
		var seconds: int = seconds_remaining % 60
		timer_label.text = "%02d:%02d" % [minutes, seconds]

		# Muda cor quando está acabando o tempo (menos de 1 minuto)
		if seconds_remaining < 60:
			timer_label.add_theme_color_override("font_color", Color.RED)
		else:
			timer_label.add_theme_color_override("font_color", Color.WHITE)

func update_hp(current: float, maximum: float) -> void:
	"""Método público para atualizar HP"""
	_on_health_changed(current, maximum)

func update_ammo(current: int, mag_size: int, reserve: int) -> void:
	"""Método público para atualizar ammo"""
	_on_ammo_changed(current, mag_size, reserve)

func update_timer(seconds: int) -> void:
	"""Método público para atualizar timer"""
	_on_time_changed(seconds)
