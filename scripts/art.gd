class_name Art
extends RefCounted
# Komplett prozedurale Pixel-Art. Keine externen Assets.

static var goods := {}      # good -> Texture2D (20x20, fuer die Oberflaeche)
static var goods_w := {}    # good -> Texture2D (10x10, fuer die Welt)
static var objs := {}       # O -> Array[variant] -> Array[4 stages] -> Array[2 frames] Texture2D
static var bld := {}        # type -> Array[Texture2D] (Frames)
static var man := {}        # key -> Array[Texture2D]
static var an := {}         # kind -> Array[Texture2D]
static var balloon: Array = []
static var road: Array = []
static var station: Texture2D
static var glow := {}
static var fieldt: Array = []
static var fieldt2: Array = []
static var rdiag: Array = []
static var stumpt: Texture2D
static var scaffold := {}
static var cloud: Texture2D
static var ready := false

# ------------------------------------------------------------ Helfer
# Gezeichnet wird in "logischen" Pixeln (Entwurfsgroesse). S ist der Aufloesungsfaktor: Jedes logische
# Pixel besteht aus S x S echten Pixeln, Kreise/Polygone/Linien werden dabei fein abgetastet.
# S = 2: Gebaeude, Baeume, Felsen (hohe Aufloesung); S = 1: kleine Dinge, Tiere, Figuren.
static var S := 2

static func mk(w: int, h: int) -> Image:
	return Image.create(w * S, h * S, false, Image.FORMAT_RGBA8)

static func tex(i: Image) -> ImageTexture:
	return ImageTexture.create_from_image(i)

static func lw(i: Image) -> int:
	return i.get_width() / S

static func lh(i: Image) -> int:
	return i.get_height() / S

static func px(i: Image, x: int, y: int, c: Color) -> void:
	i.fill_rect(Rect2i(x * S, y * S, S, S), c)

static func rect(i: Image, x: int, y: int, w: int, h: int, c) -> void:
	if w > 0 and h > 0:
		i.fill_rect(Rect2i(x * S, y * S, w * S, h * S), Color(c))

static func ppx(i: Image, x: int, y: int, c: Color) -> void:
	# echtes Pixel (ignoriert S)
	if x >= 0 and y >= 0 and x < i.get_width() and y < i.get_height():
		i.set_pixel(x, y, c)

static func disc(i: Image, cx: int, cy: int, r: int, c) -> void:
	var col := Color(c)
	var rr := r * r + r * 0.5
	var lo := -r - 1
	for y in range((cy + lo) * S, (cy + r + 2) * S):
		for x in range((cx + lo) * S, (cx + r + 2) * S):
			var dx := (x + 0.5) / S - (cx + 0.5)
			var dy := (y + 0.5) / S - (cy + 0.5)
			if dx * dx + dy * dy <= rr:
				ppx(i, x, y, col)

static func blob(i: Image, cx: float, cy: float, rx: float, ry: float, cols: Array, seed: float = 1.0) -> void:
	var cc: Array = []
	for c in cols:
		cc.append(Color(c))
	for y in range(int(floor((cy - ry) * S)), int(ceil((cy + ry) * S)) + 1):
		for x in range(int(floor((cx - rx) * S)), int(ceil((cx + rx) * S)) + 1):
			var xl := (x + 0.5) / S
			var yl := (y + 0.5) / S
			var dx := (xl - cx) / rx
			var dy := (yl - cy) / ry
			if dx * dx + dy * dy > 1.0:
				continue
			var n := Data.hsh(floorf(xl), floorf(yl), seed) * 0.6 + Data.hsh(x, y, seed + 3.0) * 0.4
			var l := -(dx * 0.5 + dy * 0.8) + (n - 0.5) * 0.35
			var k := 0 if l > 0.35 else (1 if l > -0.1 else (2 if l > -0.5 else 3))
			ppx(i, x, y, cc[mini(k, cc.size() - 1)])

static func poly(i: Image, pts: Array, c) -> void:
	var col := Color(c)
	var minx := 999.0
	var maxx := -999.0
	var miny := 999.0
	var maxy := -999.0
	for p in pts:
		minx = minf(minx, p.x)
		maxx = maxf(maxx, p.x)
		miny = minf(miny, p.y)
		maxy = maxf(maxy, p.y)
	var pv := PackedVector2Array(pts)
	for y in range(int(miny * S), int(maxy * S) + 1):
		for x in range(int(minx * S), int(maxx * S) + 1):
			if Geometry2D.is_point_in_polygon(Vector2((x + 0.5) / S, (y + 0.5) / S), pv):
				ppx(i, x, y, col)

static func line(i: Image, x0: int, y0: int, x1: int, y1: int, c) -> void:
	var col := Color(c)
	var a := Vector2(x0 + 0.5, y0 + 0.5) * S
	var b := Vector2(x1 + 0.5, y1 + 0.5) * S
	var n := int(maxf(absf(b.x - a.x), absf(b.y - a.y))) + 1
	var half := S * 0.5
	for k in n + 1:
		var p := a.lerp(b, float(k) / n)
		i.fill_rect(Rect2i(int(round(p.x - half)), int(round(p.y - half)), S, S), col)

static func outline(i: Image, f: float = 0.42) -> void:
	# duenner (1 echtes Pixel) dunkler Rand
	var w := i.get_width()
	var h := i.get_height()
	var src := i.duplicate() as Image
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.05:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h:
					var c := src.get_pixel(nx, ny)
					if c.a > 0.8:
						i.set_pixel(x, y, Color(c.r * f, c.g * f, c.b * f, 1.0))
						break

static func shadow(i: Image, cx: float, cy: float, rx: float, ry: float) -> void:
	for y in range(int((cy - ry) * S), int((cy + ry) * S) + 1):
		for x in range(int((cx - rx) * S), int((cx + rx) * S) + 1):
			var dx := ((x + 0.5) / S - cx) / rx
			var dy := ((y + 0.5) / S - cy) / ry
			if dx * dx + dy * dy <= 1.0 and x >= 0 and y >= 0 and x < i.get_width() and y < i.get_height():
				if i.get_pixel(x, y).a < 0.05:
					i.set_pixel(x, y, Color(0.1, 0.05, 0.2, 0.28))

static func fin(i: Image, sh: bool = true) -> ImageTexture:
	outline(i)
	if sh:
		shadow(i, lw(i) * 0.5, lh(i) - 3, lw(i) * 0.34, 2.2)
	return tex(i)

static func scaled(i: Image, k: float) -> Image:
	var c := i.duplicate() as Image
	c.resize(maxi(2, int(i.get_width() * k)), maxi(2, int(i.get_height() * k)), Image.INTERPOLATE_NEAREST)
	return c

