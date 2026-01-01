extends BaseWeapon

# Pistol - Arma inicial do jogador
# Semi-automática, dano médio, recoil controlável
# Boa para aprender as mecânicas do jogo

class_name Pistol


func _ready() -> void:
	# === STATS BÁSICOS ===
	damage = 20.0              # Dano bom para pistola
	fire_rate = 0.15           # Mais rápido para ser responsivo
	reload_time = 1.0          # Reload rápido
	magazine_size = 15         # Magazine um pouco maior
	max_ammo = 150             # Mais munição total

	# === RECOIL DA ARMA (kickback visual) ===
	# Movimento para trás quando atira
	kickback_position = Vector3(0.0, 0.015, 0.06)
	# Rotação do kickback (pitch up, yaw, roll)
	kickback_rotation = Vector3(-4.0, 2.0, 1.5)
	# Aleatoriedade na posição
	position_randomness = Vector3(0.003, 0.003, 0.008)
	# Aleatoriedade na rotação
	rotation_randomness = Vector3(0.8, 1.2, 0.6)
	# Velocidades
	kickback_speed = 18.0      # Kickback rápido
	return_speed = 10.0        # Retorno médio
	shooting_return_speed = 5.0  # Retorno mais lento ao atirar rápido

	# === RECOIL DA CÂMERA ===
	camera_recoil_horizontal = 0.4   # Horizontal moderado
	camera_recoil_vertical = 1.2     # Vertical mais pronunciado

	# === SWAY ===
	sway_enabled = true
	mouse_sway_amount = Vector2(0.0015, 0.0015)
	mouse_sway_max = Vector2(0.04, 0.025)
	movement_sway_amount = 0.015

	# Chama o _ready() do pai
	super._ready()
