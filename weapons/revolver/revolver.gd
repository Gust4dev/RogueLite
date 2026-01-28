extends BaseWeapon

# Revolver - Arma de alto dano, ritmo lento
# Alta precisão, dano pesado por tiro
# Upgrade Interactions:
#   - Burst Fire: Recoil muito alto até nível máximo
#   - Fast Reload: Instant reload no nível máximo

class_name Revolver

# Tipo de arma para upgrade interactions
var weapon_type: String = "revolver"

# Recoil multiplier base (para interação com Burst Fire)
var burst_recoil_multiplier: float = 3.0  # Recoil 3x maior com burst
var burst_recoil_at_max_level: float = 0.1  # Praticamente zero no nível máximo


func _ready() -> void:
	# Define meshes que devem ir para o overlay (ignora braços/corpo)
	weapon_mesh_keywords = ["revolver", "cylinder", "barrel", "hammer", "gun", "weapon"]

	# === STATS BÁSICOS ===
	# 40 dmg / 0.6s = ~66 DPS (target)
	damage = 40.0
	fire_rate = 0.6  # Ajustado para DPS target (era 1.15 no spec)
	reload_time = 1.8  # Reload mais lento devido ao alto dano
	magazine_size = 8

	# === RECOIL DA ARMA (kickback visual) ===
	# Revolver tem recoil mais pesado e pronunciado
	kickback_position = Vector3(0.0, 0.04, 0.12)  # Mais kickback que pistola
	kickback_rotation = Vector3(-8.0, 4.0, 3.0)   # Rotação mais agressiva
	position_randomness = Vector3(0.008, 0.008, 0.015)
	rotation_randomness = Vector3(1.5, 2.0, 1.0)
	kickback_speed = 20.0  # Kickback rápido
	return_speed = 6.0     # Retorno mais lento (arma pesada)
	shooting_return_speed = 3.5

	# === RECOIL DA CÂMERA ===
	camera_recoil_horizontal = 0.8   # Mais horizontal kick
	camera_recoil_vertical = 2.5     # Punch vertical significativo

	# === SWAY ===
	sway_enabled = true
	mouse_sway_amount = Vector2(0.001, 0.001)  # Menos sway (arma pesada, mais estável)
	mouse_sway_max = Vector2(0.03, 0.02)
	movement_sway_amount = 0.012

	# Nomes das animações para este modelo
	# Placeholder - será atualizado quando tiver o modelo
	anim_shoot = "Shoot"
	anim_reload = "Reload"
	anim_draw = "Draw"
	anim_idle = "Idle"

	# Velocidade das animações
	anim_speed_shoot = 1.5  # Animação de tiro mais lenta (arma pesada)
	anim_speed_reload = 1.2

	# Chama o _ready() do pai
	super._ready()

	# Toca animação inicial
	_play_initial_sequence()


func _play_initial_sequence() -> void:
	"""Toca Draw e depois vai para Idle"""
	if not animation_player:
		return

	if animation_player.has_animation(anim_draw):
		animation_player.play(anim_draw)
		await animation_player.animation_finished

	if animation_player.has_animation(anim_idle):
		animation_player.play(anim_idle)


# === REVOLVER SPECIFIC METHODS ===

func get_weapon_type() -> String:
	"""Retorna o tipo de arma para upgrade interactions"""
	return weapon_type


func get_burst_recoil_multiplier(burst_level: int) -> float:
	"""Retorna o multiplicador de recoil para burst fire
	   Level 1-2: Recoil muito alto
	   Level 3: Praticamente zero
	"""
	if burst_level >= 3:
		return burst_recoil_at_max_level
	return burst_recoil_multiplier


func can_instant_reload_at_level(fast_reload_level: int) -> bool:
	"""Verifica se pode fazer instant reload com Fast Reload
	   Level 3: Instant reload
	"""
	return fast_reload_level >= 3


# === OVERRIDE para feedback visual de dano alto ===

func _apply_shooting_effects() -> void:
	"""Override: Efeitos visuais mais intensos para revolver"""
	if camera_effects:
		camera_effects.trigger_shooting_effects()
		# Shake adicional pelo dano alto
		camera_effects.shake_shoot()
