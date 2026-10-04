extends SceneTree
# Stil-Test (Siedler-2-Look): gerichtetes Licht von links oben, Flaechen-Shading, Dithering, geworfene Schatten.
# godot --headless --path . --script tools/style_test.gd -- style_test.png 3

const W := 400
const H := 240
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
var LV := Vector3(-0.55, -0.6, 0.58).normalized()

# Rampen: dunkel (kuehl/violett) -> hell (warm)
var GRASS := _r(["#2b5f2a", "#3b7a30", "#4e9638", "#66b044", "#86c95a"])
var PATHC := _r(["#6b5638", "#8a7248", "#a58c5c", "#bfa575", "#d6c18e"])
var SAND := _r(["#a88c5a", "#c3a76c", "#dcc488", "#ecd9a4", "#f7ebc0"])
var WATER := _r(["#1b3f78", "#245a9a", "#2f78b8", "#4a96d0", "#7cc0e8"])
var WALL := _r(["#5d4e5a", "#8a7466", "#b99d7a", "#d9c294", "#f0dcb0"])
var PLANK := _r(["#3a2a2e", "#5c4034", "#855a3c", "#aa7a4a", "#cf9e62"])
var ROOF_R := _r(["#3c1a22", "#6e2a26", "#9c3f2b", "#c25a36", "#e07d48"])
var ROOF_G := _r(["#1f3a30", "#2f5a40", "#437a4a", "#62a05a", "#8cc872"])
var WOOD := _r(["#2a1a1c", "#4a2f26", "#6e4630", "#946238", "#bd8a52"])
var STONE := _r(["#4a4558", "#6c687c", "#908ca0", "#b4b0c0", "#d6d3e0"])
var OAK := _r(["#1f4a2c", "#2e6a34", "#43883c", "#62a844", "#8fcb58"])
var PINE := _r(["#16382e", "#235046", "#2f6a48", "#418a54", "#63ab62"])
var GLASS := _r(["#7a4a1c", "#c8862c", "#f0c050", "#ffe58a", "#fff4c0"])
var FLAGC := _r(["#14306a", "#1f4aa8", "#2f6ad8", "#5a92f0", "#9cc4ff"])

var img: Image
var shade_mask := PackedFloat32Array()
var sprites: Array = []   # [Image, x, y, base]


func _r(a: Array) -> Array:
	var o: Array = []
	for c in a:
		o.append(Color(c))
	return o


# ------------------------------------------------------------ Grundwerkzeuge
func hsh(x: float, y: float, s: float = 0.0) -> float:
	return fposmod(sin(x * 127.1 + y * 311.7 + s * 74.7) * 43758.5453, 1.0)


func vn(x: float, y: float, s: float = 0.0) -> float:
	var ix := floorf(x)
	var iy := floorf(y)
	var fx := x - ix
	var fy := y - iy
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	return lerpf(lerpf(hsh(ix, iy, s), hsh(ix + 1, iy, s), fx), lerpf(hsh(ix, iy + 1, s), hsh(ix + 1, iy + 1, s), fx), fy)


func ramp(cols: Array, t: float, x: int, y: int) -> Color:
	# Palettenstufe plus Bayer-Dithering an den Uebergaengen
	t = clampf(t, 0.0, 0.999)
	var v := t * (cols.size() - 1)
	var lo := int(v)
	var fr := v - lo
	var b: float = (BAYER[((y & 3) << 2) | (x & 3)] + 0.5) / 16.0
	return cols[lo + 1] if fr > b else cols[lo]


func put(s: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < s.get_width() and y < s.get_height():
		s.set_pixel(x, y, c)


func fill_poly(s: Image, pts: Array, f: Callable) -> void:
	var pv := PackedVector2Array(pts)
	var mn := Vector2(1e9, 1e9)
	var mx := Vector2(-1e9, -1e9)
	for p in pts:
		var q: Vector2 = p
		mn = mn.min(q)
		mx = mx.max(q)
	for y in range(int(mn.y), int(mx.y) + 1):
		for x in range(int(mn.x), int(mx.x) + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), pv):
				put(s, x, y, f.call(x, y))


func fill_rect_f(s: Image, x0: int, y0: int, w: int, h: int, f: Callable) -> void:
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			put(s, x, y, f.call(x, y))


func outline(s: Image, f: float = 0.42) -> void:
	var w := s.get_width()
	var h := s.get_height()
	var src := s.duplicate() as Image
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
						s.set_pixel(x, y, Color(c.r * f * 0.9, c.g * f * 0.85, c.b * f, 1.0))
						break


