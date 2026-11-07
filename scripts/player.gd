extends CharacterBody3D

signal health_changed(current: int, maximum: int)
signal died

const MAX_HEALTH := 100
const DEATH_SCREEN_TIME := 6.0   # сколько висит экран смерти до выхода в меню
const HEAL_RATE := 5.0           # скорость лечения аптечкой, HP/сек
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
const AIM_FOV := 42.0
const AIM_SPRING_SCALE := 0.6
const AIM_LOOK_SCALE := 0.45
const AIM_BLEND := 12.0
const STEP_DISTANCE_WALK := 1.1   # путь между шагами при ходьбе, м
const STEP_DISTANCE_RUN := 1.5    # то же при беге
const DEATH_CAMERA_DISTANCE := 1.4   # дистанция камеры от головы при падении
const DEATH_CAMERA_ROLL := deg_to_rad(28.0)   # наклон камеры набок на земле
const DEATH_PUSH := 3.5              # толчок тела при смерти
const Ragdoll := preload("res://scripts/ragdoll.gd")
const SHOT_SOUND := preload("res://audio/weapons/rifle/762x39 Single WAV.wav")
const STEP_SOUND := preload("res://audio/player/footsteps/Plastic_001.wav")

@onready var camera: Camera3D = $SpringArm3D/Camera3D
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var model: Node3D = $male_casual

var _animation_player: AnimationPlayer
var _shot_player: AudioStreamPlayer3D
var _step_player: AudioStreamPlayer3D
var _step_progress := STEP_DISTANCE_RUN
var _previous_position := Vector3.ZERO
var _yaw := 0.0
var _pitch := deg_to_rad(-18.0)
var _fire_cooldown := 0.0
var _block_fire := false
var _crosshair: CanvasLayer
var _hip_spring := 2.0
var _hip_fov := 75.0
var health := MAX_HEALTH
var _world_health: Label3D
var _hud: CanvasLayer
var _health_fill: ColorRect
var _health_label: Label
var _vignette_mat: ShaderMaterial
var _hit_flash := 0.0
var _dead := false
var _ragdoll_head: PhysicalBone3D
var _death_time := 0.0
var _heal_pending := 0.0
var _heal_acc := 0.0


func _enter_tree() -> void:
	# Камера и управление включаются только у своего локального игрока.
	# Сетевой спавнер называет узел peer id. Пока имени-числа нет, авторитет не трогаем,
	# чтобы сцена запускалась одна, без сервера.
	var peer_id := str(name).to_int()
	if peer_id > 0:
		set_multiplayer_authority(peer_id)


func _ready() -> void:
	add_to_group("player")
	_setup_audio()
	camera.current = is_multiplayer_authority()
	_hip_spring = spring_arm.spring_length
	_hip_fov = camera.fov
	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_apply_camera_rotation()
		_setup_crosshair()
		_setup_hud()
	_previous_position = global_position
	_setup_animations()
	_setup_health_label()
	if is_multiplayer_authority():
		# Автомат в руках виден, только пока лежит в слоте оружия.
		InventoryManager.player_inventory_changed.connect(_update_weapon_visibility)
		_update_weapon_visibility()


func _update_weapon_visibility() -> void:
	var rifle := get_node_or_null("male_casual/rig/Skeleton3D/WeaponAttachment/Rifle") as Node3D
	if rifle:
		rifle.visible = InventoryManager.has_weapon()


## Получить урон. Возвращает фактически нанесённый урон (как у врагов).
func take_damage(amount: int) -> int:
	if _dead or amount <= 0:
		return 0
	var dealt := mini(amount, health)
	health -= dealt
	_hit_flash = 1.0
	_update_health_hud()
	_update_health_label()
	health_changed.emit(health, MAX_HEALTH)
	if health <= 0:
		_die()
	return dealt


## Восстановить здоровье сразу. Возвращает, сколько реально восполнено.
func heal(amount: int) -> int:
	if _dead or amount <= 0:
		return 0
	var restored := mini(amount, MAX_HEALTH - health)
	health += restored
	_update_health_hud()
	_update_health_label()
	health_changed.emit(health, MAX_HEALTH)
	return restored


## Постепенное лечение (аптечки): amount суммарно со скоростью HEAL_RATE HP/сек.
## Возвращает, сколько здоровья будет восполнено (с учётом уже идущего лечения); 0 — лечить нечего.
func heal_over_time(amount: int) -> int:
	if _dead or amount <= 0:
		return 0
	var room := MAX_HEALTH - health - int(ceilf(_heal_pending))
	var accepted := mini(amount, room)
	if accepted <= 0:
		return 0
	_heal_pending += accepted
	return accepted


