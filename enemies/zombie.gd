extends BaseEnemy

# Zombie - Inimigo melee básico
# Segue o player e ataca em corpo a corpo

class_name Zombie

func _ready() -> void:
	# Stats específicas do zombie
	max_health = 50.0
	speed = 3.0
	damage = 10.0
	attack_range = 2.0
	attack_cooldown = 1.5

	# Chama o _ready() do pai
	super._ready()
