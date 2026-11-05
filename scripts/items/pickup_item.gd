## Выброшенный в мир предмет.
## RigidBody3D с простой коллизией-коробкой, чтобы папка падала на пол.
## Подбирается на E при приближении (обратно в инвентарь игрока).
class_name PickupItem
extends RigidBody3D

const PICKUP_RADIUS := 1.5

@export var item_data: ItemData

var _player_nearby := false
var _hint: Label3D
var _taken := false


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
	if body.is_in_group("player") and body.is_multiplayer_authority():
		_player_nearby = true
		_hint.visible = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") and body.is_multiplayer_authority():
		_player_nearby = false
		_hint.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not _player_nearby or not event.is_action_pressed("interact"):
		return
	if not _has_free_player_slot():
		return
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		request_pickup.rpc_id(1)
	elif InventoryManager.add_to_player(item_data):
		queue_free()
	get_viewport().set_input_as_handled()


func _has_free_player_slot() -> bool:
	for item in InventoryManager.player_inventory:
		if item == null:
			return true
	return false


@rpc("any_peer", "call_local", "reliable")
func request_pickup() -> void:
	if not multiplayer.is_server() or _taken or item_data == null:
		return
	_taken = true
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
