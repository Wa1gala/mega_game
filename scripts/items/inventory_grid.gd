## Сетка инвентаря: один Control рисует все ячейки, линии и предметы, сам принимает
## мышь и drag-and-drop. Так перетаскивание работает над любой точкой сетки
## (а не только над «правильной» ячейкой), а линии между ячейками общие.
## Один и тот же класс используется для рюкзака, карманов, шкафа и слотов экипировки
## (слот экипировки — сетка 1x1, где одна «ячейка» растянута до размера слота).
class_name InventoryGrid
extends Control

## Правый клик по предмету (для контекстного меню «Выбросить»).
signal item_right_clicked(grid: InventoryGrid, anchor: int)

const ACCENT := Color(0.62, 0.66, 0.67)          # серая обводка предметов
const CELL_BG := Color(0.10, 0.11, 0.12, 0.45)
const CELL_HOVER := Color(0.85, 0.9, 0.9, 0.09)
const LINE := Color(0.62, 0.68, 0.68, 0.20)
const ITEM_FILL := Color(0.25, 0.26, 0.27, 0.80)  # серая подложка
const ITEM_FILL_HOVER := Color(0.33, 0.34, 0.35, 0.88)
const SEARCH_FILL := Color(0.18, 0.19, 0.20, 0.75)
const SEARCH_HATCH := Color(0.62, 0.66, 0.67, 0.16)
const NAME_COLOR := Color(0.82, 0.85, 0.85, 0.9)

## Менеджер (автолоад InventoryManager) — правила размещения и перемещения.
var manager: Node = null
## Массив-хранилище (у предмета в массиве только «якорная» ячейка — левый верхний угол).
var inventory: Array = []
var columns := 1
## Сторона базовой ячейки в пикселях (подбирается под экран).
var cell := 64
## Размер одной ячейки этой сетки в базовых ячейках (слот оружия — 6x2).
var slot_cells := Vector2(1, 1)
## Добавка к размеру ячейки в пикселях (выравнивание слота оружия по колонке).
var slot_extra := Vector2.ZERO
## Подпись пустого слота экипировки.
var placeholder := ""
## Выключенная сетка (рюкзак не надет) не показывает ячейки и не принимает предметы.
var enabled := true
var disabled_text := ""
## Якоря ещё не обысканных предметов (ключи словаря): рисуются штриховкой с лупой.
var unsearched: Dictionary = {}

var _view_of: Dictionary = {}      # якорь -> Control с содержимым предмета
var _hover := Vector2i(-1, -1)
var _drag_anchor := -1
var _tip_anchor := -1             # якорь предмета, для которого показана подсказка
var _hint := Rect2()
var _hint_state := 0               # 0 — нет, 1 — можно положить, 2 — нельзя


func _process(_delta: float) -> void:
	if not unsearched.is_empty():
		queue_redraw()   # анимация лупы


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func cell_px() -> Vector2:
	return Vector2(cell * slot_cells.x, cell * slot_cells.y) + slot_extra


func _rows() -> int:
	return ceili(float(inventory.size()) / float(maxi(columns, 1)))


func _get_minimum_size() -> Vector2:
	var rows := _rows()
	if rows == 0:
		return Vector2.ZERO
	var cp := cell_px()
	return Vector2(columns * cp.x + 1.0, rows * cp.y + 1.0)


func set_cell(value: int) -> void:
	cell = value
	refresh()


func _cell_at(pos: Vector2) -> Vector2i:
	var cp := cell_px()
	return Vector2i(floori(pos.x / cp.x), floori(pos.y / cp.y))


