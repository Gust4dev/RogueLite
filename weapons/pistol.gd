extends BaseWeapon

# Pistol - Arma inicial do jogador
# Semi-automática, dano médio, recoil controlável

class_name Pistol


func _ready() -> void:
	# === STATS BÁSICOS ===
	damage = 20.0
	fire_rate = 0.15
	reload_time = 1.0
	magazine_size = 12

	# === RECOIL DA ARMA (kickback visual) ===
	kickback_position = Vector3(0.0, 0.015, 0.06)
	kickback_rotation = Vector3(-4.0, 2.0, 1.5)
	position_randomness = Vector3(0.003, 0.003, 0.008)
	rotation_randomness = Vector3(0.8, 1.2, 0.6)
	kickback_speed = 18.0
	return_speed = 10.0
	shooting_return_speed = 5.0

	# === RECOIL DA CÂMERA ===
	camera_recoil_horizontal = 0.4
	camera_recoil_vertical = 1.2

	# === SWAY ===
	sway_enabled = true
	mouse_sway_amount = Vector2(0.0015, 0.0015)
	mouse_sway_max = Vector2(0.04, 0.025)
	movement_sway_amount = 0.015

	# Nomes das animações para este modelo
	anim_shoot = "WEP_Fire"
	anim_reload = "WEP_Reload_01"
	anim_draw = "WEP_Draw"
	anim_idle = "WEP_Idle"
	
	# Chama o _ready() do pai
	super._ready()
	
	# Toca animação inicial: Draw → Idle
	_play_initial_sequence()


func _play_initial_sequence() -> void:
	"""Toca Draw e depois vai para Idle"""
	if not animation_player:
		return
	
	# Toca Draw
	if animation_player.has_animation(anim_draw):
		animation_player.play(anim_draw)
		await animation_player.animation_finished
	
	# Vai para Idle
	if animation_player.has_animation(anim_idle):
		animation_player.play(anim_idle)
