## Контейнер (ящик, шкаф, сейф...). Вешается на любой Node3D / StaticBody3D.
## Вместимость, замок, id ключа и таблица лута настраиваются в инспекторе.
## (Класс назван LootContainer, потому что Container — встроенный класс Godot.)
## Цель взаимодействия выбирает InventoryManager (группа "interactable").
@tool
class_name LootContainer
extends Node3D

const MAX_COLUMNS := 6

signal unlocked

@export var container_name := "Ящик"
## Число колонок сетки.
@export_range(1, 6) var grid_columns := 6:
	set(v):
		grid_columns = v
		update_configuration_warnings()
## Число рядов сетки. Всего ячеек = колонки × ряды.
@export_range(1, 10) var grid_rows := 2
## Радиус взаимодействия (по горизонтали от игрока).
@export var interact_radius := 2.2
## Высота точки, на которую нужно навести взгляд, чтобы появилась подсказка.
@export var focus_height := 0.9

@export_group("Замок")
@export var locked := false:
	set(v):
		locked = v
		notify_property_list_changed()
## id ключа (ItemData.key_id), который отпирает контейнер.
@export var key_id := ""
## Ключ пропадает после открытия.
@export var consume_key := false

@export_group("Лут")
## Заполнить контейнер по таблице при появлении на сцене.
@export var fill_on_ready := true
@export var loot_table: LootTable
## При открытии предметы «обыскиваются» по одному (штриховка и лупа), как в Tarkov.
@export var search_on_open := true

## Содержимое (пустые = null). Не сохраняется в сцене, наполняется кодом.
var inventory: Array[ItemData] = []
## Якоря ещё не обысканных предметов (ключи словаря). Пустой — всё открыто.
var unrevealed := {}

var _manager: Node


func _validate_property(property: Dictionary) -> void:
	if property.name in ["key_id", "consume_key"] and not locked:
		property.usage = PROPERTY_USAGE_NO_EDITOR


func _get_configuration_warnings() -> PackedStringArray:
	var w := PackedStringArray()
	if locked and key_id == "":
		w.append("Контейнер заперт, но key_id пуст — открыть его будет нечем.")
	if fill_on_ready and loot_table == null:
		w.append("Не назначена loot_table — контейнер будет пустым.")
	return w


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_manager = get_node("/root/InventoryManager")
	inventory.resize(capacity())
	add_to_group("interactable")
	if _is_net() and not multiplayer.is_server():
		request_contents.rpc_id(1)
		return
	if fill_on_ready:
		roll_loot()
	_mark_unsearched()


## Число колонок сетки (и в UI, и при раскладке лута).
func columns() -> int:
	return clampi(grid_columns, 1, MAX_COLUMNS)


## Общее число ячеек.
func capacity() -> int:
	return columns() * maxi(grid_rows, 1)


## Заполнить контейнер по таблице (старое содержимое остаётся). Не влезшее пропадает.
func roll_loot(rng: RandomNumberGenerator = null) -> void:
	if loot_table == null:
		return
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var drops := loot_table.roll(rng)
	# Крупные предметы первыми — так плотнее раскладка.
	drops.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		return a.grid_size.x * a.grid_size.y > b.grid_size.x * b.grid_size.y)
	for item in drops:
		_place(item)


func _place(item: ItemData) -> bool:
	var cols := columns()
	var size := item.cell_size()
	for i in inventory.size():
		var rect := Rect2i(Vector2i(i % cols, i / cols), size)
		if rect.end.x > cols or (rect.end.y - 1) * cols + rect.end.x - 1 >= inventory.size():
			continue
		var free := true
		for j in inventory.size():
			if inventory[j] == null:
				continue
			var other := Rect2i(Vector2i(j % cols, j / cols), inventory[j].cell_size())
			if rect.intersects(other):
				free = false
				break
		if free:
			inventory[i] = item
			return true
	return false


func focus_point() -> Vector3:
	return global_position + Vector3.UP * focus_height


func can_interact() -> bool:
	return true


## Подсказка взаимодействия рисуется InventoryManager на экране (иконка клавиши + действие + название).
func prompt_info() -> Dictionary:
	return {
		"verb": "Поиск" if search_on_open else "Открыть",
		"name": container_name + (" (заперто)" if locked else ""),
		"warn": locked,
	}


func set_focused(_focused: bool) -> void:
	pass


func interact() -> void:
	if locked and not _try_unlock():
		return
	_manager.open_container(self)


func _try_unlock() -> bool:
	if key_id != "" and _manager.has_key(key_id):
		if consume_key:
			_manager.consume_key(key_id)
		locked = false
		_manager.show_message("Замок открыт")
		unlocked.emit()
		return true
	_manager.show_message("Заперто. Нужен ключ")
	return false


func _is_net() -> bool:
	return multiplayer.multiplayer_peer is ENetMultiplayerPeer


func _sender_id() -> int:
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 0:
		sender = multiplayer.get_unique_id()
	return sender


func _mark_unsearched() -> void:
	if not search_on_open:
		return
	for i in inventory.size():
		if inventory[i] != null:
			unrevealed[i] = true


func encoded_contents() -> PackedStringArray:
	var paths := PackedStringArray()
	for item in inventory:
		if item == null:
			paths.append("")
		else:
			paths.append(item.resource_path + ("|1" if item.rotated else "|0"))
	return paths


func _item_from_code(code: String) -> ItemData:
	if code.is_empty():
		return null
	var rotated := code.ends_with("|1")
	var path := code.trim_suffix("|1").trim_suffix("|0")
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var item := load(path) as ItemData
	if item == null:
		return null
	item = item.duplicate() as ItemData
	item.rotated = rotated
	return item


@rpc("any_peer", "call_local", "reliable")
func request_contents() -> void:
	if multiplayer.is_server():
		apply_contents.rpc_id(_sender_id(), encoded_contents())


@rpc("any_peer", "call_local", "reliable")
func request_set_contents(paths: PackedStringArray) -> void:
	if multiplayer.is_server():
		apply_contents.rpc(paths)


@rpc("authority", "call_local", "reliable")
func apply_contents(paths: PackedStringArray) -> void:
	for i in inventory.size():
		var code := paths[i] if i < paths.size() else ""
		var next := _item_from_code(code)
		var prev: ItemData = inventory[i]
		var same := prev != null and next != null and prev.resource_path == next.resource_path and prev.rotated == next.rotated
		inventory[i] = next
		if next == null:
			unrevealed.erase(i)
		elif search_on_open and not same:
			unrevealed[i] = true
	if _manager != null and _manager.has_method("refresh_open_container"):
		_manager.refresh_open_container(self)
