## Слот инвентаря (UI-панель).
## Показывает предмет (3D-превью или PNG-иконку), имя, поддерживает drag-and-drop
## и правый клик (контекстное меню «Выбросить»). Предмет больше 1x1 хранится в
## «якорной» ячейке (левый верхний угол) и рисуется поверх соседних ячеек.
class_name InventorySlot
extends Panel

## Правый клик по слоту (для контекстного меню «Выбросить»).
signal slot_right_clicked(slot: InventorySlot)

const DEFAULT_SIZE := 64
## Цвет обводки и подсветки предмета.
const ITEM_ACCENT := Color(0.62, 0.78, 0.66)

static var _style_empty: StyleBoxFlat
static var _style_empty_hover: StyleBoxFlat
static var _style_item: StyleBoxFlat
static var _style_item_hover: StyleBoxFlat

## Ссылка на массив инвентаря, которому принадлежит слот
## (InventoryManager.player_inventory, карманы, оружие или inventory шкафа).
var inventory: Array = []
## Индекс слота внутри массива.
var slot_index: int = 0
## Менеджер (автолоад InventoryManager) — обрабатывает перемещение.
var manager: Node = null
## Сторона ячейки в пикселях.
var slot_size: int = DEFAULT_SIZE
## Размер самого слота в ячейках (слот оружия — широкий 6x2).
var slot_cells := Vector2(1, 1)
## Если не пусто — слот экипировки: принимает только предметы с таким equip_slot.
var accepts: StringName = &""
## Подпись пустого слота экипировки («ОРУЖИЕ»).
var placeholder: String = ""

var _hovered := false
var _item_bg: Panel
var _icon_rect: TextureRect
var _placeholder_label: Label
var _preview: SubViewportContainer
var _viewport: SubViewport
var _camera: Camera3D
var _model_instance: Node3D = null
var _name_label: Label


func _init() -> void:
	custom_minimum_size = Vector2(DEFAULT_SIZE, DEFAULT_SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_visuals()


## Стили общие для всех слотов. Пустая ячейка рисует только правую и нижнюю линии —
## соседние ячейки сливаются в одну сетку с общими линиями (левую и верхнюю
## границу рисует рамка сетки, см. InventoryManager._make_grid).
static func _ensure_styles() -> void:
	if _style_empty != null:
		return
	_style_empty = StyleBoxFlat.new()
	_style_empty.bg_color = Color(0.07, 0.078, 0.086, 0.92)
	_style_empty.border_color = Color(0.24, 0.27, 0.29)
	_style_empty.border_width_right = 1
	_style_empty.border_width_bottom = 1

	_style_empty_hover = _style_empty.duplicate() as StyleBoxFlat
	_style_empty_hover.bg_color = Color(0.11, 0.125, 0.135, 0.95)

	# Ячейка с предметом: тонированный фон, яркая обводка и мягкое свечение.
	_style_item = StyleBoxFlat.new()
	_style_item.bg_color = Color(0.12, 0.15, 0.135, 0.97)
	_style_item.border_color = ITEM_ACCENT
	_style_item.set_border_width_all(1)
	_style_item.shadow_color = Color(ITEM_ACCENT.r, ITEM_ACCENT.g, ITEM_ACCENT.b, 0.35)
	_style_item.shadow_size = 6

	_style_item_hover = _style_item.duplicate() as StyleBoxFlat
	_style_item_hover.bg_color = Color(0.17, 0.21, 0.19, 0.98)
	_style_item_hover.border_color = Color(0.8, 0.95, 0.84)
	_style_item_hover.shadow_size = 9


func _build_visuals() -> void:
	_ensure_styles()
	mouse_entered.connect(func() -> void:
		_hovered = true
		_update_style())
	mouse_exited.connect(func() -> void:
		_hovered = false
		_update_style())
	add_theme_stylebox_override("panel", _style_empty)

	# Фон крупного предмета (рисуется на весь его размер, а не одной ячейки).
	_item_bg = Panel.new()
	_item_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_item_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_item_bg.visible = false
	add_child(_item_bg)

	# 3D-превью предмета.
	_preview = SubViewportContainer.new()
	_preview.stretch = true
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_preview)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(DEFAULT_SIZE, DEFAULT_SIZE)
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

	# 2D-иконка (PNG) — для предметов без 3D-превью, например автомата.
	_icon_rect = TextureRect.new()
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon_rect.visible = false
	add_child(_icon_rect)

	# Имя предмета (обрезается, чтобы не вылезало за ячейку).
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_name_label.add_theme_color_override("font_color", Color(0.62, 0.66, 0.70))
	add_child(_name_label)

	# Подпись пустого слота экипировки.
	_placeholder_label = Label.new()
	_placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_placeholder_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_placeholder_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_placeholder_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_placeholder_label.add_theme_color_override("font_color", Color(0.42, 0.44, 0.46))
	add_child(_placeholder_label)

	_apply_geometry()


