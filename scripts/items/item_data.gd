## Ресурс данных предмета.
## Создаётся как .tres (правый клик в FileSystem -> New Resource -> ItemData)
## и кладётся в слоты/инвентарь.
class_name ItemData
extends Resource

@export var id: String                       # уникальный id (например "file_binder_alt4")
@export var name: String                     # отображаемое имя ("Папка с документами")
@export var icon: Texture2D                  # иконка в UI-слоте
@export var world_mesh_scene: PackedScene    # 3D-сцена для выброса в мир
@export var description: String              # описание (тултип)
