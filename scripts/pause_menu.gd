extends CanvasLayer
## Меню паузы. Время в игре НЕ останавливается: меню лишь блокирует управление игроком
## (см. InventoryManager.is_ui_open()). Рисуется поверх инвентаря (layer выше 10).

@onready var overlay: Control = $Overlay
@onready var exit_button: Button = %ExitToLobbyButton


func _ready() -> void:
	overlay.visible = false
	exit_button.pressed.connect(_on_exit_to_lobby_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	# Esc сначала закрывает инвентарь, и только следующий Esc открывает паузу.
	if not overlay.visible and InventoryManager.is_ui_open():
		InventoryManager.close_all()
		return
	_set_pause(not overlay.visible)


func _set_pause(pause: bool) -> void:
	overlay.visible = pause
	InventoryManager.pause_open = pause
	InventoryManager.refresh_mouse_mode()


func _on_exit_to_lobby_pressed() -> void:
	InventoryManager.close_all()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
