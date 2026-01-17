extends Control

# Configurações
const RADAR_RADIUS = 80.0    # Raio do radar em pixels
const SCAN_RADIUS = 40.0     # Alcance em metros no mundo
const SCALE_FACTOR = RADAR_RADIUS / SCAN_RADIUS

var player: Node3D = null

func _ready() -> void:
	# Posicionamento (será ajustado pelo HUD, mas definimos tamanho aqui)
	custom_minimum_size = Vector2(RADAR_RADIUS * 2, RADAR_RADIUS * 2)
	print("[Radar] _ready called. Size: ", custom_minimum_size)

func _process(delta: float) -> void:
	var shop_mgr = get_node_or_null("/root/ShopManager")
	if not shop_mgr or not shop_mgr.has_radar:
		visible = false
		return
	
	if not visible:
		print("[Radar] Showing radar!")
		visible = true
	queue_redraw()

func _draw() -> void:
	# 1. Desenha Fundo
	draw_circle(Vector2.ZERO, RADAR_RADIUS, Color(0, 0, 0, 0.5))
	draw_arc(Vector2.ZERO, RADAR_RADIUS, 0, TAU, 64, Color(0.2, 0.8, 0.3, 0.8), 2.0)
	
	# 2. Desenha Player (Centro)
	draw_circle(Vector2.ZERO, 3.0, Color(0.2, 1.0, 0.2)) # Verde brilhante
	
	# Busca player se necessário
	if not player:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
		else:
			return

	# 3. Desenha Inimigos
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	# Pega rotação do player para orientar o radar
	# No Godot 3D, rotação Y é em torno do eixo vertical.
	# Player olhando para -Z tem rotação 0 (ou PI, depende do modelo, mas assumindo standard)
	var player_rot = player.rotation.y
	var player_pos = player.global_position
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
			
		var delta_pos = enemy.global_position - player_pos
		
		# Converte para 2D (X, Z) -> (X, Y no radar)
		# Z no 3D vira Y no 2D
		var rel_vec = Vector2(delta_pos.x, delta_pos.z)
		
		# Rotaciona o vetor 'mundo' inversamente à rotação do player
		# Se player girou +90deg (esquerda), o mundo deve girar -90deg no radar
		var rot_vec = rel_vec.rotated(player_rot)
		
		# Ajusta escala
		var final_pos = rot_vec * SCALE_FACTOR
		
		# Verifica se está dentro do alcance
		var dist = final_pos.length()
		
		# Clampa na borda se estiver longe (opcional: ou não desenha)
		if dist > RADAR_RADIUS:
			# Opcional: mostrar na borda com fade ou simplesmente clamp
			final_pos = final_pos.normalized() * (RADAR_RADIUS - 2)
		
		# Identifica Boss ou Inimigo comum
		var is_boss = enemy.is_in_group("boss")
		var color = Color(1.0, 0.2, 0.2) if not is_boss else Color(1.0, 0.8, 0.2) # Vermelho ou Dourado
		var radius = 2.5 if not is_boss else 5.0
		
		draw_circle(final_pos, radius, color)