# ------------------------------------------------------------ Waren-Icons
static func good_img(g: String) -> Image:
	# 10x10 logische Pixel. Klare Silhouetten, kraeftige Farben, dunkle Kontur.
	var i := mk(10, 10)
	match g:
		"holz":
			# Baumstamm-Stapel, Stirnseiten mit Jahresringen
			for p in [[3, 7], [7, 7], [5, 3]]:
				disc(i, p[0], p[1], 2, "#7a4c2a")
				disc(i, p[0], p[1], 1, "#ecc994")
				px(i, p[0], p[1], Color("#b98a55"))
			rect(i, 4, 5, 2, 1, "#5e3a20")
		"bretter":
			rect(i, 0, 1, 9, 2, "#ecc58a"); rect(i, 0, 3, 9, 2, "#d3a768"); rect(i, 0, 5, 9, 2, "#ecc58a"); rect(i, 0, 7, 9, 2, "#d3a768")
			rect(i, 0, 2, 9, 1, "#a87f48"); rect(i, 0, 4, 9, 1, "#a87f48"); rect(i, 0, 6, 9, 1, "#a87f48"); rect(i, 0, 8, 9, 1, "#a87f48")
			rect(i, 8, 1, 1, 8, "#b58850")
			px(i, 2, 1, Color("#5a5a68")); px(i, 5, 5, Color("#5a5a68"))
		"stein":
			blob(i, 5, 5.5, 4.4, 3.9, ["#d9d6e4", "#b0adbd", "#8a8798", "#5e5b70"], 3.0)
			px(i, 3, 3, Color.WHITE); px(i, 4, 3, Color("#f0eef8"))
			line(i, 6, 4, 5, 7, "#4a475c")
		"steinblock":
			poly(i, [Vector2(1, 3), Vector2(5, 1), Vector2(9, 3), Vector2(5, 5)], "#f2f1fa")
			poly(i, [Vector2(1, 3), Vector2(5, 5), Vector2(5, 9), Vector2(1, 7)], "#c4c2d0")
			poly(i, [Vector2(5, 5), Vector2(9, 3), Vector2(9, 7), Vector2(5, 9)], "#8a879c")
			line(i, 5, 5, 5, 9, "#6e6b80")
		"wasser":
			# Holzeimer mit Reifen, Henkel und Wasserspiegel
			line(i, 2, 3, 3, 0, "#d4d8e4"); line(i, 3, 0, 7, 0, "#d4d8e4"); line(i, 7, 0, 8, 3, "#d4d8e4")
			poly(i, [Vector2(1.6, 3), Vector2(8.4, 3), Vector2(7.4, 9.6), Vector2(2.6, 9.6)], "#a2703c")
			poly(i, [Vector2(1.6, 3), Vector2(3.4, 3), Vector2(3.4, 9.6), Vector2(2.6, 9.6)], "#c8924f")
			poly(i, [Vector2(7, 3), Vector2(8.4, 3), Vector2(7.4, 9.6), Vector2(6.6, 9.6)], "#6e4524")
			rect(i, 2, 5, 6, 1, "#5a5a68"); rect(i, 2, 8, 6, 1, "#5a5a68")
			blob(i, 5, 3, 3.6, 1.4, ["#5a5a68", "#5a5a68", "#5a5a68", "#5a5a68"], 1.0)
			blob(i, 5, 3, 3.0, 1.0, ["#b8e8ff", "#5ab4f0", "#3b86c8", "#3b86c8"], 2.0)
		"fisch":
			poly(i, [Vector2(7, 5), Vector2(10, 2), Vector2(10, 8)], "#3f6fb8")
			blob(i, 4.5, 5, 4.0, 2.7, ["#d4ecff", "#8fc0f0", "#5588d0", "#3a5fa0"], 5.0)
			poly(i, [Vector2(3, 2.4), Vector2(6, 2.6), Vector2(5, 4)], "#3a5fa0")
			rect(i, 2, 4, 1, 1, "#ffffff"); px(i, 2, 4, Color("#101030"))
			rect(i, 1, 6, 5, 1, "#e8f4ff")
		"weizen":
			line(i, 5, 9, 5, 3, "#c9a23a"); line(i, 5, 9, 2, 4, "#c9a23a"); line(i, 5, 9, 8, 4, "#c9a23a")
			blob(i, 5, 2.5, 1.3, 2.4, ["#fff3a8", "#f4cc48", "#d9a52a", "#b8851c"], 1.0)
			blob(i, 2, 3.5, 1.1, 2.0, ["#fff3a8", "#f4cc48", "#d9a52a", "#b8851c"], 2.0)
			blob(i, 8, 3.5, 1.1, 2.0, ["#fff3a8", "#f4cc48", "#d9a52a", "#b8851c"], 3.0)
			rect(i, 3, 7, 4, 1, "#c8504c")
		"mehl":
			poly(i, [Vector2(3, 3), Vector2(7, 3), Vector2(6, 1), Vector2(4, 1)], "#efe6d2")
			blob(i, 5, 6, 4.2, 3.4, ["#fffaf0", "#efe6d2", "#d9ccae", "#b0a280"], 4.0)
			rect(i, 3, 3, 4, 1, "#c8504c"); rect(i, 4, 6, 2, 1, "#c8504c"); rect(i, 5, 5, 1, 3, "#c8504c")
		"brot":
			blob(i, 5, 5.6, 4.5, 3.2, ["#f8cc88", "#dc9c4c", "#b8742f", "#7a4a20"], 7.0)
			line(i, 3, 3, 4, 6, "#7a4a20"); line(i, 5, 3, 6, 6, "#7a4a20"); line(i, 7, 4, 7, 6, "#7a4a20")
			rect(i, 2, 4, 2, 1, "#fbe0b0")
		"fleisch":
			blob(i, 4.5, 5, 3.9, 3.3, ["#f68c88", "#d85a5a", "#b03c44", "#7c2632"], 9.0)
			rect(i, 7, 4, 2, 2, "#f4efe0"); rect(i, 8, 3, 2, 1, "#f4efe0"); rect(i, 8, 6, 2, 1, "#f4efe0")
			px(i, 3, 4, Color("#ffd0c8")); px(i, 5, 6, Color("#ffd0c8")); px(i, 2, 6, Color("#a02c38"))
		"feenstaub":
			rect(i, 3, 3, 4, 6, "#d6efff"); rect(i, 3, 3, 1, 6, "#ffffff"); rect(i, 6, 3, 1, 6, "#9cc4e0")
			rect(i, 3, 6, 4, 3, "#ff9de6"); rect(i, 4, 6, 1, 1, "#ffffff")
			rect(i, 4, 1, 2, 2, "#a07850"); rect(i, 4, 1, 2, 1, "#c89a68")
			for p in [[1, 3, "#ffb8f0"], [8, 6, "#a8f0ff"], [8, 2, "#ffffff"]]:
				px(i, p[0], p[1], Color(p[2])); px(i, p[0] - 1, p[1], Color(p[2])); px(i, p[0] + 1, p[1], Color(p[2])); px(i, p[0], p[1] - 1, Color(p[2])); px(i, p[0], p[1] + 1, Color(p[2]))
		"obsidian":
			poly(i, [Vector2(7, 4.4), Vector2(9.4, 6.2), Vector2(8.6, 9.6), Vector2(6, 9.6)], "#3a2a58")
			poly(i, [Vector2(4.4, 0), Vector2(7.6, 3), Vector2(6.8, 9.8), Vector2(2.4, 9.8), Vector2(1.6, 3)], "#241a3a")
			poly(i, [Vector2(4.4, 0), Vector2(5.4, 3), Vector2(4.6, 9.8), Vector2(2.4, 9.8), Vector2(1.6, 3)], "#6a48b0")
			rect(i, 3, 2, 1, 4, "#d0b4ff"); px(i, 4, 6, Color("#9a7aff"))
		"gluehpilz":
			rect(i, 4, 5, 2, 5, "#eafaf0")
			blob(i, 5, 3.4, 4.5, 3.0, ["#a8ffec", "#45e8c0", "#22b08e", "#137a66"], 11.0)
			px(i, 3, 2, Color.WHITE); px(i, 6, 1, Color.WHITE); px(i, 7, 3, Color("#d8fff4"))
			px(i, 0, 5, Color("#b8fff0")); px(i, 9, 6, Color("#b8fff0")); px(i, 1, 8, Color("#b8fff0"))
		"sand":
			poly(i, [Vector2(0, 9.6), Vector2(3, 5), Vector2(5, 2.6), Vector2(7, 5), Vector2(10, 9.6)], "#e8c870")
			poly(i, [Vector2(0, 9.6), Vector2(3, 5), Vector2(5, 2.6), Vector2(5.4, 9.6)], "#f8e2a0")
			rect(i, 0, 9, 10, 1, "#b8984c")
			px(i, 6, 6, Color("#c8a85c")); px(i, 7, 7, Color("#c8a85c")); px(i, 4, 5, Color.WHITE)
		"glas":
			rect(i, 2, 4, 6, 5, "#9fe0f4"); rect(i, 4, 1, 2, 3, "#9fe0f4"); rect(i, 3, 3, 4, 1, "#9fe0f4")
			rect(i, 4, 0, 2, 1, "#a07850")
			rect(i, 7, 4, 1, 5, "#4fa8c8"); rect(i, 3, 5, 1, 3, "#ffffff"); rect(i, 5, 1, 1, 2, "#d8f8ff")
		"eis":
			poly(i, [Vector2(1, 3), Vector2(5, 1), Vector2(9, 3), Vector2(5, 5)], "#f6feff")
			poly(i, [Vector2(1, 3), Vector2(5, 5), Vector2(5, 9), Vector2(1, 7)], "#c4eeff")
			poly(i, [Vector2(5, 5), Vector2(9, 3), Vector2(9, 7), Vector2(5, 9)], "#6fb4e4")
			px(i, 3, 5, Color.WHITE); px(i, 7, 5, Color("#d8f4ff")); px(i, 2, 1, Color.WHITE); px(i, 1, 1, Color.WHITE); px(i, 3, 1, Color.WHITE); px(i, 2, 0, Color.WHITE)
		"schwein":
			blob(i, 4.6, 5.6, 4.2, 3.0, ["#ffd2d2", "#f4a4ac", "#d07c88", "#a85a68"], 4.0)
			rect(i, 8, 4, 2, 3, "#f4a4ac"); px(i, 9, 5, Color("#a85a68")); px(i, 9, 6, Color("#a85a68"))
			poly(i, [Vector2(6, 2), Vector2(8, 2), Vector2(7, 4)], "#d07c88")
			px(i, 7, 4, Color("#101010"))
			rect(i, 2, 8, 1, 2, "#a85a68"); rect(i, 6, 8, 1, 2, "#a85a68")
			px(i, 0, 4, Color("#d07c88")); px(i, 0, 5, Color("#d07c88")); px(i, 1, 3, Color("#d07c88"))
		"pilz":
			rect(i, 3, 5, 4, 5, "#f4ecd8"); rect(i, 3, 5, 1, 5, "#ffffff")
			blob(i, 5, 3.6, 4.6, 3.1, ["#e8a878", "#bc7842", "#8f522c", "#5e3014"], 12.0)
			px(i, 3, 2, Color("#f8e8c8")); px(i, 6, 3, Color("#f8e8c8")); px(i, 5, 1, Color("#f8e8c8"))
		"kraut":
			rect(i, 5, 5, 1, 5, "#4f8a3a")
			blob(i, 3, 6.5, 2.4, 1.5, ["#a8e070", "#7ab84a", "#5a9a3a", "#3a7a2a"], 1.0)
			blob(i, 7.4, 6, 2.4, 1.5, ["#a8e070", "#7ab84a", "#5a9a3a", "#3a7a2a"], 2.0)
			blob(i, 5, 4, 1.6, 2.2, ["#b8f080", "#7ab84a", "#5a9a3a", "#3a7a2a"], 3.0)
			rect(i, 4, 0, 3, 2, "#b08ae0"); rect(i, 3, 1, 5, 1, "#b08ae0"); px(i, 5, 1, Color("#fff0a0"))
		"gemuese":
			poly(i, [Vector2(2.6, 3), Vector2(7.4, 3), Vector2(5, 9.8)], "#f08a30")
			poly(i, [Vector2(2.6, 3), Vector2(5, 3), Vector2(5, 9.8)], "#fbb868")
			px(i, 4, 5, Color("#c8601c")); px(i, 5, 7, Color("#c8601c"))
			rect(i, 4, 0, 2, 3, "#4f9a44"); rect(i, 2, 1, 2, 2, "#7ac85a"); rect(i, 6, 1, 2, 2, "#5aa84a")
		"gericht":
			blob(i, 5, 7.6, 4.8, 1.8, ["#ffffff", "#ece8e0", "#cfc8bc", "#a8a294"], 6.0)
			blob(i, 5, 5.6, 3.2, 2.0, ["#f0b060", "#c8743a", "#a85a28", "#7a3c1a"], 8.0)
			px(i, 4, 4, Color("#7ac85a")); px(i, 6, 5, Color("#f0d060")); px(i, 3, 6, Color("#7ac85a"))
			line(i, 4, 0, 4, 2, "#e8f0f8"); line(i, 6, 1, 6, 3, "#e8f0f8")
	outline(i, 0.28)
	return i

# ------------------------------------------------------------ Objekte
static func _stages(full: Array, small_col: String) -> Array:
	# full: [img0, img1] (Sway). Liefert 4 Stufen je 2 Frames.
	var res: Array = []
	var s0 := mk(8, 8)
	rect(s0, 3, 4, 1, 3, "#5a8a3a"); px(s0, 2, 3, Color(small_col)); px(s0, 4, 3, Color(small_col)); px(s0, 3, 2, Color(small_col))
	outline(s0)
	var s1 := mk(12, 14)
	rect(s1, 5, 7, 2, 6, "#6b4a34"); blob(s1, 6, 5, 4, 4, [small_col, Color(small_col).darkened(0.15), Color(small_col).darkened(0.3), Color(small_col).darkened(0.45)], 2.0)
	outline(s1)
	var t0 := tex(s0)
	var t1 := tex(s1)
	res.append([t0, t0])
	res.append([t1, t1])
	var a := mk(2, 2)
	res.append([fin(scaled(full[0], 0.72), true), fin(scaled(full[1], 0.72), true)])
	res.append([fin(full[0], true), fin(full[1], true)])
	return res

static func _oak(pal: Array, sw: int, seed: float) -> Image:
	var i := mk(22, 28)
	rect(i, 10, 17, 3, 8, "#6b4a34"); rect(i, 10, 17, 1, 8, "#8a6444")
	blob(i, 11 + sw, 10, 8, 8, pal, seed); blob(i, 6 + sw, 14, 5, 5, pal, seed + 1); blob(i, 16 + sw, 14, 5, 5, pal, seed + 2)
	return i

