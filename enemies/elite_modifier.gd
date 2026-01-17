extends Node

# Elite Modifier - Componente que transforma um inimigo em versão elite
# Aplica buffs de stats e efeitos visuais

class_name EliteModifier

# Configuração Elite
@export var hp_multiplier: float = 2.0
@export var damage_multiplier: float = 1.5
@export var speed_multiplier: float = 1.2
@export var xp_multiplier: float = 3.0
@export var scale_multiplier: float = 1.3

# Visual
@export var elite_glow_color: Color = Color(1.0, 0.8, 0.0)  # Dourado
@export var elite_glow_intensity: float = 3.0

# Referência ao inimigo
var enemy: BaseEnemy = null
var particle_effect: GPUParticles3D = null

func _ready() -> void:
	# Busca o inimigo pai
	enemy = get_parent() as BaseEnemy
	if not enemy:
		push_error("EliteModifier deve ser filho de um BaseEnemy!")
		queue_free()
		return

	# Aplica modificações (defer para garantir que o enemy já inicializou)
	call_deferred("_apply_elite_modifications")


func _apply_elite_modifications() -> void:
	"""Aplica todas as modificações elite ao inimigo"""
	if not enemy:
		return

	# Modifica stats
	_modify_stats()

	# Aplica visual
	_apply_elite_visual()

	# Adiciona partículas
	_add_particle_effect()

	# Marca como elite
	enemy.set_meta("is_elite", true)


func _modify_stats() -> void:
	"""Modifica os stats do inimigo"""
	# HP
	enemy.max_health *= hp_multiplier
	enemy.current_health = enemy.max_health

	# Damage
	enemy.damage *= damage_multiplier

	# Speed
	enemy.speed *= speed_multiplier

	# XP reward
	enemy.xp_reward = int(enemy.xp_reward * xp_multiplier)


func _apply_elite_visual() -> void:
	"""Aplica efeitos visuais de elite"""
	# Aumenta escala
	if enemy.mesh:
		enemy.mesh.scale *= scale_multiplier

	# Aplica glow dourado
	var mesh_instance = enemy._find_mesh_instance()
	if mesh_instance:
		var material = StandardMaterial3D.new()
		material.albedo_color = Color.WHITE
		material.emission_enabled = true
		material.emission = elite_glow_color
		material.emission_energy_multiplier = elite_glow_intensity
		material.rim_enabled = true
		material.rim = 1.0
		material.rim_tint = 0.5
		mesh_instance.set_surface_override_material(0, material)


func _add_particle_effect() -> void:
	"""Adiciona efeito de partículas elite"""
	particle_effect = GPUParticles3D.new()
	particle_effect.name = "EliteParticles"

	# Configura partículas
	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 1.0
	material.direction = Vector3(0, 1, 0)
	material.spread = 30.0
	material.gravity = Vector3(0, 0.5, 0)
	material.initial_velocity_min = 0.5
	material.initial_velocity_max = 1.5
	material.scale_min = 0.1
	material.scale_max = 0.2
	material.color = elite_glow_color

	particle_effect.process_material = material
	particle_effect.amount = 20
	particle_effect.lifetime = 1.5
	particle_effect.emitting = true

	# Mesh das partículas
	var quad = QuadMesh.new()
	quad.size = Vector2(0.2, 0.2)
	particle_effect.draw_pass_1 = quad

	enemy.add_child(particle_effect)
	particle_effect.position.y = 1.0


static func make_elite(enemy_node: BaseEnemy) -> void:
	"""Método estático para transformar um inimigo em elite"""
	if not enemy_node:
		return

	# Verifica se já é elite
	if enemy_node.has_meta("is_elite") and enemy_node.get_meta("is_elite"):
		return

	# Adiciona o modificador
	var modifier = EliteModifier.new()
	enemy_node.add_child(modifier)


static func should_be_elite(base_chance: float = 0.05) -> bool:
	"""Verifica se um inimigo deve spawnar como elite"""
	return randf() < base_chance
