extends CharacterBody3D

const WALK_SPEED := 2.6
const RUN_SPEED := 5.0
const JUMP_VELOCITY := 4.5
const WALK_ANIM_SPEED := 1.88
const RUN_ANIM_SPEED := 4.7
const LOOK_SENSITIVITY := 0.0025
const PITCH_MIN := deg_to_rad(-55.0)
const PITCH_MAX := deg_to_rad(25.0)
const FIRE_RANGE := 60.0
const FIRE_INTERVAL := 0.18
const DAMAGE_MIN := 8
const DAMAGE_MAX := 18
const MAX_HEALTH := 100
const AIM_FOV := 42.0
const AIM_SPRING_SCALE := 0.6
const AIM_LOOK_SCALE := 0.45
const AIM_BLEND := 12.0

@onready var camera: Camera3D = $SpringArm3D/Camera3D
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var model: Node3D = $male_casual

var _animation_player: AnimationPlayer
var _previous_position := Vector3.ZERO
var _yaw := 0.0
var _pitch := deg_to_rad(-18.0)
var _fire_cooldown := 0.0
var _block_fire := false
var _crosshair: CanvasLayer
var _hip_spring := 2.0
var _hip_fov := 75.0
var health := MAX_HEALTH
var _health_label: Label3D


func _enter_tree() -> void:
	# Камера и управление включаются только у своего локального игрока.
	# Сетевой спавнер называет узел peer id. Пока имени-числа нет, авторитет не трогаем,
	# чтобы сцена запускалась одна, без сервера.
	var peer_id := str(name).to_int()
	if peer_id > 0:
		set_multiplayer_authority(peer_id)


func _ready() -> void:
	add_to_group("player")
	camera.current = is_multiplayer_authority()
	_hip_spring = spring_arm.spring_length
	_hip_fov = camera.fov
	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_apply_camera_rotation()
		_setup_crosshair()
	_previous_position = global_position
	_setup_animations()
	_setup_health_label()


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			_block_fire = true
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var look := LOOK_SENSITIVITY * (AIM_LOOK_SCALE if _is_aiming() else 1.0)
		_yaw -= event.relative.x * look
		_pitch = clampf(_pitch - event.relative.y * look, PITCH_MIN, PITCH_MAX)
		_apply_camera_rotation()


func _apply_camera_rotation() -> void:
	spring_arm.rotation = Vector3(_pitch, _yaw, 0.0)


func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		_move(delta)
		_update_aim(delta)
		_update_fire(delta)
	_update_animation(delta)
	_previous_position = global_position


func _move(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (Basis(Vector3.UP, _yaw) * Vector3(input_dir.x, 0, input_dir.y)).normalized()
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
	library.add_animation("idle", _take_animation("res://art/characters/player/Idle.fbx", true))
	library.add_animation("walk", _take_animation("res://art/characters/player/Walk Forward.fbx"))
	library.add_animation("run", _take_animation("res://art/characters/player/Run Forward.fbx"))
	var jump := _take_animation("res://art/characters/player/Jump Up.fbx")
	jump.loop_mode = Animation.LOOP_NONE
	library.add_animation("jump", jump)
	_animation_player.add_animation_library(&"", library)
	_animation_player.play(&"idle")


func _take_animation(path: String, seamless_loop := false) -> Animation:
	var packed := load(path) as PackedScene
	var root := packed.instantiate()
	var source := root.get_node("AnimationPlayer") as AnimationPlayer
	var animation := source.get_animation("mixamo_com").duplicate() as Animation
	animation.loop_mode = Animation.LOOP_LINEAR
	for track in range(animation.get_track_count() - 1, -1, -1):
		var track_path := String(animation.track_get_path(track))
		if track_path == "rig" and animation.track_get_type(track) == Animation.TYPE_POSITION_3D:
			animation.remove_track(track)
	if seamless_loop:
		_make_loop_seamless(animation, 0.7)
	root.free()
	return animation


func _make_loop_seamless(animation: Animation, blend_window: float) -> void:
	var blend_start := maxf(animation.length - blend_window, 0.0)
	for track in animation.get_track_count():
		if animation.track_get_key_count(track) < 2:
			continue
		var first_value = animation.track_get_key_value(track, 0)
		for key in range(animation.track_get_key_count(track) - 1, -1, -1):
			if animation.track_get_key_time(track, key) > blend_start:
				animation.track_remove_key(track, key)
		animation.track_insert_key(track, animation.length, first_value)
		animation.track_set_interpolation_loop_wrap(track, true)
		if animation.track_get_type(track) == Animation.TYPE_ROTATION_3D:
			animation.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC_ANGLE)


