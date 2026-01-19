@tool
extends Node3D

# ============================================
# WEAPON PREVIEW TOOL (v2.1)
# ============================================

class_name WeaponPreviewTool

# === CONFIGURAÇÕES DE VIEWMODEL (ROOT DA ARMA) ===
@export_group("Viewmodel (Root)")
@export var weapon_position: Vector3 = Vector3(0.3, -0.76, -0.17):
	set(value):
		weapon_position = value
		_update_weapon_transform()

@export var weapon_rotation: Vector3 = Vector3(0, 180, 0):
	set(value):
		weapon_rotation = value
		_update_weapon_transform()

@export var weapon_scale: Vector3 = Vector3(1, 1, 1):
	set(value):
		weapon_scale = value
		_update_weapon_transform()

@export var save_weapon_transform: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_save_viewmodel_settings()
			save_weapon_transform = false

# === SELEÇÃO DE ARMA ===
@export_group("Weapon Selection")
@export_enum("Pistol", "Revolver", "SMG", "Shotgun", "Sniper", "LMG") var selected_weapon: String = "Pistol":
	set(value):
		selected_weapon = value
		if Engine.is_editor_hint():
			_load_selected_weapon()

@export var reload_weapon: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_load_selected_weapon()
			reload_weapon = false

# Mapeamento de nomes para caminhos de cena
var weapon_scenes = {
	"Pistol": "res://weapons/pistol/pistol.tscn",
	"Revolver": "res://weapons/revolver/revolver.tscn",
	"SMG": "res://weapons/smg/smg.tscn",
	"Shotgun": "res://weapons/shotgun/shotgun.tscn",
	"Sniper": "res://weapons/sniper/sniper.tscn",
	"LMG": "res://weapons/lmg/lmg.tscn"
}

# === DEBUG CAM ===
@export_group("Debug Camera")
@export var show_camera_preview: bool = true:
	set(value):
		show_camera_preview = value
		_toggle_preview_camera()

@export var preview_fov: float = 90.0:
	set(value):
		preview_fov = value
		if _preview_camera:
			_preview_camera.fov = value

# === MUZZLE FLASH (LOCAL À ARMA) ===
@export_group("Muzzle Flash (Local)")
@export var muzzle_flash_position: Vector3 = Vector3(0, 0, -0.5):
	set(value):
		muzzle_flash_position = value
		_update_muzzle_flash_transform()

@export var muzzle_flash_rotation: Vector3 = Vector3(0, 0, 0):
	set(value):
		muzzle_flash_rotation = value
		_update_muzzle_flash_transform()

@export var muzzle_flash_scale: Vector3 = Vector3(1, 1, 1):
	set(value):
		muzzle_flash_scale = value
		_update_muzzle_flash_transform()

@export var show_muzzle_flash_preview: bool = true:
	set(value):
		show_muzzle_flash_preview = value
		if _muzzle_flash_preview:
			_muzzle_flash_preview.visible = value

@export var save_muzzle_flash: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_save_muzzle_flash_transform()
			save_muzzle_flash = false

# Referências internas
var _weapon_instance: Node3D = null
var _preview_camera: Camera3D = null
var _muzzle_flash_preview: Node3D = null


func _ready() -> void:
	if Engine.is_editor_hint():
		# Pequeno delay para garantir que a árvore está estável
		call_deferred("_setup_editor_preview")


func _setup_editor_preview() -> void:
	# Primeiro tenta achar a câmera existente na cena
	_preview_camera = get_node_or_null("PreviewCamera")
	if not _preview_camera:
		_preview_camera = get_node_or_null("PreviewCam")
	
	if not _preview_camera and show_camera_preview:
		_create_preview_camera()
	
	if _preview_camera:
		_preview_camera.fov = preview_fov
	
	_load_selected_weapon()


func _load_selected_weapon() -> void:
	"""Carrega a cena da arma"""
	# Limpa instâncias antigas de armas (nós que não são a câmera nem o preview do muzzle se ele existir solto)
	for child in get_children():
		if child == _preview_camera: continue
		if child.name == "PreviewMuzzle": continue
		# Se o nome for o de uma arma conhecida ou tiver script de arma, remove
		if child.has_method("shoot") or child.name in weapon_scenes.keys() or child.name == "Sniper":
			child.free()
	
	_weapon_instance = null
	
	var path = weapon_scenes.get(selected_weapon, "")
	if not ResourceLoader.exists(path):
		printerr("[Preview] Cena não encontrada: ", path)
		return
		
	var scene = load(path)
	if scene:
		_weapon_instance = scene.instantiate()
		_weapon_instance.name = selected_weapon # Nome amigável
		add_child(_weapon_instance)
		
		# Carrega configurações salvas no script BaseWeapon da instância
		var view_pos = _weapon_instance.get("viewmodel_position")
		if view_pos != null:
			# Bloqueia setters temporariamente se necessário ou apenas aplica
			weapon_position = view_pos
			weapon_rotation = _weapon_instance.get("viewmodel_rotation")
			weapon_scale = _weapon_instance.get("viewmodel_scale")
			print("[Preview] Viewmodel configs carregadas de ", selected_weapon)
		
		# Procura MuzzleFlash existente para pegar configs
		var muzzle = _weapon_instance.get_node_or_null("MuzzleFlash")
		if muzzle:
			muzzle_flash_position = muzzle.position
			muzzle_flash_rotation = muzzle.rotation_degrees
			muzzle_flash_scale = muzzle.scale
			print("[Preview] Muzzle configs carregadas.")
		
		# Cria ou atualiza muzzle preview como FILHO da arma
		_create_muzzle_flash_preview()
		
		_update_weapon_transform()


