extends BaseWeapon

# Pistol - Arma inicial do jogador
# Semi-automática, dano médio, recoil controlável
# Boa para aprender as mecânicas do jogo

class_name Pistol

# Configuração visual do mesh (ajuste esses valores!)
@export var mesh_scale: float = 0.025
@export var mesh_rotation_degrees: Vector3 = Vector3(0, 180, 0)  # Testando sem rotação
@export var mesh_position: Vector3 = Vector3(0.48, -4.16, -0.95)  # Afastado mais da câmera

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
	
	# Configura o mesh após o pai ter buscado as referências
	_setup_mesh_transform()

func _setup_mesh_transform() -> void:
	"""Configura posição, escala e rotação do mesh da arma"""
	print("[Pistol] Verificando mesh...")
	
	if not mesh:
		print("[Pistol] ERRO: Mesh não encontrado! Filhos do nó:")
		for child in get_children():
			print("  - ", child.name, " (", child.get_class(), ")")
		return
	
	print("[Pistol] Mesh encontrado: ", mesh.name)
	mesh.scale = Vector3(mesh_scale, mesh_scale, mesh_scale)
	mesh.rotation_degrees = mesh_rotation_degrees
	mesh.position = mesh_position
	print("[Pistol] Mesh configurado - Scale: ", mesh_scale, " Rotation: ", mesh_rotation_degrees, " Position: ", mesh_position)
	
	# Debug: mostra animações disponíveis
	if animation_player:
		var anims = animation_player.get_animation_list()
		print("[Pistol] AnimationPlayer encontrado! Animações: ", anims)
		# NÃO tocar animação inicial para evitar bug de invisibilidade
		# Se quiser animação inicial, descomente a linha abaixo:
		# _play_animation(anim_draw)
	else:
		print("[Pistol] AVISO: AnimationPlayer não encontrado!")