func _update_animation(delta: float) -> void:
	var horizontal := _horizontal_velocity(delta)
	var speed := horizontal.length()
	if speed > 0.2:
		var direction := horizontal / speed
		var target_yaw := atan2(direction.x, direction.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_yaw, 12.0 * delta)

	var next := &"idle"
	var reference_speed := 1.0
	if _is_airborne():
		next = &"jump"
	elif speed > WALK_SPEED + 0.4:
		next = &"run"
		reference_speed = RUN_ANIM_SPEED
	elif speed > 0.2:
		next = &"walk"
		reference_speed = WALK_ANIM_SPEED

	if _animation_player.current_animation != String(next):
		_animation_player.play(next, 0.12)
	if next == &"idle":
		_animation_player.speed_scale = 0.55
	elif next == &"jump":
		_animation_player.speed_scale = 1.0
	else:
		_animation_player.speed_scale = clampf(speed / reference_speed, 0.75, 1.6)


func _is_airborne() -> bool:
	if is_multiplayer_authority():
		return not is_on_floor()
	return absf(global_position.y - _previous_position.y) > 0.02


func _is_aiming() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)


func _update_aim(delta: float) -> void:
	var aiming := _is_aiming()
	var target_fov := AIM_FOV if aiming else _hip_fov
	var target_spring := _hip_spring * AIM_SPRING_SCALE if aiming else _hip_spring
	var blend := 1.0 - exp(-AIM_BLEND * delta)
	camera.fov = lerpf(camera.fov, target_fov, blend)
	spring_arm.spring_length = lerpf(spring_arm.spring_length, target_spring, blend)


func _update_fire(delta: float) -> void:
	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)
	if _crosshair:
		_crosshair.visible = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if _block_fire:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_block_fire = false
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _fire_cooldown <= 0.0:
		_shoot()
		_fire_cooldown = FIRE_INTERVAL


func _shoot() -> void:
	var origin := camera.global_position
	var forward := -camera.global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * FIRE_RANGE)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var end := origin + forward * FIRE_RANGE
	if not hit.is_empty():
		end = hit.position
		var damageable := _damageable_from_hit(hit.collider)
		if damageable:
			var amount := randi_range(DAMAGE_MIN, DAMAGE_MAX)
			var at: Vector3 = end + (hit.normal as Vector3) * 0.08
			var target := damageable as Node
			if target != null and target.has_method("apply_hit"):
				if _is_network_game():
					target.rpc("apply_hit", amount, at)
				else:
					target.call("apply_hit", amount, at)
			else:
				var dealt := int(damageable.call("take_damage", amount))
				if dealt > 0:
					if _is_network_game():
						_replicate_damage.rpc(at, dealt)
					else:
						_spawn_damage_number(at, dealt)
	_spawn_tracer(_tracer_origin(), end)


@rpc("authority", "call_local", "reliable")
func _replicate_damage(at: Vector3, amount: int) -> void:
	_spawn_damage_number(at, amount)


func take_damage(amount: int) -> int:
	if health <= 0 or amount <= 0:
		return 0
	var dealt := mini(amount, health)
	health -= dealt
	_update_health_label()
	return dealt


@rpc("any_peer", "call_local", "reliable")
func apply_hit(amount: int, at: Vector3) -> void:
	var dealt := take_damage(amount)
	if dealt > 0:
		_spawn_damage_number(at, dealt)