func _ready() -> void:
	_camera.look_at(Vector3(0, 0.15, 0))
	refresh()


## Меняет размер ячейки (подбирается под экран в InventoryManager._apply_layout).
func set_slot_size(size: int) -> void:
	slot_size = size
	custom_minimum_size = Vector2(size * slot_cells.x, size * slot_cells.y)
	_apply_geometry()


## Сколько ячеек сетки занимает предмет из этого слота (в слотах экипировки — один слот целиком).
func _extent() -> Vector2i:
	var it := get_item()
	if it == null or accepts != &"":
		return Vector2i(1, 1)
	return Vector2i(maxi(it.grid_size.x, 1), maxi(it.grid_size.y, 1))


## Содержимое слота растягивается на весь размер предмета (в том числе поверх соседних ячеек).
func _apply_geometry() -> void:
	if _preview == null:
		return
	var size := slot_size
	var ext := _extent()
	var extra := Vector2((ext.x - 1) * size, (ext.y - 1) * size)
	var pad := float(size) * 0.06
	var label_h := float(size) * 0.22

	_item_bg.offset_right = extra.x
	_item_bg.offset_bottom = extra.y
	for c in [_preview, _icon_rect]:
		c.offset_left = pad
		c.offset_top = pad
		c.offset_right = extra.x - pad
		c.offset_bottom = extra.y - label_h
	_viewport.size = Vector2i(maxi(int((slot_cells.x + ext.x - 1) * size - pad * 2), 8),
			maxi(int((slot_cells.y + ext.y - 1) * size - pad * 2 - label_h), 8))
	_name_label.offset_right = extra.x
	_name_label.offset_bottom = extra.y
	_name_label.offset_top = extra.y - label_h
	_name_label.add_theme_font_size_override("font_size", maxi(9, int(float(size) * 0.13)))
	_placeholder_label.add_theme_font_size_override("font_size", maxi(8, int(float(size) * 0.17)))


func _update_style() -> void:
	var has_item := get_item() != null
	var multi := has_item and _extent() != Vector2i(1, 1)
	var style: StyleBoxFlat
	if has_item:
		style = _style_item_hover if _hovered else _style_item
	else:
		style = _style_empty_hover if _hovered else _style_empty
	if multi:
		# Крупный предмет: стиль рисует отдельная панель на весь его размер.
		_item_bg.add_theme_stylebox_override("panel", style)
		_item_bg.visible = true
		add_theme_stylebox_override("panel", _style_empty)
	else:
		_item_bg.visible = false
		add_theme_stylebox_override("panel", style)
	# Предмет с подсветкой рисуется поверх соседних ячеек, иначе свечение перекрывается.
	z_index = 1 if has_item else 0


func get_item() -> ItemData:
	if slot_index >= inventory.size():
		return null
	return inventory[slot_index]


