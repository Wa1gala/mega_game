## Автолоад InventoryManager (Project Settings -> Autoload, имя "InventoryManager").
## Хранит инвентарь игрока (экипировка, рюкзак, карманы), открытый контейнер и строит UI
## в духе Escape from Tarkov: слева заглушка персонажа и слоты экипировки, по центру
## рюкзак и карманы, справа (при открытии шкафа) его содержимое. Правила размещения
## предметов (в том числе больше одной ячейки), выброс в мир и подбор — здесь же.
extends Node

signal player_inventory_changed

const BACKPACK_COLUMNS := 7
const BACKPACK_ROWS := 4
const BACKPACK_SLOT_COUNT := BACKPACK_COLUMNS * BACKPACK_ROWS   # 28

const POCKET_COUNT := 5
const POCKET_COLUMNS := 5

## Слоты экипировки (значение ItemData.equip_slot).
const WEAPON_SLOT := &"weapon"
const BACKPACK_SLOT := &"backpack"
const ARMOR_SLOT := &"armor"
const KNIFE_SLOT := &"knife"

const SLOT_SIZE := 64          # базовая ячейка (дальше подбирается под экран)
const MIN_SLOT_SIZE := 36
const MAX_SLOT_SIZE := 72
const ROOT_MARGIN := 16
const COLUMN_GAP := 14
const GAP := 6                 # промежутки между блоками внутри колонки
const CHARACTER_COLUMN_CELLS := 6   # ширина колонки персонажа в ячейках
const CONTAINER_MAX_COLUMNS := 6

# Вес: базовая грузоподъёмность + бонус надетого рюкзака (ItemData.carry_bonus).
const BASE_CARRY_WEIGHT := 25.0         # кг
const OVERWEIGHT_SLOW_MIN := 0.35       # множитель скорости на пределе перегруза
const HARD_LIMIT_RATIO := 1.5           # больше этой доли от нормы подобрать уже нельзя
const TIP_DELAY := 0.1                  # задержка показа подсказки, сек
const TIP_MAX_WIDTH := 220.0
const SEARCH_STEP := 0.55                # секунд на обыск одного предмета
const AIM_MIN_DOT := 0.97               # ~14 градусов от центра экрана

const PANEL_BG := Color(0.05, 0.06, 0.065, 0.62)
const PANEL_BORDER := Color(0.62, 0.68, 0.68, 0.20)

var player_inventory: Array[ItemData] = []   # рюкзак, пустые слоты = null
var player_pockets: Array[ItemData] = []     # карманы
var player_weapon: Array[ItemData] = []      # слот оружия (1 элемент)
var player_backpack: Array[ItemData] = []    # слот рюкзака (1 элемент)
var player_armor: Array[ItemData] = []       # слот брони (1 элемент)
var player_knife: Array[ItemData] = []       # слот ножа (1 элемент)
var _equip := {}                              # имя слота -> массив слота экипировки
const CONTAINER_SOUND := preload("res://audio/items/containers/open_close.wav")
var _container_sfx: AudioStreamPlayer
var _open_container: Node = null              # LootContainer или null

var _ui: CanvasLayer
var _root: Control
var _backpack_grid: InventoryGrid
var _pocket_grid: InventoryGrid
var _container_grid: InventoryGrid
var _equip_grids: Array[InventoryGrid] = []
var _container_panel: Control
var _container_header: Control
var _container_columns := CONTAINER_MAX_COLUMNS
var _character_frame: PanelContainer
var _weight_label: Label
var _message_label: Label
var _message_tween: Tween
var _search_time := 0.0
var _silhouette: Control
var _tip: PanelContainer
var _tip_box: VBoxContainer
var _tip_delay := 0.0
var _tip_pending := false
var _cell := SLOT_SIZE
var _context_menu: PanelContainer
var _context_grid: InventoryGrid = null
var _context_anchor := -1
var _use_btn: Button

## Меню паузы сообщает сюда о своём состоянии (время в игре при этом не останавливается).
var pause_open := false
## Текущая цель взаимодействия (E) — ближайший подходящий интерактивный объект.
var _focus: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_container_sfx = AudioStreamPlayer.new()
	_container_sfx.stream = CONTAINER_SOUND
	_container_sfx.volume_db = -4.0
	add_child(_container_sfx)
	player_inventory.resize(BACKPACK_SLOT_COUNT)
	player_pockets.resize(POCKET_COUNT)
	for arr in [player_weapon, player_backpack, player_armor, player_knife]:
		arr.resize(1)
	_equip = {
		WEAPON_SLOT: player_weapon,
		BACKPACK_SLOT: player_backpack,
		ARMOR_SLOT: player_armor,
		KNIFE_SLOT: player_knife,
	}
	player_weapon[0] = load("res://resources/items/rifle.tres") as ItemData      # стартовое оружие
	player_backpack[0] = load("res://resources/items/backpack.tres") as ItemData  # надетый рюкзак
	_build_ui()
	_build_context_menu()
	_refresh_all()
	_apply_layout()   # размеры колонок сразу, а не после первого открытия шкафа


func _process(delta: float) -> void:
	_update_focus()
	_update_prompt()
	_tick_search(delta)
	_tick_tooltip(delta)


