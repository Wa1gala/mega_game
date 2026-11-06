## Автолоад InventoryManager (Project Settings -> Autoload, имя "InventoryManager").
## Хранит инвентарь игрока (рюкзак + карманы), открытый контейнер, строит UI:
## слева статичная 3D-модель персонажа и слоты экипировки, по центру рюкзак
## и карманы. Обрабатывает drag-and-drop, выброс предмета в мир и подбор.
extends Node

signal player_inventory_changed

const BACKPACK_COLUMNS := 7
const BACKPACK_ROWS := 4
const BACKPACK_SLOT_COUNT := BACKPACK_COLUMNS * BACKPACK_ROWS   # 28

const POCKET_COUNT := 5

const POCKET_COLUMNS := 5
const WEAPON_SLOT := &"weapon"

const SLOT_SIZE := 64          # базовая ячейка (дальше подбирается под экран)
const MIN_SLOT_SIZE := 36
const MAX_SLOT_SIZE := 72
const ROOT_MARGIN := 16
const COLUMN_GAP := 14
const CHARACTER_COLUMN_CELLS := 6   # ширина колонки персонажа в ячейках
const CONTAINER_MAX_COLUMNS := 6

const CHARACTER_SCENE := preload("res://art/characters/player/male_casual.fbx")
const IDLE_SCENE := preload("res://art/characters/player/Idle.fbx")
const IDLE_POSE_TIME := 0.6      # кадр, на котором фиксируем позу

var player_inventory: Array[ItemData] = []   # рюкзак, пустые слоты = null
var player_pockets: Array[ItemData] = []     # карманы
var player_weapon: Array[ItemData] = []      # слот оружия (1 элемент)
var _weapon_slot: InventorySlot
var _open_container: Node = null              # CabinetLarge или null

var _ui: CanvasLayer
var _backpack_grid: GridContainer
var _pocket_grid: GridContainer
var _container_grid: GridContainer
var _container_panel: Control
var _container_header: Control
var _container_columns := CONTAINER_MAX_COLUMNS
var _mid_spring: Control
var _root: Control
var _cell := SLOT_SIZE
var _equip_controls: Array[Dictionary] = []
var _character_frame: PanelContainer
var _backpack_slots: Array[InventorySlot] = []
var _pocket_slots: Array[InventorySlot] = []
var _container_slots: Array[InventorySlot] = []
var _context_menu: PanelContainer
var _context_slot: InventorySlot = null

## Меню паузы сообщает сюда о своём состоянии (время в игре при этом не останавливается).
var pause_open := false
## Текущая цель взаимодействия (E) — ближайший подходящий интерактивный объект.
var _focus: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player_inventory.resize(BACKPACK_SLOT_COUNT)
	player_pockets.resize(POCKET_COUNT)
	player_weapon.resize(1)
	player_weapon[0] = load("res://resources/items/rifle.tres") as ItemData   # стартовое оружие
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

## Положить предмет: оружие — в пустой слот оружия, иначе первое подходящее место
## в рюкзаке, затем в карманах (крупные предметы ищут свободный прямоугольник).
func add_to_player(item: ItemData) -> bool:
	if item == null:
		return false
	if item.equip_slot == WEAPON_SLOT and player_weapon[0] == null:
		player_weapon[0] = item
	elif not _place_first_free(player_inventory, item) and not _place_first_free(player_pockets, item):
		return false
	_refresh_all()
	player_inventory_changed.emit()
	return true


func has_weapon() -> bool:
	return player_weapon.size() > 0 and player_weapon[0] != null


# ---------- Сетка: предметы больше одной ячейки ----------
# В массиве предмет лежит только в «якорной» ячейке (левый верхний угол),
# остальные ячейки его прямоугольника в массиве пустые, но заняты.

func _cols(arr: Array) -> int:
	if is_same(arr, player_weapon):
		return 1
	if is_same(arr, player_inventory):
		return BACKPACK_COLUMNS
	if is_same(arr, player_pockets):
		return POCKET_COLUMNS
	return maxi(_container_columns, 1)