func new_sprite(w: int, h: int) -> Image:
	return Image.create(w, h, false, Image.FORMAT_RGBA8)


# ------------------------------------------------------------ Gelaende
func hgt(x: float, y: float) -> float:
	return vn(x / 55.0, y / 55.0, 3.0) * 16.0 + vn(x / 18.0, y / 18.0, 5.0) * 3.0


func path_y(x: float) -> float:
	return 178.0 + 14.0 * sin(x / 48.0)


func terrain() -> void:
	img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	shade_mask.resize(W * H)
	shade_mask.fill(0.0)
	for y in H:
		for x in W:
			var dhx := (hgt(x + 1, y) - hgt(x - 1, y)) * 0.5
			var dhy := (hgt(x, y + 1) - hgt(x, y - 1)) * 0.5
			var slope := 0.55 * dhx + 0.6 * dhy
			var n := vn(x / 7.0, y / 7.0, 1.0) * 0.6 + vn(x / 2.5, y / 2.5, 2.0) * 0.4
			var c := ramp(GRASS, 0.5 + slope * 1.7 + (n - 0.5) * 0.55, x, y)
			# See oben rechts mit Sandstrand
			var wd := pow((x - 372.0) / 120.0, 2.0) + pow((y - 8.0) / 58.0, 2.0) + (vn(x / 12.0, y / 12.0, 7.0) - 0.5) * 0.3
			if wd < 1.0:
				var wt := 0.45 + (vn(x / 6.0 + 2.0, y / 3.0, 9.0) - 0.5) * 0.7 - (1.0 - wd) * 0.25 * 0.0
				c = ramp(WATER, wt - clampf(wd - 0.75, 0.0, 1.0) * 0.4 + 0.1, x, y)
			elif wd < 1.2:
				c = ramp(SAND, 0.55 + slope * 1.2 + (n - 0.5) * 0.5 - (wd - 1.0) * 0.8 * 0.0, x, y)
				if wd < 1.04:
					c = c.darkened(0.12)   # nasser Sand am Ufer
			# Weg
			var dp := absf(y - path_y(x) - (vn(x / 9.0, 0.5, 4.0) - 0.5) * 4.0)
			if dp < 5.5 and wd > 1.2:
				c = ramp(PATHC, 0.58 + slope * 1.5 + (n - 0.5) * 0.5, x, y)
				if dp > 4.2:
					c = c.darkened(0.18)
				elif hsh(x, y, 11.0) > 0.97:
					c = c.lightened(0.18)
			elif dp < 7.0 and wd > 1.2:
				c = c.darkened(0.1)   # Kante: leichtes Einsinken
			elif wd > 1.2:
				var h := hsh(x, y, 3.0)
				if h > 0.992:
					c = Color("#f4f0e0") if hsh(x, y, 4.0) < 0.4 else (Color("#f2d24a") if hsh(x, y, 4.0) < 0.7 else Color("#e87aa0"))
				elif h < 0.018:
					c = GRASS[0]
			img.set_pixel(x, y, c)
	# Grasbueschel: kleine v-Formen mit Licht links
	for k in 260:
		var tx := int(hsh(k, 1.0, 21.0) * W)
		var ty := int(hsh(k, 2.0, 21.0) * H)
		if absf(ty - path_y(tx)) < 9.0:
			continue
		var base := img.get_pixel(tx, ty)
		if base.b > base.g:
			continue
		put(img, tx, ty, GRASS[0])
		put(img, tx - 1, ty - 1, GRASS[1])
		put(img, tx + 1, ty - 1, GRASS[0])
		put(img, tx - 1, ty - 2, GRASS[4])


# ------------------------------------------------------------ Schatten
func cast(s: Image, ox: int, oy: int, base: int, kx: float = 0.7, ky: float = 0.3, strength: float = 0.62) -> void:
	for sy in range(0, base + 1):
		var hh := float(base - sy)
		for sx in s.get_width():
			if s.get_pixel(sx, sy).a < 0.5:
				continue
			var tx := int(round(ox + sx + hh * kx))
			var ty := int(round(oy + base + hh * ky))
			for d in 2:
				var xx := tx + d
				if xx >= 0 and ty >= 0 and xx < W and ty < H:
					shade_mask[ty * W + xx] = maxf(shade_mask[ty * W + xx], strength)


