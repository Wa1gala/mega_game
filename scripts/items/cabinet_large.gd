## Интерактивный шкаф-контейнер.
## Вешается на StaticBody3D «CabinetLarge» в test_office.tscn.
## Цель взаимодействия выбирает InventoryManager (группа "interactable"):
## E открывает UI контейнера (две панели).
class_name CabinetLarge
extends StaticBody3D

const SLOT_COUNT := 12         # слотов в шкафу (6x2, чтобы влезал автомат 3x2)

## Радиус взаимодействия (по горизонтали от игрока до шкафа).
var interact_radius := 2.2

## Слоты шкафа (пустые = null). Заполняется в редакторе или кодом.
@export var inventory: Array[ItemData] = []

var _hint: Label3D


func _ready() -> void:
	inventory.resize(SLOT_COUNT)
	_load_demo_item()
	_build_hint()
	add_to_group("interactable")


## Демо: если шкаф пуст, кладём тестовый предмет в первый слот.
func _load_demo_item() -> void:
	for it in inventory:
		if it != null:
			return
	inventory[0] = load("res://resources/items/file_binder_alt4.tres") as ItemData


func _build_hint() -> void:
	_hint = Label3D.new()
	_hint.name = "InteractHint"
	_hint.text = "E"
	_hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hint.font_size = 48
	_hint.pixel_size = 0.008
	_hint.modulate = Color(0.5, 1, 0.5)
	_hint.outline_size = 6
	_hint.outline_modulate = Color(0, 0, 0, 1)
	_hint.no_depth_test = true
	_hint.position = Vector3(0, 1.2, 0)
	_hint.visible = false
	add_child(_hint)


func can_interact() -> bool:
	return true


func set_focused(focused: bool) -> void:
	_hint.visible = focused


func interact() -> void:
	InventoryManager.open_container(self)
