## Слот инвентаря (UI-панель).
## Показывает 3D-превью предмета (SubViewport), имя, поддерживает
## drag-and-drop и правый клик (контекстное меню «Выбросить»).
class_name InventorySlot
extends Panel

## Правый клик по слоту (для контекстного меню «Выбросить»).
signal slot_right_clicked(slot: InventorySlot)

## Ссылка на массив инвентаря, которому принадлежит слот
## (InventoryManager.player_inventory или inventory шкафа).
var inventory: Array[ItemData] = []
## Индекс слота внутри массива.
var slot_index: int = 0
## Менеджер (автолоад InventoryManager) — обрабатывает перемещение.
var manager: Node = null

var _preview: SubViewportContainer
var _viewport: SubViewport
var _camera: Camera3D
var _model_instance: Node3D = null
var _name_label: Label


func _init() -> void:
	custom_minimum_size = Vector2(64, 76)

	# 3D-превью предмета.
	_preview = SubViewportContainer.new()
	_preview.stretch = true
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview.offset_left = 3.0
	_preview.offset_top = 3.0
	_preview.offset_right = -3.0
	_preview.offset_bottom = -18.0
	add_child(_preview)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(128, 128)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_preview.add_child(_viewport)

	_camera = Camera3D.new()
	_camera.current = true
	_viewport.add_child(_camera)
	_camera.position = Vector3(0.3, 0.22, 0.45)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	_viewport.add_child(light)

	# Имя предмета (обрезается, чтобы не вылезало за ячейку).
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_name_label.offset_top = -18.0
	_name_label.add_theme_font_size_override("font_size", 9)
	_name_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	add_child(_name_label)


func _ready() -> void:
	_camera.look_at(Vector3(0, 0.15, 0))


func get_item() -> ItemData:
	if slot_index >= inventory.size():
		return null
	return inventory[slot_index]


func refresh() -> void:
	var it := get_item()
	if it != null:
		_name_label.text = it.name
		tooltip_text = it.description
		_set_model(it.world_mesh_scene)
	else:
		_name_label.text = ""
		tooltip_text = ""
		_set_model(null)


func _set_model(scene: PackedScene) -> void:
	if _model_instance != null:
		_model_instance.queue_free()
		_model_instance = null
	if scene != null:
		_model_instance = scene.instantiate()
		_viewport.add_child(_model_instance)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		slot_right_clicked.emit(self)


# --- Drag-and-drop (Godot 4) ---

func _get_drag_data(_at_position: Vector2):
	if get_item() == null:
		return null
	var preview := _make_drag_preview(get_item().world_mesh_scene)
	preview.custom_minimum_size = Vector2(64, 64)
	set_drag_preview(preview)
	return {"source_inventory": inventory, "source_index": slot_index}


## Создаёт 3D-превью предмета для drag-and-drop (модель следует за мышкой).
func _make_drag_preview(scene: PackedScene) -> SubViewportContainer:
	var container := SubViewportContainer.new()
	container.stretch = true
	var vp := SubViewport.new()
	vp.size = Vector2i(96, 96)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(vp)
	var cam := Camera3D.new()
	cam.current = true
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0.3, 0.22, 0.45), Vector3(0, 0.15, 0))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	vp.add_child(light)
	if scene != null:
		vp.add_child(scene.instantiate())
	return container


func _can_drop_data(_at_position: Vector2, data) -> bool:
	return data is Dictionary and data.has("source_inventory")


func _drop_data(_at_position: Vector2, data) -> void:
	if manager != null:
		manager.move_item(data["source_inventory"], data["source_index"], inventory, slot_index)