func _index_of(c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= columns or c.y >= _rows():
		return -1
	var i := c.y * columns + c.x
	return i if i < inventory.size() else -1


func _anchor_at(c: Vector2i) -> int:
	if manager == null:
		return -1
	var i := _index_of(c)
	if i < 0:
		return -1
	var a := int(manager.anchor_index(inventory, i))
	return -1 if unsearched.has(a) else a   # необысканный предмет нельзя ни взять, ни навести


## Якорь предмета под курсором (или -1).
func hovered_anchor() -> int:
	return _anchor_at(_cell_at(get_local_mouse_position()))


func _item_rect_px(anchor: int) -> Rect2:
	var cp := cell_px()
	var item: ItemData = inventory[anchor]
	var cells: Vector2i = manager.item_size(inventory, item)
	return Rect2(Vector2(anchor % columns, anchor / columns) * cp, Vector2(cells) * cp)


# ---------- Отрисовка ----------

func refresh() -> void:
	for v in _view_of.values():
		(v as Node).queue_free()
	_view_of.clear()
	update_minimum_size()
	if enabled and manager != null:
		for i in inventory.size():
			var item: ItemData = inventory[i]
			if item == null or unsearched.has(i):
				continue
			var rect := _item_rect_px(i)
			var view := make_item_visual(item, rect.size, cell, false)
			view.position = rect.position
			if i == _drag_anchor:
				view.modulate.a = 0.3
			add_child(view)
			_view_of[i] = view
	queue_redraw()


func _draw() -> void:
	var rows := _rows()
	if rows == 0:
		return
	var cp := cell_px()
	var total := Vector2(columns * cp.x, rows * cp.y)
	var font := ThemeDB.fallback_font
	var fs := maxi(9, int(cell * 0.17))

	draw_rect(Rect2(Vector2.ZERO, total), CELL_BG)
	if not enabled:
		draw_rect(Rect2(Vector2.ZERO, total), Color(0, 0, 0, 0.25))
		draw_string(font, Vector2(0, total.y * 0.5 + fs * 0.35), disabled_text,
				HORIZONTAL_ALIGNMENT_CENTER, total.x, fs + 2, Color(0.6, 0.64, 0.64, 0.6))
		_draw_lines(cp, rows, total, Color(LINE, 0.08))
		return

	if _index_of(_hover) >= 0:
		draw_rect(Rect2(Vector2(_hover) * cp, cp), CELL_HOVER)
	_draw_lines(cp, rows, total, LINE)

	# Подпись пустого слота экипировки.
	if placeholder != "" and inventory.size() == 1 and inventory[0] == null:
		draw_string(font, Vector2(0, total.y * 0.5 + fs * 0.35), placeholder,
				HORIZONTAL_ALIGNMENT_CENTER, total.x, fs, Color(0.62, 0.66, 0.66, 0.5))

	# Предметы: полупрозрачный тонированный фон, обводка и мягкое свечение.
	var hover_anchor := _anchor_at(_hover)
	for i in inventory.size():
		if inventory[i] == null:
			continue
		var rect := _item_rect_px(i)
		if unsearched.has(i):
			_draw_searching(rect, i == _first_hidden())
			continue
		var hot := i == hover_anchor
		draw_rect(rect, ITEM_FILL_HOVER if hot else ITEM_FILL)
		draw_rect(rect, Color(ACCENT, 0.9) if hot else Color(ACCENT, 0.45), false, 1.0)

	# Подсказка, куда ляжет перетаскиваемый предмет.
	if _hint_state != 0:
		var ok := _hint_state == 1
		draw_rect(_hint, Color(0.3, 0.9, 0.45, 0.22) if ok else Color(0.95, 0.3, 0.3, 0.22))
		draw_rect(_hint, Color(0.4, 1.0, 0.55, 0.9) if ok else Color(1.0, 0.4, 0.4, 0.9), false, 1.0)


func _first_hidden() -> int:
	var best := -1
	for k in unsearched:
		if best < 0 or int(k) < best:
			best = int(k)
	return best


## Необысканный предмет: тёмная подложка, диагональная штриховка и лупа.
func _draw_searching(rect: Rect2, active: bool) -> void:
	draw_rect(rect, SEARCH_FILL)
	var w := rect.size.x
	var h := rect.size.y
	var step := 9.0
	var d := step
	while d < w + h:
		var x1 := minf(d, w)
		var y1 := d - x1
		var y2 := minf(d, h)
		var x2 := d - y2
		draw_line(rect.position + Vector2(x1, y1), rect.position + Vector2(x2, y2), SEARCH_HATCH, 1.0)
		d += step
	draw_rect(rect, Color(ACCENT, 0.3), false, 1.0)
	var r := minf(minf(w, h) * 0.2, float(cell) * 0.3)
	var pulse := 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.008) if active else 0.45
	var col := Color(0.88, 0.91, 0.91, pulse)
	var c := rect.get_center() + Vector2(-r * 0.2, -r * 0.2)
	draw_arc(c, r, 0.0, TAU, 28, col, 2.0, true)
	draw_line(c + Vector2(r, r) * 0.72, c + Vector2(r, r) * 1.55, col, 3.0, true)


