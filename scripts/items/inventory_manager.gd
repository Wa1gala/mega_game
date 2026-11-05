## Автолоад InventoryManager (Project Settings -> Autoload, имя "InventoryManager").
## Хранит инвентарь игрока, открытый контейнер, строит UI и обрабатывает
## drag-and-drop между слотами, выброс предмета в мир и подбор.
extends Node

signal player_inventory_changed

const PLAYER_SLOT_COUNT := 10

var player_inventory: Array[ItemData] = []   # пустые слоты = null
var _open_container: Node = null              # CabinetLarge или null

var _ui: CanvasLayer
var _player_grid: GridContainer
var _container_grid: GridContainer
var _container_title: Label
var _player_slots: Array[InventorySlot] = []
var _container_slots: Array[InventorySlot] = []
var _context_menu: PanelContainer
var _context_slot: InventorySlot = null


func _ready() -> void:
	# ALWAYS — чтобы Tab/E работали и при замороженном дереве (паузе).
	process_mode = Node.PROCESS_MODE_ALWAYS
	player_inventory.resize(PLAYER_SLOT_COUNT)
	_build_ui()
	_build_context_menu()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		_toggle_inventory()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	# Левый клик вне меню закрывает контекстное меню.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_context_menu.visible = false


# ---------- Публичные методы (CabinetLarge / PickupItem / слоты) ----------

## Положить предмет в первый свободный слот игрока.
func add_to_player(item: ItemData) -> bool:
	for i in player_inventory.size():
		if player_inventory[i] == null:
			player_inventory[i] = item
			_refresh_player_slots()
			player_inventory_changed.emit()
			return true
	return false


## Переместить/поменять предмет между двумя слотами (drag-and-drop).
func move_item(source: Array, source_index: int, target: Array, target_index: int, source_container: Node = null, target_container: Node = null) -> void:
	if _is_net() and (source_container != null or target_container != null):
		var source_cabinet := source_container as CabinetLarge
		var target_cabinet := target_container as CabinetLarge
		if source_cabinet != null and target_cabinet != null and source_cabinet == target_cabinet:
			source_cabinet.request_swap.rpc_id(1, source_index, target_index)
			return
		if source_cabinet != null:
			var offered: ItemData = target[target_index]
			source_cabinet.request_exchange.rpc_id(1, source_index, target_index, _path_of(offered))
			return
		var given: ItemData = source[source_index]
		target_cabinet.request_exchange.rpc_id(1, target_index, source_index, _path_of(given))
		return
	var src_item: ItemData = source[source_index]
	source[source_index] = target[target_index]
	target[target_index] = src_item
	_refresh_all()
	if source == player_inventory or target == player_inventory:
		player_inventory_changed.emit()


## Выбросить предмет из слота в 3D-мир (по кнопке контекстного меню).
func drop_slot(slot: InventorySlot) -> void:
	var item := slot.inventory[slot.slot_index] as ItemData
	if item == null:
		return
	var origin := Vector3(0, 1, 0)
	var impulse := Vector3.UP * 2.0
	var player := _local_player()
	if player != null:
		var forward := -player.global_transform.basis.z
		origin = player.global_position + forward * 0.9 + Vector3.UP * 0.5
		impulse = forward * 1.5 + Vector3.UP * 2.0
	if _is_net():
		var cabinet := slot.container as CabinetLarge
		if cabinet != null:
			cabinet.request_drop.rpc_id(1, slot.slot_index, origin, impulse)
			return
		slot.inventory[slot.slot_index] = null
		_refresh_all()
		player_inventory_changed.emit()
		var level := get_tree().current_scene
		if level != null and level.has_method("request_spawn_pickup"):
			level.request_spawn_pickup.rpc_id(1, item.resource_path, origin, impulse)
		return
	slot.inventory[slot.slot_index] = null
	_refresh_all()
	_spawn_pickup(item, origin, impulse)
	if slot.inventory == player_inventory:
		player_inventory_changed.emit()


func _on_slot_right_clicked(slot: InventorySlot) -> void:
	if slot.get_item() == null:
		return
	_context_slot = slot
	_context_menu.position = slot.get_global_mouse_position()
	_context_menu.visible = true


func _on_context_drop_pressed() -> void:
	if _context_slot != null:
		drop_slot(_context_slot)
	_context_slot = null
	_context_menu.visible = false


## Открыть контейнер (шкаф). Показывает UI с двумя панелями.
func open_container(container: Node) -> void:
	_open_container = container
	_rebuild_container_slots()
	_set_ui_visible(true)


func close_container() -> void:
	_open_container = null
	for s in _container_slots:
		s.queue_free()
	_container_slots.clear()
	_container_title.text = ""


# ---------- Пауза / показ UI ----------

func _toggle_inventory() -> void:
	_set_ui_visible(not _ui.visible)
	if not _ui.visible:
		close_container()


func _set_ui_visible(vis: bool) -> void:
	_ui.visible = vis
	get_tree().paused = vis
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if vis else Input.MOUSE_MODE_CAPTURED


# ---------- Выброс в мир ----------

func _local_player() -> Node3D:
	for node in get_tree().get_nodes_in_group("player"):
		var body := node as Node3D
		if body != null and body.is_multiplayer_authority():
			return body
	return null


