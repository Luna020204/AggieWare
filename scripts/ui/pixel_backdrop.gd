extends Control
## Fictional Davis-inspired settings, drawn into the shared 256 x 144 surface.
## Coordinates stay in gameplay units; the owning surface supplies the 5x pixels.
const INK := Color("#14121a")
const BLUE := Color("#022851")

var kind := "lecture"


func _draw() -> void:
	match kind:
		"desk": _draw_desk()
		"lab": _draw_lab()
		"engineering": _draw_lab()
		"campus": _draw_campus()
		_: _draw_lecture()


func _box(rect: Rect2, fill: Color, edge: Color = INK, width: float = 5.0) -> void:
	draw_rect(rect, fill)
	if width > 0.0:
		draw_rect(rect, edge, false, width)


func _dither(rect: Rect2, color: Color, spacing: int = 20) -> void:
	for row: int in range(int(rect.position.y), int(rect.end.y), spacing):
		for column: int in range(int(rect.position.x), int(rect.end.x), spacing):
			if (column / spacing + row / spacing) % 2 == 0:
				draw_rect(Rect2(column, row, 5, 5), color)


func _window(rect: Rect2) -> void:
	_box(rect, Color("#254958"), INK, 10)
	draw_rect(Rect2(rect.position + Vector2(10, 10), Vector2(rect.size.x - 20, 15)), Color("#52717a"))
	_dither(Rect2(rect.position + Vector2(10, 30), rect.size - Vector2(20, 40)), Color("#345a68"), 25)
	draw_rect(Rect2(rect.position.x + rect.size.x * 0.5 - 5, rect.position.y, 10, rect.size.y), Color("#142d3a"))
	draw_rect(Rect2(rect.position.x, rect.position.y + rect.size.y * 0.5 - 5, rect.size.x, 10), Color("#142d3a"))


func _bookcase(at: Vector2, width: float) -> void:
	_box(Rect2(at, Vector2(width, 150)), Color("#3a2b28"), INK, 10)
	for shelf: int in 2:
		var top := at.y + 15 + shelf * 65
		for book: int in range(int(width / 25.0) - 1):
			var height := 35.0 + float((book + shelf * 3) % 3) * 5.0
			var color: Color = [Color("#6e4b44"), Color("#3f6175"), Color("#758166"), Color("#a68b55")][(book + shelf) % 4]
			_box(Rect2(at.x + 15 + book * 25, top + 45 - height, 20, height), color)
			draw_rect(Rect2(at.x + 20 + book * 25, top + 45 - height + 10, 10, 5), Color("#baa473"))
		draw_rect(Rect2(at.x + 5, top + 45, width - 10, 10), Color("#745443"))


func _draw_desk() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("#293b43"))
	_window(Rect2(420, -25, 440, 210))
	_bookcase(Vector2(30, 45), 330)
	_bookcase(Vector2(920, 45), 330)
	# A broad wooden work surface supports each game's own interactive objects.
	_box(Rect2(-10, 205, 1300, 540), Color("#76533d"), INK, 10)
	draw_rect(Rect2(0, 215, 1280, 15), Color("#b18b5a"))
	for plank: int in 7:
		var top := 240 + plank * 70
		draw_rect(Rect2(0, top, 1280, 5), Color("#4c382e"))
		for mark: int in 8:
			var left := float((mark * 185 + plank * 85) % 1220)
			draw_rect(Rect2(left, top + 25, 45, 5), Color("#826044"))
	_dither(Rect2(0, 635, 1280, 85), Color("#61432f"), 25)
	# Notebook and mug sit at the edge, outside the primary interaction area.
	_box(Rect2(1010, 620, 190, 80), Color("#b5b49a"))
	draw_rect(Rect2(1025, 630, 5, 60), Color("#4f5c66"))
	for line: int in 3:
		draw_rect(Rect2(1045, 640 + line * 15, 130, 5), Color("#82908b"))
	draw_circle(Vector2(90, 655), 40, INK)
	draw_circle(Vector2(90, 655), 30, BLUE)
	draw_circle(Vector2(90, 650), 20, Color("#412e25"))
	draw_arc(Vector2(125, 655), 20, -PI * 0.5, PI * 0.5, 8, INK, 10)