static func _pine(sw: int) -> Image:
	var i := mk(20, 30)
	rect(i, 9, 24, 2, 4, "#5a4030")
	var tiers := [[9, 3, 3, 13], [9, 8, 2, 19], [9, 13, 1, 25]]
	for k in 3:
		var t = tiers[k]
		var off := sw if k == 0 else 0
		var cx: int = t[0] + off
		poly(i, [Vector2(cx, t[1]), Vector2(t[2] - 0.0, t[3] - 4 * 0 - (t[3] - t[1]) * 0 ), Vector2(20 - t[2], t[3] - 0)], "#2f6a4c")
	# schoener: manuell
	i.fill(Color(0, 0, 0, 0))
	rect(i, 9, 24, 2, 4, "#5a4030")
	for k in 3:
		var y0 := 2 + k * 6
		var y1 := 12 + k * 6
		var hw := 5 + k * 2
		var cx := 10 + (sw if k == 0 else 0)
		poly(i, [Vector2(cx, y0), Vector2(cx - hw, y1), Vector2(cx + hw, y1)], "#2f6a4c")
		poly(i, [Vector2(cx, y0), Vector2(cx - hw, y1), Vector2(cx, y1)], "#3f8a60")
		poly(i, [Vector2(cx, y0), Vector2(cx - 3, y0 + 4), Vector2(cx + 3, y0 + 4)], "#f2f7fc")
		rect(i, cx - hw + 1, y1 - 1, hw * 2 - 1, 1, "#e9f2f8")
	return i

static func _ftree(sw: int, seed: float) -> Image:
	var i := mk(24, 32)
	rect(i, 11, 19, 3, 10, "#d9c9e8"); rect(i, 11, 19, 1, 10, "#f4ecfb"); rect(i, 9, 26, 7, 3, "#cbb8dc")
	var pal := ["#ffd6f5", "#f0a8ec", "#c77fe0", "#9560c4"]
	blob(i, 12 + sw, 10, 10, 9, pal, seed); blob(i, 6 + sw, 15, 6, 5, pal, seed + 1); blob(i, 18 + sw, 15, 6, 5, pal, seed + 2)
	for k in 7:
		var x := 4 + int(Data.hsh(k, seed, 1.0) * 16)
		var y := 3 + int(Data.hsh(k, seed, 2.0) * 16)
		px(i, x + sw, y, Color("#b8f4ff"))
	return i

static func _dead(sw: int) -> Image:
	var i := mk(20, 28)
	rect(i, 9, 10, 3, 15, "#6f6055"); rect(i, 9, 10, 1, 15, "#8a7a6c")
	line(i, 10, 12, 4 + sw, 5, "#6f6055"); line(i, 10, 15, 16 + sw, 8, "#6f6055"); line(i, 10, 9, 10 + sw, 2, "#6f6055"); line(i, 10, 18, 3, 14, "#5f5247")
	for p in [[4, 6], [16, 9], [10, 3], [3, 15]]:
		rect(i, p[0] + sw, p[1], 2, 2, "#6f9a55")
	return i

static func _palm(sw: int) -> Image:
	var i := mk(24, 30)
	for k in 14:
		rect(i, 11 + (k / 5), 26 - k, 2, 2, "#b08a55" if k % 3 else "#8f6d40")
	var tx := 14 + sw
	for a in [[-9, 0], [-7, -5], [-2, -7], [5, -6], [8, -1], [3, 3], [-4, 3]]:
		line(i, tx, 12, tx + a[0], 12 + a[1], "#4fa04a"); line(i, tx, 13, tx + a[0], 13 + a[1], "#3a8038")
	disc(i, tx, 13, 1, "#7a4a30")
	return i

static func _cactus() -> Image:
	var i := mk(16, 22)
	rect(i, 6, 4, 4, 15, "#4f9a55"); rect(i, 6, 4, 1, 15, "#7bc26a"); rect(i, 9, 4, 1, 15, "#3a7a44"); rect(i, 7, 3, 2, 1, "#4f9a55")
	rect(i, 2, 9, 4, 2, "#4f9a55"); rect(i, 2, 6, 2, 4, "#4f9a55"); rect(i, 10, 11, 4, 2, "#4f9a55"); rect(i, 12, 8, 2, 4, "#4f9a55")
	px(i, 8, 2, Color("#f08bb0")); px(i, 7, 8, Color("#e8f0c0")); px(i, 8, 13, Color("#e8f0c0"))
	return i

static func _rock(big: bool, seed: float) -> Image:
	var i := mk(20, 18)
	var pal := ["#d0cdd8", "#aba8b8", "#8b8899", "#6a6779"]
	blob(i, 10, 10, 8 if big else 6, 6.5 if big else 5, pal, seed)
	blob(i, 5, 12, 4, 3.5, pal, seed + 3)
	if big:
		blob(i, 14, 6, 4, 4, pal, seed + 5)
	line(i, 8, 8, 10, 12, "#5a5769")
	return i

static func _gmush(seed: float) -> Image:
	var i := mk(20, 24)
	rect(i, 8, 12, 4, 9, "#f6ecd8"); rect(i, 8, 12, 1, 9, "#fffaf0"); rect(i, 11, 12, 1, 9, "#d8c8b0")
	var pal := ["#ff9ec4", "#e8659a", "#c2437f", "#8f2d63"] if seed < 5.0 else ["#a8b8ff", "#7a8ae8", "#5a62c0", "#3c4092"]
	blob(i, 10, 9, 9, 6.5, pal, seed)
	rect(i, 6, 7, 2, 2, "#fff4fa"); rect(i, 12, 5, 2, 2, "#fff4fa"); rect(i, 14, 9, 1, 1, "#fff4fa")
	return i

static func _gflower(sw: int, seed: float) -> Image:
	var i := mk(16, 18)
	rect(i, 8, 8, 1, 8, "#4f9a55"); rect(i, 6, 12, 2, 1, "#4f9a55"); rect(i, 9, 10, 2, 1, "#4f9a55")
	var pc := "#7ef2ff" if seed < 5.0 else "#ffa8f0"
	for a in [[-3, 0], [3, 0], [0, -3], [0, 3], [-2, -2], [2, -2], [-2, 2], [2, 2]]:
		disc(i, 8 + a[0] + sw, 6 + a[1], 1, pc)
	disc(i, 8 + sw, 6, 1, "#fffbd0")
	px(i, 3, 2, Color.WHITE); px(i, 13, 3, Color.WHITE); px(i, 12, 10, Color("#fff8b0"))
	return i

static func _gshroom(sw: int) -> Image:
	var i := mk(16, 14)
	for p in [[4, 8, 3], [9, 6, 4], [12, 9, 2]]:
		rect(i, p[0] - 0, p[1] + 2, 2, 4, "#e8f8e0")
		blob(i, p[0] + 1 + sw * 0.0, p[1], p[2], p[2] * 0.8, ["#8affe0", "#45e0b8", "#22b08e", "#137a66"], p[0])
		px(i, p[0], p[1] - 1, Color.WHITE)
	return i

static func _obsc() -> Image:
	var i := mk(16, 20)
	poly(i, [Vector2(7, 1), Vector2(11, 8), Vector2(10, 17), Vector2(4, 17), Vector2(3, 8)], "#2a1f3d")
	poly(i, [Vector2(7, 1), Vector2(8, 8), Vector2(6, 16), Vector2(4, 16), Vector2(3, 8)], "#4a3670")
	poly(i, [Vector2(12, 8), Vector2(14, 13), Vector2(13, 17), Vector2(10, 17)], "#3a2a58")
	px(i, 7, 3, Color("#c8aaff")); px(i, 6, 6, Color("#9a7aff"))
	return i

static func _herb(sw: int, seed: float) -> Image:
	var i := mk(14, 14)
	rect(i, 6, 6, 1, 7, "#4f8a3a"); rect(i, 4, 8, 2, 1, "#6aa840"); rect(i, 7, 9, 3, 1, "#6aa840"); rect(i, 3, 7, 1, 2, "#7ab84a"); rect(i, 9, 7, 1, 3, "#7ab84a")
	var fc := "#b08ae0" if seed < 5.0 else "#f0d860"
	rect(i, 5 + sw, 3, 3, 3, fc); px(i, 6 + sw, 2, Color(fc).lightened(0.3)); px(i, 6 + sw, 4, Color("#fffbd0"))
	rect(i, 3, 5, 2, 2, fc); rect(i, 9, 5, 2, 2, fc)
	return i

static func _mush(sw: int, seed: float) -> Image:
	var i := mk(16, 14)
	var pal := ["#d89a60", "#b87440", "#8f522c", "#643418"] if seed < 5.0 else ["#f0a090", "#d86858", "#b04440", "#7c2830"]
	for p in [[4, 9, 3], [10, 8, 4], [7, 11, 2]]:
		rect(i, p[0], p[1] - 1, 2, 5, "#f4ecd8")
		blob(i, p[0] + 1, p[1] - 2, p[2], p[2] * 0.75, pal, p[0] + seed)
		px(i, p[0], p[1] - 3, Color("#f8e8c8"))
	return i

static func _stages_small(full: Array) -> Array:
	# Nachwachsende Kleinpflanzen: Keimling, klein, mittel, ausgewachsen
	var s0 := mk(8, 8)
	rect(s0, 3, 4, 1, 3, "#5a8a3a"); px(s0, 2, 3, Color("#7ab84a")); px(s0, 4, 3, Color("#7ab84a"))
	outline(s0)
	var t0 := tex(s0)
	return [[t0, t0], [fin(scaled(full[0], 0.5), false), fin(scaled(full[1], 0.5), false)],
		[fin(scaled(full[0], 0.75), true), fin(scaled(full[1], 0.75), true)], [fin(full[0], true), fin(full[1], true)]]

