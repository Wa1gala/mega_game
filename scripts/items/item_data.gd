## Ресурс данных предмета.
## Создаётся как .tres (правый клик в FileSystem -> New Resource -> ItemData)
## и кладётся в слоты/инвентарь.
class_name ItemData
extends Resource

@export var id: String                       # уникальный id (например "key")
@export var name: String                     # отображаемое имя ("Папка с документами")
@export var icon: Texture2D                  # иконка в UI-слоте
@export var world_mesh_scene: PackedScene    # 3D-сцена для выброса в мир (необязательно)
@export var description: String              # описание (тултип)
## Слот экипировки, в который предмет можно надеть ("weapon"); пусто — обычный предмет.
@export var equip_slot: StringName = &""
## Размер в ячейках сетки (ширина, высота). Автомат занимает 3x2.
@export var grid_size := Vector2i(1, 1)
## Повёрнут ли экземпляр на 90° в инвентаре (клавиша R). Не сохраняется в .tres:
## при повороте InventoryManager подменяет предмет его копией, чтобы не менять общий ресурс.
var rotated := false
## true — в инвентаре рисовать PNG-иконку, даже если есть 3D-модель (для крупных предметов).
@export var use_icon_in_ui := false
## Масштаб 3D-модели при выбросе в мир.
@export var world_scale := 1.0
## Размер коллизии выброшенного предмета (0 — значение по умолчанию).
@export var pickup_size := Vector3.ZERO
## Вес предмета, кг. Складывается в общий вес на персонаже (см. InventoryManager).
@export_range(0.0, 100.0, 0.05, "suffix:кг") var weight := 0.5
## Для ключей: id замка, который открывает этот ключ (LootContainer.key_id). Пусто — не ключ.
@export var key_id := ""
## Для рюкзаков/разгрузки: на сколько кг увеличивает переносимый вес, пока надет.
@export_range(0.0, 100.0, 0.5, "suffix:кг") var carry_bonus := 0.0
## Для аптечек: сколько здоровья восполняет при использовании. 0 — предмет нельзя использовать.
@export_range(0, 200, 1) var heal_amount := 0


## Размер в ячейках с учётом поворота.
func cell_size() -> Vector2i:
	var s := Vector2i(maxi(grid_size.x, 1), maxi(grid_size.y, 1))
	return Vector2i(s.y, s.x) if rotated else s


## Можно ли вращать (не квадратный предмет).
func can_rotate() -> bool:
	return grid_size.x != grid_size.y
