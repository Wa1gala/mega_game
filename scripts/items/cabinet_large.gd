## Интерактивный шкаф-контейнер.
## Вешается на StaticBody3D «CabinetLarge» в test_office.tscn.
## При приближении игрока и нажатии E открывает UI контейнера (две панели).
class_name CabinetLarge
extends StaticBody3D

const SLOT_COUNT := 6          # слотов в шкафу
const INTERACTION_RADIUS := 1.8

## Слоты шкафа (пустые = null). Заполняется в редакторе или кодом.
@export var inventory: Array[ItemData] = []

var _player_nearby := false
var _hint: Label3D


func _ready() -> void:
	inventory.resize(SLOT_COUNT)
	_load_demo_item()
	_build_interaction_area()
	_build_hint()


## Демо: если шкаф пуст, кладём тестовый предмет в первый слот.
func _load_demo_item() -> void:
	for it in inventory:
		if it != null:
			return
	inventory[0] = load("res://resources/items/file_binder_alt4.tres") as ItemData


func _build_interaction_area() -> void:
	var area := Area3D.new()
	area.name = "InteractionArea"
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = INTERACTION_RADIUS
	shape.shape = sphere
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)


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
	_hint.position = Vector3(0, 1.2, 0)
	_hint.visible = false
	add_child(_hint)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_nearby = true
		_hint.visible = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
		_hint.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _player_nearby and event.is_action_pressed("interact"):
		InventoryManager.open_container(self)
		get_viewport().set_input_as_handled()