static func _make_objs() -> void:
	var oak_pals := [
		["#a8dc70", "#78bb58", "#549a48", "#3b7842"],
		["#9ed46a", "#6fb552", "#4f9445", "#3a7440"],
		["#f3c060", "#e08a3c", "#b8602f", "#8f4a2a"],
	]
	var v: Array = []
	for k in 3:
		v.append(_stages([tex_img(_oak(oak_pals[k], 0, k * 3 + 1)), tex_img(_oak(oak_pals[k], 1, k * 3 + 1))], oak_pals[k][1]))
	objs[Data.O.TREE] = v
	objs[Data.O.PINE] = [_stages([_pine(0), _pine(1)], "#3f8a60")]
	objs[Data.O.FTREE] = [_stages([_ftree(0, 1.0), _ftree(1, 1.0)], "#f0a8ec"), _stages([_ftree(0, 5.0), _ftree(1, 5.0)], "#f0a8ec")]
	objs[Data.O.DEAD] = [_stages([_dead(0), _dead(1)], "#6f9a55")]
	objs[Data.O.PALM] = [_stages([_palm(0), _palm(1)], "#4fa04a")]
	objs[Data.O.CACTUS] = [_solid(_cactus())]
	var rk: Array = []
	for k in 3:
		rk.append(_solid(_rock(false, k * 7.0 + 1.0)))
	var rkb: Array = []
	for k in 3:
		rkb.append(_solid(_rock(true, k * 7.0 + 4.0)))
	objs[Data.O.ROCK] = [rk, rkb]  # ROCK: [klein-Varianten, gross-Varianten]
	objs[Data.O.GMUSH] = [_solid(_gmush(1.0)), _solid(_gmush(7.0))]
	objs[Data.O.OBSC] = [_solid(_obsc())]
	# kleine Pflanzen in Echtaufloesung
	S = 1
	var fl: Array = []
	for s in [1.0, 7.0]:
		fl.append(_stages([_gflower(0, s), _gflower(1, s)], "#7ef2ff"))
	objs[Data.O.GFLOWER] = fl
	objs[Data.O.GSHROOM] = [_stages([_gshroom(0), _gshroom(1)], "#45e0b8")]
	objs[Data.O.HERB] = [_stages_small([_herb(0, 1.0), _herb(1, 1.0)]), _stages_small([_herb(0, 7.0), _herb(1, 7.0)])]
	objs[Data.O.SHROOM] = [_stages_small([_mush(0, 1.0), _mush(1, 1.0)]), _stages_small([_mush(0, 7.0), _mush(1, 7.0)])]
	S = 2

static func tex_img(i: Image) -> Image:
	return i

static func _solid(img: Image) -> Array:
	var t := fin(img, true)
	var f := [t, t]
	return [f, f, f, f]

# ------------------------------------------------------------ Gebäude
static func house(i: Image, o: Dictionary) -> void:
	var W := lw(i)
	var H := lh(i)
	var bh: int = o.get("bh", 16)
	var rh: int = o.get("rh", 13)
	var bx := 3
	var bw := W - 6
	var by := H - 3 - bh
	var wall := Color(o.wall)
	var wd := wall.darkened(0.18)
	rect(i, bx, by, bw, bh, wall)
	if o.get("stone", false):
		for y in range(by, by + bh, 4):
			rect(i, bx, y, bw, 1, wd)
			for x in range(bx + (2 if ((y - by) / 4) % 2 == 0 else 5), bx + bw, 6):
				rect(i, x, y, 1, 4, wd)
	else:
		for y in range(by + 4, by + bh, 4):
			rect(i, bx, y, bw, 1, wd)
	rect(i, bx, by, bw, 1, wall.lightened(0.12))
	rect(i, bx + bw - 2, by, 2, bh, wd)
	var roof := Color(o.roof)
	var rd := roof.darkened(0.2)
	var rl := roof.lightened(0.15)
	var rt := by - rh + 3
	for k in rh:
		var t := (k + 1.0) / rh
		var w2 := int(round((bw + 6) * (0.3 + 0.7 * t)))
		var x0 := int(round(W / 2.0 - w2 / 2.0))
		rect(i, x0, rt + k, w2, 1, rd if k % 4 == 3 else roof)
		rect(i, x0, rt + k, 2, 1, rl)
		rect(i, x0 + w2 - 2, rt + k, 2, 1, rd)
	rect(i, bx, by + 3, bw, 1, Color(0, 0, 0, 0.22))
	if o.get("chim", false):
		rect(i, W - 12, rt - 1, 4, 8, "#8a6f62"); rect(i, W - 13, rt - 2, 6, 2, "#6d574d")
	var door: String = o.get("door", "#6b4a34")
	rect(i, (W >> 1) - 3, H - 3 - 10, 6, 10, door); rect(i, (W >> 1) - 3, H - 3 - 10, 6, 1, Color(door).darkened(0.3)); px(i, (W >> 1) + 1, H - 3 - 5, Color("#f0d060"))
	if o.get("win", true):
		var wins: Array = [bx + 3, bx + bw - 8]
		if W >= 44:
			wins = [bx + 3, bx + 12, bx + bw - 8, bx + bw - 17]
			wins = [bx + 3, bx + bw - 8, (W >> 1) - 14 + 2, (W >> 1) + 9]
		for wx in wins:
			if abs(wx + 2.0 - W / 2.0) < 5:
				continue
			rect(i, wx - 1, by + 4, 7, 7, "#5a3d2b"); rect(i, wx, by + 5, 5, 5, o.get("winc", "#ffe9a8")); rect(i, wx + 2, by + 5, 1, 5, "#5a3d2b"); rect(i, wx, by + 7, 5, 1, "#5a3d2b")