func _item_size(arr: Array, item: ItemData) -> Vector2i:
	if is_same(arr, player_weapon):
		return Vector2i(1, 1)   # слот оружия один, предмет занимает его целиком
	return Vector2i(maxi(item.grid_size.x, 1), maxi(item.grid_size.y, 1))


func _item_rect(arr: Array, index: int, item: ItemData) -> Rect2i:
	var cols := _cols(arr)
	return Rect2i(Vector2i(index % cols, index / cols), _item_size(arr, item))


## Якорь предмета, которому принадлежит ячейка index (или сама ячейка, если там якорь). -1 — пусто.
func anchor_index(arr: Array, index: int) -> int:
	if index < 0 or index >= arr.size():
		return -1
	if arr[index] != null:
		return index
	var cols := _cols(arr)
	var cell := Vector2i(index % cols, index / cols)
	for i in arr.size():
		if arr[i] != null and _item_rect(arr, i, arr[i]).has_point(cell):
			return i
	return -1


## На сколько клеток от якоря находится ячейка, за которую взяли предмет.
func grab_offset(arr: Array, index: int, anchor: int) -> Vector2i:
	var cols := _cols(arr)
	return Vector2i(index % cols - anchor % cols, index / cols - anchor / cols)


## Якоря предметов, пересекающихся с прямоугольником item в клетке cell.
## null — прямоугольник выходит за границы сетки. ignore_* — якоря, которые не считаются.
func _overlaps(arr: Array, item: ItemData, cell: Vector2i, ignore_a := -1, ignore_b := -1) -> Variant:
	var cols := _cols(arr)
	var rows := ceili(float(arr.size()) / float(cols))
	var size := _item_size(arr, item)
	if cell.x < 0 or cell.y < 0 or cell.x + size.x > cols or cell.y + size.y > rows:
		return null
	var rect := Rect2i(cell, size)
	var found: Array[int] = []
	for i in arr.size():
		if arr[i] == null or i == ignore_a or i == ignore_b:
			continue
		if rect.intersects(_item_rect(arr, i, arr[i])):
			found.append(i)
	return found


func _place_first_free(arr: Array, item: ItemData) -> bool:
	var cols := _cols(arr)
	for i in arr.size():
		var found: Variant = _overlaps(arr, item, Vector2i(i % cols, i / cols))
		if found != null and (found as Array).is_empty():
			arr[i] = item
			return true
	return false


## План перемещения: {"dest": индекс якоря в целевом массиве, "swap": якорь вытесняемого
## предмета или -1}. Пустой словарь — перемещение невозможно.
func _plan_move(source: Array, si: int, target: Array, ti: int, grab := Vector2i.ZERO) -> Dictionary:
	if si < 0 or si >= source.size() or ti < 0 or ti >= target.size():
		return {}
	var item: ItemData = source[si]
	if item == null:
		return {}
	if is_same(target, player_weapon):
		grab = Vector2i.ZERO
		if item.equip_slot != WEAPON_SLOT:
			return {}
	var tcols := _cols(target)
	var cell := Vector2i(ti % tcols, ti / tcols) - grab
	var same := is_same(source, target)
	var overlap: Variant = _overlaps(target, item, cell, si if same else -1)
	if overlap == null:
		return {}
	var hit := overlap as Array
	var dest := cell.y * tcols + cell.x
	if hit.is_empty():
		return {"dest": dest, "swap": -1}
	if hit.size() > 1:
		return {}

	# Ровно один предмет мешает — меняем местами, если он встанет на место исходного.
	var other_index: int = hit[0]
	var other: ItemData = target[other_index]
	if is_same(source, player_weapon) and other.equip_slot != WEAPON_SLOT:
		return {}
	var scols := _cols(source)
	var back_cell := Vector2i(si % scols, si / scols)
	var blocked: Variant = _overlaps(source, other, back_cell, si, other_index if same else -1)
	if blocked == null or not (blocked as Array).is_empty():
		return {}
	if same and Rect2i(back_cell, _item_size(source, other)).intersects(Rect2i(cell, _item_size(target, item))):
		return {}
	return {"dest": dest, "swap": other_index}