# ---------- Подсказка взаимодействия над объектом ----------
# Полупрозрачная плашка на экране: [иконка клавиши] Действие  Название.
# Объект сообщает текст через prompt_info(), точку — через focus_point().

var _prompt: PanelContainer
var _prompt_key: Label
var _prompt_verb: Label
var _prompt_name: Label


func _build_prompt() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5   # ниже инвентаря (10), выше игрового HUD
	add_child(layer)

	_prompt = PanelContainer.new()
	_prompt.visible = false
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.04, 0.045, 0.05, 0.62)
	bg.border_color = Color(1, 1, 1, 0.12)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(2)
	bg.content_margin_left = 3
	bg.content_margin_right = 6
	bg.content_margin_top = 3
	bg.content_margin_bottom = 3
	_prompt.add_theme_stylebox_override("panel", bg)
	layer.add_child(_prompt)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	_prompt.add_child(row)

	# Иконка клавиши: светлый скруглённый квадрат с буквой.
	var key_box := PanelContainer.new()
	key_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key_box.custom_minimum_size = Vector2(12, 12)
	var key_bg := StyleBoxFlat.new()
	key_bg.bg_color = Color(0.82, 0.84, 0.85, 0.92)
	key_bg.set_corner_radius_all(2)
	key_box.add_theme_stylebox_override("panel", key_bg)
	row.add_child(key_box)
	_prompt_key = Label.new()
	_prompt_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_key.add_theme_font_size_override("font_size", 9)
	_prompt_key.add_theme_color_override("font_color", Color(0.1, 0.11, 0.12))
	key_box.add_child(_prompt_key)

	_prompt_verb = Label.new()
	_prompt_verb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_verb.add_theme_font_size_override("font_size", 9)
	_prompt_verb.add_theme_color_override("font_color", Color(0.8, 0.82, 0.83))
	row.add_child(_prompt_verb)

	_prompt_name = Label.new()
	_prompt_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_name.add_theme_font_size_override("font_size", 9)
	row.add_child(_prompt_name)


## Название клавиши действия "interact" (по умолчанию E).
func _interact_key_text() -> String:
	for ev in InputMap.action_get_events("interact"):
		if ev is InputEventKey:
			var key := ev as InputEventKey
			var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
			return OS.get_keycode_string(code)
	return "E"


func _update_prompt() -> void:
	var cam := get_viewport().get_camera_3d()
	if not is_instance_valid(_focus) or is_ui_open() or cam == null or not _focus.has_method("prompt_info"):
		_prompt.visible = false
		return
	var point: Vector3 = _focus.focus_point() if _focus.has_method("focus_point") \
			else (_focus as Node3D).global_position
	point += Vector3.UP * 0.3
	if cam.is_position_behind(point):
		_prompt.visible = false
		return

	var info: Dictionary = _focus.prompt_info()
	var key_text := _interact_key_text()
	if _prompt_key.text != key_text:
		_prompt_key.text = key_text
	if _prompt_verb.text != str(info.get("verb", "")):
		_prompt_verb.text = str(info.get("verb", ""))
	if _prompt_name.text != str(info.get("name", "")):
		_prompt_name.text = str(info.get("name", ""))
	_prompt_name.add_theme_color_override("font_color",
			Color(1.0, 0.62, 0.35) if info.get("warn", false) else Color(0.96, 0.97, 0.98))

	_prompt.visible = true
	_prompt.reset_size()
	var screen := cam.unproject_position(point)
	var vp := get_viewport().get_visible_rect().size
	screen.x = clampf(screen.x - _prompt.size.x * 0.5, 8.0, maxf(vp.x - _prompt.size.x - 8.0, 8.0))
	screen.y = clampf(screen.y - _prompt.size.y, 8.0, maxf(vp.y - _prompt.size.y - 8.0, 8.0))
	_prompt.position = screen


# ---------- Подсказка о предмете ----------
# Своя, а не встроенная: следует за курсором, один полупрозрачный фон, длинный текст обрезается «…».

func show_item_tooltip(item: ItemData) -> void:
	if _tip == null or item == null:
		return
	for c in _tip_box.get_children():
		_tip_box.remove_child(c)   # сразу, иначе старые строки ещё считаются в размере
		c.queue_free()
	var lines: Array[Array] = [[item.name, 12, Color(0.88, 0.9, 0.9)]]
	if item.description != "":
		lines.append([item.description, 10, Color(0.6, 0.64, 0.64)])
	if item.heal_amount > 0:
		lines.append(["Лечит: +%d здоровья (постепенно)" % item.heal_amount, 10, Color(0.45, 0.8, 0.4)])
	lines.append(["Вес: %.2f кг" % item.weight, 10, Color(0.6, 0.64, 0.64)])
	var font := ThemeDB.fallback_font
	var width := 90.0
	for l in lines:
		width = maxf(width, font.get_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, l[1]).x)
	width = minf(width, TIP_MAX_WIDTH)
	for l in lines:
		var lab := Label.new()
		lab.text = l[0]
		lab.clip_text = true
		lab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		lab.custom_minimum_size.x = width
		lab.add_theme_font_size_override("font_size", l[1])
		lab.add_theme_color_override("font_color", l[2])
		_tip_box.add_child(lab)
	_tip.reset_size()
	_tip.visible = false
	_tip_pending = true
	_tip_delay = TIP_DELAY