func _setup_health_label() -> void:
	_health_label = Label3D.new()
	_health_label.name = "HealthLabel"
	_health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_health_label.fixed_size = true
	_health_label.font_size = 28
	_health_label.outline_size = 8
	_health_label.outline_modulate = Color(0, 0, 0, 1)
	_health_label.no_depth_test = true
	_health_label.position = Vector3(0, 2.2, 0)
	add_child(_health_label)
	_update_health_label()


func _update_health_label() -> void:
	if _health_label == null:
		return
	_health_label.text = str(health)
	var ratio := clampf(float(health) / float(MAX_HEALTH), 0.0, 1.0)
	_health_label.modulate = Color(lerpf(1.0, 0.35, ratio), lerpf(0.25, 0.95, ratio), 0.2)


func _is_network_game() -> bool:
	return multiplayer.multiplayer_peer is ENetMultiplayerPeer


func _damageable_from_hit(collider: Object) -> Object:
	var node := collider as Node
	if node == null:
		return null
	var current: Node = node
	while current:
		if current.has_method("take_damage"):
			return current
		current = current.get_parent()
	return _find_damageable_in_children(node)


func _find_damageable_in_children(node: Node) -> Object:
	for child in node.get_children():
		if child.has_method("take_damage"):
			return child
		var found := _find_damageable_in_children(child)
		if found:
			return found
	return null


func _tracer_origin() -> Vector3:
	var rifle := get_node_or_null("male_casual/rig/Skeleton3D/WeaponAttachment/Rifle") as Node3D
	if rifle:
		return rifle.global_position
	return camera.global_position


func _spawn_damage_number(at: Vector3, amount: int) -> void:
	var label := Label3D.new()
	label.text = str(amount)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = true
	label.font_size = 40
	label.outline_size = 10
	label.outline_modulate = Color(0, 0, 0, 1)
	label.no_depth_test = true
	var strength := clampf(float(amount - DAMAGE_MIN) / float(DAMAGE_MAX - DAMAGE_MIN), 0.0, 1.0)
	label.modulate = Color(1.0, lerpf(0.9, 0.3, strength), 0.15)
	var parent := get_tree().current_scene if get_tree().current_scene else get_tree().root
	parent.add_child(label)
	label.global_position = at + Vector3(randf_range(-0.12, 0.12), randf_range(0.0, 0.15), randf_range(-0.12, 0.12))
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y + 0.75, 0.55) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.18)
	tween.chain().tween_callback(label.queue_free)


func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < 0.05:
		return
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.02, 0.02, length)
	mesh_instance.mesh = box
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.86, 0.35)
	mesh_instance.material_override = material
	var parent := get_tree().current_scene if get_tree().current_scene else get_tree().root
	parent.add_child(mesh_instance)
	mesh_instance.global_position = (from + to) * 0.5
	if absf(from.direction_to(to).dot(Vector3.UP)) > 0.98:
		mesh_instance.look_at(to, Vector3.RIGHT)
	else:
		mesh_instance.look_at(to)
	var tween := mesh_instance.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, 0.07)
	tween.tween_callback(mesh_instance.queue_free)


func _setup_crosshair() -> void:
	var layer := CanvasLayer.new()
	var root_control := Control.new()
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root_control)
	_add_crosshair_bar(root_control, Vector2(14, 2))
	_add_crosshair_bar(root_control, Vector2(2, 14))
	add_child(layer)
	_crosshair = layer


func _add_crosshair_bar(parent: Control, size: Vector2) -> void:
	var bar := ColorRect.new()
	bar.color = Color(1, 1, 1, 0.9)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.set_anchors_preset(Control.PRESET_CENTER)
	bar.offset_left = -size.x * 0.5
	bar.offset_top = -size.y * 0.5
	bar.offset_right = size.x * 0.5
	bar.offset_bottom = size.y * 0.5
	parent.add_child(bar)


func _horizontal_velocity(delta: float) -> Vector3:
	if is_multiplayer_authority():
		return Vector3(velocity.x, 0.0, velocity.z)
	var step := global_position - _previous_position
	return Vector3(step.x, 0.0, step.z) / maxf(delta, 0.0001)
