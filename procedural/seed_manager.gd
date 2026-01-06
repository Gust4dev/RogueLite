extends Node
class_name SeedManager

## SeedManager - Sistema de gerenciamento de seeds para geração procedural
## Permite reproduzir mapas, salvar seeds favoritos, e compartilhar seeds.
##
## Seeds podem ser numéricos ou strings convertidas para hash.

# === SIGNALS ===
signal seed_changed(new_seed: int, seed_string: String)
signal seed_validated(is_valid: bool, seed_value: int)
signal favorite_added(seed: int, name: String)
signal favorite_removed(seed: int)

# === CONFIGURAÇÃO ===
const MAX_SEED_VALUE: int = 2147483647  # Max int32
const MIN_SEED_VALUE: int = 0
const FAVORITES_SAVE_PATH: String = "user://favorite_seeds.json"
const HISTORY_MAX_SIZE: int = 20

# === ESTADO ===
var current_seed: int = 0
var current_seed_string: String = ""
var seed_history: Array[Dictionary] = []  # {seed: int, string: String, biome: String, date: String}
var favorite_seeds: Array[Dictionary] = []  # {seed: int, name: String, biome: String}

# === PREFIXOS PARA SEEDS ESPECIAIS ===
# Seeds que começam com esses prefixos têm comportamentos especiais
const SPECIAL_PREFIXES = {
	"debug_": true,   # Ativa modo debug
	"easy_": true,    # Menos obstáculos
	"hard_": true,    # Mais obstáculos
	"boss_": true     # Força boss arenas no centro
}


func _ready() -> void:
	_load_favorites()
	_generate_new_seed()


## Gera um novo seed aleatório
func generate_random_seed() -> int:
	randomize()  # Garante aleatoriedade baseada em tempo
	current_seed = randi()
	current_seed_string = str(current_seed)
	seed_changed.emit(current_seed, current_seed_string)
	return current_seed


## Define um seed a partir de um valor numérico
func set_seed_from_number(seed_value: int) -> int:
	current_seed = clampi(seed_value, MIN_SEED_VALUE, MAX_SEED_VALUE)
	current_seed_string = str(current_seed)
	seed_changed.emit(current_seed, current_seed_string)
	return current_seed


## Define um seed a partir de uma string (converte para hash)
func set_seed_from_string(seed_string: String) -> int:
	current_seed_string = seed_string.strip_edges()

	# Se for apenas números, usa diretamente
	if current_seed_string.is_valid_int():
		current_seed = int(current_seed_string)
	else:
		# Converte string para hash numérico
		current_seed = _string_to_seed(current_seed_string)

	current_seed = clampi(current_seed, MIN_SEED_VALUE, MAX_SEED_VALUE)
	seed_changed.emit(current_seed, current_seed_string)
	return current_seed


## Converte uma string para um seed numérico consistente
func _string_to_seed(text: String) -> int:
	# Usa hash da string para gerar seed consistente
	var hash_value = text.hash()

	# Garante que é positivo
	if hash_value < 0:
		hash_value = -hash_value

	return hash_value % MAX_SEED_VALUE


## Valida se um seed input é válido
func validate_seed_input(input: String) -> Dictionary:
	var result = {
		"valid": false,
		"seed": 0,
		"message": "",
		"is_special": false,
		"special_type": ""
	}

	if input.is_empty():
		result.message = "Seed vazio"
		return result

	var clean_input = input.strip_edges()

	# Verifica prefixos especiais
	for prefix in SPECIAL_PREFIXES:
		if clean_input.begins_with(prefix):
			result.is_special = true
			result.special_type = prefix.trim_suffix("_")

	# Tenta converter
	if clean_input.is_valid_int():
		var num = int(clean_input)
		if num >= MIN_SEED_VALUE and num <= MAX_SEED_VALUE:
			result.valid = true
			result.seed = num
			result.message = "Seed numérico válido"
		else:
			result.message = "Número fora do range (0 - " + str(MAX_SEED_VALUE) + ")"
	else:
		# String seed - sempre válido
		result.valid = true
		result.seed = _string_to_seed(clean_input)
		result.message = "Seed por texto: " + str(result.seed)

	seed_validated.emit(result.valid, result.seed)
	return result


## Retorna o seed atual
func get_current_seed() -> int:
	return current_seed


## Retorna a representação string do seed atual
func get_seed_string() -> String:
	return current_seed_string