func refresh() -> void:
	var it := get_item()
	if it != null:
		_name_label.text = it.name
		tooltip_text = it.description
		var use_mesh := it.world_mesh_scene != null and not it.use_icon_in_ui
		_set_model(it.world_mesh_scene if use_mesh else null)
		_preview.visible = use_mesh
		_icon_rect.texture = it.icon
		_icon_rect.visible = not use_mesh and it.icon != null
		_placeholder_label.text = ""
	else:
		_name_label.text = ""
		tooltip_text = ""
		_set_model(null)
		_preview.visible = true
		_icon_rect.visible = false
		_placeholder_label.text = placeholder
	_apply_geometry()
	_update_style()


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

func _get_drag_data(at_position: Vector2):
	# Клик по любой клетке крупного предмета берёт весь предмет за его якорь.
	var anchor := manager.anchor_index(inventory, slot_index) as int if manager != null else slot_index
	if anchor < 0 or inventory[anchor] == null:
		return null
	var item: ItemData = inventory[anchor]
	var grab: Vector2i = manager.grab_offset(inventory, slot_index, anchor) if manager != null else Vector2i.ZERO

	# Предмет в руке выглядит как в слоте и держится за ту же точку своей рамки, что и в слоте.
	var frame_px := Vector2(slot_size * maxi(item.grid_size.x, 1), slot_size * maxi(item.grid_size.y, 1))
	var cursor_in_frame := at_position + Vector2(grab) * slot_size
	if accepts != &"":
		cursor_in_frame = at_position / size * frame_px   # слот экипировки: пропорционально
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var visual := _make_drag_visual(item, frame_px)
	visual.position = -cursor_in_frame
	holder.add_child(visual)
	set_drag_preview(holder)
	return {"source_inventory": inventory, "source_index": anchor, "grab": grab}


## Копия внешнего вида слота с предметом: фон с обводкой и свечением, модель/иконка, имя.
func _make_drag_visual(item: ItemData, frame_px: Vector2) -> Control:
	var root := Panel.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.custom_minimum_size = frame_px
	root.size = frame_px
	root.add_theme_stylebox_override("panel", _style_item_hover)

	var pad := float(slot_size) * 0.06
	var label_h := float(slot_size) * 0.22
	var content: Control
	if item.world_mesh_scene != null and not item.use_icon_in_ui:
		content = _make_drag_preview(item.world_mesh_scene)
	else:
		var tex := TextureRect.new()
		tex.texture = item.icon
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		content = tex
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.position = Vector2(pad, pad)
	content.size = Vector2(frame_px.x - pad * 2.0, frame_px.y - pad - label_h)
	root.add_child(content)

	var label := Label.new()
	label.text = item.name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2(0, frame_px.y - label_h)
	label.size = Vector2(frame_px.x, label_h)
	label.add_theme_font_size_override("font_size", maxi(9, int(float(slot_size) * 0.13)))
	label.add_theme_color_override("font_color", Color(0.62, 0.66, 0.70))
	root.add_child(label)
	return root


## Создаёт 3D-превью предмета для drag-and-drop (та же камера и свет, что в слоте).
func _make_drag_preview(scene: PackedScene) -> SubViewportContainer:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.size = Vector2i(96, 96)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(vp)
	var cam := Camera3D.new()
	cam.current = true
	vp.add_child(cam)
	cam.position = Vector3(0.3, 0.22, 0.45)
	cam.look_at(Vector3(0, 0.15, 0))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	vp.add_child(light)
	if scene != null:
		vp.add_child(scene.instantiate())
	return container


func _can_drop_data(_at_position: Vector2, data) -> bool:
	if not (data is Dictionary and data.has("source_inventory")):
		return false
	return manager == null or manager.can_move(data["source_inventory"], data["source_index"],
			inventory, slot_index, data.get("grab", Vector2i.ZERO))


func _drop_data(_at_position: Vector2, data) -> void:
	if manager != null:
		manager.move_item(data["source_inventory"], data["source_index"],
				inventory, slot_index, data.get("grab", Vector2i.ZERO))
