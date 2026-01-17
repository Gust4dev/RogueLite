extends Node

func _ready() -> void:
	print("--- MODEL INSPECTION START ---")
	var model_path = "res://assets/weapons/modern-weapon/PumpySMGglb.glb"
	if not FileAccess.file_exists(model_path):
		print("ERROR: File not found at ", model_path)
		get_tree().quit()
		return
		
	var scene = load(model_path).instantiate()
	add_child(scene)
	print_tree_recursive(scene, "")
	print("--- MODEL INSPECTION END ---")
	get_tree().quit()

func print_tree_recursive(node: Node, prefix: String) -> void:
	print(prefix + node.name + " (" + node.get_class() + ")")
	for child in node.get_children():
		print_tree_recursive(child, prefix + "  |--")