func _tick_heal(delta: float) -> void:
	if _heal_pending <= 0.0:
		return
	var step := minf(HEAL_RATE * delta, _heal_pending)
	_heal_pending -= step
	_heal_acc += step
	var whole := int(_heal_acc)
	if _heal_pending <= 0.0:
		whole = int(roundf(_heal_acc))
		_heal_pending = 0.0
		_heal_acc = 0.0
	elif whole > 0:
		_heal_acc -= whole
	if whole > 0:
		health = mini(health + whole, MAX_HEALTH)
		_update_health_hud()
		_update_health_label()
		health_changed.emit(health, MAX_HEALTH)


func _die() -> void:
	_dead = true
	_heal_pending = 0.0
	_heal_acc = 0.0
	died.emit()
	_start_ragdoll()
	if not is_multiplayer_authority():
		return
	InventoryManager.close_all()
	_show_death_screen()
	await get_tree().create_timer(DEATH_SCREEN_TIME).timeout
	if not is_inside_tree():
		return
	# Пока без системы респауна: после смерти выкидываем в главное меню.
	InventoryManager.close_all()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Тело падает целиком как тряпичная кукла (см. ragdoll.gd), в случайную сторону.
func _start_ragdoll() -> void:
	$CollisionShape3D.set_deferred("disabled", true)
	if _animation_player:
		_animation_player.stop()
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return
	var angle := randf() * TAU
	var push := Vector3(velocity.x, 0.0, velocity.z) + Vector3(cos(angle), 0.0, sin(angle)) * DEATH_PUSH
	for body in Ragdoll.start(skeleton, 70.0, push):
		# Камера на пружине не должна упираться в собственное тело.
		spring_arm.add_excluded_object(body.get_rid())
		if body.bone_name == "head":
			_ragdoll_head = body


## Камера следует за головой падающего тела, сближается и заваливается набок.
func _update_death_camera(delta: float) -> void:
	_death_time += delta
	if _ragdoll_head:
		spring_arm.global_position = spring_arm.global_position.lerp(_ragdoll_head.global_position, minf(8.0 * delta, 1.0))
	var blend := minf(2.0 * delta, 1.0)
	spring_arm.spring_length = lerpf(spring_arm.spring_length, DEATH_CAMERA_DISTANCE, blend)
	camera.fov = lerpf(camera.fov, _hip_fov, blend)
	camera.rotation.z = lerp_angle(camera.rotation.z, DEATH_CAMERA_ROLL, minf(1.5 * delta, 1.0))
	_pitch = lerpf(_pitch, deg_to_rad(-35.0), minf(1.0 * delta, 1.0))
	_apply_camera_rotation()