func hide_item_tooltip() -> void:
	_tip_pending = false
	if _tip != null:
		_tip.visible = false


func _tick_tooltip(delta: float) -> void:
	if _tip == null or not _ui.visible:
		return
	if _tip_pending:
		_tip_delay -= delta
		if _tip_delay <= 0.0:
			_tip_pending = false
			_tip.visible = true
	if _tip.visible:
		var m := _root.get_local_mouse_position() + Vector2(16, 20)
		var sz := _tip.get_combined_minimum_size()
		if m.x + sz.x > _root.size.x:
			m.x = _root.get_local_mouse_position().x - sz.x - 10.0
		m.y = minf(m.y, _root.size.y - sz.y)
		_tip.size = sz   # размер строго по содержимому (панель сама не сжимается)
		_tip.position = m


## Обыск контейнера: предметы открываются по одному, слева направо и сверху вниз.
func _tick_search(delta: float) -> void:
	if _open_container == null or not _ui.visible:
		return
	var hidden: Dictionary = _open_container.unrevealed
	if hidden.is_empty():
		return
	_search_time += delta
	if _search_time < SEARCH_STEP:
		return
	_search_time = 0.0
	var first := -1
	for k in hidden:
		if first < 0 or int(k) < first:
			first = int(k)
	hidden.erase(first)
	_container_grid.refresh()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory") and not pause_open:
		_toggle_inventory()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R \
			and _ui.visible and not pause_open:
		if not drag_data.is_empty() and get_viewport().gui_is_dragging():
			_rotate_dragged()
		else:
			_rotate_hovered()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	# Левый клик вне меню закрывает контекстное меню.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_context_menu()
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
	close_context_menu()
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
	var eye := cam.global_position if cam != null else player.global_position + Vector3.UP * 1.6
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
		# Подсказка только у предмета, на который наведён взгляд (прицел по центру экрана).
		var point: Vector3 = node.focus_point() if node.has_method("focus_point") else target.global_position
		var facing := look.dot((point - eye).normalized())
		if facing < AIM_MIN_DOT:
			continue
		var score := flat + (1.0 - facing) * 8.0
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


# ---------- Публичные методы (LootContainer / PickupItem / сетки) ----------

func has_weapon() -> bool:
	return player_weapon.size() > 0 and player_weapon[0] != null


func has_backpack() -> bool:
	return player_backpack.size() > 0 and player_backpack[0] != null


# ---------- Вес ----------

func _player_arrays() -> Array:
	return [player_inventory, player_pockets, player_weapon, player_backpack, player_armor, player_knife]


func get_total_weight() -> float:
	var total := 0.0
	for arr in _player_arrays():
		for it in arr:
			if it != null:
				total += (it as ItemData).weight
	return total


func get_max_weight() -> float:
	var m := BASE_CARRY_WEIGHT
	for arr in _equip.values():
		if (arr as Array)[0] != null:
			m += ((arr as Array)[0] as ItemData).carry_bonus
	return m


func _weight_ratio() -> float:
	return get_total_weight() / maxf(get_max_weight(), 0.1)


func is_overweight() -> bool:
	return _weight_ratio() > 1.0


## Перегруз: бегать нельзя.
func can_sprint() -> bool:
	return not is_overweight()


## Множитель скорости ходьбы: 1 в норме, плавно падает до минимума к 150% веса.
func speed_multiplier() -> float:
	var r := _weight_ratio()
	if r <= 1.0:
		return 1.0
	return lerpf(1.0, OVERWEIGHT_SLOW_MIN, clampf((r - 1.0) / (HARD_LIMIT_RATIO - 1.0), 0.0, 1.0))


## Влезет ли ещё delta кг (жёсткий предел).
func _weight_allows(delta: float) -> bool:
	return delta <= 0.0 or get_total_weight() + delta <= get_max_weight() * HARD_LIMIT_RATIO + 0.0001


func _update_weight_label() -> void:
	if _weight_label == null:
		return
	var total := get_total_weight()
	var r := _weight_ratio()
	_weight_label.text = "ВЕС  %.1f / %.1f кг" % [total, get_max_weight()]
	if r > 1.0:
		_weight_label.text += "\nПЕРЕГРУЗ"
	var col := Color(0.75, 0.8, 0.8)
	if r > 1.25:
		col = Color(1, 0.35, 0.3)
	elif r > 1.0:
		col = Color(1, 0.6, 0.25)
	elif r > 0.8:
		col = Color(0.95, 0.85, 0.4)
	_weight_label.add_theme_color_override("font_color", col)


# ---------- Ключи и сообщения ----------

func has_key(key_id: String) -> bool:
	return not _find_key(key_id).is_empty()


func _find_key(key_id: String) -> Array:
	if key_id == "":
		return []
	for arr in _player_arrays():
		for i in (arr as Array).size():
			var it = arr[i]
			if it != null and (it as ItemData).key_id == key_id:
				return [arr, i]
	return []


func consume_key(key_id: String) -> void:
	var f := _find_key(key_id)
	if f.is_empty():
		return
	(f[0] as Array)[f[1]] = null
	_refresh_all()
	player_inventory_changed.emit()