func _draw_lecture() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("#29373b"))
	for tile: int in 8:
		draw_rect(Rect2(tile * 160, 0, 5, 125), Color("#36484a"))
	_box(Rect2(145, 20, 230, 20), Color("#d2d2b4"))
	_box(Rect2(905, 20, 230, 20), Color("#d2d2b4"))
	# This is the room's physical chalkboard, not a HUD or instruction panel.
	_box(Rect2(25, 135, 1230, 465), Color("#172f30"), Color("#101b23"), 15)
	draw_rect(Rect2(40, 150, 1200, 10), Color("#39534c"))
	_dither(Rect2(45, 165, 1190, 415), Color("#1a3332"), 35)
	draw_rect(Rect2(20, 595, 1240, 15), Color("#8f7951"))
	draw_rect(Rect2(65, 585, 45, 10), Color("#c3c9ac"))
	draw_rect(Rect2(1170, 575, 50, 20), Color("#6b6b58"))
	# Foreground seats frame the activity without covering the playfield.
	draw_rect(Rect2(0, 615, 1280, 105), Color("#282529"))
	for seat: int in 8:
		var left := seat * 170 - 35
		_box(Rect2(left, 650, 145, 70), Color("#3e4850"), INK, 10)
		draw_rect(Rect2(left + 10, 660, 125, 10), Color("#637079"))
		_box(Rect2(left - 15, 630, 175, 15), Color("#8a6946"))


func _draw_lab() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("#1d3944"))
	for row: int in 6:
		draw_rect(Rect2(0, row * 65, 1280, 5), Color("#294952"))
		for column: int in 9:
			draw_rect(Rect2(column * 155 + (75 if row % 2 == 0 else 0), row * 65, 5, 65), Color("#294952"))
	_box(Rect2(-5, 390, 1290, 335), Color("#30454a"), INK, 10)
	draw_rect(Rect2(0, 400, 1280, 15), Color("#637a78"))
	_dither(Rect2(0, 680, 1280, 40), Color("#263b40"), 20)
	# Instrument housing beneath the interactive eyepiece.
	_box(Rect2(375, 515, 115, 155), Color("#798b89"), INK, 10)
	draw_rect(Rect2(390, 525, 20, 125), Color("#b8c4b2"))
	_box(Rect2(245, 655, 380, 40), Color("#829391"), INK, 10)
	draw_circle(Vector2(630, 565), 40, INK)
	draw_circle(Vector2(630, 565), 30, Color("#9ba6a0"))
	draw_rect(Rect2(625, 540, 10, 50), Color("#506169"))
	for bottle: int in 3:
		var left := 45 + bottle * 60
		_box(Rect2(left + 10, 440, 25, 25), Color("#739e9a"))
		_box(Rect2(left, 465, 45, 85), Color("#427879"))
		draw_rect(Rect2(left + 5, 505, 35, 40), Color("#294e62"))
		draw_rect(Rect2(left + 10, 475, 5, 60), Color("#9bb9ae"))
	# The reference bacterium is drawn over a small physical specimen dish.
	draw_circle(Vector2(910, 275), 80, INK)
	draw_circle(Vector2(910, 275), 70, Color("#7d9b8f"))
	draw_circle(Vector2(910, 275), 60, Color("#c1cdb2"))


func _tree(at: Vector2, radius: float = 75.0) -> void:
	_box(Rect2(at.x - 15, at.y + 30, 30, 135), Color("#624333"))
	draw_circle(at, radius + 10, INK)
	draw_circle(at, radius, Color("#285345"))
	draw_circle(at + Vector2(-20, -20), radius * 0.65, Color("#3b6d4c"))
	_dither(Rect2(at.x - 35, at.y - 45, 65, 60), Color("#527d50"), 20)


func _draw_campus() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("#2e5267"))
	_dither(Rect2(0, 90, 1280, 115), Color("#365e70"), 25)
	draw_rect(Rect2(0, 200, 1280, 520), Color("#314f42"))
	_box(Rect2(350, 135, 730, 230), Color("#7b735f"), INK, 10)
	draw_rect(Rect2(335, 125, 760, 20), Color("#b09b73"))
	for window: int in 8:
		_window(Rect2(380 + window * 85, 175, 55, 105))
	draw_rect(Rect2(0, 375, 1280, 10), Color("#56705a"))
	_tree(Vector2(85, 205), 85)
	_tree(Vector2(1190, 220), 90)
	draw_rect(Rect2(0, 590, 1280, 130), Color("#8c8069"))
	for row: int in 3:
		draw_rect(Rect2(0, 590 + row * 45, 1280, 5), Color("#655f53"))
		for joint: int in 10:
			draw_rect(Rect2(joint * 145 + (70 if row % 2 == 0 else 0), 590 + row * 45, 5, 45), Color("#655f53"))
	# A bicycle rack sits at the far edge of the walkway.
	for rack: int in 4:
		draw_arc(Vector2(1040 + rack * 50, 650), 20, PI, TAU, 8, INK, 15)
		draw_arc(Vector2(1040 + rack * 50, 650), 20, PI, TAU, 8, Color("#819391"), 5)
		draw_line(Vector2(1020 + rack * 50, 650), Vector2(1020 + rack * 50, 700), INK, 10)
		draw_line(Vector2(1060 + rack * 50, 650), Vector2(1060 + rack * 50, 700), INK, 10)
