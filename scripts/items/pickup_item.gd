## Выброшенный в мир предмет.
## RigidBody3D с простой коллизией-коробкой, чтобы папка падала на пол.
## Подбирается на E при приближении (обратно в инвентарь игрока).
class_name PickupItem
extends RigidBody3D

const PICKUP_RADIUS := 1.5

@export var item_data: ItemData

var _player_nearby := false
var _hint: Label3D


func _ready() -> void:
	_setup_visual()
	_setup_collision()
	_setup_interaction_area()
	_build_hint()


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


func _setup_interaction_area() -> void:
	var area := Area3D.new()
	area.name = "InteractionArea"
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = PICKUP_RADIUS
	shape.shape = sphere
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)


func _build_hint() -> void:
	_hint = Label3D.new()
	_hint.name = "InteractHint"
	_hint.text = "E"
	_hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hint.font_size = 40
	_hint.pixel_size = 0.006
	_hint.modulate = Color(0.5, 1, 0.5)
	_hint.outline_size = 6
	_hint.outline_modulate = Color(0, 0, 0, 1)
	_hint.position = Vector3(0, 0.6, 0)
	_hint.visible = false
	add_child(_hint)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_nearby = true
		_hint.visible = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
		_hint.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _player_nearby and event.is_action_pressed("interact"):
		if InventoryManager.add_to_player(item_data):
			queue_free()
			get_viewport().set_input_as_handled()
