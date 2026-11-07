## Одна строка таблицы лута: какой предмет, с каким шансом и в каком количестве.
class_name LootEntry
extends Resource

@export var item: ItemData
## Шанс выпадения, %. 100 — гарантированно.
@export_range(0.0, 100.0, 0.5, "suffix:%") var chance := 50.0
## Сколько штук кладётся при выпадении (случайно от min до max).
@export_range(1, 20) var min_count := 1
@export_range(1, 20) var max_count := 1
