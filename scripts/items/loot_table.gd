## Таблица лута контейнера. Каждая запись выпадает независимо по своему шансу.
## Таблицу можно сделать отдельным .tres и использовать в нескольких ящиках
## или создать прямо в инспекторе ящика (и сделать уникальной).
class_name LootTable
extends Resource

@export var entries: Array[LootEntry] = []
## Максимум разных записей, которые выпадут за раз (0 — без ограничения).
## Если выпало больше, остаются случайные.
@export_range(0, 60) var max_entries := 0
## Минимум разных записей за раз. Если по шансам выпало меньше, недостающие
## добираются случайно из остальных (чем выше шанс, тем вероятнее). 1 — ящик никогда не пустой.
@export_range(0, 60) var min_entries := 1


## Бросок: список предметов (с повторами по количеству), которые выпали.
func roll(rng: RandomNumberGenerator) -> Array[ItemData]:
	var hits: Array[LootEntry] = []
	for e in entries:
		if e != null and e.item != null and rng.randf() * 100.0 < e.chance:
			hits.append(e)
	_top_up(hits, rng)
	if max_entries > 0 and hits.size() > max_entries:
		# Перемешиваем (Fisher-Yates) и обрезаем.
		for i in range(hits.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t := hits[i]
			hits[i] = hits[j]
			hits[j] = t
		hits.resize(max_entries)
	var result: Array[ItemData] = []
	for e in hits:
		var count := rng.randi_range(mini(e.min_count, e.max_count), maxi(e.min_count, e.max_count))
		for _k in count:
			result.append(e.item)
	return result


## Добирает записи до min_entries из невыпавших (с весом по шансу; нулевой шанс не берём).
func _top_up(hits: Array[LootEntry], rng: RandomNumberGenerator) -> void:
	var need := mini(min_entries, max_entries) if max_entries > 0 else min_entries
	while hits.size() < need:
		var pool: Array[LootEntry] = []
		var total := 0.0
		for e in entries:
			if e != null and e.item != null and e.chance > 0.0 and not hits.has(e):
				pool.append(e)
				total += e.chance
		if pool.is_empty():
			return
		var pick := rng.randf() * total
		for e in pool:
			pick -= e.chance
			if pick <= 0.0 or e == pool[-1]:
				hits.append(e)
				break
