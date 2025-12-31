extends BaseWeapon

# Pistol - Arma inicial do jogador
# Semi-automática, dano médio, fire rate médio

class_name Pistol

# Configuração visual do mesh (ajuste esses valores!)
@export var mesh_scale: float = 0.025
@export var mesh_rotation_degrees: Vector3 = Vector3(0, 180, 0)  # Testando sem rotação
@export var mesh_position: Vector3 = Vector3(0.48, -4.16, -0.95)  # Afastado mais da câmera

func _ready() -> void:
	# Stats específicas da pistola
	damage = 15.0
	fire_rate = 0.25
	reload_time = 1.2
	magazine_size = 12
	max_ammo = 120
	recoil_amount = Vector2(0.005, 0.015)

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
