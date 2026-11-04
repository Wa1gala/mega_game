extends CharacterBody3D

const WALK_SPEED := 2.6
const RUN_SPEED := 5.0
const JUMP_VELOCITY := 4.5
const WALK_ANIM_SPEED := 1.88
const RUN_ANIM_SPEED := 4.7

@onready var camera: Camera3D = $SpringArm3D/Camera3D
@onready var model: Node3D = $male_casual

var _animation_player: AnimationPlayer
var _previous_position := Vector3.ZERO


func _enter_tree() -> void:
	# Камера и управление включаются только у своего локального игрока.
	# Сетевой спавнер называет узел peer id. Пока имени-числа нет, авторитет не трогаем,
	# чтобы сцена запускалась одна, без сервера.
	var peer_id := str(name).to_int()
	if peer_id > 0:
		set_multiplayer_authority(peer_id)


func _ready() -> void:
	camera.current = is_multiplayer_authority()
	_previous_position = global_position
	_setup_animations()
	_setup_weapon()


func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		_move(delta)
	_update_animation(delta)
	_previous_position = global_position


func _move(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var speed := RUN_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()


func _setup_animations() -> void:
	_animation_player = AnimationPlayer.new()
	_animation_player.name = "AnimationPlayer"
	_animation_player.root_node = NodePath("..")
	model.add_child(_animation_player)
	var library := AnimationLibrary.new()
	library.add_animation("idle", _take_animation("res://art/characters/player/Idle.fbx"))
	library.add_animation("walk", _take_animation("res://art/characters/player/Walk Forward.fbx"))
	library.add_animation("run", _take_animation("res://art/characters/player/Run Forward.fbx"))
	_animation_player.add_animation_library(&"", library)
	_animation_player.play(&"idle")


func _setup_weapon() -> void:
	var weapon := model.get_node_or_null("Rifle") as Node3D
	if weapon == null:
		push_warning("Weapon: 'Rifle' node not found under model")
		return

	var skeleton := _find_skeleton()
	if skeleton == null:
		push_warning("Weapon: Skeleton3D not found in player model")
		return

	var bone_idx := skeleton.find_bone("hand_right")
	if bone_idx == -1:
		push_warning("Weapon: bone 'hand_right' not found")
		return

	var attachment := BoneAttachment3D.new()
	attachment.name = "WeaponAttachment"
	attachment.bone_name = "hand_right"
	skeleton.add_child(attachment)

	# Даём привязке кадр, чтобы она встала по кости, затем переносим
	# винтовку под неё, сохранив текущую мировую трансформацию.
	await get_tree().process_frame
	var world_transform := weapon.global_transform
	weapon.get_parent().remove_child(weapon)
	attachment.add_child(weapon)
	weapon.global_transform = world_transform


func _find_skeleton() -> Skeleton3D:
	for child in model.find_children("*", "Skeleton3D", true, false):
		return child as Skeleton3D
	return null


func _take_animation(path: String) -> Animation:
	var packed := load(path) as PackedScene
	var root := packed.instantiate()
	var source := root.get_node("AnimationPlayer") as AnimationPlayer
	var animation := source.get_animation("mixamo_com").duplicate() as Animation
	animation.loop_mode = Animation.LOOP_LINEAR
	for track in range(animation.get_track_count() - 1, -1, -1):
		var track_path := String(animation.track_get_path(track))
		if track_path == "rig" and animation.track_get_type(track) == Animation.TYPE_POSITION_3D:
			animation.remove_track(track)
	root.free()
	return animation


func _update_animation(delta: float) -> void:
	var horizontal := _horizontal_velocity(delta)
	var speed := horizontal.length()
	if speed > 0.2:
		var direction := horizontal / speed
		var target_yaw := atan2(direction.x, direction.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_yaw, 12.0 * delta)

	var next := &"idle"
	var reference_speed := 1.0
	if speed > WALK_SPEED + 0.4:
		next = &"run"
		reference_speed = RUN_ANIM_SPEED
	elif speed > 0.2:
		next = &"walk"
		reference_speed = WALK_ANIM_SPEED

	if _animation_player.current_animation != String(next):
		_animation_player.play(next, 0.12)
	_animation_player.speed_scale = 1.0 if next == &"idle" else clampf(speed / reference_speed, 0.75, 1.6)


func _horizontal_velocity(delta: float) -> Vector3:
	if is_multiplayer_authority():
		return Vector3(velocity.x, 0.0, velocity.z)
	var step := global_position - _previous_position
	return Vector3(step.x, 0.0, step.z) / maxf(delta, 0.0001)