## Можно ли положить предмет в слот (drag-and-drop подсвечивает допустимость).
func can_move(source: Array, source_index: int, target: Array, target_index: int,
		grab := Vector2i.ZERO) -> bool:
	return not _plan_move(source, source_index, target, target_index, grab).is_empty()


## Переместить/поменять предмет между слотами (drag-and-drop).
func move_item(source: Array, source_index: int, target: Array, target_index: int,
		grab := Vector2i.ZERO) -> void:
	var plan := _plan_move(source, source_index, target, target_index, grab)
	if plan.is_empty():
		return
	var moving: ItemData = source[source_index]
	source[source_index] = null
	var other: ItemData = null
	if plan["swap"] >= 0:
		other = target[plan["swap"]]
		target[plan["swap"]] = null
	target[plan["dest"]] = moving
	if other != null:
		source[source_index] = other
	_refresh_all()
	if _is_player_array(source) or _is_player_array(target):
		player_inventory_changed.emit()


## Выбросить предмет из слота в 3D-мир (по кнопке контекстного меню).
func drop_slot(slot: InventorySlot) -> void:
	var anchor := anchor_index(slot.inventory, slot.slot_index)
	if anchor < 0:
		return
	var item := slot.inventory[anchor] as ItemData
	slot.inventory[anchor] = null
	_refresh_all()
	_spawn_pickup(item)
	if _is_player_array(slot.inventory):
		player_inventory_changed.emit()


func _on_slot_right_clicked(slot: InventorySlot) -> void:
	if anchor_index(slot.inventory, slot.slot_index) < 0:
		return
	_context_slot = slot
	_context_menu.visible = true
	_context_menu.reset_size()
	# Меню открывается над курсором (не перекрывается предметами) и не выходит за экран.
	var mouse := slot.get_global_mouse_position()
	var screen := _root.size
	var pos := mouse - Vector2(0, _context_menu.size.y + 2.0)
	pos.x = clampf(pos.x, 0.0, maxf(screen.x - _context_menu.size.x, 0.0))
	pos.y = clampf(pos.y, 0.0, maxf(screen.y - _context_menu.size.y, 0.0))
	_context_menu.position = pos


func _on_context_drop_pressed() -> void:
	if _context_slot != null:
		drop_slot(_context_slot)
	_context_slot = null
	_context_menu.visible = false


func _is_player_array(arr: Array) -> bool:
	return is_same(arr, player_inventory) or is_same(arr, player_pockets) or is_same(arr, player_weapon)


## Открыть контейнер (шкаф). Показывает панель контейнера справа.
func open_container(container: Node) -> void:
	if pause_open:
		return
	_open_container = container
	_rebuild_container_slots()
	_set_container_shown(true)
	_set_ui_visible(true)
	_apply_layout()


func close_container() -> void:
	_open_container = null
	for s in _container_slots:
		_container_grid.remove_child(s)
		s.queue_free()
	_container_slots.clear()
	_set_container_shown(false)
	_apply_layout()


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
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(dim)

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.resized.connect(_apply_layout)
	_ui.add_child(_root)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", ROOT_MARGIN)
	margin.add_theme_constant_override("margin_right", ROOT_MARGIN)
	margin.add_theme_constant_override("margin_top", ROOT_MARGIN)
	margin.add_theme_constant_override("margin_bottom", ROOT_MARGIN)
	_root.add_child(margin)

	# [пружина] [персонаж + рюкзак] [пружина] [контейнер] [пружина]
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 0)
	margin.add_child(row)

	row.add_child(_make_spring())

	var main := HBoxContainer.new()
	main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.size_flags_vertical = Control.SIZE_SHRINK_BEGIN   # оба блока выровнены по верхнему краю
	main.add_theme_constant_override("separation", COLUMN_GAP)
	row.add_child(main)
	main.add_child(_build_character_column())
	main.add_child(_build_center_column())

	_mid_spring = Control.new()   # фиксированный зазор между инвентарём и шкафом
	_mid_spring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mid_spring.custom_minimum_size.x = COLUMN_GAP * 2
	row.add_child(_mid_spring)

	_container_panel = _build_container_column()
	_set_container_shown(false)
	row.add_child(_container_panel)

	row.add_child(_make_spring())