## Короткое сообщение внизу экрана.
func show_message(text: String) -> void:
	if _message_label == null:
		return
	_message_label.text = text
	_message_label.modulate.a = 1.0
	if _message_tween != null:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(1.4)
	_message_tween.tween_property(_message_label, "modulate:a", 0.0, 0.5)


## Положить в первое свободное место массива; если не влезает — пробуем повернув на 90°.
func _place_any(arr: Array, item: ItemData) -> bool:
	if _place_first_free(arr, item):
		return true
	if item.can_rotate():
		var turned := item.duplicate() as ItemData
		turned.rotated = not item.rotated
		if _place_first_free(arr, turned):
			return true
	return false


## Ctrl + клик: переложить предмет в свободное место.
## Из контейнера — к игроку; от игрока — в открытый контейнер, иначе между рюкзаком и карманами.
func quick_move(arr: Array, anchor: int) -> void:
	if anchor < 0 or anchor >= arr.size() or arr[anchor] == null:
		return
	var item := arr[anchor] as ItemData
	if item.equip_slot == BACKPACK_SLOT and is_single(arr):
		return   # снятый рюкзак быстро не перекладываем — в нём могут лежать вещи
	arr[anchor] = null
	var done := false
	if _open_container != null and is_same(arr, _open_container.inventory):
		done = add_to_player(item)   # сам обновит UI и покажет сообщение о весе
		if not done:
			arr[anchor] = item
		return
	var targets: Array = []
	if _open_container != null:
		targets.append(_open_container.inventory)
	if not is_same(arr, player_inventory) and has_backpack():
		targets.append(player_inventory)
	if not is_same(arr, player_pockets):
		targets.append(player_pockets)
	for t in targets:
		if _accepts(t, item) and _place_any(t, item):
			done = true
			break
	if not done:
		arr[anchor] = item
		show_message("Нет места")
		return
	_refresh_all()
	player_inventory_changed.emit()


## Положить предмет: в свой слот экипировки (если свободен), иначе в рюкзак (если надет),
## затем в карманы. Крупные предметы ищут свободный прямоугольник.
func add_to_player(item: ItemData) -> bool:
	if item == null:
		return false
	if not _weight_allows(item.weight):
		show_message("Слишком тяжело")
		return false
	var key := item.equip_slot
	if key != &"" and _equip.has(key) and (_equip[key] as Array)[0] == null:
		(_equip[key] as Array)[0] = item
	elif item.equip_slot == BACKPACK_SLOT:
		return false   # рюкзак нельзя убрать в рюкзак или карманы
	elif not (has_backpack() and _place_any(player_inventory, item)) \
			and not _place_any(player_pockets, item):
		return false
	_refresh_all()
	player_inventory_changed.emit()
	return true


# ---------- Сетка: правила размещения ----------
# В массиве предмет лежит только в «якорной» ячейке (левый верхний угол),
# остальные ячейки его прямоугольника в массиве пустые, но заняты.

func _equip_key(arr: Array) -> StringName:
	for key in _equip:
		if is_same(_equip[key], arr):
			return key
	return &""


## Слот экипировки: один слот, предмет занимает его целиком.
func is_single(arr: Array) -> bool:
	return _equip_key(arr) != &""


func _cols(arr: Array) -> int:
	if is_single(arr):
		return 1
	if is_same(arr, player_inventory):
		return BACKPACK_COLUMNS
	if is_same(arr, player_pockets):
		return POCKET_COLUMNS
	return maxi(_container_columns, 1)


func item_size(arr: Array, item: ItemData) -> Vector2i:
	if is_single(arr):
		return Vector2i(1, 1)
	return item.cell_size()


## Повернуть предмет на 90° (R), если в новом положении он помещается на том же месте.
## Предмет подменяется копией — ресурс .tres общий для всех экземпляров.
func rotate_item(arr: Array, anchor: int) -> bool:
	if anchor < 0 or anchor >= arr.size() or arr[anchor] == null or is_single(arr):
		return false
	var item := arr[anchor] as ItemData
	if not item.can_rotate():
		return false
	var turned := item.duplicate() as ItemData
	turned.rotated = not item.rotated
	var cols := _cols(arr)
	var found: Variant = _overlaps(arr, turned, Vector2i(anchor % cols, anchor / cols), anchor)
	if found == null or not (found as Array).is_empty():
		show_message("Не помещается")
		return false
	if _open_container != null and is_same(arr, _open_container.inventory):
		(_open_container.unrevealed as Dictionary).erase(anchor)
	arr[anchor] = turned
	_refresh_all()
	return true


## Данные текущего перетаскивания (ставит InventoryGrid).
var drag_data := {}


## R во время перетаскивания: поворачиваем предмет «в руке» (в массиве он меняется только при броске).
func _rotate_dragged() -> void:
	var src: Array = drag_data["source"]
	var item: ItemData = drag_data["item"] if drag_data.has("item") else src[drag_data["index"]]
	if item == null or not item.can_rotate():
		return
	var turned := item.duplicate() as ItemData
	turned.rotated = not item.rotated
	var gs := item.cell_size()
	var g: Vector2 = drag_data["grab"]
	# Поворот на 90° по часовой: точка (x, y) в рамке w×h переходит в (h − y, x).
	var ng := Vector2(float(gs.y) - g.y, g.x)
	var ns := Vector2(turned.cell_size())
	drag_data["grab"] = ng.clamp(Vector2.ZERO, ns - Vector2(0.01, 0.01))
	drag_data["item"] = turned
	(drag_data["grid"] as InventoryGrid).update_drag_preview(drag_data)


