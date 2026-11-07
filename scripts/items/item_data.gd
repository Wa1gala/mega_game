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
