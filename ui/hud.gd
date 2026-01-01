extends CanvasLayer

# HUD - Interface do jogador
# Mostra HP, ammo, timer, crosshair dinâmico e hitmarker

# Referências aos elementos UI
@onready var health_bar: ProgressBar = $Control/HealthBar
@onready var health_label: Label = $Control/HealthBar/Label
@onready var ammo_label: Label = $Control/AmmoLabel
@onready var timer_label: Label = $Control/TimerLabel
@onready var crosshair: Control = $Control/Crosshair
@onready var crosshair_container: Control = $Control/CrosshairContainer

# Referências ao player e weapon
var player: Node3D = null
var player_controller: PlayerController = null
var current_weapon: Node3D = null
var camera_effects: CameraEffects = null

# === CROSSHAIR DINÂMICO ===
var crosshair_drawer: CrosshairDrawer = null

# === VIGNETTE ===
var vignette_drawer: VignetteDrawer = null


func _ready() -> void:
	# Conecta aos signals do GameManager
	if GameManager:
		GameManager.time_changed.connect(_on_time_changed)

	# Encontra o player
	call_deferred("_find_player")

	# Cria o drawer do crosshair
	_setup_crosshair_drawer()

	# Cria o drawer da vignette
	_setup_vignette_drawer()


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

		# Muda cor quando está acabando o tempo
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


# === CLASSES INTERNAS PARA DESENHO ===

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
