extends Node3D

# Merchant - NPC Goblin que vende upgrades
# Abre menu de loja quando player interage com E

signal shop_requested()

@export var interaction_range: float = 3.5

var player: Node3D = null
var is_player_near: bool = false
var shop_menu: CanvasLayer = null
var interact_label: Label3D = null
var goblin_model: Node3D = null


func _ready() -> void:
	_setup_model()
	_setup_collision()
	_setup_interact_label()
	
	add_to_group("merchant")
	
	# Busca player inicial se já existir
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	
	for child in node.get_children():
		var found = _find_animation_player(child)
		if found:
			return found
	return null


func _setup_model() -> void:
	"""Carrega modelo do goblin"""
	var model_path = "res://assets/merchants/goblin_a_traveling_merchant.glb"
	
	if ResourceLoader.exists(model_path):
		var scene = load(model_path)
		if scene:
			goblin_model = scene.instantiate()
			goblin_model.name = "GoblinModel"
			
			# Debug: mostra estrutura do modelo
			print("[Merchant] Modelo carregado: ", goblin_model.name)
			print("[Merchant] Filhos do modelo: ", goblin_model.get_child_count())
			for child in goblin_model.get_children():
				print("[Merchant]   - ", child.name, " (", child.get_class(), ")")
			
			# Escala grande para garantir visibilidade
			goblin_model.scale = Vector3(1.0, 1.0, 1.0)
			
			# Rotação de 180 graus porque o modelo olha para +Z
			goblin_model.rotation_degrees.y = 180
			
			# Posição (levemente acima do chão se estiver afundando)
			goblin_model.position.y = 0.3
			
			add_child(goblin_model)
			print("[Merchant] Modelo adicionado à cena!")
			
			# Procura e toca animação Idle
			var anim_player = _find_animation_player(goblin_model)
			if anim_player:
				var anim_name = "Armature|Idle"
				if anim_player.has_animation(anim_name):
					anim_player.play(anim_name)
					# Define loop (se não estiver configurado na importação)
					var anim = anim_player.get_animation(anim_name)
					anim.loop_mode = Animation.LOOP_LINEAR
					print("[Merchant] Tocando animação: ", anim_name)
				else:
					print("[Merchant] Animação não encontrada: ", anim_name)
			else:
				print("[Merchant] AnimationPlayer não encontrado no modelo")
		else:
			print("[Merchant] ERRO: Falha ao carregar cena do modelo")
			_create_fallback_visual()
	else:
		print("[Merchant] ERRO: Modelo não encontrado em: ", model_path)
		_create_fallback_visual()


func _create_fallback_visual() -> void:
	"""Visual de fallback caso modelo não carregue"""
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "FallbackMesh"
	
	var capsule = CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.0
	mesh_instance.mesh = capsule
	mesh_instance.position.y = 0.5
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.6, 0.2)  # Verde goblin
	mesh_instance.material_override = material
	
	add_child(mesh_instance)


func _setup_collision() -> void:
	"""Configura área de interação"""
	var area = Area3D.new()
	area.name = "InteractionArea"
	add_child(area)
	
	var collision = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape = SphereShape3D.new()
	shape.radius = interaction_range
	collision.shape = shape
	area.add_child(collision)
	
	area.collision_layer = 0
	area.collision_mask = 1  # Só detecta player
	
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)


func _setup_interact_label() -> void:
	"""Cria label 3D flutuante com tecla de interação"""
	interact_label = Label3D.new()
	interact_label.name = "InteractLabel"
	interact_label.text = "🛒 [E] Loja"
	interact_label.font_size = 64
	interact_label.position.y = 2.2  # Acima do goblin
	interact_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	interact_label.modulate = Color(1.0, 0.9, 0.3)
	interact_label.outline_modulate = Color(0, 0, 0)
	interact_label.outline_size = 8
	interact_label.visible = false  # Só aparece quando player está perto
	
	add_child(interact_label)


