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
## Число слотов (ячеек сетки).
@export_range(1, 60) var capacity := 12
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
	inventory.resize(capacity)
	if fill_on_ready:
		roll_loot()
	if search_on_open:
		for i in inventory.size():
			if inventory[i] != null:
				unrevealed[i] = true
	add_to_group("interactable")


## Число колонок сетки (и в UI, и при раскладке лута).
func columns() -> int:
	return clampi(capacity, 1, MAX_COLUMNS)


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
	var size := Vector2i(maxi(item.grid_size.x, 1), maxi(item.grid_size.y, 1))
	for i in inventory.size():
		var rect := Rect2i(Vector2i(i % cols, i / cols), size)
		if rect.end.x > cols or (rect.end.y - 1) * cols + rect.end.x - 1 >= inventory.size():
			continue
		var free := true
		for j in inventory.size():
			if inventory[j] == null:
				continue
			var other := Rect2i(Vector2i(j % cols, j / cols), 
					Vector2i(maxi(inventory[j].grid_size.x, 1), maxi(inventory[j].grid_size.y, 1)))
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