func contact(cx: int, cy: int, rx: float, ry: float, strength: float = 0.5) -> void:
	for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
		for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
			var dx := (x - cx) / rx
			var dy := (y - cy) / ry
			if dx * dx + dy * dy <= 1.0 and x >= 0 and y >= 0 and x < W and y < H:
				shade_mask[y * W + x] = maxf(shade_mask[y * W + x], strength)


func apply_shadows() -> void:
	var tint := Color(0.5, 0.56, 0.8)
	for y in H:
		for x in W:
			var m := shade_mask[y * W + x]
			if m > 0.0:
				var c := img.get_pixel(x, y)
				img.set_pixel(x, y, c.lerp(c * tint, m))


# ------------------------------------------------------------ Sprites
func house(wall: Array, roof: Array, planks: bool, seed: float) -> Image:
	var s := new_sprite(76, 64)
	# Seitenwand (rechts, vom Licht abgewandt)
	fill_poly(s, [Vector2(48, 32), Vector2(62, 26), Vector2(62, 52), Vector2(48, 58)], func(x: int, y: int) -> Color:
		var t := 0.17 + (vn(x / 2.0, y / 2.0, seed) - 0.5) * 0.12
		if planks and x % 3 == 0:
			t -= 0.07
		t -= clampf((y - 50.0 + (x - 48) * 0.4) / 10.0, 0.0, 1.0) * 0.08
		return ramp(wall, t, x, y))
	# Vorderwand
	fill_rect_f(s, 8, 32, 40, 26, func(x: int, y: int) -> Color:
		var t := 0.64 + (vn(x / 1.5, y / 1.5, seed + 1.0) - 0.5) * 0.16 + (48.0 - x) / 40.0 * 0.07
		if planks and x % 3 == 0:
			t -= 0.1
		t -= clampf((y - 52.0) / 6.0, 0.0, 1.0) * 0.22                 # Boden-Verschattung
		t -= clampf(1.0 - (y - 36.0) / 6.0, 0.0, 1.0) * 0.38 if y >= 36 else 0.0   # Traufschatten
		var c := ramp(wall, t, x, y)
		if y >= 55:
			c = ramp(STONE, 0.52 + (vn(x / 3.0, y / 2.0, seed) - 0.5) * 0.5 + (0.0 if (x / 5 + y / 3) % 2 == 0 else -0.12), x, y)
		elif not planks and (x <= 9 or x >= 46 or y == 44 or y == 45):
			c = ramp(WOOD, 0.46 - float(x - 8) * 0.004 + (vn(x, y / 3.0, 3.0) - 0.5) * 0.2, x, y)
		return c)
	# Tuer
	fill_rect_f(s, 21, 44, 9, 14, func(x: int, y: int) -> Color:
		var t := 0.5 - (x - 21) * 0.045 + (vn(x * 2.0, y / 4.0, 6.0) - 0.5) * 0.25
		if x == 21 or x == 29 or y == 44:
			t += 0.3
		return ramp(WOOD, t, x, y))
	put(s, 27, 51, GLASS[3])
	fill_rect_f(s, 19, 58, 13, 2, func(x: int, y: int) -> Color:
		return ramp(STONE, 0.7 - (y - 58) * 0.2, x, y))
	# Fenster mit warmem Licht
	for wx: int in [11, 35]:
		fill_rect_f(s, wx - 1, 42, 8, 8, func(x: int, y: int) -> Color:
			return ramp(WOOD, 0.62 - (x - wx) * 0.04, x, y))
		fill_rect_f(s, wx, 43, 6, 6, func(x: int, y: int) -> Color:
			var t := 0.55 + (6.0 - (x - wx) - (y - 43)) * 0.05
			if x == wx + 2 or y == 45:
				return ramp(WOOD, 0.5, x, y)
			return ramp(GLASS, t, x, y))
		fill_rect_f(s, wx - 1, 50, 8, 1, func(x: int, y: int) -> Color:
			return ramp(WALL, 0.9, x, y))
		fill_rect_f(s, wx - 1, 51, 8, 1, func(x: int, y: int) -> Color:
			return ramp(WALL, 0.2, x, y))
	# Schornstein (hinter dem Dach)
	fill_rect_f(s, 40, 5, 8, 14, func(x: int, y: int) -> Color:
		var brick := 0.0 if ((x + (y / 3) * 2) % 4 != 0 and y % 3 != 0) else -0.12
		var t := (0.7 if x < 44 else 0.22) + brick + (vn(x, y, 8.0) - 0.5) * 0.12
		if y == 5:
			t = 0.92
		return ramp(STONE, t, x, y))
	# Dach: dunkle rechte Flaeche zuerst
	fill_poly(s, [Vector2(53, 36), Vector2(60, 16), Vector2(67, 29)], func(x: int, y: int) -> Color:
		var row := y / 3
		var t := 0.2 + (vn(x / 2.0, y / 2.0, seed + 5.0) - 0.5) * 0.12
		if y % 3 == 2:
			t -= 0.08
		return ramp(roof, t, x, y))
	# Dach: Vorderseite, zum Licht gewandt
	fill_poly(s, [Vector2(3, 36), Vector2(53, 36), Vector2(60, 16), Vector2(10, 16)], func(x: int, y: int) -> Color:
		var row := y / 3
		var off := (row % 2) * 3
		var t := 0.7 + (hsh(float((x + off) / 6), float(row), seed) - 0.5) * 0.26 + (36.0 - y) / 20.0 * 0.12 + (60.0 - x) / 60.0 * 0.04 * -1.0
		if (x + off) % 6 == 0:
			t -= 0.16
		if y % 3 == 2:
			t -= 0.2
		elif y % 3 == 0:
			t += 0.1
		if y >= 35:
			t = 0.2
		if y <= 17:
			t = 0.93
		return ramp(roof, t, x, y))
	outline(s)
	return s


