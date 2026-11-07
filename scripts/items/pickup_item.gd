## Выброшенный в мир предмет.
## RigidBody3D с простой коллизией-коробкой, чтобы папка падала на пол.
## Подбирается на E (цель взаимодействия выбирает InventoryManager, группа "interactable").
class_name PickupItem
extends RigidBody3D

const FALL_LIMIT_Y := -20.0   # ниже этой высоты предмет считается провалившимся

## Радиус взаимодействия (по горизонтали от игрока до предмета).
var interact_radius := 1.8

@export var item_data: ItemData

const CELL_METERS := 0.3
const SPRITE_BOX_HEIGHT := 0.1

var _picked := false
var _is_sprite := false
var _sprite_size := Vector2(0.3, 0.3)


func _ready() -> void:
	continuous_cd = true
	_setup_visual()
	_setup_collision()
	add_to_group("interactable")


func _physics_process(_delta: float) -> void:
	# Предмет мог провалиться сквозь пол — возвращаем к игроку, а не теряем.
	if global_position.y < FALL_LIMIT_Y:
		var player := get_tree().get_first_node_in_group("player") as Node3D
		linear_velocity = Vector3.ZERO
		global_position = (player.global_position if player != null else Vector3.ZERO) + Vector3.UP * 1.0


func _setup_visual() -> void:
	if item_data == null:
		return
	if item_data.world_mesh_scene != null:
		var mesh := item_data.world_mesh_scene.instantiate() as Node3D
		add_child(mesh)
		if item_data.world_scale != 1.0 and mesh != null:
			# Модель из рук игрока бывает в другом масштабе: уменьшаем и центрируем по габаритам.
			mesh.scale = Vector3.ONE * item_data.world_scale
			var box := _mesh_bounds(mesh, mesh)
			if box.size != Vector3.ZERO:
				mesh.position = -(box.get_center() * item_data.world_scale)
	elif item_data.icon != null:
		# Нет 3D-модели — показываем PNG спрайтом, повёрнутым к камере. Тело не крутится.
		_is_sprite = true
		axis_lock_angular_x = true
		axis_lock_angular_y = true
		axis_lock_angular_z = true
		var sprite := Sprite3D.new()
		sprite.texture = item_data.icon
		# Размер в мире — по размеру предмета в сетке (ячейка = 0.3 м), пропорции как у PNG.
		var width := float(maxi(item_data.grid_size.x, 1)) * CELL_METERS
		sprite.pixel_size = width / float(item_data.icon.get_width())
		_sprite_size = Vector2(width, float(item_data.icon.get_height()) * sprite.pixel_size)
		# Спрайт стоит на коробке-коллизии, а не утопает в полу.
		sprite.position.y = _sprite_size.y * 0.5 - SPRITE_BOX_HEIGHT * 0.5
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
		sprite.shaded = false
		add_child(sprite)
	else:
		# Ни модели, ни иконки (например, рюкзак): простая коробка-заглушка.
		var box_mesh := BoxMesh.new()
		box_mesh.size = item_data.pickup_size if item_data.pickup_size != Vector3.ZERO else Vector3(0.3, 0.3, 0.3)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.22, 0.3, 0.22)
		box_mesh.material = mat
		var mi := MeshInstance3D.new()
		mi.mesh = box_mesh
		add_child(mi)


## Габариты всех мешей внутри node в системе координат root.
func _mesh_bounds(node: Node, root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var to_root := root.global_transform.affine_inverse() * mi.global_transform \
				if root.is_inside_tree() else mi.transform
		result = to_root * mi.get_aabb()
		first = false
	for child in node.get_children():
		var sub := _mesh_bounds(child, root)
		if sub.size == Vector3.ZERO:
			continue
		result = sub if first else result.merge(sub)
		first = false
	return result


func _setup_collision() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(_sprite_size.x, SPRITE_BOX_HEIGHT, minf(_sprite_size.x, 0.2)) if _is_sprite else Vector3(0.45, 0.08, 0.3)
	if item_data != null and item_data.pickup_size != Vector3.ZERO:
		box.size = item_data.pickup_size
	shape.shape = box
	add_child(shape)


func focus_point() -> Vector3:
	return global_position + Vector3(0, _sprite_size.y * 0.5 if _is_sprite else 0.1, 0)


func can_interact() -> bool:
	return not _picked and item_data != null


func prompt_info() -> Dictionary:
	return {"verb": "Подобрать", "name": item_data.name if item_data != null else "", "warn": false}


func set_focused(_focused: bool) -> void:
	pass


func interact() -> void:
	if _picked or item_data == null:
		return
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		request_pickup.rpc_id(1)
		return
	if InventoryManager.add_to_player(item_data):
		_picked = true
		remove_from_group("interactable")
		queue_free()


@rpc("any_peer", "call_local", "reliable")
func request_pickup() -> void:
	if not multiplayer.is_server() or _picked or item_data == null:
		return
	_picked = true
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 0:
		sender = multiplayer.get_unique_id()
	if sender == multiplayer.get_unique_id():
		InventoryManager.grant_item(item_data.resource_path)
	else:
		InventoryManager.grant_item.rpc_id(sender, item_data.resource_path)
	var level := get_tree().current_scene
	if level != null and level.has_method("remove_world_pickup"):
		level.remove_world_pickup.rpc(name)