func _draw_lines(cp: Vector2, rows: int, total: Vector2, color: Color) -> void:
	for x in columns + 1:
		draw_line(Vector2(x * cp.x, 0), Vector2(x * cp.x, total.y), color, 1.0)
	for y in rows + 1:
		draw_line(Vector2(0, y * cp.y), Vector2(total.x, y * cp.y), color, 1.0)


## Содержимое предмета: 3D-превью или иконка + имя. framed — со своим фоном (для drag).
static func make_item_visual(item: ItemData, px: Vector2, base: int, framed := false) -> Control:
	var root: Control
	if framed:
		var panel := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.29, 0.30, 0.31, 0.88)
		sb.border_color = Color(ACCENT.lightened(0.3), 0.9)
		sb.set_border_width_all(1)
		panel.add_theme_stylebox_override("panel", sb)
		root = panel
	else:
		root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.custom_minimum_size = px
	root.size = px

	var pad := float(base) * 0.06
	var has_art := (item.world_mesh_scene != null and not item.use_icon_in_ui) or item.icon != null
	var label_h := 0.0   # названия в ячейках не рисуем — только в тултипе при наведении
	if has_art:
		var art: Control
		if item.world_mesh_scene != null and not item.use_icon_in_ui:
			art = _make_3d_preview(item.world_mesh_scene)
		else:
			var tex := TextureRect.new()
			tex.texture = item.icon
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			art = tex
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if item.rotated:
			# Повёрнутый предмет: рисуем в исходной ориентации и крутим на 90° вокруг центра.
			var asz := Vector2(maxf(px.y - pad * 2.0, 1.0), maxf(px.x - pad * 2.0, 1.0))
			art.size = asz
			art.pivot_offset = asz * 0.5
			art.rotation = PI * 0.5
			art.position = px * 0.5 - asz * 0.5
		else:
			art.position = Vector2(pad, pad)
			art.size = Vector2(maxf(px.x - pad * 2.0, 1.0), maxf(px.y - pad * 2.0 - label_h, 1.0))
		root.add_child(art)

	if has_art:
		# Мелкое название справа сверху.
		var nm := Label.new()
		nm.text = item.name
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		nm.clip_text = true
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nm.add_theme_color_override("font_color", NAME_COLOR)
		var nfs := maxi(8, int(float(base) * 0.15))
		nm.add_theme_font_size_override("font_size", nfs)
		nm.position = Vector2(2, 0)
		nm.size = Vector2(maxf(px.x - 5.0, 1.0), float(nfs) + 6.0)
		root.add_child(nm)
	else:
		# Предмет без картинки (заглушка, например рюкзак): название по центру.
		var label := Label.new()
		label.text = item.name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override("font_color", Color(0.78, 0.84, 0.8))
		label.position = Vector2.ZERO
		label.size = px
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", maxi(10, int(float(base) * 0.2)))
		root.add_child(label)
	return root


static func _make_3d_preview(scene: PackedScene) -> SubViewportContainer:
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
	# Узел ещё не в дереве, поэтому look_at_from_position, а не look_at.
	cam.look_at_from_position(Vector3(0.3, 0.22, 0.45), Vector3(0, 0.15, 0))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	vp.add_child(light)
	vp.add_child(scene.instantiate())
	return container


# ---------- Мышь ----------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var c := _cell_at((event as InputEventMouseMotion).position)
		if c != _hover:
			_hover = c
			queue_redraw()
			_update_tooltip(_anchor_at(c))
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		if manager != null:
			manager.close_context_menu()
		_update_tooltip(-1)
		# Ctrl + левый клик: быстро переложить предмет в свободное место.
		if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and (event as InputEventMouseButton).ctrl_pressed \
				and enabled and manager != null:
			var qa := _anchor_at(_cell_at((event as InputEventMouseButton).position))
			if qa >= 0:
				manager.quick_move(inventory, qa)
				accept_event()
			return
		if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT and enabled:
			var a := _anchor_at(_cell_at((event as InputEventMouseButton).position))
			if a >= 0:
				item_right_clicked.emit(self, a)


