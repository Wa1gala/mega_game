extends Node3D

const PLAYER_SCENE := preload("res://player.tscn")
# Смещения от игрока-заглушки уровня, чтобы игроки не появлялись друг в друге.
const SPAWN_OFFSETS: Array[Vector3] = [
	Vector3(0, 0.2, 0),
	Vector3(1.4, 0.2, 0),
	Vector3(-1.4, 0.2, 0),
	Vector3(0, 0.2, -1.5),
]

var _spawner: MultiplayerSpawner
var _pickup_id := 0
var _spawn_origin := Vector3(0, 0, 3.5)


func _enter_tree() -> void:
	if not _is_online():
		return
	var placeholder := get_node_or_null("Player") as Node3D
	if placeholder:
		_spawn_origin = placeholder.position
	_spawner = MultiplayerSpawner.new()
	_spawner.name = "PlayerSpawner"
	# Относительно спавнера ".." — это корень уровня.
	_spawner.spawn_path = NodePath("..")
	add_child(_spawner)
	_spawner.spawn_function = _spawn_player


func _ready() -> void:
	if not _is_online():
		return
	var placeholder := get_node_or_null("Player")
	if placeholder:
		placeholder.queue_free()
	if multiplayer.is_server():
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		_spawner.spawn(multiplayer.get_unique_id())
	else:
		request_player_spawn.rpc_id(1)


@rpc("any_peer", "reliable")
func request_player_spawn() -> void:
	if not multiplayer.is_server() or _spawner == null:
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if peer_id <= 0 or has_node(str(peer_id)):
		return
	_spawner.spawn(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	var player := get_node_or_null(str(peer_id))
	if player:
		player.queue_free()


@rpc("any_peer", "call_local", "reliable")
func request_spawn_pickup(item_path: String, origin: Vector3, impulse: Vector3) -> void:
	if multiplayer.is_server():
		spawn_world_pickup(item_path, origin, impulse)


func spawn_world_pickup(item_path: String, origin: Vector3, impulse: Vector3) -> void:
	if not multiplayer.is_server():
		return
	_pickup_id += 1
	_create_pickup.rpc(_pickup_id, item_path, origin, impulse)


@rpc("authority", "call_local", "reliable")
func _create_pickup(id: int, item_path: String, origin: Vector3, impulse: Vector3) -> void:
	var pickup_name := "Pickup%s" % id
	if has_node(pickup_name) or item_path.is_empty() or not ResourceLoader.exists(item_path):
		return
	var pickup := PickupItem.new()
	pickup.name = pickup_name
	pickup.item_data = load(item_path)
	add_child(pickup)
	pickup.global_position = origin
	pickup.apply_central_impulse(impulse)


@rpc("authority", "call_local", "reliable")
func remove_world_pickup(pickup_name: String) -> void:
	var pickup := get_node_or_null(pickup_name)
	if pickup:
		pickup.queue_free()


func _spawn_player(id: Variant) -> Node:
	var peer_id := int(id)
	var player := PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.position = _spawn_origin + SPAWN_OFFSETS[(peer_id - 1) % SPAWN_OFFSETS.size()]
	return player


func _is_online() -> bool:
	return multiplayer.multiplayer_peer is ENetMultiplayerPeer
