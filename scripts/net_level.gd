extends Node3D

const PLAYER_SCENE := preload("res://player.tscn")
const SPAWNS: Array[Vector3] = [
	Vector3(0, 0.2, 3.5),
	Vector3(1.4, 0.2, 3.5),
	Vector3(-1.4, 0.2, 3.5),
	Vector3(0, 0.2, 2.0),
]

var _spawner: MultiplayerSpawner


func _enter_tree() -> void:
	if not _is_online():
		return
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


func _spawn_player(id: Variant) -> Node:
	var peer_id := int(id)
	var player := PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.position = SPAWNS[(peer_id - 1) % SPAWNS.size()]
	return player


func _is_online() -> bool:
	return multiplayer.multiplayer_peer is ENetMultiplayerPeer