## Подсказка о предмете (рисует менеджер, следует за мышью).
func _update_tooltip(anchor: int) -> void:
	if anchor == _tip_anchor:
		return
	_tip_anchor = anchor
	if manager == null:
		return
	if anchor >= 0 and enabled:
		manager.show_item_tooltip(inventory[anchor])
	else:
		manager.hide_item_tooltip()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_update_tooltip(-1)
		_hover = Vector2i(-1, -1)
		_hint_state = 0
		queue_redraw()
	elif what == NOTIFICATION_DRAG_END:
		if manager != null:
			manager.drag_data = {}
		_drag_anchor = -1
		_hint_state = 0
		for v in _view_of.values():
			(v as Control).modulate.a = 1.0
		queue_redraw()


# ---------- Drag-and-drop ----------

func _get_drag_data(at_position: Vector2):
	if not enabled or manager == null:
		return null
	_update_tooltip(-1)
	var a := _anchor_at(_cell_at(at_position))
	if a < 0:
		return null
	var item: ItemData = inventory[a]
	var gs := Vector2(item.cell_size())

	# За какую точку рамки предмета его взяли (в долях ячейки).
	var grab: Vector2
	if manager.is_single(inventory):
		var cp := cell_px()
		grab = Vector2(at_position.x / cp.x, at_position.y / cp.y) * gs
	else:
		grab = at_position / cell_px() - Vector2(a % columns, a / columns)
	grab = grab.clamp(Vector2.ZERO, gs - Vector2(0.01, 0.01))

	# "item" — предмет «в руке» (при вращении на R подменяется повёрнутой копией).
	var data := {"source": inventory, "index": a, "grab": grab, "item": item, "grid": self}
	update_drag_preview(data)
	manager.drag_data = data

	_drag_anchor = a
	if _view_of.has(a):
		(_view_of[a] as Control).modulate.a = 0.3
	return data


## Предмет в руке выглядит как в слоте и висит под курсором той же точкой рамки.
func update_drag_preview(data: Dictionary) -> void:
	var item: ItemData = data["item"]
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var visual := make_item_visual(item, Vector2(item.cell_size()) * float(cell), cell, true)
	visual.position = -(data["grab"] as Vector2) * float(cell)
	holder.add_child(visual)
	set_drag_preview(holder)


func _drag_target(at_position: Vector2, data: Dictionary) -> Dictionary:
	var source: Array = data["source"]
	var item := (data["item"] if data.has("item") else source[data["index"]]) as ItemData
	if item == null:
		return {}
	var gs: Vector2i = manager.item_size(inventory, item)
	var c := Vector2i.ZERO
	if not manager.is_single(inventory):
		var top_left := at_position / cell_px() - (data["grab"] as Vector2)
		c = Vector2i(roundi(top_left.x), roundi(top_left.y))
		c.x = clampi(c.x, 0, maxi(columns - gs.x, 0))
		c.y = clampi(c.y, 0, maxi(_rows() - gs.y, 0))
	return {"cell": c, "size": gs}


func _can_drop_data(at_position: Vector2, data) -> bool:
	if not enabled or manager == null or not (data is Dictionary) or not data.has("source"):
		return false
	var target := _drag_target(at_position, data)
	if target.is_empty():
		return false
	var c: Vector2i = target["cell"]
	var ok: bool = manager.can_move(data["source"], data["index"], inventory, c, data.get("item"))
	_hint = Rect2(Vector2(c) * cell_px(), Vector2(target["size"]) * cell_px())
	_hint_state = 1 if ok else 2
	queue_redraw()
	return ok


func _drop_data(at_position: Vector2, data) -> void:
	_hint_state = 0
	queue_redraw()
	if manager == null:
		return
	var target := _drag_target(at_position, data)
	if target.is_empty():
		return
	manager.move_item(data["source"], data["index"], inventory, target["cell"], data.get("item"))