func _create_preview_camera() -> void:
	if _preview_camera: return
	_preview_camera = Camera3D.new()
	_preview_camera.name = "PreviewCamera"
	_preview_camera.fov = preview_fov
	_preview_camera.near = 0.01
	add_child(_preview_camera)
	_preview_camera.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else self


func _toggle_preview_camera() -> void:
	if show_camera_preview:
		_create_preview_camera()
	elif _preview_camera:
		_preview_camera.queue_free()
		_preview_camera = null


func _create_muzzle_flash_preview() -> void:
	if not _weapon_instance: return
	
	# Se já existir um preview antigo na arma, remove
	var old = _weapon_instance.get_node_or_null("PreviewMuzzle")
	if old: old.free()
	
	_muzzle_flash_preview = Node3D.new()
	_muzzle_flash_preview.name = "PreviewMuzzle"
	
	# Indicador visual
	var mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1
	mesh.mesh = sphere
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.ORANGE
	mat.emission_enabled = true
	mat.emission = Color.ORANGE_RED
	mat.emission_energy_multiplier = 4.0
	mesh.material_override = mat
	_muzzle_flash_preview.add_child(mesh)
	
	# Adiciona como FILHO DA ARMA
	_weapon_instance.add_child(_muzzle_flash_preview)
	_muzzle_flash_preview.visible = show_muzzle_flash_preview
	
	_update_muzzle_flash_transform()


func _update_weapon_transform() -> void:
	if _weapon_instance:
		_weapon_instance.position = weapon_position
		_weapon_instance.rotation_degrees = weapon_rotation
		_weapon_instance.scale = weapon_scale


func _update_muzzle_flash_transform() -> void:
	# Atualiza o indicador (bolinha laranja)
	if _muzzle_flash_preview:
		_muzzle_flash_preview.position = muzzle_flash_position
		_muzzle_flash_preview.rotation_degrees = muzzle_flash_rotation
		_muzzle_flash_preview.scale = muzzle_flash_scale
	
	# ATUALIZA O NÓ REAL TAMBÉM (para feedback imediato)
	if _weapon_instance:
		var real_muzzle = _weapon_instance.get_node_or_null("MuzzleFlash")
		if real_muzzle:
			real_muzzle.position = muzzle_flash_position
			real_muzzle.rotation_degrees = muzzle_flash_rotation
			real_muzzle.scale = muzzle_flash_scale


# === SALVAMENTO ===

func _save_viewmodel_settings() -> void:
	var tscn_path = weapon_scenes.get(selected_weapon, "")
	var abs_path = ProjectSettings.globalize_path(tscn_path)
	
	var content = FileAccess.get_file_as_string(abs_path)
	if content.is_empty(): return
		
	var s_pos = "viewmodel_position = Vector3(%f, %f, %f)" % [weapon_position.x, weapon_position.y, weapon_position.z]
	var s_rot = "viewmodel_rotation = Vector3(%f, %f, %f)" % [weapon_rotation.x, weapon_rotation.y, weapon_rotation.z]
	var s_scl = "viewmodel_scale = Vector3(%f, %f, %f)" % [weapon_scale.x, weapon_scale.y, weapon_scale.z]
	
	content = _update_property_in_tscn(content, "viewmodel_position", s_pos)
	content = _update_property_in_tscn(content, "viewmodel_rotation", s_rot)
	content = _update_property_in_tscn(content, "viewmodel_scale", s_scl)
	
	var file = FileAccess.open(abs_path, FileAccess.WRITE)
	file.store_string(content)
	file.close()
	print("[Preview] Viewmodel settings salvas em: ", tscn_path)


func _save_muzzle_flash_transform() -> void:
	var tscn_path = weapon_scenes.get(selected_weapon, "")
	var abs_path = ProjectSettings.globalize_path(tscn_path)
	
	var file = FileAccess.open(abs_path, FileAccess.READ)
	var lines = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()
	
	var rot_rad = muzzle_flash_rotation * (PI / 180.0)
	var basis = Basis.from_euler(rot_rad).scaled(muzzle_flash_scale)
	
	var s_transform = "transform = Transform3D(%f, %f, %f, %f, %f, %f, %f, %f, %f, %f, %f, %f)" % [
		basis.x.x, basis.x.y, basis.x.z,
		basis.y.x, basis.y.y, basis.y.z,
		basis.z.x, basis.z.y, basis.z.z,
		muzzle_flash_position.x, muzzle_flash_position.y, muzzle_flash_position.z
	]
	
	var found_node = false
	var modified = false
	
	for i in range(lines.size()):
		if '[node name="MuzzleFlash"' in lines[i]:
			found_node = true
			continue
			
		if found_node:
			if lines[i].strip_edges().begins_with("transform ="):
				lines[i] = s_transform
				modified = true
				break
			elif lines[i].begins_with("[node") or lines[i].begins_with("[ext_resource"):
				lines.insert(i, s_transform)
				modified = true
				break
	
	if not found_node:
		printerr("[Preview] Nó MuzzleFlash não encontrado.")
		return
		
	file = FileAccess.open(abs_path, FileAccess.WRITE)
	for line in lines:
		file.store_line(line)
	file.close()
	print("[Preview] MuzzleFlash transform salvo em: ", tscn_path)


func _update_property_in_tscn(content: String, prop_name: String, new_line: String) -> String:
	var regex = RegEx.new()
	regex.compile(prop_name + "\\s*=\\s*Vector3\\([^)]+\\)")
	
	if regex.search(content):
		return regex.sub(content, new_line)
	else:
		var script_pos = content.find("script =")
		if script_pos != -1:
			var end_line = content.find("\n", script_pos)
			return content.insert(end_line + 1, new_line + "\n")
		var first_break = content.find("\n")
		return content.insert(first_break + 1, new_line + "\n")
