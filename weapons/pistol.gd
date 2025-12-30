extends BaseWeapon

# Pistol - Arma inicial do jogador
# Semi-automática, dano médio, fire rate médio

class_name Pistol

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