func _process(delta: float) -> void:
	# Anima o label flutuante
	if interact_label and interact_label.visible:
		interact_label.position.y = 2.2 + sin(Time.get_ticks_msec() * 0.003) * 0.1
	
	# Faz o mercador olhar para o jogador
	if player:
		var target_pos = player.global_position
		target_pos.y = global_position.y # Mantém o nível dos olhos (sem tilt)
		look_at(target_pos, Vector3.UP) 



func _input(event: InputEvent) -> void:
	if is_player_near and event.is_action_pressed("interact"):
		_open_shop()
	
	# Fallback para tecla E direta caso input não esteja configurado
	if is_player_near and event is InputEventKey:
		var key_event = event as InputEventKey
		if key_event.pressed and key_event.keycode == KEY_E:
			_open_shop()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player = body
		is_player_near = true
		if interact_label:
			interact_label.visible = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		is_player_near = false
		if interact_label:
			interact_label.visible = false
		_close_shop()


func _open_shop() -> void:
	"""Abre o menu da loja"""
	if shop_menu:
		return  # Já está aberto
	
	# Verifica se ShopManager existe
	var shop_mgr = get_node_or_null("/root/ShopManager")
	if shop_mgr and not shop_mgr.can_purchase():
		print("[Merchant] Limite de compras atingido!")
		return
	
	shop_menu = _create_shop_menu()
	get_tree().current_scene.add_child(shop_menu)
	
	# Pausa o jogo e libera mouse
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	shop_requested.emit()


func _close_shop() -> void:
	"""Fecha o menu da loja"""
	if shop_menu:
		shop_menu.queue_free()
		shop_menu = null
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _create_shop_menu() -> CanvasLayer:
	"""Cria o menu de loja"""
	var root = CanvasLayer.new()
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Fundo escuro
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.7)
	root.add_child(bg)
	
	# Container central
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	
	# Painel
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(650, 550)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.12, 0.08, 0.95)
	panel_style.border_color = Color(0.4, 0.6, 0.3)
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)
	
	# Margin
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 25)
	margin.add_theme_constant_override("margin_right", 25)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	
	# VBox principal
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)
	
	# Título
	var title = Label.new()
	title.text = "🛒 LOJA DO GOBLIN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.4, 0.8, 0.3))
	vbox.add_child(title)
	
	# Info de dinheiro e compras
	var info_row = HBoxContainer.new()
	info_row.alignment = BoxContainer.ALIGNMENT_CENTER
	info_row.add_theme_constant_override("separation", 40)
	vbox.add_child(info_row)
	
	var money_label = Label.new()
	money_label.name = "MoneyLabel"
	var money_mgr = get_node_or_null("/root/MoneyManager")
	var shop_mgr = get_node_or_null("/root/ShopManager")
	money_label.text = "🪙 %d" % (money_mgr.get_money() if money_mgr else 0)
	money_label.add_theme_font_size_override("font_size", 22)
	money_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	info_row.add_child(money_label)
	
	var purchases_label = Label.new()
	purchases_label.name = "PurchasesLabel"
	purchases_label.text = "Compras: %d/%d" % [shop_mgr.purchases_this_map if shop_mgr else 0, shop_mgr.MAX_PURCHASES_PER_MAP if shop_mgr else 2]
	purchases_label.add_theme_font_size_override("font_size", 16)
	purchases_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	info_row.add_child(purchases_label)
	
	# Separador
	var sep = HSeparator.new()
	vbox.add_child(sep)
	
	# ScrollContainer para itens
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	
	var items_vbox = VBoxContainer.new()
	items_vbox.name = "ItemsVBox"
	items_vbox.add_theme_constant_override("separation", 8)
	items_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(items_vbox)
	
	# Popula itens
	_populate_shop_items(items_vbox, root)
	
	# Separador antes do botão
	var sep2 = HSeparator.new()
	vbox.add_child(sep2)
	
	# Botão fechar
	var close_btn = Button.new()
	close_btn.text = "✖ FECHAR (ESC)"
	close_btn.custom_minimum_size = Vector2(180, 45)
	close_btn.pressed.connect(_close_shop)
	
	var btn_container = CenterContainer.new()
	btn_container.add_child(close_btn)
	vbox.add_child(btn_container)
	
	return root