static func bld_img(type: String, fr: int) -> Image:
	var d: Dictionary = Data.BD[type]
	var W: int = d.w / Data.K * 16
	var H: int = d.h / Data.K * 16 + 12
	if type == "haus":
		H += fr * 9   # fr = Stufe-1: hoehere Haeuser
	var i := mk(W, H)
	match type:
		"haus":
			if fr == 0:
				house(i, {"wall": "#d8c0a0", "roof": "#b8603c", "bh": 14, "rh": 10, "door": "#6b4a34"})
			elif fr == 1:
				house(i, {"wall": "#e2cba8", "roof": "#9a4a3c", "bh": 23, "rh": 12, "chim": true, "door": "#5a3a2a"})
				var by1 := H - 3 - 23
				for wx in [6, W - 11]:
					rect(i, wx - 1, by1 + 14, 7, 7, "#5a3d2b"); rect(i, wx, by1 + 15, 5, 5, "#ffe9a8"); rect(i, wx + 2, by1 + 15, 1, 5, "#5a3d2b")
			else:
				house(i, {"wall": "#d0c4b4", "roof": "#4f6a9a", "bh": 32, "rh": 13, "chim": true, "stone": true, "door": "#4a3020"})
				var by2 := H - 3 - 32
				for wx in [6, W - 11]:
					for wy in [14, 24]:
						rect(i, wx - 1, by2 + wy, 7, 7, "#5a3d2b"); rect(i, wx, by2 + wy + 1, 5, 5, "#ffe9a8"); rect(i, wx + 2, by2 + wy + 1, 1, 5, "#5a3d2b")
				rect(i, (W >> 1) - 5, by2 + 6, 10, 3, "#c89a50")
		"metzger":
			house(i, {"wall": "#d8a8a0", "roof": "#8a3a3a", "chim": true, "door": "#5a3a2a"})
			for k in 3:
				rect(i, 3 + k * 3, H - 14, 1, 3, "#6b4a34"); rect(i, 2 + k * 3, H - 11, 3, 3, "#c8504c")
			rect(i, W - 10, H - 8, 7, 5, "#e8e0d0"); rect(i, W - 10, H - 8, 7, 1, "#ffffff"); rect(i, W - 8, H - 6, 3, 2, "#d87a7a")
		"garten":
			house(i, {"wall": "#c9b890", "roof": "#5a9a4a", "bh": 14, "rh": 10, "door": "#6b4a34"})
			for k in 3:
				rect(i, 2 + k * 10, H - 7, 8, 4, "#7a5430")
				rect(i, 3 + k * 10, H - 9, 2, 3, "#5aa84a"); rect(i, 6 + k * 10, H - 9, 2, 3, ["#f08a30", "#c85a7a", "#9ad05a"][k])
		"kraeuter":
			house(i, {"wall": "#a8b878", "roof": "#6a8a4a", "bh": 14, "rh": 11, "door": "#5a4030"})
			for k in 4:
				rect(i, 3 + k * 7, H - 17, 1, 3, "#6b4a34"); rect(i, 2 + k * 7, H - 14, 3, 4, ["#b08ae0", "#7ab84a", "#f0d860", "#c870b0"][k])
			rect(i, W - 10, H - 7, 7, 4, "#a07850"); rect(i, W - 9, H - 9, 5, 2, "#7ab84a")
		"pilzsammler":
			house(i, {"wall": "#b89870", "roof": "#a0522d", "bh": 14, "rh": 12, "door": "#4a3020"})
			for p in [[12, 2], [16, 5], [8, 6]]:
				px(i, p[0], H - 28 + p[1] + 4, Color("#f8e8c8")); px(i, p[0] + 1, H - 28 + p[1] + 4, Color("#f8e8c8"))
			rect(i, 3, H - 8, 7, 5, "#a07850"); rect(i, 4, H - 10, 5, 2, "#d89a60"); rect(i, 5, H - 11, 2, 1, "#8f522c")
		"kueche":
			house(i, {"wall": "#e6d4b8", "roof": "#4a8a6a", "chim": true, "door": "#7a4a30"})
			rect(i, 3, H - 9, 6, 6, "#4a4a56"); rect(i, 3, H - 9, 6, 1, "#7a7a88"); rect(i, 4, H - 11, 4, 2, "#c8c8d0")
			rect(i, W - 10, H - 8, 7, 5, "#c8743a"); rect(i, W - 10, H - 8, 7, 1, "#e0a050")
		"hq":
			# Langhaus mit drei Toren
			house(i, {"wall": "#d9c7a0", "roof": "#a34a3c", "bh": 17, "rh": 17, "chim": true, "door": "#5a3a2a", "win": false})
			var by := H - 3 - 17
			for bx in [4, 20, 36, 44, 60, 75]:
				rect(i, bx, by, 2, 17, "#6b4a34")
			rect(i, 3, by, W - 6, 2, "#6b4a34")
			for dxc in [8, 72]:   # Seitentueren (nur Zierde)
				rect(i, dxc - 3, H - 13, 6, 10, "#5a3a2a"); rect(i, dxc - 3, H - 13, 6, 1, "#3a2418"); px(i, dxc + 1, H - 8, Color("#f0d060"))
				rect(i, dxc - 4, H - 14, 8, 1, "#6b4a34")
			for wx in [22, 30, 50, 58]:
				rect(i, wx - 1, by + 4, 7, 7, "#5a3d2b"); rect(i, wx, by + 5, 5, 5, "#ffe9a8" if fr == 0 else "#ffd890"); rect(i, wx + 2, by + 5, 1, 5, "#5a3d2b")
			rect(i, 16, 10, 5, 7, "#8a6f62"); rect(i, 15, 9, 7, 2, "#6d574d")
			rect(i, 39, 1, 1, 12, "#5a3a2a"); rect(i, 40, 1, 7, 4, "#e8c040" if fr == 0 else "#f0d050"); rect(i, 40, 3, 7, 1, "#c89a20")
		"ballon":
			house(i, {"wall": "#e8dcc0", "roof": "#e8453c", "door": "#6b4a34"})
			rect(i, W - 10, H - 9, 6, 6, "#8a8a98"); rect(i, W - 10, H - 9, 6, 1, "#c8ccd8"); rect(i, W - 8, H - 11, 2, 2, "#6a6a78")
			rect(i, (W >> 1), H - 33, 1, 5, "#6b4a34"); rect(i, (W >> 1) + 1, H - 33, 5, 3, "#fff0c0"); rect(i, (W >> 1) + 1, H - 32, 5, 1, "#e8453c")
			rect(i, 3, H - 8, 5, 5, "#a07850"); rect(i, 3, H - 8, 5, 1, "#c8a070")
		"wagner":
			house(i, {"wall": "#c9a06a", "roof": "#7a5a3c", "chim": true})
			# Schubkarre vor dem Haus
			rect(i, W - 12, H - 9, 8, 3, "#8a5a34"); rect(i, W - 12, H - 10, 8, 1, "#b58850"); disc(i, W - 5, H - 5, 2, "#4a3a2a"); rect(i, W - 16, H - 8, 4, 1, "#6b4a34")
			rect(i, 3, H - 9, 6, 2, "#e6bf80"); rect(i, 3, H - 7, 6, 2, "#d3a768")
		"lager":
			house(i, {"wall": "#b58b5a", "roof": "#6b4a3a", "bh": 16, "door": "#4a3020"})
			rect(i, 2, H - 9, 6, 6, "#9a6a3a"); rect(i, 2, H - 9, 6, 1, "#c89a60"); rect(i, W - 9, H - 8, 6, 5, "#9a6a3a"); rect(i, W - 9, H - 8, 6, 1, "#c89a60")
		"holzfaeller":
			house(i, {"wall": "#b48454", "roof": "#4f9a55"})
			rect(i, W - 10, H - 7, 8, 3, "#8a5a34"); rect(i, W - 10, H - 7, 8, 1, "#a9713f"); rect(i, W - 9, H - 10, 6, 3, "#7a4c2a"); rect(i, 2, H - 7, 5, 4, "#a0703f"); rect(i, 3, H - 10, 3, 3, "#c8ccd8")
		"foerster":
			house(i, {"wall": "#c9a36a", "roof": "#6cbd58"})
			for p in [[3, H - 8], [W - 8, H - 9]]:
				rect(i, p[0], p[1], 1, 5, "#6b4a34"); blob(i, p[0] + 0.5, p[1] - 1, 3, 3, ["#a8dc70", "#78bb58", "#549a48", "#3b7842"], 2.0)
		"saegewerk":
			house(i, {"wall": "#a67c52", "roof": "#8a5a3c", "chim": true})
			disc(i, 4, H - 9, 4, "#c8ccd8"); disc(i, 4, H - 9, 1, "#5a5a6a"); rect(i, W - 10, H - 8, 8, 2, "#e6bf80"); rect(i, W - 10, H - 6, 8, 2, "#d3a768"); rect(i, W - 10, H - 10, 8, 2, "#e6bf80")
		"steinbruch":
			house(i, {"wall": "#9a97a5", "roof": "#7a5c46", "stone": true})
			blob(i, W - 6, H - 8, 4, 3, ["#d0cdd8", "#aba8b8", "#8b8899", "#6a6779"], 3.0); blob(i, 5, H - 7, 3, 2.5, ["#d0cdd8", "#aba8b8", "#8b8899", "#6a6779"], 6.0)
			line(i, 2, H - 14, 6, H - 10, "#7a5c46"); rect(i, 1, H - 15, 4, 1, "#c8ccd8")
		"steinmetz":
			house(i, {"wall": "#c9c6d1", "roof": "#5a6f9a", "stone": true})
			rect(i, W - 10, H - 8, 7, 5, "#c4c2d0"); rect(i, W - 10, H - 8, 7, 2, "#eeedf7"); rect(i, 3, H - 6, 5, 3, "#c4c2d0"); rect(i, 3, H - 6, 5, 1, "#eeedf7")
		"brunnen":
			rect(i, 2, H - 10, 12, 8, "#a7a4b3"); rect(i, 2, H - 10, 12, 2, "#d0cdd8"); rect(i, 4, H - 9, 8, 3, "#3b78c4"); rect(i, 4, H - 9, 8, 1, "#7ac0f0")
			rect(i, 2, H - 20, 1, 11, "#6b4a34"); rect(i, 13, H - 20, 1, 11, "#6b4a34"); rect(i, 1, H - 22, 14, 3, "#a34a3c"); rect(i, 1, H - 22, 14, 1, "#c96a58")
			rect(i, 7, H - 18, 1, 6, "#c8b090")
			if fr == 1:
				rect(i, 6, H - 12, 3, 3, "#8a5a34")
			else:
				rect(i, 6, H - 15, 3, 3, "#8a5a34")
		"fischer":
			house(i, {"wall": "#7a9cc0", "roof": "#d0a04a"})
			line(i, 3, H - 14, 3, H - 6, "#6b4a34"); line(i, 3, H - 14, 9, H - 14, "#6b4a34"); rect(i, 4, H - 13, 5, 5, "#e8e0c8")
			rect(i, W - 10, H - 9, 5, 2, "#b8d0e8"); rect(i, W - 6, H - 9, 2, 2, "#8fb0d0")
		"jaeger":
			house(i, {"wall": "#8a6a48", "roof": "#7a4a3a"})
			line(i, (W >> 1) - 3, H - 20, (W >> 1) - 5, H - 24, "#f4efe0"); line(i, (W >> 1) + 3, H - 20, (W >> 1) + 5, H - 24, "#f4efe0"); rect(i, (W >> 1) - 2, H - 21, 5, 3, "#a07850")
		"farm":
			house(i, {"wall": "#d9b27a", "roof": "#c65a3c", "door": "#7a4a30"})
			blob(i, W - 6, H - 7, 5, 4, ["#f6da70", "#e0b84a", "#c09632", "#8f6f22"], 4.0); blob(i, 5, H - 6, 3, 2.5, ["#f6da70", "#e0b84a", "#c09632", "#8f6f22"], 5.0)
		"muehle":
			# Windmühle
			poly(i, [Vector2(9, H - 3), Vector2(23, H - 3), Vector2(20, H - 22), Vector2(12, H - 22)], "#e6ddc8")
			poly(i, [Vector2(19, H - 3), Vector2(23, H - 3), Vector2(20, H - 22), Vector2(18, H - 22)], "#c8bca0")
			poly(i, [Vector2(10, H - 22), Vector2(22, H - 22), Vector2(16, H - 30)], "#a34a3c")
			rect(i, 13, H - 9, 6, 6, "#6b4a34"); rect(i, 14, H - 16, 4, 4, "#ffe9a8")
			var c := Vector2(16, H - 24)
			for k in 4:
				var a := fr * 0.4 + k * PI / 2.0
				var e := c + Vector2(cos(a), sin(a)) * 12.0
				line(i, int(c.x), int(c.y), int(e.x), int(e.y), "#8a5a34")
				var e2 := c + Vector2(cos(a), sin(a)) * 11.0 + Vector2(-sin(a), cos(a)) * 3.0
				line(i, int(c.x + cos(a) * 4), int(c.y + sin(a) * 4), int(e2.x), int(e2.y), "#f2ead4")
			disc(i, int(c.x), int(c.y), 1, "#5a3a2a")
			rect(i, W - 6, H - 7, 4, 4, "#efe6d2"); rect(i, 2, H - 6, 4, 3, "#efe6d2")
		"baeckerei":
			house(i, {"wall": "#e8c9a0", "roof": "#c4643c", "chim": true, "door": "#7a4a30"})
			rect(i, 4, H - 11, 6, 4, "#f0c078"); rect(i, 4, H - 11, 6, 1, "#f8d898")
			rect(i, W - 11, H - 10, 7, 1, "#6b4a34"); rect(i, W - 10, H - 9, 5, 2, "#f0c078")
		"ranch":
			house(i, {"wall": "#b8503c", "roof": "#7a4a3a", "bh": 14, "rh": 11, "door": "#f0e0c0"})
			for k in range(2, W - 2, 6):
				rect(i, k, H - 7, 1, 6, "#c8a878")
			rect(i, 2, H - 6, W - 4, 1, "#c8a878"); rect(i, 2, H - 4, W - 4, 1, "#c8a878")
		"taverne":
			house(i, {"wall": "#c58b5c", "roof": "#b6453b", "chim": true, "bh": 18, "rh": 14, "door": "#5a3a2a", "winc": "#ffd070" if fr == 0 else "#ffe9a8"})
			rect(i, W - 12, H - 24, 1, 5, "#6b4a34"); rect(i, W - 15, H - 20, 8, 5, "#e0b040"); rect(i, W - 15, H - 20, 8, 1, "#f8d870"); rect(i, W - 8, H - 19, 2, 3, "#e0b040")
			rect(i, 4, H - 8, 5, 5, "#8a5a34"); rect(i, 4, H - 8, 5, 1, "#c89a60")
		"feensammler":
			blob(i, W / 2.0, 12, 15, 11, ["#ffb8e6", "#f088cc", "#c85aa4", "#8f3a78"], 3.0)
			rect(i, 9, 20, 14, 12 if H > 30 else 8, "#f6ecd8"); rect(i, 9, 20, 2, 12, "#fffaf0"); rect(i, 21, 20, 2, 12, "#d8c8b0")
			for p in [[7, 8], [14, 4], [22, 9], [18, 13]]:
				rect(i, p[0], p[1], 3, 3, "#fff4fa")
			rect(i, 13, H - 13, 6, 10, "#8a5a8a"); rect(i, 13, H - 13, 6, 1, "#5a3a5a"); rect(i, 10, 24, 3, 3, "#a8f0ff"); rect(i, 20, 26, 3, 3, "#a8f0ff")
			for p in [[3, H - 8], [W - 5, H - 10]]:
				px(i, p[0], p[1], Color("#7ef2ff")); px(i, p[0], p[1] - 1, Color.WHITE)
		"obsidian":
			house(i, {"wall": "#4b4557", "roof": "#2d2a3a", "stone": true, "winc": "#ff8a30", "door": "#2a2030"})
			rect(i, W - 10, H - 9, 6, 6, "#2c2140"); rect(i, W - 9, H - 9, 2, 5, "#5b3f96"); rect(i, 3, H - 8, 4, 5, "#2c2140")
			px(i, 5, H - 8, Color("#ff8a30")); px(i, W - 7, H - 9, Color("#c8aaff"))
		"pilzhuette":
			rect(i, 6, H - 12, 3, 10, "#6b4a34"); rect(i, W - 9, H - 12, 3, 10, "#6b4a34")
			rect(i, 4, H - 22, W - 8, 11, "#7a8a52"); rect(i, 4, H - 22, W - 8, 1, "#98a86a")
			blob(i, W / 2.0, H - 24, 15, 10, ["#8affe0", "#45e0b8", "#22b08e", "#137a66"], 6.0)
			for p in [[8, 6], [16, 4], [22, 9]]:
				rect(i, p[0], H - 30 + p[1] - 4 + 4, 3, 3, "#e8fff4")
			rect(i, (W >> 1) - 3, H - 13, 6, 10, "#4a3a2a"); rect(i, W - 12, H - 19, 4, 4, "#ffe9a8")
		"sandgrube":
			poly(i, [Vector2(2, H - 3), Vector2(W - 2, H - 3), Vector2(W / 2.0, 6)], "#e08a5a")
			poly(i, [Vector2(W / 2.0 + 1, 6), Vector2(W - 2, H - 3), Vector2(W / 2.0 + 1, H - 3)], "#c06a3c")
			for k in range(-1, 3):
				poly(i, [Vector2(W / 2.0 - 3 + k * 5, H - 3), Vector2(W / 2.0 - 1 + k * 5, 14 + k * 3), Vector2(W / 2.0 + k * 5, H - 3)], "#f4d8a0")
			rect(i, (W >> 1) - 3, H - 14, 6, 11, "#5a3a2a")
			blob(i, W - 5, H - 6, 5, 3, ["#f4dc98", "#e8cc80", "#c8a85c", "#a8883c"], 3.0)
		"glashuette":
			house(i, {"wall": "#d8b48c", "roof": "#5a9ab5", "chim": true, "winc": "#ff9a40" if fr == 0 else "#ffc060"})
			rect(i, W - 10, H - 9, 6, 6, "#7a4a3a"); rect(i, W - 9, H - 8, 4, 3, "#ff9a40" if fr == 0 else "#ffc060")
			rect(i, 3, H - 8, 4, 5, "#a8e8f8"); rect(i, 3, H - 8, 1, 5, "#eafcff")
		"eishauer":
			blob(i, W / 2.0, H - 14, 15, 13, ["#f0fcff", "#cfeeff", "#a8d8f0", "#7ab8d8"], 8.0)
			rect(i, 0, H - 14, W, 12, Color(0, 0, 0, 0))
			blob(i, W / 2.0, H - 12, 14, 11, ["#f0fcff", "#cfeeff", "#a8d8f0", "#7ab8d8"], 8.0)
			rect(i, (W >> 1) - 4, H - 12, 8, 9, "#5a7a9a"); rect(i, (W >> 1) - 4, H - 12, 8, 1, "#3a5a7a")
			for x in [4, 10, 20, 26]:
				rect(i, x, H - 26, 1, 3 + x % 3, "#e8fbff")
			rect(i, W - 8, H - 7, 5, 4, "#bfeaff"); rect(i, W - 8, H - 7, 5, 1, "#f0fcff")
		"wegebauer":
			house(i, {"wall": "#b9a27a", "roof": "#7a6a52", "bh": 14, "rh": 10, "door": "#5a4030"})
			blob(i, W - 6, H - 7, 4.5, 3, ["#d8d2c4", "#b8b2a4", "#98927f", "#78725f"], 7.0)
			rect(i, 3, H - 8, 6, 5, "#a07850"); rect(i, 3, H - 8, 6, 1, "#c8a070")
			line(i, 12, H - 18, 12, H - 11, "#6b4a34"); rect(i, 11, H - 20, 3, 2, "#c8ccd8")
		"traeger":
			_traeger(i, fr / 2, fr % 2, W, H)
		"schrein":
			for k in 8:
				var a := k * TAU / 8.0
				rect(i, int(W / 2 + cos(a) * 19) - 2, int(H - 12 + sin(a) * 6) - 3, 4, 6, "#a8a5b6")
			rect(i, 21, H - 26, 6, 22, "#e0cfe8"); rect(i, 21, H - 26, 2, 22, "#f8f0fc")
			var pal := ["#ffd6f5", "#f0a8ec", "#c77fe0", "#9560c4"]
			blob(i, 24, 16, 17, 14, pal, 2.0); blob(i, 12, 24, 8, 6, pal, 3.0); blob(i, 36, 24, 8, 6, pal, 4.0)
			for k in 10:
				px(i, 8 + int(Data.hsh(k, 1.0, 5.0) * 32), 4 + int(Data.hsh(k, 2.0, 5.0) * 26), Color("#b8f4ff"))
		"obelisk":
			rect(i, 6, H - 8, 36, 5, "#5a566a"); rect(i, 10, H - 13, 28, 5, "#6a667c"); rect(i, 6, H - 8, 36, 1, "#8a869c")
			poly(i, [Vector2(24, 2), Vector2(31, 14), Vector2(30, H - 13), Vector2(18, H - 13), Vector2(17, 14)], "#2a1f3d")
			poly(i, [Vector2(24, 2), Vector2(26, 14), Vector2(25, H - 13), Vector2(18, H - 13), Vector2(17, 14)], "#4a3670")
			for y in range(10, H - 14, 7):
				rect(i, 22, y, 4, 2, "#9a7aff" if (y + fr * 7) % 14 == 0 else "#6a4ab8")
			px(i, 24, 4, Color("#e8d8ff"))
		"glaspalast":
			rect(i, 4, H - 10, 40, 8, "#d8ccb0"); rect(i, 4, H - 10, 40, 1, "#f0e8d0")
			poly(i, [Vector2(24, 2), Vector2(44, H - 10), Vector2(4, H - 10)], "#8adcf0")
			poly(i, [Vector2(24, 2), Vector2(24, H - 10), Vector2(4, H - 10)], "#b8f0fc")
			poly(i, [Vector2(24, 2), Vector2(44, H - 10), Vector2(24, H - 10)], "#5ab8d8")
			line(i, 24, 2, 14, H - 10, "#eafcff"); line(i, 24, 2, 34, H - 10, "#3a98b8"); line(i, 10, 30, 38, 30, "#eafcff")
			rect(i, 20, H - 20, 8, 10, "#e8c040"); rect(i, 22, H - 18, 4, 8, "#fff4a0")
		"eispavillon":
			rect(i, 4, H - 8, 40, 5, "#a8a5b6"); rect(i, 4, H - 8, 40, 1, "#d0cdd8")
			for p in [[10, 22, 26], [20, 6, 40], [34, 22, 26]]:
				poly(i, [Vector2(p[0], p[1]), Vector2(p[0] + 5, p[2] + 6), Vector2(p[0] - 5, p[2] + 6)], "#bfeaff")
				poly(i, [Vector2(p[0], p[1]), Vector2(p[0], p[2] + 6), Vector2(p[0] - 5, p[2] + 6)], "#f0fcff")
			rect(i, 6, H - 20, 36, 3, "#cfeeff"); rect(i, 6, H - 20, 36, 1, "#ffffff")
			for x in [8, 15, 22, 29, 36]:
				rect(i, x, H - 17, 2, 9, "#a8d8f0")
		"laterne":
			rect(i, 20, H - 30, 8, 28, "#e8ddc0"); rect(i, 20, H - 30, 2, 28, "#fff6dc"); rect(i, 26, H - 30, 2, 28, "#c8bc98")
			blob(i, 24, 14, 20, 12, ["#b8fff0", "#5df2c8", "#22b08e", "#137a66"], 5.0)
			for p in [[10, 14], [24, 6], [36, 14], [18, 18], [30, 18]]:
				rect(i, p[0], p[1], 3, 3, "#f0fff8")
			rect(i, 21, H - 12, 6, 9, "#4a3a2a")
			for p in [[6, H - 8], [40, H - 9]]:
				blob(i, p[0], p[1], 4, 3, ["#8affe0", "#45e0b8", "#22b08e", "#137a66"], 2.0)
	return i

