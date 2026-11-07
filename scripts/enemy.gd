extends CharacterBody3D

# Враг: та же модель и анимации, что у игрока, но в полицейском скине.
# Пока стоит на месте в idle, по нему можно стрелять (цифры урона показывает игрок).
# Урон сначала съедает броню, потом здоровье. При смерти враг падает всем телом как кукла,
# труп можно обыскать. Когда лут забран, через несколько секунд труп плавно исчезает.

const PLAYER_ANIM_DIR := "res://art/characters/player/"
const Ragdoll := preload("res://scripts/ragdoll.gd")

signal died
signal health_changed(health: int, armor: int)

@export_group("Здоровье")
## Обычное здоровье.
@export_range(1, 10000) var max_health: int = 100
## Броня: поглощает урон до того, как он дойдёт до здоровья. 0 — без брони.
@export_range(0, 10000) var max_armor: int = 100

@export_group("Рэгдолл")
## Падать как тряпичная кукла при смерти.
@export var ragdoll_enabled := true
## Вес тела куклы (кг на всё тело).
@export_range(10.0, 300.0) var ragdoll_mass := 70.0
## Сила начального толчка: тело заваливается в случайную сторону.
@export_range(0.0, 20.0) var death_push := 3.5

@export_group("Лут с трупа")
## Можно ли обыскать труп.
@export var lootable := true
## Таблица лута трупа.
@export var loot_table: LootTable = preload("res://resources/loot/office_cabinet.tres")
@export var loot_name := "Труп"
## Число колонок и рядов сетки трупа.
@export_range(1, 6) var loot_columns := 4
@export_range(1, 10) var loot_rows := 2
## Через сколько секунд после того, как лут забран, труп начинает исчезать.
@export_range(0.0, 600.0) var vanish_delay := 5.0
## Сколько секунд труп плавно растворяется.
@export_range(0.1, 10.0) var fade_time := 1.5

@onready var model: Node3D = $male_casual

var health: int
var armor: int
var dead := false

var _animation_player: AnimationPlayer
var _skeleton: Skeleton3D
var _loot: LootContainer
var _pelvis: PhysicalBone3D
var _empty_time := 0.0
var _fading := false


func _ready() -> void:
	add_to_group("enemy")
	health = max_health
	armor = max_armor
	_setup_animations()
	_skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D


func take_damage(amount: int) -> int:
	if dead or amount <= 0:
		return 0
	var left := amount
	var absorbed := mini(left, armor)
	armor -= absorbed
	left -= absorbed
	health -= left
	health_changed.emit(maxi(health, 0), armor)
	if health <= 0:
		_die()
	return amount


func _die() -> void:
	dead = true
	remove_from_group("enemy")
	died.emit()
	# Капсула больше не нужна: дальше тело двигается физикой костей.
	$CollisionShape3D.set_deferred("disabled", true)
	if _animation_player:
		_animation_player.stop()
	if ragdoll_enabled and _skeleton:
		var angle := randf() * TAU
		var push := Vector3(cos(angle), 0.0, sin(angle)) * death_push
		var bodies := Ragdoll.start(_skeleton, ragdoll_mass, push)
		_pelvis = bodies[0]
	if lootable:
		_loot = LootContainer.new()
		_loot.name = "CorpseLoot"
		_loot.container_name = loot_name
		_loot.grid_columns = loot_columns
		_loot.grid_rows = loot_rows
		_loot.loot_table = loot_table
		_loot.focus_height = 0.25
		add_child(_loot)
		_follow_corpse()


# Точка обыска ездит вместе с тазом куклы.
func _follow_corpse() -> void:
	if _loot == null:
		return
	if _pelvis:
		_loot.global_position = _pelvis.global_position
	else:
		_loot.global_position = global_position


func _process(delta: float) -> void:
	if not dead or _fading:
		return
	_follow_corpse()
	if _loot == null:
		return
	# Лут забран (и контейнер не открыт прямо сейчас) — запускаем отсчёт до исчезновения.
	if _is_looted():
		_empty_time += delta
		if _empty_time >= vanish_delay:
			_start_fade()
	else:
		_empty_time = 0.0


func _is_looted() -> bool:
	if InventoryManager._open_container == _loot:
		return false
	for item in _loot.inventory:
		if item != null:
			return false
	return true


# Плавно растворяем все меши трупа и удаляем его.
func _start_fade() -> void:
	_fading = true
	if _loot:
		_loot.remove_from_group("interactable")
	var tween := create_tween().set_parallel(true)
	for node in find_children("*", "GeometryInstance3D", true, false):
		tween.tween_property(node, "transparency", 1.0, fade_time)
	tween.chain().tween_callback(queue_free)


func _setup_animations() -> void:
	_animation_player = AnimationPlayer.new()
	_animation_player.name = "AnimationPlayer"
	_animation_player.root_node = NodePath("..")
	model.add_child(_animation_player)
	var library := AnimationLibrary.new()
	library.add_animation("idle", _take_animation(PLAYER_ANIM_DIR + "Idle.fbx", true))
	library.add_animation("walk", _take_animation(PLAYER_ANIM_DIR + "Walk Forward.fbx"))
	library.add_animation("run", _take_animation(PLAYER_ANIM_DIR + "Run Forward.fbx"))
	_animation_player.add_animation_library(&"", library)
	_animation_player.play(&"idle")


# Логика совпадает с player.gd, чтобы игрока не трогать.
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