func _spawn_pickup(item: ItemData, origin: Vector3, impulse: Vector3) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var pickup := PickupItem.new()
	pickup.item_data = item
	scene.add_child(pickup)
	pickup.global_position = origin
	pickup.apply_central_impulse(impulse)


func _is_net() -> bool:
	return multiplayer.multiplayer_peer is ENetMultiplayerPeer


func _path_of(item: ItemData) -> String:
	if item == null:
		return ""
	return item.resource_path


func _load_item(path: String) -> ItemData:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as ItemData


@rpc("authority", "reliable")
func apply_player_slot(index: int, item_path: String) -> void:
	if index < 0 or index >= player_inventory.size():
		return
	player_inventory[index] = _load_item(item_path)
	_refresh_player_slots()
	player_inventory_changed.emit()


@rpc("authority", "reliable")
func grant_item(item_path: String) -> void:
	var item := _load_item(item_path)
	if item != null:
		add_to_player(item)


func refresh_open_container(container: Node) -> void:
	if _open_container == container:
		for slot in _container_slots:
			slot.refresh()


# ---------- Построение UI ----------

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.name = "InventoryUI"
	_ui.layer = 10
	_ui.visible = false
	add_child(_ui)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	margin.add_child(hbox)

	# Левая панель — инвентарь игрока.
	var player_vbox := VBoxContainer.new()
	player_vbox.add_theme_constant_override("separation", 10)
	hbox.add_child(player_vbox)

	var player_label := Label.new()
	player_label.text = "ИНВЕНТАРЬ"
	player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_label.add_theme_font_size_override("font_size", 18)
	player_label.add_theme_color_override("font_color", Color(0.45, 1, 0.5))
	player_vbox.add_child(player_label)

	_player_grid = GridContainer.new()
	_player_grid.columns = 5
	_player_grid.add_theme_constant_override("h_separation", 8)
	_player_grid.add_theme_constant_override("v_separation", 8)
	player_vbox.add_child(_player_grid)

	# Правая панель — контейнер (шкаф).
	var cont_vbox := VBoxContainer.new()
	cont_vbox.add_theme_constant_override("separation", 10)
	hbox.add_child(cont_vbox)

	_container_title = Label.new()
	_container_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_container_title.add_theme_font_size_override("font_size", 18)
	_container_title.add_theme_color_override("font_color", Color(0.45, 1, 0.5))
	cont_vbox.add_child(_container_title)

	_container_grid = GridContainer.new()
	_container_grid.columns = 3
	_container_grid.add_theme_constant_override("h_separation", 8)
	_container_grid.add_theme_constant_override("v_separation", 8)
	cont_vbox.add_child(_container_grid)

	# Слоты игрока.
	for i in PLAYER_SLOT_COUNT:
		var slot := InventorySlot.new()
		slot.inventory = player_inventory
		slot.slot_index = i
		slot.manager = self
		slot.slot_right_clicked.connect(_on_slot_right_clicked)
		_player_grid.add_child(slot)
		_player_slots.append(slot)


func _build_context_menu() -> void:
	_context_menu = PanelContainer.new()
	_context_menu.name = "ContextMenu"
	_context_menu.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.08, 0.05, 0.95)
	style.border_color = Color(0.2, 0.55, 0.3)
	style.set_border_width_all(1)
	_context_menu.add_theme_stylebox_override("panel", style)
	_ui.add_child(_context_menu)

	var drop_btn := Button.new()
	drop_btn.text = "ВЫБРОСИТЬ"
	drop_btn.custom_minimum_size = Vector2(0, 36)
	drop_btn.add_theme_stylebox_override("normal", _make_button_style())
	drop_btn.add_theme_stylebox_override("hover", _make_button_style(Color(0.06, 0.14, 0.08)))
	drop_btn.add_theme_stylebox_override("pressed", _make_button_style(Color(0.1, 0.2, 0.12)))
	drop_btn.add_theme_color_override("font_color", Color(0.5, 0.9, 0.55))
	drop_btn.add_theme_font_size_override("font_size", 15)
	drop_btn.pressed.connect(_on_context_drop_pressed)
	_context_menu.add_child(drop_btn)


func _rebuild_container_slots() -> void:
	for s in _container_slots:
		s.queue_free()
	_container_slots.clear()

	if _open_container == null:
		return

	_container_title.text = "ШКАФ"
	var inv: Array = _open_container.inventory
	_container_grid.columns = maxi(2, ceili(sqrt(inv.size())))
	for i in inv.size():
		var slot := InventorySlot.new()
		slot.inventory = inv
		slot.slot_index = i
		slot.manager = self
		slot.container = _open_container
		slot.slot_right_clicked.connect(_on_slot_right_clicked)
		_container_grid.add_child(slot)
		_container_slots.append(slot)
		slot.refresh()


func _refresh_all() -> void:
	_refresh_player_slots()
	for s in _container_slots:
		s.refresh()


func _refresh_player_slots() -> void:
	for s in _player_slots:
		s.refresh()


func _make_panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.05, 0.03, 0.95)
	sb.border_color = Color(0.15, 0.5, 0.25)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(2)
	return sb


func _make_button_style(bg := Color(0.03, 0.08, 0.05)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = Color(0.2, 0.55, 0.3)
	sb.set_border_width_all(1)
	return sb
