extends BaseEnemy

# Zombie - Inimigo melee básico
# Segue o player e ataca em corpo a corpo

class_name Zombie

## Customização Visual (ajuste no Inspector)
@export var mesh_scale: float = 1.0
@export var mesh_y_offset: float = 0.0
@export var mesh_rotation_y: float = 180.0  ## Rotação em graus (180 = virar de frente)

func _ready() -> void:
	# Stats específicas do zombie
	max_health = 50.0
	speed = 3.0
	damage = 10.0
	attack_range = 2.0
	attack_cooldown = 1.5

	# Chama o _ready() do pai
	super._ready()

	# Aplica customização visual ao mesh
	_apply_visual_customization()

func _apply_visual_customization() -> void:
	"""Aplica escala, offset Y e rotação ao mesh"""
	if mesh:
		mesh.scale = Vector3(mesh_scale, mesh_scale, mesh_scale)
		mesh.position.y = mesh_y_offset
		mesh.rotation_degrees.y = mesh_rotation_y
