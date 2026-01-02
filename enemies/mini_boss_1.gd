extends MiniBoss

# Mini Boss 1 - "Brute"
# O primeiro boss, mais simples mas ainda perigoso
# HP: 200, Charge attacks básicos

func _ready() -> void:
	# Configuração do Boss 1
	boss_number = 1
	boss_name = "The Brute"

	# Stats - definidos pelo sistema de scaling em MiniBoss
	base_health = 200.0
	base_damage = 20.0

	# Comportamento
	speed = 4.0
	charge_attack_enabled = true
	charge_speed = 10.0
	charge_cooldown = 6.0
	charge_range = 12.0

	# Visual
	boss_scale = 1.5
	glow_color = Color(1.0, 0.3, 0.1, 1.0)  # Laranja/vermelho
	glow_intensity = 1.5

	# Mesh adjustments (para o modelo enemy1.glb)
	mesh_scale = 0.015  # Maior que zombies normais
	mesh_y_offset = 6.0

	super._ready()
