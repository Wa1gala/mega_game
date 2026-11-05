## Выброшенный в мир предмет.
## RigidBody3D с простой коллизией-коробкой, чтобы папка падала на пол.
## Подбирается на E (цель взаимодействия выбирает InventoryManager, группа "interactable").
class_name PickupItem
extends RigidBody3D

const FALL_LIMIT_Y := -20.0   # ниже этой высоты предмет считается провалившимся

## Радиус взаимодействия (по горизонтали от игрока до предмета).
var interact_radius := 1.8

@export var item_data: ItemData

var _hint: Label3D
var _picked := false


func _ready() -> void:
	continuous_cd = true
	_setup_visual()
	_setup_collision()
	_build_hint()
	add_to_group("interactable")


func _physics_process(_delta: float) -> void:
	# Предмет мог провалиться сквозь пол — возвращаем к игроку, а не теряем.
	if global_position.y < FALL_LIMIT_Y:
		var player := get_tree().get_first_node_in_group("player") as Node3D
		linear_velocity = Vector3.ZERO
		global_position = (player.global_position if player != null else Vector3.ZERO) + Vector3.UP * 1.0


func _setup_visual() -> void:
	if item_data != null and item_data.world_mesh_scene != null:
		var mesh := item_data.world_mesh_scene.instantiate()
		add_child(mesh)


func _setup_collision() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.45, 0.08, 0.3)
	shape.shape = box
	add_child(shape)


func _build_hint() -> void:
	_hint = Label3D.new()
	_hint.name = "InteractHint"
	_hint.text = "E"
	_hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hint.top_level = true          # не вращается вместе с телом
	_hint.font_size = 40
	_hint.pixel_size = 0.006
	_hint.modulate = Color(0.5, 1, 0.5)
	_hint.outline_size = 6
	_hint.outline_modulate = Color(0, 0, 0, 1)
	_hint.no_depth_test = true
	_hint.visible = false
	add_child(_hint)


func _process(_delta: float) -> void:
	if _hint.visible:
		_hint.global_position = global_position + Vector3(0, 0.6, 0)


func can_interact() -> bool:
	return not _picked and item_data != null


func set_focused(focused: bool) -> void:
	_hint.visible = focused


func interact() -> void:
	if _picked:
		return
	if InventoryManager.add_to_player(item_data):
		_picked = true
		remove_from_group("interactable")
		queue_free()
