@tool
extends EditorScenePostImport

func _post_import(scene):
	_generate_collisions(scene)
	return scene

func _generate_collisions(node: Node):
	if node is MeshInstance3D:
		# Создает статическое тело с выпуклой коллизией вокруг меша
		node.create_convex_collision(true, false)
	for child in node.get_children():
		_generate_collisions(child)
