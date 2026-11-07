extends Control

const PORT := 7777
const LEVEL := "res://art/levels/base.tscn"

@onready var ip_address: LineEdit = %IPAddress
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var singleplayer_button: Button = %SingleplayerButton
@onready var exit_button: Button = %ExitButton

var _status: Label


func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	singleplayer_button.pressed.connect(_on_singleplayer_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 13)
	_status.add_theme_color_override("font_color", Color(0.55, 0.85, 0.6))
	_status.text = "Порт %s. В поле только IPv4 из Radmin или Hamachi." % PORT
	$Center/Panel/VBox.add_child(_status)
	$Center/Panel/VBox.move_child(_status, ip_address.get_index() + 1)


func _on_host_pressed() -> void:
	_close_peer()
	var peer := ENetMultiplayerPeer.new()
	# 0.0.0.0 — только IPv4. Иначе Windows через Radmin/Hamachi не отправляет пакеты.
	peer.set_bind_ip("0.0.0.0")
	var error := peer.create_server(PORT)
	if error != OK:
		_status.text = "Порт %s занят или закрыт файрволом (%s)." % [PORT, error]
		return
	multiplayer.multiplayer_peer = peer
	get_tree().change_scene_to_file(LEVEL)


func _on_join_pressed() -> void:
	var ip := _host_address()
	if ip.is_empty():
		return
	_close_peer()
	var peer := ENetMultiplayerPeer.new()
	peer.set_bind_ip("0.0.0.0")
	var error := ERR_CANT_CREATE
	for local_port in range(7780, 7790):
		error = peer.create_client(ip, PORT, 0, 0, 0, local_port)
		if error == OK:
			break
		peer.close()
		peer = ENetMultiplayerPeer.new()
		peer.set_bind_ip("0.0.0.0")
	if error != OK:
		_status.text = "Не удалось начать подключение к %s (%s)." % [ip, error]
		return
	multiplayer.multiplayer_peer = peer
	_status.text = "Подключение к %s:%s..." % [ip, PORT]
	if multiplayer.connected_to_server.is_connected(_on_connected):
		multiplayer.connected_to_server.disconnect(_on_connected)
	if multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.disconnect(_on_connection_failed)
	multiplayer.connected_to_server.connect(_on_connected, CONNECT_ONE_SHOT)
	multiplayer.connection_failed.connect(_on_connection_failed, CONNECT_ONE_SHOT)


func _on_connected() -> void:
	get_tree().change_scene_to_file(LEVEL)


func _on_connection_failed() -> void:
	var ip := ip_address.text.strip_edges()
	_close_peer()
	_status.text = "Нет ответа от %s:%s. Оба должны быть в одной сети, в поле только IPv4." % [ip, PORT]


func _on_singleplayer_pressed() -> void:
	_close_peer()
	# Одиночная игра: просто грузим уровень без сети/сервера.
	get_tree().change_scene_to_file("res://art/levels/office_middle.tscn")


func _on_exit_pressed() -> void:
	get_tree().quit()


func _host_address() -> String:
	var ip := ip_address.text.strip_edges()
	if ip.is_empty():
		return "127.0.0.1"
	if "/" in ip:
		ip = ip.split("/")[0].strip_edges()
	if ip.count(":") == 1 and ip.split(":")[0].contains("."):
		ip = ip.split(":")[0].strip_edges()
	if not ip.is_valid_ip_address():
		_status.text = "Нужен IPv4 из Radmin или Hamachi, без текста вокруг. Сейчас это не адрес: %s" % ip
		return ""
	return ip


func _close_peer() -> void:
	var peer := multiplayer.multiplayer_peer
	if peer is ENetMultiplayerPeer:
		peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