## Retorna seed formatado para display (com separadores)
func get_formatted_seed() -> String:
	var seed_str = str(current_seed)
	var formatted = ""

	# Adiciona separadores a cada 3 dígitos (da direita para esquerda)
	var count = 0
	for i in range(seed_str.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			formatted = "." + formatted
		formatted = seed_str[i] + formatted
		count += 1

	return formatted


## Adiciona seed atual aos favoritos
func add_to_favorites(custom_name: String = "", biome_name: String = "") -> bool:
	# Verifica se já existe
	for fav in favorite_seeds:
		if fav.seed == current_seed:
			return false

	var name = custom_name if not custom_name.is_empty() else "Seed " + str(current_seed)

	favorite_seeds.append({
		"seed": current_seed,
		"string": current_seed_string,
		"name": name,
		"biome": biome_name,
		"date": Time.get_datetime_string_from_system()
	})

	_save_favorites()
	favorite_added.emit(current_seed, name)
	return true


## Remove um seed dos favoritos
func remove_from_favorites(seed_value: int) -> bool:
	for i in range(favorite_seeds.size()):
		if favorite_seeds[i].seed == seed_value:
			favorite_seeds.remove_at(i)
			_save_favorites()
			favorite_removed.emit(seed_value)
			return true
	return false


## Verifica se seed está nos favoritos
func is_favorite(seed_value: int) -> bool:
	for fav in favorite_seeds:
		if fav.seed == seed_value:
			return true
	return false


## Retorna lista de favoritos
func get_favorites() -> Array[Dictionary]:
	return favorite_seeds.duplicate()


## Adiciona seed ao histórico
func add_to_history(biome_name: String = "") -> void:
	# Remove duplicatas antigas
	seed_history = seed_history.filter(func(entry): return entry.seed != current_seed)

	# Adiciona no início
	seed_history.insert(0, {
		"seed": current_seed,
		"string": current_seed_string,
		"biome": biome_name,
		"date": Time.get_datetime_string_from_system()
	})

	# Limita tamanho
	if seed_history.size() > HISTORY_MAX_SIZE:
		seed_history.resize(HISTORY_MAX_SIZE)


## Retorna histórico de seeds
func get_history() -> Array[Dictionary]:
	return seed_history.duplicate()


## Limpa histórico
func clear_history() -> void:
	seed_history.clear()


## Gera seed com características especiais baseadas em modificadores
func generate_special_seed(modifiers: Dictionary = {}) -> int:
	randomize()
	var base = randi()

	# Aplica modificadores ao seed
	if modifiers.get("easy", false):
		base = base % 1000000  # Seeds menores tendem a ter menos obstáculos
	elif modifiers.get("hard", false):
		base = base | 0x40000000  # Força bit alto

	if modifiers.get("specific_biome", -1) >= 0:
		# Incorpora bioma no seed para consistência
		base = (base & 0xFFFFFFF0) | (modifiers.specific_biome & 0xF)

	current_seed = clampi(base, MIN_SEED_VALUE, MAX_SEED_VALUE)
	current_seed_string = str(current_seed)
	seed_changed.emit(current_seed, current_seed_string)
	return current_seed


## Gera seed baseado na data atual (seed do dia)
func generate_daily_seed() -> int:
	var date = Time.get_date_dict_from_system()
	var date_string = "%04d%02d%02d" % [date.year, date.month, date.day]
	return set_seed_from_string(date_string)


## Gera seed baseado na hora atual (seed da hora)
func generate_hourly_seed() -> int:
	var datetime = Time.get_datetime_dict_from_system()
	var datetime_string = "%04d%02d%02d%02d" % [datetime.year, datetime.month, datetime.day, datetime.hour]
	return set_seed_from_string(datetime_string)


## Copia seed para clipboard
func copy_seed_to_clipboard() -> void:
	DisplayServer.clipboard_set(current_seed_string)


## Cola seed do clipboard
func paste_seed_from_clipboard() -> int:
	var clipboard = DisplayServer.clipboard_get()
	if not clipboard.is_empty():
		return set_seed_from_string(clipboard)
	return current_seed


## Salva favoritos em arquivo
func _save_favorites() -> void:
	var file = FileAccess.open(FAVORITES_SAVE_PATH, FileAccess.WRITE)
	if file:
		var data = JSON.stringify(favorite_seeds)
		file.store_string(data)
		file.close()


## Carrega favoritos de arquivo
func _load_favorites() -> void:
	if FileAccess.file_exists(FAVORITES_SAVE_PATH):
		var file = FileAccess.open(FAVORITES_SAVE_PATH, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()

			var json = JSON.new()
			var error = json.parse(json_string)
			if error == OK:
				var data = json.data
				if data is Array:
					favorite_seeds.clear()
					for entry in data:
						if entry is Dictionary:
							favorite_seeds.append(entry)


## Gera um novo seed interno (chamado no _ready)
func _generate_new_seed() -> void:
	generate_random_seed()


## Retorna informações do seed para UI
func get_seed_info() -> Dictionary:
	return {
		"seed": current_seed,
		"string": current_seed_string,
		"formatted": get_formatted_seed(),
		"is_favorite": is_favorite(current_seed),
		"is_daily": _is_daily_seed(),
		"is_numeric": current_seed_string.is_valid_int()
	}


## Verifica se o seed atual é o seed do dia
func _is_daily_seed() -> bool:
	var date = Time.get_date_dict_from_system()
	var date_string = "%04d%02d%02d" % [date.year, date.month, date.day]
	var daily = _string_to_seed(date_string)
	return current_seed == daily


## Gera seeds relacionados (para sugestões)
func get_related_seeds(count: int = 5) -> Array[int]:
	var related: Array[int] = []
	var base = current_seed

	for i in range(count):
		var variant = (base + (i + 1) * 12345) % MAX_SEED_VALUE
		related.append(variant)

	return related


## Exporta seed em formato compartilhável
func export_seed() -> String:
	var data = {
		"s": current_seed,
		"t": current_seed_string if not current_seed_string.is_valid_int() else ""
	}
	return JSON.stringify(data).replace(" ", "")


## Importa seed de formato compartilhável
func import_seed(export_string: String) -> bool:
	var json = JSON.new()
	var error = json.parse(export_string)
	if error == OK:
		var data = json.data
		if data is Dictionary:
			if data.has("s"):
				var seed_val = int(data.s)
				var seed_str = data.get("t", str(seed_val))
				current_seed = seed_val
				current_seed_string = seed_str if not seed_str.is_empty() else str(seed_val)
				seed_changed.emit(current_seed, current_seed_string)
				return true
	return false


## Debug: imprime informações do seed
func debug_print() -> void:
	print("\n=== SEED INFO ===")
	print("  Numérico: ", current_seed)
	print("  String: ", current_seed_string)
	print("  Formatado: ", get_formatted_seed())
	print("  É favorito: ", is_favorite(current_seed))
	print("  É seed diário: ", _is_daily_seed())
	print("  Histórico: ", seed_history.size(), " entries")
	print("  Favoritos: ", favorite_seeds.size(), " entries")
	print("==================\n")
