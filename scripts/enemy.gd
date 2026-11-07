extends CharacterBody3D

# Враг: та же модель и анимации, что у игрока, но в полицейском скине.
# Пока стоит на месте в idle, по нему можно стрелять (цифры урона показывает игрок).

const PLAYER_ANIM_DIR := "res://art/characters/player/"

@onready var model: Node3D = $male_casual

var _animation_player: AnimationPlayer


func _ready() -> void:
	add_to_group("enemy")
	_setup_animations()


func take_damage(amount: int) -> int:
	return amount


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
