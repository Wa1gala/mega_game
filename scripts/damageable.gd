extends Node3D

# Повесь на модель, по которой нужно стрелять.
# Цифры урона показываются на каждом попадании, без запаса здоровья.
# Если у модели нет коллайдера, скрипт соберёт хитбокс по её мешам.


func _ready() -> void:
	add_to_group("damageable")
	_ensure_hit_box()


func take_damage(amount: int) -> int:
	return amount


func _ensure_hit_box() -> void:
	if _has_collision_body():
		return
	var body := StaticBody3D.new()
	body.name = "HitBox"
	add_child(body)
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var collision := CollisionShape3D.new()
		collision.shape = mesh_instance.mesh.create_convex_shape()
		body.add_child(collision)
		collision.global_transform = mesh_instance.global_transform


func _has_collision_body() -> bool:
	var current: Node = self
	while current:
		if current is CollisionObject3D:
			return true
		current = current.get_parent()
	return false
