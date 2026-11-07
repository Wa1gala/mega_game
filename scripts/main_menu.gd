extends Control

const PORT := 7777
const LEVEL := "res://art/levels/office_middle.tscn"

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
	_status.text = "Порт %s. В поле — IPv4 хоста. Этот компьютер: %s." % [PORT, _address_list()]
	$Center/Panel/VBox.add_child(_status)
	$Center/Panel/VBox.move_child(_status, ip_address.get_index() + 1)


func _on_host_pressed() -> void:
	_close_peer()
	var peer := ENetMultiplayerPeer.new()
	# IPv4 на всех адаптерах. Если Godot в исключениях раздельного туннеля AmneziaVPN,
	# её драйвер переписывает этот адрес на один LAN-адрес, и Radmin до сервера не доходит.
	peer.set_bind_ip("0.0.0.0")
	var error := peer.create_server(PORT)
	if error != OK:
		_status.text = "Порт %s занят или закрыт файрволом (%s)." % [PORT, error]
		return
	multiplayer.multiplayer_peer = peer
	print("Сервер, порт %s. Друг вводит один из этих IPv4: %s" % [PORT, _address_list()])
	get_tree().change_scene_to_file(LEVEL)


func _on_join_pressed() -> void:
	var ip := _host_address()
	if ip.is_empty():
		return
	var local_ip := _bind_address_for(ip)
	if local_ip.is_empty():
		_status.text = "К %s не выйти: нет своего адреса в этой сети. Сейчас есть %s. Включи Hamachi или Radmin в ту же сеть, что и хост." % [ip, _address_list()]
		return
	_close_peer()
	var peer := ENetMultiplayerPeer.new()
	# Порт клиента обязателен: без него Godot игнорирует set_bind_ip и пакет уходит в tun2 вместо VPN.
	peer.set_bind_ip(local_ip)
	var error := ERR_CANT_CREATE
	for local_port in range(7780, 7790):
		error = peer.create_client(ip, PORT, 0, 0, 0, local_port)
		if error == OK:
			break
		peer.close()
		peer = ENetMultiplayerPeer.new()
		peer.set_bind_ip(local_ip)
	if error != OK:
		_status.text = "Не удалось начать подключение к %s (%s)." % [ip, error]
		return
	multiplayer.multiplayer_peer = peer
	_status.text = "Подключение к %s:%s с адреса %s..." % [ip, PORT, local_ip]
	print("Подключение к %s:%s с адреса %s" % [ip, PORT, local_ip])
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
	_status.text = "Нет ответа от %s:%s. Хост должен быть в сети, где у тебя есть свой адрес. Сейчас: %s." % [ip, PORT, _address_list()]


func _on_singleplayer_pressed() -> void:
	_close_peer()
	# Одиночная игра: просто грузим уровень без сети/сервера.
	get_tree().change_scene_to_file(LEVEL)


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


func _address_list() -> String:
	var parts: PackedStringArray = []
	for endpoint in _local_endpoints():
		parts.append("%s %s" % [endpoint["name"], endpoint["ip"]])
	if parts.is_empty():
		return "нет адресов"
	return ", ".join(parts)


# Свой IPv4, с которого маршрут до хоста реально уходит в ту же сеть.
# Пустая строка — такой сети на компьютере нет (Hamachi выключен или адрес из другой VPN).
func _bind_address_for(remote_ip: String) -> String:
	if remote_ip == "127.0.0.1":
		return "127.0.0.1"
	var best_ip := ""
	var best_bits := -1
	for endpoint in _local_endpoints():
		var bits := _common_prefix_bits(str(endpoint["ip"]), remote_ip)
		if bits > best_bits:
			best_bits = bits
			best_ip = str(endpoint["ip"])
	if best_bits >= 8:
		return best_ip
	return ""


func _local_endpoints() -> Array:
	var found: Array = []
	for iface in IP.get_local_interfaces():
		var friendly := str(iface.get("friendly", ""))
		if _skip_interface(friendly):
			continue
		var addresses: Array = iface.get("addresses", [])
		for addr in addresses:
			var ip := str(addr)
			if not ip.is_valid_ip_address() or ip.contains(":") or ip.begins_with("169.254.") or ip.begins_with("127."):
				continue
			found.append({"ip": ip, "name": friendly})
	return found


func _skip_interface(friendly: String) -> bool:
	var lowered := friendly.to_lower()
	# tun2socks и прочие прокси забирают чужие диапазоны, в том числе Hamachi 25.x.
	return lowered.contains("tun") or lowered.contains("teredo") or lowered.contains("loopback") or lowered.contains("bluetooth")


func _common_prefix_bits(left_ip: String, right_ip: String) -> int:
	var left := left_ip.split(".")
	var right := right_ip.split(".")
	if left.size() != 4 or right.size() != 4:
		return 0
	var bits := 0
	for i in 4:
		var diff := int(left[i]) ^ int(right[i])
		if diff == 0:
			bits += 8
			continue
		var mask := 128
		while mask > 0 and (diff & mask) == 0:
			bits += 1
			mask >>= 1
		break
	return bits


func _close_peer() -> void:
	var peer := multiplayer.multiplayer_peer
	if peer is ENetMultiplayerPeer:
		peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