static func _traeger(i: Image, design: int, fr: int, W: int, H: int) -> void:
	# Traegerlager: Platz mit Sitzen auf einer Ellipse (gleiche Stellen wie Sim.seat_off) und Mitte.
	# 0 Steinkreis, 1 Staemme um ein Lagerfeuer, 2 Pilze
	var cx := W / 2.0
	var cy := H - 25.0       # Mitte des Grundstuecks
	blob(i, cx, cy + 1.6, 25.0, 15.5, ["#c9b588", "#b39d70", "#9a855c", "#806e4a"], 11.0)
	var stone := ["#d0cdd8", "#aba8b8", "#8b8899", "#6a6779"]
	var caps := [
		["#ff8a7a", "#e8453c", "#b82a2a", "#7a1a22"],
		["#e8c090", "#c89458", "#a07040", "#6a4a2a"],
		["#b8e0ff", "#74b0ec", "#4e80c8", "#2e5090"],
	]
	var order: Array = []
	for s in Sim.SEATS:
		order.append(s)
	order.sort_custom(func(a, b): return Sim.seat_off(a).y < Sim.seat_off(b).y)
	var mid_done := false
	for s in order:
		var so: Vector2 = Sim.seat_off(s)
		if not mid_done and so.y > 0.5:
			_traeger_mitte(i, design, fr, cx, cy + 1.6, stone)
			mid_done = true
		var px_ := cx + so.x * 8.0
		var py_ := cy + so.y * 8.0
		match design:
			0:
				blob(i, px_, py_ + 2.0, 5.5, 3.6, stone, 1.0 + s)
			1:
				rect(i, int(px_) - 5, int(py_), 10, 4, "#8a5a34")
				rect(i, int(px_) - 5, int(py_), 10, 1, "#b88450")
				rect(i, int(px_) - 5, int(py_) + 1, 2, 2, "#d9b070")
				rect(i, int(px_) + 3, int(py_) + 1, 2, 2, "#6b4424")
			2:
				rect(i, int(px_) - 1, int(py_) + 1, 3, 5, "#f0e4cc")
				rect(i, int(px_) + 1, int(py_) + 1, 1, 5, "#d8c8a8")
				blob(i, px_, py_ + 0.5, 5.8, 3.2, caps[s % 3], 2.0 + s)
				if s % 3 == 0:
					rect(i, int(px_) - 3, int(py_) - 1, 2, 1, "#ffffff")
					rect(i, int(px_) + 1, int(py_), 2, 1, "#ffffff")
	if not mid_done:
		_traeger_mitte(i, design, fr, cx, cy + 1.6, stone)

static func _traeger_mitte(i: Image, design: int, fr: int, cx: float, cy: float, stone: Array) -> void:
	var x := int(cx)
	var y := int(cy)
	match design:
		0:
			# flache Steinplatte mit einer kleinen Glut
			blob(i, cx, cy, 7.0, 3.6, stone, 5.0)
			rect(i, x - 1, y - 1, 3, 2, "#4a4552")
			px(i, x, y - 1, Color("#ff9a30") if fr == 0 else Color("#ffc060"))
		1:
			# Lagerfeuer: Steinring, gekreuzte Scheite, Flamme
			for k in 8:
				var a := k * TAU / 8.0
				blob(i, cx + cos(a) * 6.0, cy + 1.0 + sin(a) * 3.2, 2.0, 1.6, stone, 3.0 + k)
			line(i, x - 5, y + 1, x + 5, y - 2, "#6b4424")
			line(i, x - 5, y - 2, x + 5, y + 1, "#8a5a34")
			var fh := 9 if fr == 0 else 11
			poly(i, [Vector2(x - 3, y), Vector2(x + 3, y), Vector2(x + 1, y - fh), Vector2(x - 1, y - fh + 3)], "#ff8a30")
			poly(i, [Vector2(x - 2, y), Vector2(x + 2, y), Vector2(x, y - fh + 3)], "#ffd060")
			rect(i, x - 1, y - 3, 2, 3, "#fff4b0")
		2:
			# kleine Pilzgruppe in der Mitte
			for p in [[-3, 1, 0], [2, 0, 1], [0, -2, 2]]:
				rect(i, x + p[0], y + p[1] + 1, 2, 3, "#f0e4cc")
				blob(i, cx + p[0] + 1.0, cy + p[1] + 1.0, 3.2, 2.0, [["#ff8a7a", "#e8453c", "#b82a2a", "#7a1a22"], ["#b8fff0", "#5df2c8", "#22b08e", "#137a66"], ["#ffd6f5", "#f0a8ec", "#c77fe0", "#9560c4"]][p[2]], 6.0 + p[0])