## Полноэкранная надпись «ВЫ ПОГИБЛИ» в духе Dark Souls: затемнение и красный текст.
func _show_death_screen() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30   # выше инвентаря и сообщений
	add_child(layer)
	# Закрывающиеся глаза: два чёрных века сходятся к середине экрана (с первым морганием).
	var lid_top := ColorRect.new()
	var lid_bottom := ColorRect.new()
	for lid in [lid_top, lid_bottom]:
		lid.color = Color.BLACK
		lid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lid.anchor_left = 0.0
		lid.anchor_right = 1.0
		lid.offset_left = 0
		lid.offset_right = 0
		lid.offset_top = 0
		lid.offset_bottom = 0
		layer.add_child(lid)
	lid_top.anchor_top = 0.0
	lid_top.anchor_bottom = 0.0
	lid_bottom.anchor_top = 1.0
	lid_bottom.anchor_bottom = 1.0
	var blink := create_tween().set_parallel(true)
	blink.tween_property(lid_top, "anchor_bottom", 0.2, 0.7).set_trans(Tween.TRANS_SINE)
	blink.tween_property(lid_bottom, "anchor_top", 0.8, 0.7).set_trans(Tween.TRANS_SINE)
	blink.chain().tween_property(lid_top, "anchor_bottom", 0.1, 0.4)
	blink.parallel().tween_property(lid_bottom, "anchor_top", 0.9, 0.4)
	blink.chain().tween_property(lid_top, "anchor_bottom", 0.52, 1.4).set_trans(Tween.TRANS_QUAD)
	blink.parallel().tween_property(lid_bottom, "anchor_top", 0.48, 1.4).set_trans(Tween.TRANS_QUAD)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var band := ColorRect.new()   # тёмная полоса за текстом
	band.color = Color(0, 0, 0, 0.0)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	band.anchor_right = 1.0
	band.anchor_top = 0.38
	band.anchor_bottom = 0.62
	band.offset_left = 0
	band.offset_right = 0
	band.offset_top = 0
	band.offset_bottom = 0
	layer.add_child(band)
	var label := Label.new()
	label.text = "ВЫ ПОГИБЛИ"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 96)
	label.add_theme_color_override("font_color", Color(0.62, 0.05, 0.05))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	label.modulate.a = 0.0
	layer.add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(dim, "color:a", 0.75, 1.5)
	tween.tween_property(band, "color:a", 0.55, 1.5)
	tween.tween_property(label, "modulate:a", 1.0, 1.5).set_delay(2.0)
	# Медленное «наезжание» текста.
	label.pivot_offset = get_viewport().get_visible_rect().size * 0.5
	label.scale = Vector2(0.92, 0.92)
	tween.tween_property(label, "scale", Vector2(1.04, 1.04), DEATH_SCREEN_TIME)


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	# Отладка: H — получить 10 урона (только в запуске из редактора).
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_H:
		take_damage(10)
	if InventoryManager.is_ui_open() or _dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var look := LOOK_SENSITIVITY * (AIM_LOOK_SCALE if _is_aiming() else 1.0)
		_yaw -= event.relative.x * look
		_pitch = clampf(_pitch - event.relative.y * look, PITCH_MIN, PITCH_MAX)
		_apply_camera_rotation()


func _apply_camera_rotation() -> void:
	spring_arm.rotation = Vector3(_pitch, _yaw, 0.0)


func _process(delta: float) -> void:
	if _vignette_mat == null:
		return
	_tick_heal(delta)
	_hit_flash = maxf(_hit_flash - delta * 1.6, 0.0)
	# Красные края: вспышка при ударе + постоянное лёгкое покраснение при низком здоровье.
	var low := clampf(1.0 - float(health) / float(MAX_HEALTH) * 2.0, 0.0, 1.0) * 0.35
	_vignette_mat.set_shader_parameter("intensity", maxf(_hit_flash * 0.75, low))
	_hud.visible = not InventoryManager.pause_open


## Создаёт 3D-проигрыватели выстрела и шагов (слышны и у других игроков).
func _setup_audio() -> void:
	_shot_player = AudioStreamPlayer3D.new()
	_shot_player.stream = SHOT_SOUND
	_shot_player.max_polyphony = 4
	_shot_player.unit_size = 8.0
	add_child(_shot_player)
	_step_player = AudioStreamPlayer3D.new()
	_step_player.stream = STEP_SOUND
	_step_player.max_polyphony = 2
	_step_player.unit_size = 4.0
	_step_player.volume_db = -11.0
	add_child(_step_player)


func _update_footsteps(speed: float, delta: float) -> void:
	if _is_airborne() or speed < 0.5:
		# Шаг играет сразу в начале движения, чтобы короткое нажатие тоже звучало.
		_step_progress = STEP_DISTANCE_RUN
		return
	var sprinting := speed > WALK_SPEED + 0.4
	_step_progress += speed * delta
	if _step_progress >= (STEP_DISTANCE_RUN if sprinting else STEP_DISTANCE_WALK):
		_step_progress = 0.0
		_step_player.pitch_scale = randf_range(0.9, 1.1)
		_step_player.play()


func _physics_process(delta: float) -> void:
	if _dead:
		if is_multiplayer_authority():
			_update_death_camera(delta)
		return
	if is_multiplayer_authority():
		_move(delta)
		_update_aim(delta)
		_update_fire(delta)
	_update_animation(delta)
	_previous_position = global_position