func _make_spring() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


## Панель шкафа всегда занимает своё место; закрытая — прозрачная и не ловит мышь.
func _set_container_shown(shown: bool) -> void:
	_container_panel.modulate.a = 1.0 if shown else 0.0
	_container_header.mouse_filter = Control.MOUSE_FILTER_STOP if shown else Control.MOUSE_FILTER_IGNORE


## Размер ячейки подбирается под текущий размер окна, чтобы всё помещалось.
func _apply_layout() -> void:
	if _root == null or _container_panel == null or _character_frame == null:
		return
	# Место под панель контейнера резервируется всегда, чтобы масштаб и положение
	# инвентаря не прыгали, когда шкаф открывается или закрывается.
	var cols := CHARACTER_COLUMN_CELLS + BACKPACK_COLUMNS + CONTAINER_MAX_COLUMNS
	var fixed := float(ROOT_MARGIN * 2 + COLUMN_GAP * 3 + 6 + 8 + 4)
	var by_width := (_root.size.x - fixed) / float(cols)
	# По высоте: колонка персонажа = 5 ячеек + оружие 2 ячейки + отступы.
	var by_height := (_root.size.y - ROOT_MARGIN * 2 - 24.0) / 7.6
	var s := clampi(int(floorf(minf(by_width, by_height))), MIN_SLOT_SIZE, MAX_SLOT_SIZE)
	_cell = s
	_container_panel.custom_minimum_size.x = float(CONTAINER_MAX_COLUMNS * s + 1)

	for slot in _all_slots():
		slot.set_slot_size(s)
	for e in _equip_controls:
		var ctrl := e["control"] as Control
		var cells: Vector2 = e["cells"]
		ctrl.custom_minimum_size = Vector2(cells.x * s, cells.y * s)
		var icon := e["icon"] as Label
		icon.add_theme_font_size_override("font_size", maxi(14, int(s * 0.5)))
		var title := e["title"] as Label
		title.add_theme_font_size_override("font_size", maxi(8, int(s * 0.17)))
	_character_frame.custom_minimum_size = Vector2(4 * s, 5 * s)


func _all_slots() -> Array[InventorySlot]:
	var all: Array[InventorySlot] = []
	all.append_array(_backpack_slots)
	all.append_array(_pocket_slots)
	all.append_array(_container_slots)
	if _weapon_slot != null:
		all.append(_weapon_slot)
	return all


## Левая колонка: персонаж в центре, броня и нож сбоку, оружие снизу
## (пропорции как в Tarkov: размеры слотов кратны ячейке).
func _build_character_column() -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	vbox.add_child(top)

	_character_frame = PanelContainer.new()
	_character_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_character_frame.add_theme_stylebox_override("panel", _make_panel_style(
		Color(0.03, 0.04, 0.045), Color(0.22, 0.24, 0.26), 0))
	top.add_child(_character_frame)
	_character_frame.add_child(_build_character_viewport())

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 6)
	top.add_child(side)
	var armor := _make_equip_slot("БРОНЯ", Vector2(2, 3))
	armor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	armor.size_flags_stretch_ratio = 3.0
	side.add_child(armor)
	var knife := _make_equip_slot("НОЖ", Vector2(2, 2))
	knife.size_flags_vertical = Control.SIZE_EXPAND_FILL
	knife.size_flags_stretch_ratio = 2.0
	side.add_child(knife)

	# Оружие — широкий слот на всю ширину колонки.
	_weapon_slot = _make_slot(player_weapon, 0, SLOT_SIZE, vbox)
	_weapon_slot.slot_cells = Vector2(CHARACTER_COLUMN_CELLS, 2)
	_weapon_slot.accepts = WEAPON_SLOT
	_weapon_slot.placeholder = "ОРУЖИЕ"
	_weapon_slot.set_slot_size(SLOT_SIZE)
	_weapon_slot.refresh()

	return vbox


