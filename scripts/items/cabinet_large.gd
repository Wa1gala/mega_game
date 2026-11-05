## Интерактивный шкаф-контейнер.
## Вешается на StaticBody3D «CabinetLarge» в test_office.tscn.
## При приближении игрока и нажатии E открывает UI контейнера (две панели).
class_name CabinetLarge
extends StaticBody3D

const SLOT_COUNT := 6
const INTERACTION_RADIUS := 1.8

## Слоты шкафа (пустые = null). В сети содержимое решает сервер.
@export var inventory: Array[ItemData] = []

var _player_nearby := false
var _hint: Label3D


func _ready() -> void:
	inventory.resize(SLOT_COUNT)
	_build_interaction_area()
	_build_hint()
	if _is_net():
		if multiplayer.is_server():
			_load_demo_item()
		else:
			for i in inventory.size():
				inventory[i] = null
			request_state.rpc_id(1)
	else:
		_load_demo_item()


func _load_demo_item() -> void:
	for it in inventory:
		if it != null:
			return
	inventory[0] = load("res://resources/items/file_binder_alt4.tres") as ItemData


func _build_interaction_area() -> void:
	var area := Area3D.new()
	area.name = "InteractionArea"
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = INTERACTION_RADIUS
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
	_hint.font_size = 48
	_hint.pixel_size = 0.008
	_hint.modulate = Color(0.5, 1, 0.5)
	_hint.outline_size = 6
	_hint.outline_modulate = Color(0, 0, 0, 1)
	_hint.position = Vector3(0, 1.2, 0)
	_hint.visible = false
	add_child(_hint)


func _on_body_entered(body: Node3D) -> void:
	if _is_local_player(body):
		_player_nearby = true
		_hint.visible = true


func _on_body_exited(body: Node3D) -> void:
	if _is_local_player(body):
		_player_nearby = false
		_hint.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _player_nearby and event.is_action_pressed("interact"):
		InventoryManager.open_container(self)
		get_viewport().set_input_as_handled()


func _is_local_player(body: Node) -> bool:
	return body.is_in_group("player") and body.is_multiplayer_authority()


func _is_net() -> bool:
	return multiplayer.multiplayer_peer is ENetMultiplayerPeer


func _sender_id() -> int:
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 0:
		sender = multiplayer.get_unique_id()
	return sender


func _load_item(path: String) -> ItemData:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as ItemData


func _paths() -> PackedStringArray:
	var paths := PackedStringArray()
	for item in inventory:
		paths.append(item.resource_path if item != null else "")
	return paths


@rpc("any_peer", "call_local", "reliable")
func request_state() -> void:
	if multiplayer.is_server():
		apply_all.rpc_id(_sender_id(), _paths())


@rpc("authority", "call_local", "reliable")
func apply_all(paths: PackedStringArray) -> void:
	for i in mini(paths.size(), inventory.size()):
		inventory[i] = _load_item(paths[i])
	InventoryManager.refresh_open_container(self)


@rpc("authority", "call_local", "reliable")
func apply_slot(index: int, item_path: String) -> void:
	if index < 0 or index >= inventory.size():
		return
	inventory[index] = _load_item(item_path)
	InventoryManager.refresh_open_container(self)


@rpc("any_peer", "call_local", "reliable")
func request_exchange(cabinet_index: int, player_slot: int, player_item_path: String) -> void:
	if not multiplayer.is_server():
		return
	if cabinet_index < 0 or cabinet_index >= inventory.size():
		return
	if player_slot < 0 or player_slot >= InventoryManager.PLAYER_SLOT_COUNT:
		return
	var previous := ""
	if inventory[cabinet_index] != null:
		previous = inventory[cabinet_index].resource_path
	if player_item_path.is_empty() and previous.is_empty():
		return
	inventory[cabinet_index] = _load_item(player_item_path)
	apply_slot.rpc(cabinet_index, player_item_path)
	_send_player_slot(_sender_id(), player_slot, previous)


@rpc("any_peer", "call_local", "reliable")
func request_swap(first: int, second: int) -> void:
	if not multiplayer.is_server():
		return
	if first < 0 or second < 0 or first >= inventory.size() or second >= inventory.size():
		return
	var saved: ItemData = inventory[first]
	inventory[first] = inventory[second]
	inventory[second] = saved
	apply_all.rpc(_paths())


@rpc("any_peer", "call_local", "reliable")
func request_drop(index: int, origin: Vector3, impulse: Vector3) -> void:
	if not multiplayer.is_server():
		return
	if index < 0 or index >= inventory.size() or inventory[index] == null:
		return
	var item_path := inventory[index].resource_path
	inventory[index] = null
	apply_slot.rpc(index, "")
	var level := get_tree().current_scene
	if level != null and level.has_method("spawn_world_pickup"):
		level.spawn_world_pickup(item_path, origin, impulse)


func _send_player_slot(peer_id: int, slot_index: int, item_path: String) -> void:
	if peer_id == multiplayer.get_unique_id():
		InventoryManager.apply_player_slot(slot_index, item_path)
	else:
		InventoryManager.apply_player_slot.rpc_id(peer_id, slot_index, item_path)
