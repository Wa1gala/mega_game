extends CanvasLayer

@onready var overlay: Control = $Overlay
@onready var exit_button: Button = %ExitToLobbyButton


func _ready() -> void:
	overlay.visible = false
	exit_button.pressed.connect(_on_exit_to_lobby_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()


func _toggle_pause() -> void:
	var pause := not overlay.visible
	overlay.visible = pause
	get_tree().paused = pause
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if pause else Input.MOUSE_MODE_CAPTURED


func _on_exit_to_lobby_pressed() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