static func station_img() -> Image:
	# Fliegenpilz fuer die Traegerstation (ein Pixler sitzt oben drauf, siehe main.gd)
	var i := mk(14, 14)
	rect(i, 5, 7, 4, 6, "#f4ecd8")
	rect(i, 5, 7, 1, 6, "#fffaf0")
	rect(i, 8, 7, 1, 6, "#d8ccb0")
	blob(i, 7, 5, 6.5, 4.3, ["#ff7a68", "#e8453c", "#b82a2a", "#7a1a22"], 4.0)
	for p in [[2, 3], [6, 1], [10, 3], [4, 6], [8, 6]]:
		rect(i, p[0], p[1], 2, 1, "#ffffff")
		px(i, p[0], p[1] + 1, Color("#f4ecd8"))
	return i

static func house_tex(type: String) -> Array:
	var res: Array = []
	for fr in (3 if type == "haus" else (6 if type == "traeger" else 2)):
		res.append(fin(bld_img(type, fr), true))
	return res

# ------------------------------------------------------------ Figuren & Tiere
const TOOL_OF := {
	"holzfaeller": "axe", "foerster": "shovel", "steinbruch": "pick", "steinmetz": "hammer", "saegewerk": "saw", "wagner": "hammer",
	"fischer": "rod", "jaeger": "bow", "farm": "hoe", "garten": "hoe", "kraeuter": "basket", "pilzsammler": "basket",
	"feensammler": "basket", "pilzhuette": "basket", "obsidian": "pick", "sandgrube": "shovel", "eishauer": "pick",
	"builder": "hammer", "glashuette": "pipe", "muehle": "sack", "baeckerei": "sack", "metzger": "knife", "kueche": "ladle",
}

static func man_img(role: String, tun: String, hat: String, fr: int) -> Image:
	# Pixler in Echtaufloesung (20x30): grosse Zipfelmuetze mit Bommel, grosse Nase, Guertel, Stiefel und
	# ein Werkzeug je nach Beruf. Blick nach rechts. fr 0-3: Gehzyklus, 4: Stand.
	var old_s := S
	S = 1
	var i := mk(20, 30)
	var tc := Color(tun)
	var hc := Color(hat)
	var skin := Color("#f2c9a0")
	var skd := skin.darkened(0.14)
	var bob := 1 if (fr == 1 or fr == 3) else 0
	var yo := -bob
	var sw := 0
	if fr == 0: sw = -1
	elif fr == 2: sw = 1
	# Muetze: Spitze haengt nach hinten, Bommel am Ende
	rect(i, 8, 2 + yo, 4, 2, hc.lightened(0.12))
	rect(i, 7, 4 + yo, 6, 2, hc)
	rect(i, 6, 6 + yo, 8, 2, hc)
	rect(i, 5, 8 + yo, 10, 1, hc.darkened(0.12))
	rect(i, 5, 2 + yo, 3, 1, hc.lightened(0.12))
	rect(i, 3, 3 + yo, 3, 1, hc)
	rect(i, 2, 4 + yo, 2, 2, hc.darkened(0.1))
	rect(i, 0, 5 + yo, 3, 3, "#f6f0e0")
	rect(i, 0, 5 + yo, 2, 1, "#ffffff")
	rect(i, 7, 4 + yo, 1, 4, hc.lightened(0.2))
	rect(i, 12, 5 + yo, 1, 3, hc.darkened(0.2))
	# Krempe
	rect(i, 4, 9 + yo, 12, 2, hc.darkened(0.25))
	rect(i, 4, 9 + yo, 12, 1, hc.darkened(0.1))
	# Gesicht + grosse Nase
	rect(i, 6, 11 + yo, 8, 5, skin)
	rect(i, 6, 11 + yo, 1, 5, skd)
	rect(i, 14, 12 + yo, 4, 3, Color("#f0a888"))
	rect(i, 17, 13 + yo, 1, 2, Color("#d88868"))
	rect(i, 14, 12 + yo, 2, 1, Color("#f8c0a0"))
	rect(i, 11, 12 + yo, 1, 2, Color("#2a1a1a"))
	rect(i, 10, 11 + yo, 3, 1, Color("#7a5a44"))
	rect(i, 12, 15 + yo, 2, 1, Color("#b0645a"))
	# Kragen + Tunika
	rect(i, 6, 16 + yo, 8, 1, Color("#f6f0e0"))
	rect(i, 6, 17 + yo, 8, 8, tc)
	rect(i, 6, 17 + yo, 1, 8, tc.lightened(0.15))
	rect(i, 13, 17 + yo, 1, 8, tc.darkened(0.2))
	rect(i, 8, 18 + yo, 1, 3, tc.lightened(0.08))
	rect(i, 6, 22 + yo, 8, 1, Color("#5a3a2a"))
	rect(i, 9, 22 + yo, 2, 1, Color("#e8c050"))
	rect(i, 6, 24 + yo, 8, 1, tc.darkened(0.18))
	# hinterer Arm
	rect(i, 4, 18 + yo - sw, 2, 5, tc.darkened(0.2))
	rect(i, 4, 23 + yo - sw, 2, 2, skd)
	# Beine + Stiefel
	var ax := 7
	var bx := 10
	match fr:
		0: ax = 5; bx = 11
		1: ax = 7; bx = 9
		2: ax = 11; bx = 5
		3: ax = 8; bx = 8
	var dk := Color("#4a3a4a")
	rect(i, ax, 25, 3, 3, Color("#6a5a6a"))
	rect(i, ax, 28, 4, 2, dk)
	rect(i, bx, 25, 3, 3, Color("#7a6a7a"))
	rect(i, bx, 28, 4, 2, dk.lightened(0.1))
	# vorderer Arm + Werkzeug
	var hy := 23 + yo + sw
	rect(i, 14, 18 + yo + sw, 2, 5, tc)
	rect(i, 14, hy, 2, 2, skin)
	var steel := Color("#c8ccd8")
	var wood := Color("#8a5a34")
	match TOOL_OF.get(role, ""):
		"axe":
			rect(i, 15, hy - 9, 1, 11, wood); rect(i, 16, hy - 9, 3, 3, steel); rect(i, 16, hy - 9, 3, 1, Color.WHITE)
		"pick":
			rect(i, 15, hy - 9, 1, 11, wood); rect(i, 13, hy - 9, 6, 1, steel); rect(i, 18, hy - 8, 1, 2, steel)
		"hammer":
			rect(i, 15, hy - 8, 1, 10, wood); rect(i, 14, hy - 9, 4, 3, Color("#8a8a98")); rect(i, 14, hy - 9, 4, 1, steel)
		"saw":
			rect(i, 15, hy - 3, 5, 1, steel); rect(i, 15, hy - 2, 5, 1, Color("#9aa0b0")); rect(i, 15, hy - 4, 1, 3, wood)
		"rod":
			rect(i, 16, hy - 12, 1, 12, wood); rect(i, 17, hy - 13, 2, 1, wood); rect(i, 19, hy - 12, 1, 6, Color("#e8e0d0"))
		"bow":
			rect(i, 17, hy - 9, 1, 11, wood); rect(i, 16, hy - 10, 1, 1, wood); rect(i, 16, hy + 2, 1, 1, wood); rect(i, 15, hy - 8, 1, 9, Color("#e8e0d0"))
		"hoe":
			rect(i, 15, hy - 9, 1, 11, wood); rect(i, 16, hy - 9, 3, 1, steel); rect(i, 18, hy - 8, 1, 2, steel)
		"shovel":
			rect(i, 15, hy - 9, 1, 10, wood); rect(i, 14, hy - 10, 3, 1, wood); rect(i, 14, hy + 1, 3, 3, steel)
		"basket":
			rect(i, 14, hy - 1, 6, 4, Color("#a07850")); rect(i, 14, hy - 1, 6, 1, Color("#c8a070")); rect(i, 15, hy + 1, 4, 1, Color("#7a5430"))
			rect(i, 15, hy - 3, 2, 2, Color("#7ab84a")); rect(i, 17, hy - 2, 2, 1, Color("#b08ae0"))
		"pipe":
			rect(i, 15, hy - 9, 1, 10, steel); rect(i, 14, hy - 11, 3, 3, Color("#a8e8f8"))
		"sack":
			rect(i, 13, hy - 4, 6, 6, Color("#efe6d2")); rect(i, 13, hy - 4, 6, 1, Color("#d9ccae")); rect(i, 17, hy - 3, 1, 5, Color("#cfc2a4"))
		"knife":
			rect(i, 15, hy - 6, 1, 7, steel); rect(i, 15, hy + 1, 1, 2, wood)
		"ladle":
			rect(i, 15, hy - 7, 1, 8, wood); rect(i, 14, hy - 9, 3, 2, Color("#c8c8d0"))
	outline(i)
	shadow(i, 10, 29.0, 6.5, 1.5)
	S = old_s
	return i

static func deer_img(fr: int) -> Image:
	var i := mk(20, 18)
	rect(i, 5, 7, 10, 5, "#b07a4a"); rect(i, 5, 7, 10, 1, "#c99060"); rect(i, 5, 11, 10, 1, "#e0c090"); rect(i, 14, 4, 3, 5, "#b07a4a"); rect(i, 15, 2, 4, 3, "#b07a4a"); px(i, 18, 3, Color.BLACK)
	rect(i, 4, 8, 1, 2, "#f4efe0"); px(i, 16, 1, Color("#e0d0a0")); px(i, 15, 0, Color("#e0d0a0")); px(i, 17, 0, Color("#e0d0a0"))
	for p in [[7, 8], [10, 9], [12, 8]]:
		px(i, p[0], p[1], Color("#f4efe0"))
	if fr == 0:
		rect(i, 6, 12, 1, 4, "#7a5230"); rect(i, 13, 12, 1, 4, "#7a5230"); rect(i, 8, 12, 1, 3, "#7a5230"); rect(i, 11, 12, 1, 3, "#7a5230")
	else:
		rect(i, 7, 12, 1, 4, "#7a5230"); rect(i, 12, 12, 1, 4, "#7a5230"); rect(i, 5, 12, 1, 3, "#7a5230"); rect(i, 14, 12, 1, 3, "#7a5230")
	outline(i)
	return i