func oak(seed: float) -> Image:
	var s := new_sprite(60, 68)
	# Stamm als Zylinder
	fill_rect_f(s, 25, 38, 8, 24, func(x: int, y: int) -> Color:
		var nx := (x - 28.5) / 4.0
		var t := 0.62 - nx * 0.42 + (vn(x * 2.0, y / 5.0, seed) - 0.5) * 0.3
		if y > 56:
			t -= (y - 56) * 0.03
		return ramp(WOOD, t, x, y))
	fill_poly(s, [Vector2(23, 62), Vector2(25, 57), Vector2(33, 57), Vector2(36, 62)], func(x: int, y: int) -> Color:
		return ramp(WOOD, 0.5 - (x - 29) * 0.04, x, y))
	var cl := [[30.0, 22.0, 17.0], [17.0, 32.0, 11.0], [43.0, 32.0, 11.0], [30.0, 36.0, 12.0], [21.0, 16.0, 10.0], [39.0, 15.0, 10.0]]
	for y in 62:
		for x in 60:
			var best := -1e9
			var nrm := Vector3.ZERO
			for c in cl:
				var dx: float = (x - c[0]) / c[2]
				var dy: float = (y - c[1]) / c[2]
				var d2 := dx * dx + dy * dy
				if d2 > 1.0:
					continue
				var nz := sqrt(1.0 - d2)
				var z: float = nz * c[2] * 0.6 + c[1] * 0.25
				if z > best:
					best = z
					nrm = Vector3(dx, dy, nz).normalized()
			if best <= -1e8:
				continue
			var lam := nrm.dot(LV)
			var leaf := vn(x / 1.7, y / 1.7, seed + 2.0)
			var t := 0.46 + lam * 0.55 + (leaf - 0.5) * 0.42 - clampf((y - 30.0) / 30.0, 0.0, 1.0) * 0.18
			if hsh(x, y, seed) > 0.95 and lam > 0.1:
				t += 0.25
			put(s, x, y, ramp(OAK, t, x, y))
	outline(s)
	return s


func pine() -> Image:
	var s := new_sprite(44, 72)
	fill_rect_f(s, 20, 58, 4, 11, func(x: int, y: int) -> Color:
		return ramp(WOOD, 0.58 - (x - 21) * 0.2, x, y))
	for k in 4:
		var y0 := 2 + k * 14
		var y1 := 22 + k * 14
		var hw := 7 + k * 3
		var pts := [Vector2(22, y0), Vector2(22 - hw, y1), Vector2(22 + hw, y1)]
		fill_poly(s, pts, func(x: int, y: int) -> Color:
			var fr := float(y - y0) / float(y1 - y0)
			var side := (x - 22.0) / maxf(0.5, hw * fr)
			var jag := 1.0 if (y + (x / 3) * 2) % 5 == 0 else 0.0
			var t := 0.66 - side * 0.5 + (vn(x / 1.5, y / 1.5, k * 3.0) - 0.5) * 0.3 - jag * 0.18
			t -= clampf(1.0 - (y1 - y) / 4.0 - 0.0, 0.0, 1.0) * 0.22   # Schatten unter jeder Etage
			return ramp(PINE, t, x, y))
	outline(s)
	return s


