extends RefCounted

# Общая сборка рэгдолла для скелета персонажа (игрок и враги).
# Суставы жёсткие: корпус и ноги почти не гнутся, поэтому тело падает целиком,
# а не складывается пополам.

# Максимальный наклон сустава и закрутка (градусы) по началу имени кости.
const JOINT_LIMITS := {
	"pelvis": Vector2(0.0, 0.0),
	"spine": Vector2(8.0, 5.0),
	"chest": Vector2(8.0, 5.0),
	"neck": Vector2(15.0, 10.0),
	"head": Vector2(15.0, 10.0),
	"shoulder": Vector2(10.0, 5.0),
	"upper_arm": Vector2(55.0, 25.0),
	"forearm": Vector2(30.0, 15.0),
	"hand": Vector2(25.0, 10.0),
	"thigh": Vector2(22.0, 8.0),
	"shin": Vector2(14.0, 5.0),
	"foot": Vector2(14.0, 5.0),
}
const DEFAULT_LIMIT := Vector2(20.0, 10.0)
# Рост, на высоте которого скорость равна push (м). Ниже — толчок слабее.
const FULL_HEIGHT := 1.7


static func _is_finger(bone_name: String) -> bool:
	return bone_name.begins_with("thumb") or bone_name.begins_with("f_")


## Запускает рэгдолл на скелете. push — горизонтальная скорость на уровне головы (м/с):
## чем выше часть тела, тем сильнее толчок, поэтому кукла опрокидывается целиком вокруг ног.
## Возвращает созданные физ. тела.
static func start(skeleton: Skeleton3D, total_mass: float, push: Vector3) -> Array[PhysicalBone3D]:
	var simulator := PhysicalBoneSimulator3D.new()
	simulator.name = "Ragdoll"
	skeleton.add_child(simulator)
	var bodies: Array[PhysicalBone3D] = []
	for bone in skeleton.get_bone_count():
		var bone_name := skeleton.get_bone_name(bone)
		if _is_finger(bone_name):
			continue
		var body := _make_bone(skeleton, bone)
		body.bone_name = bone_name
		simulator.add_child(body)
		bodies.append(body)
	var weight := total_mass / maxf(bodies.size(), 1)
	for body in bodies:
		body.mass = weight
		var height := (skeleton.global_transform * skeleton.get_bone_global_pose(body.get_bone_id()).origin).y 				- skeleton.global_position.y
		body.linear_velocity = push * clampf(height / FULL_HEIGHT, 0.0, 1.2)
	simulator.physical_bones_start_simulation()
	return bodies


static func _make_bone(skeleton: Skeleton3D, bone: int) -> PhysicalBone3D:
	# Направление кости — к первому ребёнку с телом; у листьев (голова, стопа, кисть) — вверх по Y.
	var direction := Vector3(0.0, 0.12, 0.0)
	for child in skeleton.get_bone_children(bone):
		if not _is_finger(skeleton.get_bone_name(child)):
			direction = skeleton.get_bone_rest(child).origin
			break
	var length := maxf(direction.length(), 0.08)
	var radius := clampf(length * 0.25, 0.04, 0.11)
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = maxf(length, radius * 2.0 + 0.01)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	var body := PhysicalBone3D.new()
	body.add_child(collision)
	# Капсула по умолчанию вытянута вдоль Y: поворачиваем её вдоль кости, ставим на середину.
	var axis := direction.normalized()
	var rotation_axis := Vector3.UP.cross(axis)
	var basis := Basis()
	if rotation_axis.length() > 0.001:
		basis = Basis(rotation_axis.normalized(), Vector3.UP.angle_to(axis))
	body.body_offset = Transform3D(basis, direction * 0.5)
	if skeleton.get_bone_parent(bone) >= 0:
		body.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
		# Ось конуса сустава — X: направляем её вдоль кости, иначе пределы действуют поперёк.
		var joint_axis := Vector3.RIGHT.cross(axis)
		var joint_basis := Basis()
		if joint_axis.length() > 0.001:
			joint_basis = Basis(joint_axis.normalized(), Vector3.RIGHT.angle_to(axis))
		elif axis.x < 0.0:
			joint_basis = Basis(Vector3.UP, PI)
		body.joint_offset = Transform3D(joint_basis, Vector3.ZERO)
		var limit := DEFAULT_LIMIT
		var bone_name := skeleton.get_bone_name(bone)
		for key in JOINT_LIMITS:
			if bone_name.begins_with(key):
				limit = JOINT_LIMITS[key]
				break
		body.set("joint_constraints/swing_span", limit.x)
		body.set("joint_constraints/twist_span", limit.y)
	return body
