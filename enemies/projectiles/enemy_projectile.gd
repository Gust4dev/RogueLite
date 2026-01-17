extends Area3D

# Enemy Projectile - Projétil disparado por inimigos ranged
# Usado por Shooter, Flying Drone, e Bosses

class_name EnemyProjectile

@export var speed: float = 15.0
@export var damage: float = 5.0
@export var lifetime: float = 5.0  # Tempo máximo antes de auto-destruir
@export var projectile_color: Color = Color.RED

var direction: Vector3 = Vector3.FORWARD
var is_active: bool = false

func _ready() -> void:
	# Configura colisão
	collision_layer = 0
	collision_mask = 1  # Colide com player (layer 1)

	# Conecta sinais de colisão
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	# Cria visual do projétil
	_create_projectile_visual()

	# Auto-destruir após lifetime
	get_tree().create_timer(lifetime).timeout.connect(_expire)


func setup(dir: Vector3, spd: float, dmg: float) -> void:
	"""Configura o projétil com direção, velocidade e dano"""
	direction = dir.normalized()
	speed = spd
	damage = dmg
	is_active = true

	# Rotaciona para apontar na direção do movimento
	if direction.length() > 0.1:
		look_at(global_position + direction)


func _physics_process(delta: float) -> void:
	if not is_active:
		return

	# Move o projétil
	global_position += direction * speed * delta


func _create_projectile_visual() -> void:
	"""Cria a representação visual do projétil"""
	# Cria mesh esférico
	var mesh_instance = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	mesh_instance.mesh = sphere

	# Material com glow
	var material = StandardMaterial3D.new()
	material.albedo_color = projectile_color
	material.emission_enabled = true
	material.emission = projectile_color
	material.emission_energy_multiplier = 3.0
	mesh_instance.set_surface_override_material(0, material)

	add_child(mesh_instance)

	# Cria CollisionShape
	var collision = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.2
	collision.shape = shape
	add_child(collision)


func _on_body_entered(body: Node3D) -> void:
	"""Quando colide com um corpo físico"""
	if not is_active:
		return

	# Verifica se é o player
	if body.is_in_group("player"):
		_hit_player(body)


func _on_area_entered(area: Area3D) -> void:
	"""Quando colide com outra área"""
	if not is_active:
		return

	# Se colidiu com hitbox do player
	var parent = area.get_parent()
	if parent and parent.is_in_group("player"):
		_hit_player(parent)


func _hit_player(player: Node3D) -> void:
	"""Aplica dano ao player e destrói o projétil"""
	if player.has_method("take_damage"):
		player.take_damage(damage)

	is_active = false
	_destroy()


func _expire() -> void:
	"""Projétil expirou sem acertar nada"""
	if is_active:
		is_active = false
		_destroy()


func _destroy() -> void:
	"""Destrói o projétil com efeito visual"""
	# Efeito de desaparecimento
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.1)
	await tween.finished
	queue_free()