func rock(seed: float, big: bool) -> Image:
	var s := new_sprite(48, 36)
	var f: Array = []
	for k in 8:
		var a := hsh(k, seed, 1.0) * TAU
		var tilt := 0.35 + hsh(k, seed, 2.0) * 0.8
		f.append([14.0 + hsh(k, seed, 3.0) * 20.0, 8.0 + hsh(k, seed, 4.0) * 18.0,
			Vector3(cos(a) * tilt, sin(a) * tilt - 0.3, 1.0).normalized()])
	var rx := 19.0 if big else 14.0
	var ry := 13.0 if big else 10.0
	for y in 36:
		for x in 48:
			var ex := (x - 24.0) / rx
			var ey := (y - 20.0) / ry
			var ex2 := (x - 15.0) / (rx * 0.5)
			var ey2 := (y - 24.0) / (ry * 0.55)
			if ex * ex + ey * ey * 1.15 > 1.0 and ex2 * ex2 + ey2 * ey2 > 1.0:
				continue
			var bd := 1e9
			var nrm := Vector3(0, 0, 1)
			for q in f:
				var d: float = (x - q[0]) * (x - q[0]) + (y - q[1]) * (y - q[1])
				if d < bd:
					bd = d
					nrm = q[2]
			var lam := nrm.dot(LV)
			var t := 0.42 + lam * 0.62 + (vn(x / 2.0, y / 2.0, seed) - 0.5) * 0.2 - clampf((y - 24.0) / 12.0, 0.0, 1.0) * 0.2
			var c := ramp(STONE, t, x, y)
			if nrm.y < -0.15 and vn(x / 3.0, y / 3.0, seed + 9.0) > 0.55 and y < 24:
				c = ramp(OAK, 0.35 + lam * 0.5, x, y)   # Moos auf den Oberseiten
			put(s, x, y, c)
	outline(s)
	return s


func flag() -> Image:
	var s := new_sprite(14, 22)
	fill_rect_f(s, 2, 0, 1, 21, func(x: int, y: int) -> Color:
		return WOOD[3])
	fill_poly(s, [Vector2(3, 1), Vector2(12, 3), Vector2(11, 7), Vector2(3, 9)], func(x: int, y: int) -> Color:
		var t := 0.62 + sin((x - 3.0) * 0.9) * 0.2 - (y - 1.0) * 0.03
		return ramp(FLAGC, t, x, y))
	outline(s)
	return s


func add(s: Image, x: int, y: int, base: int, kx: float = 0.7, ky: float = 0.3, contact_r: float = 0.0, st: float = 0.62) -> void:
	sprites.append([s, x, y, base])
	cast(s, x, y, base, kx, ky, st)
	if contact_r > 0.0:
		contact(x + s.get_width() / 2, y + base, contact_r, contact_r * 0.32, 0.55)


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "style_test.png"
	var sc: int = int(args[1]) if args.size() > 1 else 3
	terrain()
	add(house(WALL, ROOF_R, false, 1.0), 18, 52, 58, 0.62, 0.28, 24.0)
	add(house(PLANK, ROOF_G, true, 4.0), 118, 30, 58, 0.62, 0.28, 24.0)
	add(oak(2.0), 196, 14, 62, 0.75, 0.32, 12.0)
	add(oak(5.0), 250, 70, 62, 0.75, 0.32, 12.0)
	add(pine(), 306, 40, 69, 0.8, 0.32, 8.0)
	add(pine(), 345, 76, 69, 0.8, 0.32, 8.0)
	add(rock(1.0, true), 40, 118, 32, 0.7, 0.3, 17.0)
	add(rock(6.0, false), 290, 138, 32, 0.7, 0.3, 13.0)
	add(flag(), 52, 108, 20, 0.7, 0.3, 0.0, 0.45)
	add(flag(), 150, 86, 20, 0.7, 0.3, 0.0, 0.45)
	apply_shadows()
	sprites.sort_custom(func(a, b): return a[2] + a[3] < b[2] + b[3])
	for e in sprites:
		var sp: Image = e[0]
		img.blend_rect(sp, Rect2i(0, 0, sp.get_width(), sp.get_height()), Vector2i(e[1], e[2]))
	if sc > 1:
		img.resize(W * sc, H * sc, Image.INTERPOLATE_NEAREST)
	img.save_png(out)
	print("saved ", out)
	quit()