func _build_character_viewport() -> SubViewportContainer:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vp := SubViewport.new()
	vp.size = Vector2i(300, 380)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	container.add_child(vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.68)
	env.ambient_light_energy = 1.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	vp.add_child(world_env)

	var cam := Camera3D.new()
	cam.current = true
	cam.fov = 40.0
	cam.position = Vector3(0.0, 0.95, 2.7)
	vp.add_child(cam)
	cam.look_at(Vector3(0.0, 0.9, 0.0))

	# Модель смотрит в +Z (на камеру), поэтому ключевой свет — спереди, контровой — сзади.
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-28, 35, 0)
	key.light_energy = 1.5
	key.shadow_enabled = true
	vp.add_child(key)

	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15, 140, 0)
	rim.light_color = Color(0.6, 0.75, 1.0)
	rim.light_energy = 0.8
	vp.add_child(rim)

	# Статичная модель персонажа в позе ожидания, лицом к камере.
	var model := CHARACTER_SCENE.instantiate() as Node3D
	if model != null:
		vp.add_child(model)
		_apply_static_idle_pose(model)

	return container


## Базовый FBX без анимаций даёт T-позу. Подмешиваем позу из Idle.fbx
## и замираем на одном кадре — модель должна выглядеть статично.
func _apply_static_idle_pose(model: Node3D) -> void:
	var root := IDLE_SCENE.instantiate()
	var source := root.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if source == null or not source.has_animation("mixamo_com"):
		root.free()
		return
	var idle := source.get_animation("mixamo_com").duplicate() as Animation
	root.free()
	if idle == null:
		return

	var player := AnimationPlayer.new()
	player.name = "IdlePose"
	player.root_node = NodePath("..")
	model.add_child(player)

	var library := AnimationLibrary.new()
	library.add_animation(&"idle", idle)
	player.add_animation_library(&"", library)

	player.play(&"idle")
	player.seek(IDLE_POSE_TIME, true)
	player.pause()


## Слот экипировки. Пока предметов не надеваем — заглушка. cells — размер в ячейках.
func _make_equip_slot(title: String, cells: Vector2) -> Control:
	var slot := PanelContainer.new()
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.add_theme_stylebox_override("panel", _make_panel_style(
		Color(0.07, 0.078, 0.086, 0.92), Color(0.24, 0.27, 0.29), 0))

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 0)
	slot.add_child(vbox)

	var icon := Label.new()
	icon.text = "—"
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_color_override("font_color", Color(0.30, 0.33, 0.35))
	vbox.add_child(icon)

	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.42, 0.44, 0.46))
	vbox.add_child(label)

	_equip_controls.append({"control": slot, "cells": cells, "icon": icon, "title": label})
	return slot


## Центральная колонка: рюкзак и карманы.
func _build_center_column() -> Control:
	var vbox := VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	vbox.add_theme_constant_override("separation", 14)

	var backpack := VBoxContainer.new()
	backpack.add_theme_constant_override("separation", 6)
	vbox.add_child(backpack)
	backpack.add_child(_make_section_header("РЮКЗАК", "%d слотов" % BACKPACK_SLOT_COUNT))
	_backpack_grid = _make_grid(BACKPACK_COLUMNS, backpack)
	for i in BACKPACK_SLOT_COUNT:
		_backpack_slots.append(_make_slot(player_inventory, i, SLOT_SIZE, _backpack_grid))

	var pockets := VBoxContainer.new()
	pockets.add_theme_constant_override("separation", 6)
	vbox.add_child(pockets)
	pockets.add_child(_make_section_header("КАРМАНЫ", "%d" % POCKET_COUNT))
	_pocket_grid = _make_grid(POCKET_COLUMNS, pockets)
	for i in POCKET_COUNT:
		_pocket_slots.append(_make_slot(player_pockets, i, SLOT_SIZE, _pocket_grid))

	return vbox


## Сетка ячеек без промежутков внутри рамки: линии между ячейками общие.
## Рамка рисует левую и верхнюю границу, ячейки — правую и нижнюю.
func _make_grid(columns: int, parent: Node) -> GridContainer:
	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color(0.24, 0.27, 0.29)
	sb.border_width_left = 1
	sb.border_width_top = 1
	frame.add_theme_stylebox_override("panel", sb)
	parent.add_child(frame)

	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	frame.add_child(grid)
	return grid