## R: повернуть предмет под курсором.
func _rotate_hovered() -> void:
	for g in _all_grids():
		if g.enabled and g.is_visible_in_tree() and g.get_global_rect().has_point(g.get_global_mouse_position()):
			var a := g.hovered_anchor()
			if a >= 0:
				rotate_item(g.inventory, a)
			return


func _item_rect(arr: Array, index: int, item: ItemData) -> Rect2i:
	var cols := _cols(arr)
	return Rect2i(Vector2i(index % cols, index / cols), item_size(arr, item))


## Можно ли вообще класть предмет в этот массив (без учёта места).
func _accepts(arr: Array, item: ItemData) -> bool:
	var key := _equip_key(arr)
	if key != &"":
		return item.equip_slot == key
	if is_same(arr, player_inventory) or is_same(arr, player_pockets):
		if item.equip_slot == BACKPACK_SLOT:
			return false
		if is_same(arr, player_inventory) and not has_backpack():
			return false
	return true


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


## Якоря предметов, пересекающихся с прямоугольником item в клетке cell.
## null — прямоугольник выходит за границы сетки. ignore_* — якоря, которые не считаются.
func _overlaps(arr: Array, item: ItemData, cell: Vector2i, ignore_a := -1, ignore_b := -1) -> Variant:
	var cols := _cols(arr)
	var rows := ceili(float(arr.size()) / float(cols))
	var size := item_size(arr, item)
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


## План перемещения предмета source[si] так, чтобы его левый верхний угол оказался в клетке cell
## массива target: {"dest": индекс якоря, "swap": якорь вытесняемого предмета или -1}.
## Пустой словарь — перемещение невозможно.
func _plan_move(source: Array, si: int, target: Array, cell: Vector2i, held: ItemData = null) -> Dictionary:
	if si < 0 or si >= source.size():
		return {}
	var item: ItemData = source[si]
	if item == null:
		return {}
	if held != null:
		item = held   # предмет в руке, возможно повёрнутый
	if not _accepts(target, item):
		return {}
	var same := is_same(source, target)
	if _is_player_array(target) and not _is_player_array(source) and not _weight_allows(item.weight):
		return {}
	var overlap: Variant = _overlaps(target, item, cell, si if same else -1)
	if overlap == null:
		return {}
	var hit := overlap as Array
	if _open_container != null and is_same(target, _open_container.inventory):
		for h in hit:
			if (_open_container.unrevealed as Dictionary).has(h):
				return {}
	var dest := cell.y * _cols(target) + cell.x
	if hit.is_empty():
		if same and dest == si:
			return {}
		return {"dest": dest, "swap": -1}
	if hit.size() > 1:
		return {}

	# Ровно один предмет мешает — меняем местами, если он встанет на место исходного.
	var other_index: int = hit[0]
	var other: ItemData = target[other_index]
	if not _accepts(source, other):
		return {}
	var scols := _cols(source)
	var back_cell := Vector2i(si % scols, si / scols)
	var blocked: Variant = _overlaps(source, other, back_cell, si, other_index if same else -1)
	if blocked == null or not (blocked as Array).is_empty():
		return {}
	if same and Rect2i(back_cell, item_size(source, other)).intersects(Rect2i(cell, item_size(target, item))):
		return {}
	return {"dest": dest, "swap": other_index}


## Можно ли положить предмет в эту клетку (сетка подсвечивает допустимость).
func can_move(source: Array, source_index: int, target: Array, cell: Vector2i, held: ItemData = null) -> bool:
	return not _plan_move(source, source_index, target, cell, held).is_empty()


## Переместить/поменять предмет (drag-and-drop).
func move_item(source: Array, source_index: int, target: Array, cell: Vector2i, held: ItemData = null) -> void:
	var plan := _plan_move(source, source_index, target, cell, held)
	if plan.is_empty():
		return
	var moving: ItemData = held if held != null else source[source_index]
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


## Выбросить предмет из якорной ячейки в 3D-мир.
func drop_item(arr: Array, anchor: int) -> void:
	if anchor < 0 or anchor >= arr.size() or arr[anchor] == null:
		return
	var item := arr[anchor] as ItemData
	arr[anchor] = null
	_refresh_all()
	_spawn_pickup(item)
	if _is_player_array(arr):
		player_inventory_changed.emit()


func _is_player_array(arr: Array) -> bool:
	return is_same(arr, player_inventory) or is_same(arr, player_pockets) or is_single(arr)


# ---------- Контекстное меню ----------

