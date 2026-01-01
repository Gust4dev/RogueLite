extends Area3D

# Key Item - Pickup que dropa dos bosses
# Necessário para abrir o portal final

class_name KeyItem

signal key_collected()

# Visual config
@export var rotation_speed: float = 2.0
@export var bob_speed: float = 2.0
@export var bob_height: float = 0.3
@export var glow_color: Color = Color(1.0, 0.8, 0.0, 1.0)  # Dourado
@export var glow_intensity: float = 3.0

# Estado
var base_y: float = 0.0
var time_passed: float = 0.0
var collected: bool = false

# Referências
var mesh_instance: MeshInstance3D = null
var particles: GPUParticles3D = null


func _ready() -> void:
	# Configura collision
	collision_layer = 0
	collision_mask = 1  # Apenas player

	# Conecta signal de colisão
	body_entered.connect(_on_body_entered)

	# Salva posição Y base
	base_y = global_position.y

	# Cria visual da key
	_create_key_visual()

	# Cria partículas de glow
	_create_particles()


func _process(delta: float) -> void:
	if collected:
		return

	time_passed += delta

	# Rotação contínua
	if mesh_instance:
		mesh_instance.rotation.y += rotation_speed * delta

	# Movimento de bobbing (sobe e desce)
	global_position.y = base_y + sin(time_passed * bob_speed) * bob_height


func _create_key_visual() -> void:
	"""Cria a representação visual da key"""
	# Cria mesh da key (usando um cilindro simples como placeholder)
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "KeyMesh"

	# Cria forma de key simples (combinando formas)
	var key_mesh = BoxMesh.new()
	key_mesh.size = Vector3(0.3, 0.1, 0.8)

	mesh_instance.mesh = key_mesh

	# Material com glow
	var material = StandardMaterial3D.new()
	material.albedo_color = glow_color
	material.emission_enabled = true
	material.emission = glow_color
	material.emission_energy_multiplier = glow_intensity
	material.metallic = 0.8
	material.roughness = 0.2

	mesh_instance.set_surface_override_material(0, material)
	add_child(mesh_instance)

	# Collision shape
	var collision = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 1.0
	collision.shape = shape
	add_child(collision)


func _create_particles() -> void:
	"""Cria partículas de brilho ao redor da key"""
	particles = GPUParticles3D.new()
	particles.name = "KeyParticles"

	# Configura partículas
	var particle_mat = ParticleProcessMaterial.new()
	particle_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particle_mat.emission_sphere_radius = 0.5
	particle_mat.direction = Vector3(0, 1, 0)
	particle_mat.spread = 180.0
	particle_mat.initial_velocity_min = 0.5
	particle_mat.initial_velocity_max = 1.0
	particle_mat.gravity = Vector3(0, 0.5, 0)
	particle_mat.scale_min = 0.05
	particle_mat.scale_max = 0.1
	particle_mat.color = glow_color

	particles.process_material = particle_mat
	particles.amount = 20
	particles.lifetime = 1.5
	particles.emitting = true

	# Mesh das partículas
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(0.1, 0.1)
	particles.draw_pass_1 = quad_mesh

	add_child(particles)


func _on_body_entered(body: Node3D) -> void:
	"""Quando player encosta na key"""
	if collected:
		return

	if body.is_in_group("player"):
		collect()


func collect() -> void:
	"""Coleta a key"""
	if collected:
		return

	collected = true

	# Atualiza GameManager
	GameManager.has_boss_key = true

	# Emite signal
	key_collected.emit()

	# Efeito de coleta
	_collect_effect()


func _collect_effect() -> void:
	"""Animação de coleta da key"""
	# Scale up e fade
	var tween = create_tween()
	tween.set_parallel(true)

	if mesh_instance:
		tween.tween_property(mesh_instance, "scale", Vector3(2, 2, 2), 0.3)

	# Para partículas
	if particles:
		particles.emitting = false

	await tween.finished

	# Remove da cena
	queue_free()