func _make_section_header(title: String, hint: String) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_panel_style(
		Color(0.06, 0.07, 0.08), Color(0.20, 0.22, 0.24)))

	var hbox := HBoxContainer.new()
	panel.add_child(hbox)

	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.55, 0.58, 0.61))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)

	var hint_label := Label.new()
	hint_label.text = hint
	hint_label.add_theme_font_size_override("font_size", 12)
	hint_label.add_theme_color_override("font_color", Color(0.38, 0.40, 0.43))
	hbox.add_child(hint_label)

	return panel


func _make_slot(inv: Array, index: int, size: int, parent: Node) -> InventorySlot:
	var slot := InventorySlot.new()
	slot.inventory = inv
	slot.slot_index = index
	slot.manager = self
	slot.set_slot_size(size)
	slot.slot_right_clicked.connect(_on_slot_right_clicked)
	parent.add_child(slot)
	return slot


## Панель открытого контейнера (шкаф) — справа, как в Tarkov.
func _build_container_column() -> Control:
	var vbox := VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	vbox.add_theme_constant_override("separation", 6)

	_container_header = _make_section_header("ШКАФ", "")
	vbox.add_child(_container_header)
	_container_grid = _make_grid(_container_columns, vbox)
	return vbox


func _build_context_menu() -> void:
	_context_menu = PanelContainer.new()
	_context_menu.name = "ContextMenu"
	_context_menu.visible = false
	_context_menu.z_index = 100   # выше подсвеченных предметов (у них z_index = 1)
	_context_menu.z_as_relative = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.08, 0.96)
	style.border_color = Color(0.3, 0.33, 0.36)
	style.set_border_width_all(1)
	_context_menu.add_theme_stylebox_override("panel", style)
	_ui.add_child(_context_menu)

	var drop_btn := Button.new()
	drop_btn.text = "ВЫБРОСИТЬ"
	drop_btn.custom_minimum_size = Vector2(0, 22)
	drop_btn.add_theme_stylebox_override("normal", _make_button_style())
	drop_btn.add_theme_stylebox_override("hover", _make_button_style(Color(0.14, 0.15, 0.17)))
	drop_btn.add_theme_stylebox_override("pressed", _make_button_style(Color(0.2, 0.22, 0.24)))
	drop_btn.add_theme_color_override("font_color", Color(0.78, 0.8, 0.82))
	drop_btn.add_theme_font_size_override("font_size", 11)
	drop_btn.pressed.connect(_on_context_drop_pressed)
	_context_menu.add_child(drop_btn)


func _rebuild_container_slots() -> void:
	for s in _container_slots:
		_container_grid.remove_child(s)
		s.queue_free()
	_container_slots.clear()

	if _open_container == null:
		return

	var inv: Array = _open_container.inventory
	_container_columns = mini(CONTAINER_MAX_COLUMNS, maxi(inv.size(), 1))
	_container_grid.columns = _container_columns
	_set_container_header(inv.size())
	for i in inv.size():
		var slot := _make_slot(inv, i, _cell, _container_grid)
		_container_slots.append(slot)
		slot.refresh()


func _set_container_header(count: int) -> void:
	var hbox := _container_header.get_child(0) as HBoxContainer
	(hbox.get_child(0) as Label).text = "ШКАФ"
	(hbox.get_child(1) as Label).text = "%d слотов" % count


func _refresh_all() -> void:
	for s in _all_slots():
		s.refresh()


func _make_panel_style(bg := Color(0.05, 0.055, 0.06),
		brd := Color(0.22, 0.24, 0.26), margin := 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = brd
	sb.set_border_width_all(1)
	sb.content_margin_left = 10 if margin > 0 else 1
	sb.content_margin_top = margin if margin > 0 else 1
	sb.content_margin_right = 10 if margin > 0 else 1
	sb.content_margin_bottom = margin if margin > 0 else 1
	return sb


func _make_button_style(bg := Color(0.10, 0.11, 0.12)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = Color(0.3, 0.33, 0.36)
	sb.set_border_width_all(1)
	return sb
