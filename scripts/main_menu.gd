extends Control

@onready var ip_address: LineEdit = %IPAddress
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var singleplayer_button: Button = %SingleplayerButton
@onready var exit_button: Button = %ExitButton


func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	singleplayer_button.pressed.connect(_on_singleplayer_pressed)
	exit_button.pressed.connect(_on_exit_pressed)


func _on_host_pressed() -> void:
	# TODO(напарник): запустить сервер (Host).
	pass


func _on_join_pressed() -> void:
	# TODO(напарник): подключиться к ip_address.text (Join).
	pass


func _on_singleplayer_pressed() -> void:
	# Одиночная игра: просто грузим уровень без сети/сервера.
	get_tree().change_scene_to_file("res://art/levels/test_office.tscn")


func _on_exit_pressed() -> void:
	get_tree().quit()