func _on_item_right_clicked(grid: InventoryGrid, anchor: int) -> void:
	hide_item_tooltip()
	_context_grid = grid
	_context_anchor = anchor
	var clicked := grid.inventory[anchor] as ItemData if anchor >= 0 and anchor < grid.inventory.size() else null
	_use_btn.visible = clicked != null and clicked.heal_amount > 0
	_context_menu.visible = true
	_context_menu.reset_size()
	# Меню открывается над курсором (не перекрывается предметами) и не выходит за экран.
	var mouse := _root.get_local_mouse_position()
	var pos := mouse - Vector2(0, _context_menu.size.y + 2.0)
	pos.x = clampf(pos.x, 0.0, maxf(_root.size.x - _context_menu.size.x, 0.0))
	pos.y = clampf(pos.y, 0.0, maxf(_root.size.y - _context_menu.size.y, 0.0))
	_context_menu.position = pos


func close_context_menu() -> void:
	if _context_menu != null:
		_context_menu.visible = false
	_context_grid = null
	_context_anchor = -1


func _on_context_use_pressed() -> void:
	if _context_grid != null:
		use_item(_context_grid.inventory, _context_anchor)
	close_context_menu()


## Использовать предмет (аптечка лечит и расходуется).
func use_item(arr: Array, anchor: int) -> void:
	if anchor < 0 or anchor >= arr.size() or arr[anchor] == null:
		return
	var item := arr[anchor] as ItemData
	if item.heal_amount <= 0:
		return
	var player := _local_player()
	if player == null or not player.has_method("heal_over_time"):
		return
	var restored := int(player.call("heal_over_time", item.heal_amount))
	if restored <= 0:
		show_message("Здоровье полное")
		return
	arr[anchor] = null
	_refresh_all()
	if _is_player_array(arr):
		player_inventory_changed.emit()


func _on_context_drop_pressed() -> void:
	if _context_grid != null:
		drop_item(_context_grid.inventory, _context_anchor)
	close_context_menu()


# ---------- Контейнер / пауза / показ UI ----------

## Открыть контейнер (шкаф). Показывает панель контейнера справа.
func open_container(container: Node) -> void:
	if pause_open:
		return
	_open_container = container
	_play_container_sound(1.0)
	_search_time = -0.25   # небольшая пауза перед первым предметом
	_rebuild_container()
	_set_container_shown(true)
	_set_ui_visible(true)
	_apply_layout()


func _play_container_sound(pitch: float) -> void:
	_container_sfx.pitch_scale = pitch
	_container_sfx.play()


func close_container() -> void:
	if _open_container != null:
		_play_container_sound(0.8)   # закрытие — тот же звук, ниже тоном
	_open_container = null
	_rebuild_container()
	_set_container_shown(false)
	_apply_layout()


func _toggle_inventory() -> void:
	_set_ui_visible(not _ui.visible)
	if not _ui.visible:
		close_container()


## Время в игре не останавливается: окно лишь блокирует управление игроком.
func _set_ui_visible(vis: bool) -> void:
	_ui.visible = vis
	if not vis:
		close_context_menu()
		hide_item_tooltip()
	else:
		_apply_layout()
		call_deferred("_apply_layout")
	if vis and _silhouette != null:
		_silhouette.queue_redraw()
		_silhouette.call_deferred("queue_redraw")
	refresh_mouse_mode()


# ---------- Выброс в мир ----------

func _local_player() -> Node3D:
	for node in get_tree().get_nodes_in_group("player"):
		var body := node as Node3D
		if body != null and body.is_multiplayer_authority():
			return body
	return null


func _spawn_pickup(item: ItemData) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var pickup := PickupItem.new()
	pickup.item_data = item
	scene.add_child(pickup)
	var player := _local_player()
	if player != null:
		var forward := -player.global_transform.basis.z
		pickup.global_position = player.global_position + forward * 0.9 + Vector3.UP * 0.5
		# Небольшой импульс вперёд и вверх — папка падает на пол.
		pickup.apply_central_impulse(forward * 1.5 + Vector3.UP * 2.0)
	else:
		pickup.global_position = Vector3(0, 1, 0)


# ---------- Построение UI ----------

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.name = "InventoryUI"
	_ui.layer = 10
	_ui.visible = false
	add_child(_ui)

	_message_label = Label.new()
	_message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.add_theme_font_size_override("font_size", 18)
	_message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_message_label.add_theme_constant_override("outline_size", 6)
	_message_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_message_label.offset_top = -120
	_message_label.offset_bottom = -80
	_message_label.modulate.a = 0.0
	# Сообщения видны и при закрытом инвентаре — отдельный слой.
	var msg_layer := CanvasLayer.new()
	msg_layer.layer = 20
	add_child(msg_layer)
	msg_layer.add_child(_message_label)
	_build_prompt()

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
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
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, ROOT_MARGIN)
	_root.add_child(margin)

	# [пружина] [персонаж + рюкзак] [зазор] [контейнер] [пружина]
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

	var gap := Control.new()   # фиксированный зазор между инвентарём и шкафом
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.custom_minimum_size.x = COLUMN_GAP * 2
	row.add_child(gap)

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
	_container_grid.mouse_filter = Control.MOUSE_FILTER_STOP if shown else Control.MOUSE_FILTER_IGNORE