func _move(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	var ui_open := InventoryManager.is_ui_open() or _dead
	if not ui_open and Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Vector2.ZERO
	if not ui_open:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (Basis(Vector3.UP, _yaw) * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var sprinting := not ui_open and Input.is_action_pressed("sprint") and InventoryManager.can_sprint()
	var speed := (RUN_SPEED if sprinting else WALK_SPEED) * InventoryManager.speed_multiplier()
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
			# Горизонтальное смещение убираем (двигает CharacterBody3D), а высоту корня
			# оставляем: иначе при ходьбе/беге ноги зависают над полом.
			for key in animation.track_get_key_count(track):
				var offset: Vector3 = animation.track_get_key_value(track, key)
				animation.track_set_key_value(track, key, Vector3(0.0, offset.y, 0.0))
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
	_update_footsteps(speed, delta)
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
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) \
			and InventoryManager.has_weapon()


func _update_aim(delta: float) -> void:
	var aiming := _is_aiming() and not InventoryManager.is_ui_open()
	var target_fov := AIM_FOV if aiming else _hip_fov
	var target_spring := _hip_spring * AIM_SPRING_SCALE if aiming else _hip_spring
	var blend := 1.0 - exp(-AIM_BLEND * delta)
	camera.fov = lerpf(camera.fov, target_fov, blend)
	spring_arm.spring_length = lerpf(spring_arm.spring_length, target_spring, blend)


func _update_fire(delta: float) -> void:
	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)
	var ui_open := InventoryManager.is_ui_open() or _dead
	if _crosshair:
		_crosshair.visible = not ui_open
	if ui_open:
		# Клик, закрывающий окно, не должен сразу превращаться в выстрел.
		_block_fire = true
		return
	if _block_fire:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_block_fire = false
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _fire_cooldown <= 0.0 \
			and InventoryManager.has_weapon():
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
	_shot_player.pitch_scale = randf_range(0.95, 1.05)
	_shot_player.play()
	_spawn_tracer(_tracer_origin(), end)


@rpc("authority", "call_local", "reliable")
func _replicate_damage(at: Vector3, amount: int) -> void:
	_spawn_damage_number(at, amount)


@rpc("any_peer", "call_local", "reliable")
func apply_hit(amount: int, at: Vector3) -> void:
	var dealt := take_damage(amount)
	if dealt > 0:
		_spawn_damage_number(at, dealt)


func _setup_health_label() -> void:
	_world_health = Label3D.new()
	_world_health.name = "HealthLabel"
	_world_health.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_world_health.fixed_size = true
	_world_health.font_size = 28
	_world_health.outline_size = 8
	_world_health.outline_modulate = Color(0, 0, 0, 1)
	_world_health.no_depth_test = true
	_world_health.position = Vector3(0, 2.2, 0)
	add_child(_world_health)
	_update_health_label()


func _update_health_label() -> void:
	if _world_health == null:
		return
	_world_health.text = str(health)
	var ratio := clampf(float(health) / float(MAX_HEALTH), 0.0, 1.0)
	_world_health.modulate = Color(lerpf(1.0, 0.35, ratio), lerpf(0.25, 0.95, ratio), 0.2)


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


## HUD: полоска здоровья снизу слева и красная виньетка по краям экрана.
func _setup_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 4   # ниже подсказок (5) и инвентаря (10)
	add_child(_hud)

	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec2 d = abs(UV - vec2(0.5)) * 2.0;
	float edge = smoothstep(0.55, 1.25, max(d.x, d.y) * 0.6 + length(d) * 0.55);
	COLOR = vec4(0.75, 0.02, 0.02, edge * intensity);
}
"""
	_vignette_mat = ShaderMaterial.new()
	_vignette_mat.shader = shader
	var vignette := ColorRect.new()
	vignette.material = _vignette_mat
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.add_child(vignette)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 20
	panel.offset_bottom = -20
	panel.offset_top = -48
	panel.offset_right = 240
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.04, 0.045, 0.05, 0.62)
	bg.border_color = Color(1, 1, 1, 0.14)
	bg.set_border_width_all(1)
	bg.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", bg)
	_hud.add_child(panel)

	var back := Control.new()
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(back)
	_health_fill = ColorRect.new()
	_health_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.add_child(_health_fill)
	_health_label = Label.new()
	_health_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_health_label.add_theme_font_size_override("font_size", 13)
	_health_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_health_label.add_theme_constant_override("outline_size", 4)
	back.add_child(_health_label)
	_update_health_hud()


func _update_health_hud() -> void:
	if _health_fill == null:
		return
	var ratio := clampf(float(health) / float(MAX_HEALTH), 0.0, 1.0)
	_health_fill.anchor_right = ratio
	_health_fill.offset_right = 0
	_health_fill.color = Color(0.78, 0.12, 0.1).lerp(Color(0.3, 0.7, 0.25), ratio)
	_health_label.text = "%d / %d" % [health, MAX_HEALTH]


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
