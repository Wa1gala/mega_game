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

## Меню паузы сообщает сюда о своём состоянии (время в игре при этом не останавливается).
var pause_open := false
## Текущая цель взаимодействия (E) — ближайший подходящий интерактивный объект.
var _focus: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player_inventory.resize(PLAYER_SLOT_COUNT)
	_build_ui()
	_build_context_menu()


func _process(_delta: float) -> void:
	_update_focus()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory") and not pause_open:
		_toggle_inventory()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	# Левый клик вне меню закрывает контекстное меню.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_context_menu.visible = false
	elif event.is_action_pressed("interact") and is_instance_valid(_focus) and not is_ui_open():
		_focus.interact()
		get_viewport().set_input_as_handled()


## Открыто ли любое окно (инвентарь или пауза). Пока true — игрок не двигается и не стреляет.
func is_ui_open() -> bool:
	return pause_open or _ui.visible


## Закрыть всё (при выходе в лобби).
func close_all() -> void:
	pause_open = false
	if _ui.visible:
		_ui.visible = false
		close_container()
	_context_menu.visible = false
	refresh_mouse_mode()


func refresh_mouse_mode() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if is_ui_open() else Input.MOUSE_MODE_CAPTURED


# ---------- Выбор цели взаимодействия ----------

## Из всех объектов группы "interactable" выбирается один: в радиусе, ближе к игроку
## и ближе к направлению взгляда. Подсказка «E» показывается только у него.
func _update_focus() -> void:
	var best: Node = null
	if not is_ui_open():
		best = _find_best_interactable()
	if best == _focus:
		return
	if is_instance_valid(_focus):
		_focus.set_focused(false)
	_focus = best
	if is_instance_valid(_focus):
		_focus.set_focused(true)


func _find_best_interactable() -> Node:
	var player := _local_player()
	if player == null:
		return null
	var cam := get_viewport().get_camera_3d()
	var look := -cam.global_transform.basis.z if cam != null else -player.global_transform.basis.z
	var origin := player.global_position + Vector3.UP * 1.0
	var best: Node = null
	var best_score := INF
	for node in get_tree().get_nodes_in_group("interactable"):
		var target := node as Node3D
		if target == null or not target.is_inside_tree() or not node.can_interact():
			continue
		var to_target := target.global_position - origin
		var flat := Vector3(to_target.x, 0.0, to_target.z).length()
		if flat > node.interact_radius or absf(to_target.y) > 2.5:
			continue
		var facing := look.dot(to_target.normalized()) if flat > 0.01 else 1.0
		var score := flat + (1.0 - facing) * 0.5
		if score < best_score:
			best_score = score
			best = node
	return best


func _local_player() -> Node3D:
	var first: Node3D = null
	for p in get_tree().get_nodes_in_group("player"):
		if first == null:
			first = p as Node3D
		if p.is_multiplayer_authority():
			return p as Node3D
	return first


# ---------- Публичные методы (CabinetLarge / PickupItem / слоты) ----------

## Положить предмет в первый свободный слот игрока.
func add_to_player(item: ItemData) -> bool:
	if item == null:
		return false
	for i in player_inventory.size():
		if player_inventory[i] == null:
			player_inventory[i] = item
			_refresh_player_slots()
			player_inventory_changed.emit()
			return true
	return false


## Переместить/поменять предмет между двумя слотами (drag-and-drop).
func move_item(source: Array, source_index: int, target: Array, target_index: int) -> void:
	if source == target and source_index == target_index:
		return
	if source_index < 0 or source_index >= source.size() or target_index < 0 or target_index >= target.size():
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
	slot.inventory[slot.slot_index] = null
	_refresh_all()
	_spawn_pickup(item)
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
	if pause_open:
		return
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


## Время в игре не останавливается: окно лишь блокирует управление игроком.
func _set_ui_visible(vis: bool) -> void:
	_ui.visible = vis
	if not vis:
		_context_menu.visible = false
		_context_slot = null
	refresh_mouse_mode()


# ---------- Выброс в мир ----------

func _spawn_pickup(item: ItemData) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var pickup := PickupItem.new()
	pickup.item_data = item
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player != null:
		var forward := -player.global_transform.basis.z
		scene.add_child(pickup)
		pickup.global_position = player.global_position + forward * 0.9 + Vector3.UP * 0.5
		# Небольшой импульс вперёд и вверх — папка падает на пол.
		pickup.apply_central_impulse(forward * 1.5 + Vector3.UP * 2.0)
	else:
		scene.add_child(pickup)
		pickup.global_position = Vector3(0, 1, 0)


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