static func rabbit_img(fr: int) -> Image:
	var i := mk(11, 11)
	blob(i, 5, 6 - fr, 3.5, 2.5, ["#f4efe6", "#d8ccbc", "#b8a890", "#8a7a68"], 2.0)
	rect(i, 6, 2 - fr, 1, 3, "#d8ccbc"); rect(i, 7, 2 - fr, 1, 3, "#f4efe6"); px(i, 8, 5 - fr, Color.BLACK); px(i, 2, 6 - fr, Color.WHITE)
	outline(i)
	return i

static func sheep_img(fr: int) -> Image:
	var i := mk(15, 12)
	blob(i, 7, 5, 5.5, 3.5, ["#ffffff", "#ece8e0", "#cfc8bc", "#a8a090"], 3.0)
	rect(i, 11, 4, 3, 3, "#4a3a3a"); rect(i, 5 + fr, 8, 1, 2, "#4a3a3a"); rect(i, 9 - fr, 8, 1, 2, "#4a3a3a")
	outline(i)
	return i

static func pig_img(fr: int) -> Image:
	var i := mk(15, 11)
	blob(i, 7, 5, 5.5, 3, ["#ffc8c8", "#f0a0a8", "#d07c88", "#a85a68"], 4.0)
	rect(i, 11, 4, 3, 3, "#f0a0a8"); px(i, 13, 5, Color("#a85a68")); px(i, 12, 3, Color.BLACK); rect(i, 5 + fr, 8, 1, 2, "#a85a68"); rect(i, 9 - fr, 8, 1, 2, "#a85a68")
	outline(i)
	return i

static func bird_img(fr: int) -> Image:
	var i := mk(13, 9)
	rect(i, 5, 4, 4, 2, "#3a3a4a"); px(i, 9, 4, Color("#f0c040"))
	if fr == 0:
		line(i, 5, 4, 1, 1, "#3a3a4a"); line(i, 8, 4, 12, 1, "#3a3a4a")
	else:
		line(i, 5, 4, 1, 7, "#3a3a4a"); line(i, 8, 4, 12, 7, "#3a3a4a")
	return i

static func barrow_img() -> Image:
	var i := mk(14, 9)
	rect(i, 3, 2, 7, 3, "#8a5a34"); rect(i, 3, 2, 7, 1, "#b58850"); rect(i, 0, 4, 4, 1, "#6b4a34"); disc(i, 9, 6, 1, "#3a2a20")
	rect(i, 9, 3, 4, 1, "#6b4a34"); rect(i, 4, 5, 1, 2, "#6b4a34")
	outline(i)
	return i

static func fly_img(fr: int, col: String) -> Image:
	var i := mk(6, 6)
	var c := Color(col)
	if fr == 0:
		rect(i, 0, 1, 2, 3, c); rect(i, 4, 1, 2, 3, c)
	else:
		rect(i, 1, 2, 1, 2, c); rect(i, 4, 2, 1, 2, c)
	rect(i, 2, 1, 2, 4, "#3a2a3a")
	return i

static func field_img2(st: int) -> Image:
	# Gemuesebeet
	var i := mk(16, 16)
	for y in 16:
		for x in 16:
			i.set_pixel(x, y, Color("#7a5430") if (y % 4) < 2 else Color("#6a4628"))
	for row in 4:
		for x in range(1, 15, 3):
			var y := row * 4 + 2
			match st:
				0: px(i, x, y, Color("#7ab84a"))
				1: rect(i, x, y - 1, 2, 2, "#5aa84a")
				2: rect(i, x, y - 2, 3, 3, "#4a9a44"); px(i, x + 1, y - 2, Color("#7ac85a"))
				3:
					rect(i, x, y - 2, 3, 3, ["#c8504c", "#9ad05a", "#f08a30"][(x + row) % 3]); px(i, x + 1, y - 3, Color("#4a9a44"))
	return i

static func glow_img(col: Color) -> Image:
	var i := mk(48, 48)
	for y in 48:
		for x in 48:
			var d := Vector2(x - 23.5, y - 23.5).length() / 23.5
			if d < 1.0:
				var a := pow(1.0 - d, 2.0) * 0.9
				i.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	return i

static func field_img(st: int) -> Image:
	var i := mk(16, 16)
	for y in 16:
		for x in 16:
			i.set_pixel(x, y, Color("#8a6238") if (y % 4) < 2 else Color("#7a5430"))
	for row in 4:
		for x in range(1, 15, 3):
			var y := row * 4 + 2
			match st:
				0: px(i, x, y, Color("#7ab84a"))
				1:
					rect(i, x, y - 2, 1, 3, "#7ab84a")
				2:
					rect(i, x, y - 3, 1, 4, "#a8c84a"); px(i, x + 1, y - 3, Color("#d8d060"))
				3:
					rect(i, x, y - 4, 2, 5, "#e8c040"); px(i, x, y - 4, Color("#f8e070"))
	return i

static func scaffold_img(w: int, h: int) -> Image:
	var W := w / Data.K * 16
	var H := h / Data.K * 16 + 12
	var i := mk(W, H)
	for x in [2, W - 4]:
		rect(i, x, 8, 2, H - 10, "#8a6444")
	for y in range(10, H - 4, 8):
		rect(i, 2, y, W - 4, 2, "#b58850")
	line(i, 3, H - 4, W - 3, 12, "#8a6444")
	outline(i)
	return i

static func balloon_img(fr: int) -> Image:
	# Heissluftballon mit Korb und Pixler (26x36 logisch, Fuss = Unterkante des Korbs)
	var i := mk(26, 36)
	var cols := [Color("#e8453c"), Color("#fff0c8"), Color("#e8453c"), Color("#fff0c8"), Color("#e8453c"), Color("#fff0c8")]
	for y in range(0, 25 * S):
		for x in range(0, 26 * S):
			var xl := (x + 0.5) / S
			var yl := (y + 0.5) / S
			var hw := 0.0
			if yl <= 14.0:
				var dy := (yl - 12.0) / 12.0
				hw = 12.0 * sqrt(maxf(0.0, 1.0 - dy * dy)) if yl >= 0.0 else 0.0
				if yl < 12.0:
					hw = 12.0 * sqrt(maxf(0.0, 1.0 - dy * dy))
			else:
				var hw14 := 12.0 * sqrt(maxf(0.0, 1.0 - pow((14.0 - 12.0) / 12.0, 2.0)))
				hw = lerpf(hw14, 3.0, clampf((yl - 14.0) / 10.0, 0.0, 1.0))
			var dx := xl - 13.0
			if absf(dx) <= hw and hw > 0.5:
				var band := int(floor((dx / hw + 1.0) * 3.0))
				var c: Color = cols[clampi(band, 0, 5)]
				c = c.darkened(0.25 * clampf(dx / 12.0 + 0.3, 0.0, 1.0))
				if yl < 3.0:
					c = c.lightened(0.1)
				i.set_pixel(x, y, c)
	# Brenner + Seile + Korb
	rect(i, 12, 24, 2, 2, "#3a3a46")
	rect(i, 13, 25 - (1 if fr == 1 else 0), 1, 1, "#ffd040")
	line(i, 10, 23, 9, 29, "#6b4a34")
	line(i, 16, 23, 17, 29, "#6b4a34")
	rect(i, 8, 29, 11, 6, "#a07850")
	rect(i, 8, 29, 11, 1, "#c8a070")
	rect(i, 8, 33, 11, 2, "#7a5430")
	rect(i, 11, 27, 5, 3, Color("#f2c9a0"))
	rect(i, 10, 25, 6, 2, "#e8453c")
	rect(i, 12, 24, 3, 1, "#e8453c")
	rect(i, 16, 28, 2, 1, "#f0a888")
	outline(i)
	return i

static func build() -> void:
	if ready:
		return
	ready = true
	S = 2
	for g in Data.GOODS:
		goods[g] = tex(good_img(g))
	S = 1
	for g in Data.GOODS:
		goods_w[g] = tex(good_img(g))
	S = 2
	_make_objs()
	for k in Data.BD:
		bld[k] = house_tex(k)
	for k in Data.BD:
		var d: Dictionary = Data.BD[k]
		if not scaffold.has(str(d.w) + "x" + str(d.h)):
			scaffold[str(d.w) + "x" + str(d.h)] = tex(scaffold_img(d.w, d.h))
	balloon = [tex(balloon_img(0)), tex(balloon_img(1))]
	S = 1
	var roles := {
		"carrier": ["#c9a06a", "#6b4a34"], "idler": ["#8fbf8f", "#e8d8a0"], "builder": ["#e0c040", "#e8892c"],
	}
	for k in Data.BD:
		if Data.BD[k].has("col"):
			roles[k] = [Data.BD[k].col, Color(Data.BD[k].col).darkened(0.35).to_html(false)]
	for k in roles:
		var frs: Array = []
		for f in 5:
			frs.append(tex(man_img(k, roles[k][0], roles[k][1], f)))
		man[k] = frs
	an["barrow"] = [tex(barrow_img())]
	an["deer"] = [tex(deer_img(0)), tex(deer_img(1))]
	an["rabbit"] = [tex(rabbit_img(0)), tex(rabbit_img(1))]
	an["sheep"] = [tex(sheep_img(0)), tex(sheep_img(1))]
	an["pig"] = [tex(pig_img(0)), tex(pig_img(1))]
	an["bird"] = [tex(bird_img(0)), tex(bird_img(1))]
	for c in ["#f5a0d0", "#a0d8f5", "#f5e070"]:
		an["fly" + c] = [tex(fly_img(0, c)), tex(fly_img(1, c))]
	S = 2
	station = fin(station_img(), true)
	S = 1
	glow["warm"] = tex(glow_img(Color(1.0, 0.7, 0.35)))
	glow["pink"] = tex(glow_img(Color(1.0, 0.6, 0.95)))
	glow["cyan"] = tex(glow_img(Color(0.5, 0.95, 1.0)))
	glow["teal"] = tex(glow_img(Color(0.35, 1.0, 0.8)))
	glow["violet"] = tex(glow_img(Color(0.65, 0.5, 1.0)))
	glow["lava"] = tex(glow_img(Color(1.0, 0.45, 0.12)))
	for s in 4:
		fieldt.append(tex(field_img(s)))
		fieldt2.append(tex(field_img2(s)))
	var st := mk(16, 12)
	blob(st, 8, 8, 4, 2.5, ["#b58850", "#8a6444", "#6b4a34", "#4a3020"], 3.0)
	rect(st, 5, 6, 6, 2, "#d9b070")
	stumpt = fin(st, false)
	S = 2