## Размер ячейки подбирается под текущий размер окна, чтобы всё помещалось.
func _apply_layout() -> void:
	if _root == null or _container_panel == null or _character_frame == null:
		return
	# Место под панель контейнера резервируется всегда, чтобы масштаб и положение
	# инвентаря не прыгали, когда шкаф открывается или закрывается.
	var cols := CHARACTER_COLUMN_CELLS + BACKPACK_COLUMNS + CONTAINER_MAX_COLUMNS
	var fixed := float(ROOT_MARGIN * 2 + COLUMN_GAP * 3 + GAP + 8 + 4)
	var by_width := (_root.size.x - fixed) / float(cols)
	# По высоте: колонка персонажа = 5 ячеек + оружие 2 ячейки + отступы.
	var by_height := (_root.size.y - ROOT_MARGIN * 2 - 24.0) / 7.6
	var s := clampi(int(floorf(minf(by_width, by_height))), MIN_SLOT_SIZE, MAX_SLOT_SIZE)
	_cell = s
	_container_panel.custom_minimum_size.x = float(CONTAINER_MAX_COLUMNS * s + 1)
	_character_frame.custom_minimum_size.x = float(4 * s)
	for g in _all_grids():
		g.set_cell(s)


func _all_grids() -> Array[InventoryGrid]:
	var all: Array[InventoryGrid] = [_backpack_grid, _pocket_grid, _container_grid]
	all.append_array(_equip_grids)
	return all


func _refresh_all() -> void:
	if _backpack_grid == null:
		return
	hide_item_tooltip()
	_backpack_grid.enabled = has_backpack()
	for g in _all_grids():
		g.refresh()
	_update_weight_label()


## Левая колонка: заглушка персонажа, рядом броня/рюкзак/нож, снизу оружие.
func _build_character_column() -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", GAP)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", GAP)
	vbox.add_child(top)

	# Серая заглушка вместо 3D-модели персонажа.
	_character_frame = PanelContainer.new()
	_character_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_character_frame.add_theme_stylebox_override("panel", _make_panel_style(
		Color(0.32, 0.34, 0.35, 0.22), PANEL_BORDER, 0))
	top.add_child(_character_frame)
	var art := Control.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.draw.connect(_draw_silhouette.bind(art))
	art.resized.connect(art.queue_redraw)
	_silhouette = art
	_character_frame.add_child(art)
	_weight_label = Label.new()
	_weight_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weight_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_weight_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_weight_label.add_theme_font_size_override("font_size", 13)
	_weight_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_weight_label.offset_top = -44
	_weight_label.offset_bottom = -4
	art.add_child(_weight_label)

	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", GAP)
	top.add_child(side)
	side.add_child(_make_equip_grid(player_armor, Vector2(2, 2), "БРОНЯ"))
	side.add_child(_make_equip_grid(player_backpack, Vector2(2, 2), "РЮКЗАК"))
	side.add_child(_make_equip_grid(player_knife, Vector2(2, 1), "НОЖ"))

	# Оружие — широкий слот на всю ширину колонки.
	vbox.add_child(_make_equip_grid(player_weapon, Vector2(CHARACTER_COLUMN_CELLS, 2), "ОРУЖИЕ",
			Vector2(GAP, 0)))
	return vbox


func _draw_silhouette(c: Control) -> void:
	var w := c.size.x
	var h := c.size.y
	if w < 4.0 or h < 4.0:
		return
	var col := Color(0.6, 0.63, 0.64, 0.2)
	var cx := w * 0.5
	var u := minf(w, h * 0.62)
	c.draw_circle(Vector2(cx, h * 0.2), u * 0.11, col)
	c.draw_colored_polygon(PackedVector2Array([
		Vector2(cx - u * 0.30, h * 0.31), Vector2(cx + u * 0.30, h * 0.31),
		Vector2(cx + u * 0.36, h * 0.58), Vector2(cx + u * 0.20, h * 0.60),
		Vector2(cx + u * 0.20, h * 0.95), Vector2(cx + u * 0.03, h * 0.95),
		Vector2(cx, h * 0.66), Vector2(cx - u * 0.03, h * 0.95),
		Vector2(cx - u * 0.20, h * 0.95), Vector2(cx - u * 0.20, h * 0.60),
		Vector2(cx - u * 0.36, h * 0.58)]), col)


## Слот экипировки: сетка из одной растянутой ячейки. cells — размер слота в базовых ячейках.
func _make_equip_grid(arr: Array, cells: Vector2, title: String, extra := Vector2.ZERO) -> InventoryGrid:
	var grid := _make_grid(arr, 1)
	grid.slot_cells = cells
	grid.slot_extra = extra
	grid.placeholder = title
	_equip_grids.append(grid)
	return grid


func _make_grid(arr: Array, columns: int) -> InventoryGrid:
	var grid := InventoryGrid.new()
	grid.manager = self
	grid.inventory = arr
	grid.columns = columns
	grid.cell = SLOT_SIZE
	grid.item_right_clicked.connect(_on_item_right_clicked)
	return grid