func _create_item_row(item: Dictionary, menu_root: Node) -> PanelContainer:
	"""Cria linha de item na loja"""
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.15, 0.1, 0.8)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 15)
	margin.add_child(row)
	
	# Ícone
	var icon = Label.new()
	icon.text = item.icon
	icon.add_theme_font_size_override("font_size", 36)
	icon.custom_minimum_size = Vector2(50, 0)
	row.add_child(icon)
	
	# Info
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info_vbox)
	
	var name_label = Label.new()
	name_label.text = item.name
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	info_vbox.add_child(name_label)
	
	var desc_label = Label.new()
	desc_label.text = item.description
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.6))
	info_vbox.add_child(desc_label)
	
	# Preço
	var price_label = Label.new()
	price_label.text = "🪙 %d" % item.price
	price_label.add_theme_font_size_override("font_size", 18)
	var money_mgr2 = get_node_or_null("/root/MoneyManager")
	var can_afford = money_mgr2.can_afford(item.price) if money_mgr2 else false
	price_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4) if can_afford else Color(1.0, 0.4, 0.4))
	price_label.custom_minimum_size = Vector2(80, 0)
	row.add_child(price_label)
	
	# Botão comprar
	var shop_mgr3 = get_node_or_null("/root/ShopManager")
	var buy_btn = Button.new()
	buy_btn.text = "COMPRAR"
	buy_btn.custom_minimum_size = Vector2(110, 40)
	buy_btn.disabled = not can_afford or (shop_mgr3 and not shop_mgr3.can_purchase())
	
	buy_btn.pressed.connect(func():
		var s_mgr = get_node_or_null("/root/ShopManager")
		var m_mgr = get_node_or_null("/root/MoneyManager")
		if s_mgr and s_mgr.purchase_item(item.id):
			# Atualiza toda a UI (preços, saldos, botões)
			_refresh_shop_ui(menu_root)
			
			# Fecha se atingiu limite
			if not s_mgr.can_purchase():
				_close_shop()
				_disappear()
	)
	row.add_child(buy_btn)
	
	return panel


func _disappear() -> void:
	"""Mercador desaparece após limite de compras"""
	print("[Merchant] Até logo! Nos vemos no próximo mapa.")
	
	if interact_label:
		interact_label.visible = false
	
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.5).set_ease(Tween.EASE_IN)
	await tween.finished
	
	visible = false
	set_process(false)


func _populate_shop_items(container: VBoxContainer, menu_root: Node) -> void:
	"""Popula a lista de itens"""
	# Limpa itens existentes
	for child in container.get_children():
		child.queue_free()
		
	var shop_mgr = get_node_or_null("/root/ShopManager")
	var items = shop_mgr.get_available_items() if shop_mgr else []
	
	for item in items:
		var item_row = _create_item_row(item, menu_root)
		container.add_child(item_row)


func _refresh_shop_ui(menu_root: Node) -> void:
	"""Atualiza toda a UI da loja"""
	var shop_mgr = get_node_or_null("/root/ShopManager")
	var money_mgr = get_node_or_null("/root/MoneyManager")
	
	# Atualiza labels
	var money_lbl = menu_root.find_child("MoneyLabel", true, false)
	var purch_lbl = menu_root.find_child("PurchasesLabel", true, false)
	
	if money_lbl and money_mgr:
		money_lbl.text = "🪙 %d" % money_mgr.get_money()
	if purch_lbl and shop_mgr:
		purch_lbl.text = "Compras: %d/%d" % [shop_mgr.purchases_this_map, shop_mgr.MAX_PURCHASES_PER_MAP]
	
	# Atualiza itens (reconstroi a lista para atualizar preços/cores)
	var items_vbox = menu_root.find_child("ItemsVBox", true, false)
	if items_vbox:
		_populate_shop_items(items_vbox, menu_root)


func reappear() -> void:
	"""Reaparece para novo mapa"""
	visible = true
	scale = Vector3.ONE
	set_process(true)
	var shop_mgr = get_node_or_null("/root/ShopManager")
	if shop_mgr:
		shop_mgr.reset_for_new_map()
