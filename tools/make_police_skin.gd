extends SceneTree

# Перекрашивает текстуру игрока (man_tex.png) в полицейскую форму:
# тёмный жилет, голубые рукава, тёмно-серые брюки. Лицо/руки не трогаем.
# Запуск: godot --headless --path . --script tools/make_police_skin.gd

const SRC := "res://art/characters/player/man_tex.png"
const DST := "res://art/characters/enemy/man_police_tex.png"


func _init() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SRC))
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.v < 0.08:
				continue
			var is_skin := c.s > 0.22 and c.h > 0.02 and c.h < 0.12
			var is_green := c.s > 0.2 and c.h > 0.2 and c.h < 0.5
			if is_skin:
				continue
			if is_green:  # галстук -> цвет жилета
				img.set_pixel(x, y, Color.from_hsv(0.6, 0.1, 0.16))
			elif c.s < 0.25 and c.v > 0.45:  # светлая рубашка
				if x < 575 and y < 330:  # торс -> чёрный жилет
					img.set_pixel(x, y, Color.from_hsv(0.6, 0.12, 0.10 + c.v * 0.22))
				else:  # рукава -> голубая рубашка
					img.set_pixel(x, y, Color.from_hsv(0.6, 0.38, clampf(c.v + 0.1, 0.0, 1.0)))
			elif c.s < 0.3 and c.v < 0.35 and y >= 330 and x < 575:  # брюки -> нейтральный тёмно-серый
				img.set_pixel(x, y, Color.from_hsv(0.6, 0.04, c.v * 1.15))
	var err := img.save_png(ProjectSettings.globalize_path(DST))
	print("saved ", DST, " err=", err)
	quit()
