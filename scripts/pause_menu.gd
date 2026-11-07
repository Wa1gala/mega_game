extends CanvasLayer
## Меню паузы. Время в игре НЕ останавливается: меню лишь блокирует управление игроком
## (см. InventoryManager.is_ui_open()). Рисуется поверх инвентаря (layer выше 10).

@onready var overlay: Control = $Overlay
@onready var exit_button: Button = %ExitToLobbyButton
@onready var volume_slider: HSlider = %VolumeSlider
@onready var volume_label: Label = %VolumeLabel

const SETTINGS_PATH := "user://settings.cfg"


func _ready() -> void:
	overlay.visible = false
	exit_button.pressed.connect(_on_exit_to_lobby_pressed)
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)   # нет файла — остаётся значение по умолчанию
	volume_slider.value = float(config.get_value("audio", "master_volume", 1.0))
	volume_slider.value_changed.connect(_on_volume_changed)
	_apply_volume(volume_slider.value)


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


func _on_volume_changed(value: float) -> void:
	_apply_volume(value)
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("audio", "master_volume", value)
	config.save(SETTINGS_PATH)


func _apply_volume(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), value <= 0.001)
	volume_label.text = "ГРОМКОСТЬ: %d%%" % roundi(value * 100.0)