## Центральная колонка: рюкзак и карманы.
func _build_center_column() -> Control:
	var vbox := VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	vbox.add_theme_constant_override("separation", 14)

	var backpack := VBoxContainer.new()
	backpack.add_theme_constant_override("separation", GAP)
	vbox.add_child(backpack)
	backpack.add_child(_make_section_header("РЮКЗАК", "%d слотов" % BACKPACK_SLOT_COUNT))
	_backpack_grid = _make_grid(player_inventory, BACKPACK_COLUMNS)
	_backpack_grid.disabled_text = "РЮКЗАК НЕ НАДЕТ"
	backpack.add_child(_backpack_grid)

	var pockets := VBoxContainer.new()
	pockets.add_theme_constant_override("separation", GAP)
	vbox.add_child(pockets)
	pockets.add_child(_make_section_header("КАРМАНЫ", "%d" % POCKET_COUNT))
	_pocket_grid = _make_grid(player_pockets, POCKET_COLUMNS)
	pockets.add_child(_pocket_grid)
	return vbox


func _make_section_header(title: String, hint: String) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_panel_style(
		Color(0.04, 0.05, 0.055, 0.7), PANEL_BORDER))

	var hbox := HBoxContainer.new()
	panel.add_child(hbox)

	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.72, 0.76, 0.76, 0.9))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)

	var hint_label := Label.new()
	hint_label.text = hint
	hint_label.add_theme_font_size_override("font_size", 11)
	hint_label.add_theme_color_override("font_color", Color(0.5, 0.54, 0.54, 0.85))
	hbox.add_child(hint_label)
	return panel


## Панель открытого контейнера (шкаф) — справа, как в Tarkov.
func _build_container_column() -> Control:
	var vbox := VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	vbox.add_theme_constant_override("separation", GAP)

	_container_header = _make_section_header("ШКАФ", "")
	vbox.add_child(_container_header)
	_container_grid = _make_grid([], _container_columns)
	vbox.add_child(_container_grid)
	return vbox


func _rebuild_container() -> void:
	if _open_container == null:
		_container_grid.unsearched = {}
		_container_grid.inventory = []
		_container_grid.refresh()
		return
	var inv: Array = _open_container.inventory
	_container_grid.inventory = inv
	_container_grid.unsearched = (_open_container as LootContainer).unrevealed
	_set_container_header(inv.size())
	_container_columns = (_open_container as LootContainer).columns()
	_container_grid.columns = _container_columns
	_container_grid.cell = _cell
	_container_grid.refresh()


func _set_container_header(count: int) -> void:
	var hbox := _container_header.get_child(0) as HBoxContainer
	(hbox.get_child(0) as Label).text = (_open_container.container_name as String).to_upper() if _open_container != null else "ШКАФ"
	(hbox.get_child(1) as Label).text = "%d слотов" % count


func _build_context_menu() -> void:
	_context_menu = PanelContainer.new()
	_context_menu.name = "ContextMenu"
	_context_menu.visible = false
	_context_menu.z_index = 100
	_context_menu.z_as_relative = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.09, 0.97)
	style.border_color = Color(0.5, 0.55, 0.55, 0.45)
	style.set_border_width_all(1)
	style.set_content_margin_all(2)
	_context_menu.add_theme_stylebox_override("panel", style)
	_ui.add_child(_context_menu)
	_build_tooltip()

	var menu_box := VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 0)
	_context_menu.add_child(menu_box)
	_use_btn = _make_menu_button("Использовать", _on_context_use_pressed)
	menu_box.add_child(_use_btn)
	menu_box.add_child(_make_menu_button("Выбросить", _on_context_drop_pressed))


func _make_menu_button(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(120, 24)
	for st in ["normal", "focus"]:
		btn.add_theme_stylebox_override(st, _flat_button(Color(0, 0, 0, 0)))
	btn.add_theme_stylebox_override("hover", _flat_button(Color(0.22, 0.24, 0.25, 0.95)))
	btn.add_theme_stylebox_override("pressed", _flat_button(Color(0.3, 0.32, 0.33, 0.98)))
	btn.add_theme_color_override("font_color", Color(0.78, 0.82, 0.82))
	btn.add_theme_color_override("font_hover_color", Color(0.95, 0.97, 0.97))
	btn.add_theme_font_size_override("font_size", 12)
	btn.pressed.connect(callback)
	return btn


func _build_tooltip() -> void:
	_tip = PanelContainer.new()
	_tip.name = "ItemTooltip"
	_tip.visible = false
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.z_index = 200
	_tip.z_as_relative = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.09, 0.82)
	sb.border_color = Color(0.5, 0.55, 0.55, 0.4)
	sb.set_border_width_all(1)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	_tip.add_theme_stylebox_override("panel", sb)
	_tip_box = VBoxContainer.new()
	_tip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_box.add_theme_constant_override("separation", 0)
	_tip.add_child(_tip_box)
	_ui.add_child(_tip)


func _flat_button(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	return sb


func _make_panel_style(bg := PANEL_BG, brd := PANEL_BORDER, margin := 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = brd
	sb.set_border_width_all(1)
	sb.content_margin_left = 10 if margin > 0 else 1
	sb.content_margin_top = margin if margin > 0 else 1
	sb.content_margin_right = 10 if margin > 0 else 1
	sb.content_margin_bottom = margin if margin > 0 else 1
	return sb


func _make_button_style(bg := Color(0.08, 0.09, 0.1, 0.9)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = Color(0.5, 0.55, 0.55, 0.4)
	sb.set_border_width_all(1)
	return sb
