extends SceneTree
# Stil-Test 2: Maerchenhaft / handgemalt / ausfallend. Vier Gebaeude in vier Kulturen.
# godot --path . --rendering-method forward_plus --script tools/style3d2.gd -- style3d2
# Schreibt <prefix>_scene.png und <prefix>_hq / _bakery / _lumber / _fisher.png

const BASE_H := 0.5
const LAKE := Vector2(5.0, 11.5)
const LAKE_R := 6.2
const SUN := Vector3(-0.4, 0.8, 0.55)

var world: Node3D
var vp: SubViewport
var cache := {}
var nh := FastNoiseLite.new()
var pads: Array = []
var segs: Array = []
var sun_dir := SUN.normalized()
var outline_mat: ShaderMaterial


# ------------------------------------------------------------ Helfer
func hsh(x: float, y: float, s: float = 0.0) -> float:
	return fposmod(sin(x * 127.1 + y * 311.7 + s * 74.7) * 43758.5453, 1.0)


func ntex(sz: int, freq: float, oct: int, seed: int) -> Image:
	var n := FastNoiseLite.new()
	n.seed = seed
	n.frequency = freq
	n.fractal_octaves = oct
	return n.get_seamless_image(sz, sz)


func finish(col: Image, hi: Image, nrm: float) -> Dictionary:
	col.generate_mipmaps()
	var d := {"a": ImageTexture.create_from_image(col)}
	if hi != null and nrm > 0.0:
		hi.bump_map_to_normal_map(nrm)
		hi.generate_mipmaps()
		d["n"] = ImageTexture.create_from_image(hi)
	return d


func gray(h: float) -> Color:
	return Color(h, h, h)


func st_at(im: Image, x: float, y: float, kx: float, ky: float) -> float:
	var sz := im.get_width()
	return im.get_pixel(int(x * kx) % sz, int(y * ky) % sz).r


# ------------------------------------------------------------ Texturen (handgemalt: weiche Pinselstriche, wenig Kontrast)
func tex_grass() -> Dictionary:
	var sz := 256
	var col := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var n1 := ntex(sz, 0.014, 3, 11)
	var n2 := ntex(sz, 0.09, 2, 12)
	for y in sz:
		for x in sz:
			var a := n1.get_pixel(x, y).r
			var s := st_at(n2, x, y, 1.0, 3.0)
			var t := clampf(a * 0.75 + s * 0.45 - 0.12, 0.0, 1.0)
			var c := Color("#3c8f55").lerp(Color("#9fd868"), t)
			if t > 0.55 and hsh(x / 3, y / 3, 3.0) > 0.8:
				c = c.lerp(Color("#d8f07a"), 0.35)
			col.set_pixel(x, y, c)
	return finish(col, null, 0.0)


func tex_cobble() -> Dictionary:
	var sz := 256
	var col := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var hi := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var n1 := ntex(sz, 0.05, 3, 61)
	var cell := 32.0
	for y in sz:
		for x in sz:
			var cx := int(x / cell)
			var cy := int(y / cell)
			var f1 := 1e9
			var f2 := 1e9
			var id := 0.0
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					var gx := cx + ox
					var gy := cy + oy
					var px := (gx + 0.2 + hsh(gx % 8, gy % 8, 1.0) * 0.6) * cell
					var py := (gy + 0.2 + hsh(gx % 8, gy % 8, 2.0) * 0.6) * cell
					var d := Vector2(x - px, y - py).length()
					if d < f1:
						f2 = f1
						f1 = d
						id = hsh(gx % 8, gy % 8, 3.0)
					elif d < f2:
						f2 = d
			var edge := (f2 - f1)
			var nv := n1.get_pixel(x, y).r
			var b := 0.72 + id * 0.22 + (nv - 0.5) * 0.2
			var c := Color(b * 1.0, b * 0.92, b * 0.82)
			var h := clampf(edge / 7.0, 0.0, 1.0)
			if edge < 2.2:
				c = Color(0.46, 0.38, 0.3)
			col.set_pixel(x, y, c)
			hi.set_pixel(x, y, gray(h))
	return finish(col, hi, 2.5)


func tex_sand() -> Dictionary:
	var sz := 256
	var col := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var n1 := ntex(sz, 0.04, 3, 71)
	for y in sz:
		for x in sz:
			var v := n1.get_pixel(x, y).r
			var c := Color("#d8bd86").lerp(Color("#f8e6b0"), v)
			col.set_pixel(x, y, c)
	return finish(col, null, 0.0)


func tex_plaster() -> Dictionary:
	var sz := 256
	var col := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var hi := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var n1 := ntex(sz, 0.012, 3, 21)
	var n2 := ntex(sz, 0.08, 2, 22)
	for y in sz:
		for x in sz:
			var a := n1.get_pixel(x, y).r
			var s := st_at(n2, x, y, 2.0, 1.0)
			var k := 0.84 + 0.2 * a + 0.1 * s
			var c := Color(k, k * 0.97, k * 0.93)
			col.set_pixel(x, y, c)
			hi.set_pixel(x, y, gray(s))
	return finish(col, hi, 1.2)


func tex_plank(horizontal: bool) -> Dictionary:
	var sz := 256
	var col := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var hi := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var nn := ntex(sz, 0.08, 3, 31)
	for y in sz:
		for x in sz:
			var u := y if horizontal else x
			var v := x if horizontal else y
			var p := u / 32
			var fu := u % 32
			var id := hsh(p, 0.0, 3.0)
			var g := nn.get_pixel((u * 3) % sz, (v / 8 + p * 17) % sz).r
			var b := 0.74 + id * 0.16 + (g - 0.5) * 0.28
			var c := Color(b, b * 0.93, b * 0.84)
			var h := 0.7 + g * 0.2
			if fu < 2 or fu > 29:
				c = Color(0.3, 0.24, 0.22)
				h = 0.0
			col.set_pixel(x, y, c)
			hi.set_pixel(x, y, gray(h))
	return finish(col, hi, 2.0)


func tex_stone() -> Dictionary:
	var sz := 256
	var col := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var hi := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var nn := ntex(sz, 0.05, 3, 5)
	var th := sz / 8
	for y in sz:
		for x in sz:
			var r := y / th
			var tw := 40 + int(hsh(r, 0.0, 2.0) * 24.0)
			var xo := (x + int(hsh(r, 1.0, 2.0) * 60.0)) % sz
			var c := xo / tw
			var fx := float(xo % tw)
			var fy := float(y % th)
			var d := minf(minf(fx, tw - fx), minf(fy, th - fy))
			var id := hsh(c, r, 7.0)
			var nv := nn.get_pixel(x, y).r
			var cc: Color
			var h: float
			if d < 2.0:
				cc = Color(0.52, 0.5, 0.56)
				h = 0.0
			else:
				var b := 0.8 + id * 0.16 + (nv - 0.5) * 0.18
				cc = Color(b, b * 0.98, b)
				h = clampf(0.4 + minf(d - 2.0, 5.0) * 0.1, 0.0, 1.0)
			col.set_pixel(x, y, cc)
			hi.set_pixel(x, y, gray(h))
	return finish(col, hi, 3.0)


func tex_scale() -> Dictionary:
	# Fischschuppen-Schindeln, neutral hell, wird per albedo_color eingefaerbt
	var sz := 256
	var col := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var hi := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var nn := ntex(sz, 0.05, 3, 3)
	var th := 28
	var tw := 32
	var rows := sz / th + 1
	var rad := tw * 0.62
	for y in sz:
		for x in sz:
			var best := -99
			var bd := 0.0
			var bid := 0.0
			var r0 := y / th
			for r in range(r0 - 1, r0 + 3):
				var off := (r & 1) * 0.5
				var c := roundi(float(x) / tw - off - 0.5)
				var cx := (c + 0.5 + off) * tw
				var dx := x - cx
				var dy := y - r * th
				var d := sqrt(dx * dx + dy * dy)
				if d <= rad and r > best:
					best = r
					bd = d / rad
					bid = hsh(c, r, 4.0)
			var nv := nn.get_pixel(x, y).r
			var c: Color
			var h := 0.0
			if best == -99:
				c = Color(0.4, 0.4, 0.4)
			else:
				var b := 0.78 + bid * 0.2 + (nv - 0.5) * 0.14
				var rim := smoothstep(0.78, 1.0, bd)
				b *= 1.0 - rim * 0.5
				b += (1.0 - bd) * 0.08
				c = Color(b, b, b)
				h = 1.0 - bd * bd
			col.set_pixel(x, y, c)
			hi.set_pixel(x, y, gray(h))
	return finish(col, hi, 3.0)


func tex_bark() -> Dictionary:
	var sz := 256
	var col := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var hi := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var nn := ntex(sz, 0.07, 3, 41)
	for y in sz:
		for x in sz:
			var g := nn.get_pixel((x * 4) % sz, (y / 10) % sz).r
			var k := 0.62 + g * 0.5
			col.set_pixel(x, y, Color(k, k * 0.82, k * 0.64))
			hi.set_pixel(x, y, gray(g))
	return finish(col, hi, 3.0)


func tex_leaf() -> Dictionary:
	var sz := 256
	var col := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var nn := ntex(sz, 0.04, 3, 51)
	for y in sz:
		for x in sz:
			var v := nn.get_pixel(x, y).r * 0.6 + hsh(x / 7, y / 7, 2.0) * 0.4
			var c := Color("#3a8a58").lerp(Color("#b8e870"), clampf(v * 1.2 - 0.1, 0.0, 1.0))
			col.set_pixel(x, y, c)
	return finish(col, null, 0.0)


func tex(kind: String) -> Dictionary:
	if cache.has("t_" + kind):
		return cache["t_" + kind]
	var d: Dictionary
	match kind:
		"cobble": d = tex_cobble()
		"sand": d = tex_sand()
		"plaster": d = tex_plaster()
		"plank": d = tex_plank(false)
		"plank_h": d = tex_plank(true)
		"stone": d = tex_stone()
		"scale": d = tex_scale()
		"bark": d = tex_bark()
		"leaf": d = tex_leaf()
		_: d = tex_grass()
	cache["t_" + kind] = d
	return d


func mat(kind: String, tint: Color = Color.WHITE, sc: float = 0.5, rough: float = 0.9, nrm: float = 1.0, tri: bool = true, ol: bool = true) -> StandardMaterial3D:
	var key := "m_%s_%s_%s_%s_%s_%s" % [kind, tint, sc, rough, tri, ol]
	if cache.has(key):
		return cache[key]
	var t := tex(kind)
	var m := StandardMaterial3D.new()
	m.albedo_texture = t["a"]
	m.albedo_color = tint
	m.roughness = rough
	if t.has("n"):
		m.normal_enabled = true
		m.normal_texture = t["n"]
		m.normal_scale = nrm
	m.uv1_triplanar = tri
	m.uv1_scale = Vector3(sc, sc, sc) if tri else Vector3(sc, sc, 1.0)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if ol:
		m.next_pass = outline_mat
	cache[key] = m
	return m


func flat(c: Color, rough: float = 0.7, emit: float = 0.0, ol: bool = true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	elif ol:
		m.next_pass = outline_mat
	return m


# ------------------------------------------------------------ Szenen-Helfer
func mi(parent: Node3D, mesh: Mesh, m: Material, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO, shadow: bool = true) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = m
	n.position = pos
	n.rotation_degrees = rot
	if not shadow:
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(n)
	return n


func box(parent: Node3D, size: Vector3, m: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return mi(parent, b, m, pos, rot)


func cyl(parent: Node3D, rb: float, rt: float, h: float, m: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, seg: int = 14) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.bottom_radius = rb
	c.top_radius = rt
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return mi(parent, c, m, pos, rot)


func ball(parent: Node3D, r: float, m: Material, pos: Vector3, seg: int = 16, rings: int = 10, shadow: bool = true) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = rings
	return mi(parent, s, m, pos, Vector3.ZERO, shadow)


func torus(parent: Node3D, R: float, r: float, m: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = R - r
	t.outer_radius = R + r
	t.rings = 20
	t.ring_segments = 8
	return mi(parent, t, m, pos, rot)


func tri(st: SurfaceTool, a: Vector3, ua: Vector2, b: Vector3, ub: Vector2, c: Vector3, uc: Vector2, out: Vector3, sg: int) -> void:
	var n := (b - a).cross(c - a)
	if n.dot(out) > 0.0:
		var t := b
		b = c
		c = t
		var tu := ub
		ub = uc
		uc = tu
	st.set_smooth_group(sg)
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_smooth_group(sg)
	st.set_uv(ub)
	st.add_vertex(b)
	st.set_smooth_group(sg)
	st.set_uv(uc)
	st.add_vertex(c)


func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3, sg: int) -> void:
	tri(st, a, Vector2(0, 0), b, Vector2(1, 0), c, Vector2(1, 1), out, sg)
	tri(st, a, Vector2(0, 0), c, Vector2(1, 1), d, Vector2(0, 1), out, sg)


func lathe(profile: Array, seg: int, uvs: Vector2 = Vector2(3, 1)) -> ArrayMesh:
	# Drehkoerper aus Profil [(radius, hoehe) ...] von unten nach oben
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var acc: Array = [0.0]
	for j in profile.size() - 1:
		acc.append(float(acc[j]) + (Vector2(profile[j + 1]) - Vector2(profile[j])).length())
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var am := (a0 + a1) * 0.5
		for j in profile.size() - 1:
			var p0: Vector2 = profile[j]
			var p1: Vector2 = profile[j + 1]
			var t := p1 - p0
			var nn := Vector2(t.y, -t.x).normalized()
			var out := Vector3(nn.x * cos(am), nn.y, nn.x * sin(am))
			var A := Vector3(p0.x * cos(a0), p0.y, p0.x * sin(a0))
			var B := Vector3(p0.x * cos(a1), p0.y, p0.x * sin(a1))
			var C := Vector3(p1.x * cos(a1), p1.y, p1.x * sin(a1))
			var D := Vector3(p1.x * cos(a0), p1.y, p1.x * sin(a0))
			var u0 := float(i) / seg * uvs.x
			var u1 := float(i + 1) / seg * uvs.x
			var v0: float = float(acc[j]) * uvs.y
			var v1: float = float(acc[j + 1]) * uvs.y
			tri(st, A, Vector2(u0, v0), B, Vector2(u1, v0), C, Vector2(u1, v1), out, 1)
			tri(st, A, Vector2(u0, v0), C, Vector2(u1, v1), D, Vector2(u0, v1), out, 1)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


func extrude(pts: PackedVector2Array, depth: float) -> ArrayMesh:
	# 2D-Umriss (x,y) mit Tiefe in z, zentriert
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx := Geometry2D.triangulate_polygon(pts)
	var cen := Vector2.ZERO
	for p in pts:
		cen += p
	cen /= pts.size()
	var z1 := depth * 0.5
	var z0 := -depth * 0.5
	for k in range(0, idx.size(), 3):
		var a := pts[idx[k]]
		var b := pts[idx[k + 1]]
		var c := pts[idx[k + 2]]
		tri(st, Vector3(a.x, a.y, z1), a * 0.5, Vector3(b.x, b.y, z1), b * 0.5, Vector3(c.x, c.y, z1), c * 0.5, Vector3(0, 0, 1), -1)
		tri(st, Vector3(a.x, a.y, z0), a * 0.5, Vector3(b.x, b.y, z0), b * 0.5, Vector3(c.x, c.y, z0), c * 0.5, Vector3(0, 0, -1), -1)
	for i in pts.size():
		var p := pts[i]
		var q := pts[(i + 1) % pts.size()]
		var e := q - p
		var nrm := Vector2(e.y, -e.x)
		if nrm.dot((p + q) * 0.5 - cen) < 0.0:
			nrm = -nrm
		quad(st, Vector3(p.x, p.y, z1), Vector3(q.x, q.y, z1), Vector3(q.x, q.y, z0), Vector3(p.x, p.y, z0), Vector3(nrm.x, nrm.y, 0), -1)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


func arch_pts(w: float, h1: float) -> PackedVector2Array:
	var half := w * 0.5
	var pts := PackedVector2Array([Vector2(-half, 0), Vector2(half, 0)])
	var n := 9
	for k in n + 1:
		var a := deg_to_rad(60.0 * k / n)
		pts.append(Vector2(-half + w * cos(a), h1 + w * sin(a)))
	for k in range(n - 1, -1, -1):
		var a := deg_to_rad(60.0 * k / n)
		pts.append(Vector2(half - w * cos(a), h1 + w * sin(a)))
	return pts


func hull(length: float, wid: float, hgt: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nu := 20
	var nv := 14
	var P: Array = []
	for i in nu + 1:
		var u := -1.0 + 2.0 * i / nu
		var s := pow(maxf(1.0 - u * u, 0.0), 0.55)
		var row: Array = []
		for j in nv + 1:
			var a := PI * j / nv
			row.append(Vector3(u * length * 0.5, hgt * s * sin(a) + hgt * 0.6 * pow(absf(u), 4.0), wid * 0.5 * s * cos(a)))
		P.append(row)
	for i in nu:
		for j in nv:
			var a: Vector3 = P[i][j]
			var b: Vector3 = P[i + 1][j]
			var c: Vector3 = P[i + 1][j + 1]
			var d: Vector3 = P[i][j + 1]
			var am := PI * (j + 0.5) / nv
			var out := Vector3(0, sin(am), cos(am))
			var u0 := float(j) / nv * 2.0
			var u1 := float(j + 1) / nv * 2.0
			var v0 := float(i) / nu * 3.0
			var v1 := float(i + 1) / nu * 3.0
			tri(st, a, Vector2(u0, v0), b, Vector2(u0, v1), c, Vector2(u1, v1), out, 1)
			tri(st, a, Vector2(u0, v0), c, Vector2(u1, v1), d, Vector2(u1, v0), out, 1)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


# ------------------------------------------------------------ Gelaende
func gh(x: float, z: float) -> float:
	var h := BASE_H + nh.get_noise_2d(x * 0.55, z * 0.55) * 0.55
	for p in pads:
		var d := Vector2(x - p[0], z - p[1]).length()
		var w := 1.0 - smoothstep(p[2], p[2] + 2.5, d)
		h = lerpf(h, BASE_H, w)
	var dl := Vector2(x - LAKE.x, z - LAKE.y).length()
	h -= (1.0 - smoothstep(LAKE_R - 3.8, LAKE_R + 3.0, dl)) * 2.5
	return h


func dseg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return (p - (a + ab * t)).length()


func path_dist(x: float, z: float) -> float:
	var d := 1e9
	var p := Vector2(x, z)
	for s in segs:
		d = minf(d, dseg(p, s[0], s[1]))
	return d


func ground() -> void:
	var half := 36.0
	var step := 0.25
	var n := int(half * 2.0 / step) + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	verts.resize(n * n)
	norms.resize(n * n)
	cols.resize(n * n)
	var e := 0.2
	for j in n:
		for i in n:
			var x := -half + i * step
			var z := -half + j * step
			verts[j * n + i] = Vector3(x, gh(x, z), z)
			var dx := (gh(x + e, z) - gh(x - e, z)) / (2.0 * e)
			var dz := (gh(x, z + e) - gh(x, z - e)) / (2.0 * e)
			norms[j * n + i] = Vector3(-dx, 1.0, -dz).normalized()
			var m := nh.get_noise_2d(x * 0.1 + 40.0, z * 0.1)
			var tint := Color(1.0 + m * 0.22, 1.0 + m * 0.08, 1.0 - m * 0.22)
			var jit := nh.get_noise_2d(x * 1.5, z * 1.5) * 0.3
			tint.a = 1.0 - smoothstep(0.75, 1.35, path_dist(x, z) + jit)
			cols[j * n + i] = tint
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			idx.append_array([a, a + 1, a + n + 1, a, a + n + 1, a + n])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform sampler2D grass_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D path_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D sand_tex : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 uv = wpos.xz * 0.16;
	vec3 g = mix(texture(grass_tex, uv).rgb, texture(grass_tex, uv * 0.23 + 0.37).rgb, 0.5);
	vec3 p = texture(path_tex, wpos.xz * 0.22).rgb;
	vec3 s = texture(sand_tex, uv).rgb;
	float pm = smoothstep(0.42, 0.58, COLOR.a + (g.g - 0.55) * 0.3);
	vec3 col = mix(g * COLOR.rgb, p, pm);
	float sm = 1.0 - smoothstep(-0.38, -0.12, wpos.y + (g.r - 0.3) * 0.25);
	col = mix(col, s, sm);
	col *= mix(1.0, 0.6, 1.0 - smoothstep(-1.5, -0.55, wpos.y));
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	sm.set_shader_parameter("grass_tex", tex("grass")["a"])
	sm.set_shader_parameter("path_tex", tex("cobble")["a"])
	sm.set_shader_parameter("sand_tex", tex("sand")["a"])
	var g := MeshInstance3D.new()
	g.mesh = am
	g.material_override = sm
	world.add_child(g)
	var pl := PlaneMesh.new()
	pl.size = Vector2(80, 80)
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.2, 0.62, 0.72, 0.8)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.06
	wm.metallic = 0.25
	wm.metallic_specular = 0.9
	mi(world, pl, wm, Vector3(0, -0.6, 0), Vector3.ZERO, false)


func tufts() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 4:
		var c := CylinderMesh.new()
		c.top_radius = 0.0
		c.bottom_radius = 0.07
		c.height = 0.4
		c.radial_segments = 4
		c.rings = 1
		var tf := Transform3D(Basis.from_euler(Vector3(deg_to_rad(-16.0 + k * 10.0), k * 1.7, deg_to_rad(12.0 - k * 7.0))), Vector3(0, 0.18, 0))
		st.append_from(c, 0, tf)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = st.commit()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var xf: Array = []
	var cl: Array = []
	var fxf: Array = []
	var fcl: Array = []
	var gcols := [Color("#3a8a4e"), Color("#4fa05a"), Color("#6cba62"), Color("#2f7a4c"), Color("#8ad070")]
	var fcols := [Color("#fff4e0"), Color("#ffd84a"), Color("#ff8ab4"), Color("#a8c4ff"), Color("#d6a8ff")]
	for k in 4200:
		var x := rng.randf_range(-32.0, 32.0)
		var z := rng.randf_range(-32.0, 32.0)
		var y := gh(x, z)
		if y < -0.1 or path_dist(x, z) < 1.3:
			continue
		var blocked := false
		for p in pads:
			if Vector2(x - p[0], z - p[1]).length() < p[2] * 0.9:
				blocked = true
				break
		if blocked:
			continue
		var s := rng.randf_range(0.8, 1.6)
		xf.append(Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(s, s, s)), Vector3(x, y, z)))
		cl.append(gcols[rng.randi() % gcols.size()])
		if rng.randf() < 0.12:
			fxf.append(Transform3D(Basis.IDENTITY, Vector3(x, y + 0.36, z)))
			fcl.append(fcols[rng.randi() % fcols.size()])
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		mm.set_instance_color(i, cl[i])
	var gm := flat(Color.WHITE, 0.9, 0.0, false)
	gm.vertex_color_use_as_albedo = true
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = gm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mmi)
	var fm := MultiMesh.new()
	fm.transform_format = MultiMesh.TRANSFORM_3D
	fm.use_colors = true
	var sp := SphereMesh.new()
	sp.radius = 0.1
	sp.height = 0.2
	sp.radial_segments = 6
	sp.rings = 3
	fm.mesh = sp
	fm.instance_count = fxf.size()
	for i in fxf.size():
		fm.set_instance_transform(i, fxf[i])
		fm.set_instance_color(i, fcl[i])
	var fmi := MultiMeshInstance3D.new()
	fmi.multimesh = fm
	fmi.material_override = gm
	fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(fmi)


# ------------------------------------------------------------ Dach
func roof_pt(w: float, d: float, y0: float, rh: float, ov: float, sag: float, curl: float, u: float, v: float, side: float) -> Vector3:
	var x := (u - 0.5) * (w + 2.0 * ov)
	var zabs := lerpf(d * 0.5 + ov, 0.0, v)
	var y := y0 + (d * 0.5 - zabs) * (rh / (d * 0.5)) - sag * sin(PI * u) * v + curl * pow(1.0 - v, 4.0)
	return Vector3(x, y, side * zabs)


func roof(w: float, d: float, y0: float, rh: float, ov: float, sag: float, curl: float, thick: float, tile: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nu := 16
	var nv := 8
	var slope_len := sqrt(pow(d * 0.5 + ov, 2.0) + rh * rh)
	for si in 2:
		var side := 1.0 if si == 0 else -1.0
		var P: Array = []
		for i in nu + 1:
			var row: Array = []
			for j in nv + 1:
				row.append(roof_pt(w, d, y0, rh, ov, sag, curl, float(i) / nu, float(j) / nv, side))
			P.append(row)
		var low := Vector3(0, -thick, 0)
		var sgt := 1 + si
		var sgb := 3 + si
		var wu := (w + 2.0 * ov) / tile
		var sv := slope_len / tile
		for i in nu:
			for j in nv:
				var a: Vector3 = P[i][j]
				var b: Vector3 = P[i + 1][j]
				var c: Vector3 = P[i + 1][j + 1]
				var dd: Vector3 = P[i][j + 1]
				var ua := Vector2(float(i) / nu * wu, float(j) / nv * sv)
				var ub := Vector2(float(i + 1) / nu * wu, float(j) / nv * sv)
				var uc := Vector2(float(i + 1) / nu * wu, float(j + 1) / nv * sv)
				var ud := Vector2(float(i) / nu * wu, float(j + 1) / nv * sv)
				tri(st, a, ua, b, ub, c, uc, Vector3.UP, sgt)
				tri(st, a, ua, c, uc, dd, ud, Vector3.UP, sgt)
				tri(st, a + low, ua, b + low, ub, c + low, uc, Vector3.DOWN, sgb)
				tri(st, a + low, ua, c + low, uc, dd + low, ud, Vector3.DOWN, sgb)
		for i in nu:
			var a: Vector3 = P[i][0]
			var b: Vector3 = P[i + 1][0]
			quad(st, a, b, b + low, a + low, Vector3(0, 0, side), -1)
		for j in nv:
			var a: Vector3 = P[0][j]
			var b: Vector3 = P[0][j + 1]
			quad(st, a, b, b + low, a + low, Vector3(-1, 0, 0), -1)
			var c: Vector3 = P[nu][j]
			var dd: Vector3 = P[nu][j + 1]
			quad(st, c, dd, dd + low, c + low, Vector3(1, 0, 0), -1)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


func smoke(parent: Node3D, pos: Vector3, tint: Color = Color(0.97, 0.97, 1.0, 0.6)) -> void:
	var sm := StandardMaterial3D.new()
	sm.albedo_color = tint
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.roughness = 1.0
	for k in 4:
		ball(parent, 0.28 + k * 0.12, sm, pos + Vector3(0.14 * k, 0.5 + k * 0.7, 0.05 * k), 10, 6, false)


func glow_disc(parent: Node3D, r: float, c: Color, pos: Vector3, e: float = 1.8) -> void:
	cyl(parent, r, r, 0.08, flat(c, 0.3, e, false), pos, Vector3(90, 0, 0), 16)


func arch_win(parent: Node3D, w: float, h: float, pos: Vector3, c: Color, frame: Material) -> void:
	mi(parent, extrude(arch_pts(w + 0.3, h), 0.14), frame, pos + Vector3(0, -0.12, -0.02))
	mi(parent, extrude(arch_pts(w, h), 0.14), flat(c, 0.3, 1.8, false), pos + Vector3(0, 0, 0.03), Vector3.ZERO, false)


func spire_flag(parent: Node3D, pos: Vector3, c: Color) -> void:
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(1.0, -0.12), Vector2(0.75, -0.3), Vector2(1.0, -0.48), Vector2(0, -0.5)])
	mi(parent, extrude(pts, 0.05), flat(c, 0.6, 0.0, false), pos + Vector3(0.02, 0.0, 0.0), Vector3(0, 0, 0))


# ------------------------------------------------------------ HAUPTLAGER: gotisch-orientalische Maerchenhalle
func build_hq(pos: Vector3) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	world.add_child(g)
	var hall := Node3D.new()
	hall.rotation_degrees.y = -90.0
	g.add_child(hall)
	var wl := 8.6
	var dl := 6.0
	var h1 := 3.8
	var stone := mat("stone", Color(1.0, 0.96, 1.0), 0.26, 0.95, 1.0)
	var stone_d := mat("stone", Color(0.78, 0.74, 0.9), 0.26)
	var gold := flat(Color("#f0c24a"), 0.3)
	var wood := mat("plank", Color(0.6, 0.38, 0.28), 0.5)
	box(hall, Vector3(wl + 0.6, 1.0, dl + 0.6), stone_d, Vector3(0, 0.0, 0))
	box(hall, Vector3(wl, h1, dl), stone, Vector3(0, 0.5 + h1 * 0.5, 0))
	for x in [-3.2, -1.1, 1.1, 3.2]:
		for s in [-1.0, 1.0]:
			box(hall, Vector3(0.55, h1 + 0.5, 0.6), stone, Vector3(x, 0.5 + h1 * 0.5 - 0.1, s * (dl * 0.5 + 0.28)))
			box(hall, Vector3(0.7, 0.18, 0.75), stone_d, Vector3(x, 0.5 + h1 + 0.2, s * (dl * 0.5 + 0.28)))
			cyl(hall, 0.0, 0.3, 0.6, stone, Vector3(x, 0.5 + h1 + 0.6, s * (dl * 0.5 + 0.28)), Vector3.ZERO, 6)
	# Seitenfenster (spitzbogig, leuchtend)
	for x in [-2.2, 0.0, 2.2]:
		arch_win(hall, 0.9, 1.4, Vector3(x, 1.5, dl * 0.5 + 0.03), Color("#ffd27a"), stone_d)
		var b := Node3D.new()
		hall.add_child(b)
	var y0 := 0.5 + h1
	var rh := 4.4
	var rmat := mat("scale", Color(0.52, 0.58, 0.95), 1.0, 0.8, 1.0, false)
	mi(hall, roof(wl, dl, y0, rh, 0.6, 0.32, 0.3, 0.18, 1.0), rmat)
	var pr := PrismMesh.new()
	pr.size = Vector3(dl, rh * 0.7, wl - 0.1)
	mi(hall, pr, stone, Vector3(0, y0 + rh * 0.35, 0), Vector3(0, 90, 0))
	# Dachfirst: Zacken und Dachreiter
	for k in 9:
		var x := -wl * 0.5 - 0.3 + k * (wl + 0.6) / 8.0
		cyl(hall, 0.0, 0.2, 0.55, gold, Vector3(x, y0 + rh - 0.3 + 0.0, 0), Vector3.ZERO, 6)
	var cup := Node3D.new()
	cup.position = Vector3(-0.8, y0 + rh - 0.2, 0)
	hall.add_child(cup)
	cyl(cup, 0.5, 0.42, 0.9, stone, Vector3(0, 0.3, 0), Vector3.ZERO, 8)
	mi(cup, lathe([Vector2(0.62, 0.7), Vector2(0.7, 0.95), Vector2(0.45, 1.5), Vector2(0.12, 2.0), Vector2(0.0, 2.7)], 8), mat("scale", Color(0.3, 0.8, 0.8), 1.0, 0.7, 1.0, false), Vector3(0, 0.3, 0))
	ball(cup, 0.1, gold, Vector3(0, 3.05, 0), 8, 6, false)
	# Fassade (Giebel nach +x der Halle = Vorderseite)
	var fx := Node3D.new()
	fx.position = Vector3(wl * 0.5 + 0.02, 0, 0)
	fx.rotation_degrees.y = 90.0
	hall.add_child(fx)
	mi(fx, extrude(arch_pts(2.9, 2.2), 0.4), stone_d, Vector3(0, 0.45, 0.1))
	mi(fx, extrude(arch_pts(2.3, 2.0), 0.3), wood, Vector3(0, 0.5, 0.18))
	for k in 3:
		box(fx, Vector3(2.2, 0.1, 0.06), flat(Color(0.2, 0.18, 0.2), 0.5), Vector3(0, 0.9 + k * 0.8, 0.36))
	ball(fx, 0.09, gold, Vector3(-0.2, 1.6, 0.4), 8, 6, false)
	ball(fx, 0.09, gold, Vector3(0.2, 1.6, 0.4), 8, 6, false)
	for k in 3:
		box(fx, Vector3(3.6 - k * 0.5, 0.2, 0.7 - k * 0.12), stone_d, Vector3(0, 0.35 - k * 0.15 + 0.1, 0.35 + (3 - k) * 0.2 + 0.2 - 0.0))
	arch_win(fx, 0.8, 1.6, Vector3(-1.9, 1.8, 0.1), Color("#8fd8ff"), stone_d)
	arch_win(fx, 0.8, 1.6, Vector3(1.9, 1.8, 0.1), Color("#ffb4d8"), stone_d)
	var ry := y0 + 1.4
	torus(fx, 0.95, 0.12, stone_d, Vector3(0, ry, 0.1), Vector3(90, 0, 0))
	glow_disc(fx, 0.9, Color("#ffcf6a"), Vector3(0, ry, 0.08), 1.8)
	for k in 8:
		var a := k * 45.0
		box(fx, Vector3(0.07, 1.8, 0.06), stone_d, Vector3(0, ry, 0.15), Vector3(0, 0, a))
	for k in 6:
		var a := k * 60.0 + 15.0
		ball(fx, 0.12, flat(Color("#ff6aa8") if k % 2 == 0 else Color("#6ab8ff"), 0.4, 1.4, false), Vector3(cos(deg_to_rad(a)) * 0.55, ry + sin(deg_to_rad(a)) * 0.55, 0.16), 8, 5, false)
	cyl(fx, 0.04, 0.04, 2.2, gold, Vector3(0, y0 + rh * 0.45 + 1.0, 0.35), Vector3(0, 0, 90), 6)
	var bn := PackedVector2Array([Vector2(-0.55, 0), Vector2(0.55, 0), Vector2(0.55, -2.1), Vector2(0, -1.65), Vector2(-0.55, -2.1)])
	mi(fx, extrude(bn, 0.06), flat(Color("#d8344e"), 0.6, 0.0, false), Vector3(0, y0 + rh * 0.45 + 0.95, 0.4))
	ball(fx, 0.2, gold, Vector3(0, y0 + rh * 0.45 - 0.55, 0.45), 10, 6, false)
	# Tuerme: Zwiebelhaube und gedrehter Spitzhelm
	for ti in 2:
		var s := -1.0 if ti == 0 else 1.0
		var t := Node3D.new()
		t.position = Vector3(s * (dl * 0.5 + 0.15), 0, wl * 0.5 - 0.5)
		g.add_child(t)
		var r := 1.45
		cyl(t, r + 0.35, r + 0.3, 1.0, stone_d, Vector3(0, 0.0, 0), Vector3.ZERO, 16)
		cyl(t, r + 0.1, r, 6.4, stone, Vector3(0, 0.5 + 3.2, 0), Vector3.ZERO, 16)
		cyl(t, r + 0.4, r + 0.4, 0.3, stone_d, Vector3(0, 0.5 + 6.5, 0), Vector3.ZERO, 16)
		cyl(t, r * 0.82, r * 0.82, 1.8, stone, Vector3(0, 0.5 + 7.5, 0), Vector3.ZERO, 14)
		for k in 8:
			var a := k * 45.0
			box(t, Vector3(0.3, 0.3, 0.3), stone_d, Vector3(sin(deg_to_rad(a)) * (r + 0.4), 0.5 + 6.78, cos(deg_to_rad(a)) * (r + 0.4)))
		for q in [[0.0, 1.0], [90.0, 1.0]]:
			var a := deg_to_rad(float(q[0]) + 20.0)
			var tw := Node3D.new()
			tw.position = Vector3(sin(a) * (r * 0.82), 0, cos(a) * (r * 0.82))
			tw.rotation.y = a
			t.add_child(tw)
			arch_win(tw, 0.55, 0.9, Vector3(0, 0.5 + 7.1, 0.0), Color("#ffd27a"), stone_d)
		for q in 3:
			var a := deg_to_rad(q * 40.0 - 40.0 + 15.0)
			var tw := Node3D.new()
			tw.position = Vector3(sin(a) * (r + 0.1), 0, cos(a) * (r + 0.1))
			tw.rotation.y = a
			t.add_child(tw)
			box(tw, Vector3(0.18, 0.9, 0.1), flat(Color("#ffd27a"), 0.3, 1.6, false), Vector3(0, 2.0 + q * 1.4, 0.0))
		if ti == 0:
			mi(t, lathe([Vector2(1.5, 0.0), Vector2(1.75, 0.4), Vector2(1.85, 1.0), Vector2(1.6, 1.7), Vector2(1.0, 2.3), Vector2(0.45, 2.8), Vector2(0.14, 3.4), Vector2(0.06, 4.2)], 18), mat("scale", Color(0.25, 0.85, 0.78), 1.0, 0.65, 1.0, false), Vector3(0, 0.5 + 8.4, 0))
			ball(t, 0.2, gold, Vector3(0, 0.5 + 8.4 + 4.2, 0), 10, 6, false)
			cyl(t, 0.025, 0.025, 1.1, gold, Vector3(0, 0.5 + 8.4 + 4.7, 0), Vector3.ZERO, 6)
			spire_flag(t, Vector3(0, 0.5 + 8.4 + 5.0, 0), Color("#d8344e"))
		else:
			var prof: Array = []
			for k in 11:
				var f := k / 10.0
				prof.append(Vector2(1.7 * pow(1.0 - f, 1.1) + 0.04, 0.5 + 8.4 + f * 5.0 + sin(f * 9.0) * 0.12))
			mi(t, lathe(prof, 14), mat("scale", Color(0.95, 0.55, 0.75), 1.0, 0.65, 1.0, false), Vector3(0, 0, 0))
			ball(t, 0.16, gold, Vector3(0, 0.5 + 8.4 + 5.1, 0), 10, 6, false)
			spire_flag(t, Vector3(0, 0.5 + 8.4 + 5.3, 0), Color("#2f9ae8"))
	# Warenlager davor: Fass-, Kisten- und Saecke-Stapel
	var crate := mat("plank", Color(0.85, 0.68, 0.5), 0.5)
	var bx := Vector3(4.6, 0, 3.2)
	box(g, Vector3(1.0, 0.9, 1.0), crate, bx + Vector3(0, 0.45 + 0.3, 0), Vector3(0, 14, 0))
	box(g, Vector3(0.8, 0.75, 0.8), crate, bx + Vector3(0.1, 1.3 + 0.35, 0.05), Vector3(0, -8, 0))
	box(g, Vector3(0.9, 0.8, 0.9), crate, bx + Vector3(1.2, 0.4 + 0.3, 0.6), Vector3(0, 28, 0))
	for k in 3:
		var bp := bx + Vector3(-0.9 - k * 0.8, 0.0, 0.7 + (k % 2) * 0.5)
		var bb := cyl(g, 0.38, 0.38, 0.8, mat("plank", Color(0.75, 0.5, 0.34), 0.6), bp + Vector3(0, 0.7, 0))
		cyl(g, 0.4, 0.4, 0.07, flat(Color(0.35, 0.3, 0.38), 0.5), bp + Vector3(0, 0.45, 0))
		cyl(g, 0.4, 0.4, 0.07, flat(Color(0.35, 0.3, 0.38), 0.5), bp + Vector3(0, 0.95, 0))
	for k in 3:
		var sp := ball(g, 0.42, flat(Color("#f0e0b8"), 0.9), bx + Vector3(0.5 + k * 0.55, 0.65, 1.7), 12, 8)
		sp.scale = Vector3(1.0, 0.8, 0.85)
	return g


# ------------------------------------------------------------ BAECKEREI: Lebkuchen-Maerchenhaus
func build_bakery(pos: Vector3, yaw: float) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation_degrees.y = yaw
	world.add_child(g)
	var w := 5.0
	var d := 4.2
	var h1 := 2.2
	var h2 := 1.9
	var pink := mat("plaster", Color(1.0, 0.8, 0.86), 0.3, 0.95)
	var cream := mat("plaster", Color(1.0, 0.95, 0.82), 0.3, 0.95)
	var white := flat(Color("#fffaf0"), 0.55)
	var wood := mat("plank", Color(0.7, 0.45, 0.32), 0.5)
	box(g, Vector3(w + 0.3, 0.8, d + 0.3), cream, Vector3(0, 0.1, 0))
	box(g, Vector3(w, h1, d), pink, Vector3(0, 0.5 + h1 * 0.5, 0))
	var yu := 0.5 + h1
	var up := box(g, Vector3(w + 0.7, h2, d + 0.7), pink, Vector3(0, yu + h2 * 0.5 + 0.05, 0), Vector3(0, 2.0, 0))
	# Zuckerguss-Wellen am Obergeschoss-Fuss und Stangenzucker-Ecken
	for i in 14:
		var x := -(w + 0.7) * 0.5 + 0.2 + i * (w + 0.3) / 13.0
		var b1 := ball(g, 0.17, white, Vector3(x, yu + 0.02, (d + 0.7) * 0.5 + 0.02), 8, 6, false)
		b1.scale = Vector3(1.0, 0.8, 1.0)
	for k in 8:
		cyl(g, 0.15, 0.15, 0.3, flat(Color("#e8445c") if k % 2 == 0 else Color("#fffaf0"), 0.5), Vector3(-w * 0.5 + 0.0, 0.5 + 0.15 + k * 0.27, d * 0.5), Vector3.ZERO, 8)
		cyl(g, 0.15, 0.15, 0.3, flat(Color("#e8445c") if k % 2 == 0 else Color("#fffaf0"), 0.5), Vector3(w * 0.5, 0.5 + 0.15 + k * 0.27, d * 0.5), Vector3.ZERO, 8)
	# Dach: hoch, durchhaengend, Eckaufschwung wie ein Pagodendach
	var y0 := yu + h2 + 0.05
	var rh := 2.9
	var ov := 0.8
	var sag := 0.55
	var curl := 0.5
	var du := d + 0.7
	var wu := w + 0.7
	mi(g, roof(wu, du, y0, rh, ov, sag, curl, 0.22, 1.0), mat("scale", Color(0.86, 0.55, 0.34), 1.0, 0.7, 1.2, false))
	var pr := PrismMesh.new()
	pr.size = Vector3(du, rh * 0.66, wu - 0.1)
	mi(g, pr, pink, Vector3(0, y0 + rh * 0.33, 0), Vector3(0, 90, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 22:
		var u := (i + 0.5) / 22.0
		var p := roof_pt(wu, du, y0, rh, ov, sag, curl, u, 0.0, 1.0)
		var len := 0.22 + rng.randf() * 0.35
		var dr := cyl(g, 0.07, 0.07, len, white, p + Vector3(0, -0.22 - len * 0.5 + 0.1, 0.0), Vector3.ZERO, 8)
		ball(g, 0.075, white, p + Vector3(0, -0.22 - len + 0.1, 0.0), 8, 6, false)
	for i in 40:
		var p := roof_pt(wu, du, y0, rh, ov, sag, curl, rng.randf_range(0.05, 0.95), rng.randf_range(0.12, 0.85), 1.0)
		var cc := [Color("#ff5a7a"), Color("#ffd23a"), Color("#6ad8c8"), Color("#a07af0"), Color("#fffaf0"), Color("#ff9a3a")]
		var cd := cyl(g, 0.17, 0.17, 0.09, flat(cc[rng.randi() % 6], 0.4), p + Vector3(0, 0.07, 0.03), Vector3(40, rng.randf() * 90.0, 0), 10)
	for i in 14:
		var p := roof_pt(wu, du, y0, rh, ov, sag, curl, (i + 0.5) / 14.0, 1.0, 1.0)
		ball(g, 0.15, white, p + Vector3(0, 0.1, 0), 8, 6, false)
	# Dach-Windmuehle als Wetterfahne
	var wm := Node3D.new()
	wm.position = Vector3(-wu * 0.28, y0 + rh - 0.2, 0)
	g.add_child(wm)
	cyl(wm, 0.07, 0.07, 1.4, flat(Color("#8a5a3a"), 0.6), Vector3(0, 0.7, 0), Vector3.ZERO, 6)
	var hub := Node3D.new()
	hub.position = Vector3(0, 1.3, 0.15)
	hub.rotation_degrees.z = 20.0
	wm.add_child(hub)
	for k in 4:
		var arm := Node3D.new()
		arm.rotation_degrees.z = k * 90.0
		hub.add_child(arm)
		box(arm, Vector3(0.06, 1.8, 0.05), flat(Color("#8a5a3a"), 0.6), Vector3(0, 0.9, 0))
		box(arm, Vector3(0.4, 0.9, 0.03), flat(Color("#fffaf0"), 0.8, 0.0, false), Vector3(0.23, 1.1, 0))
	ball(hub, 0.1, flat(Color("#f0c24a"), 0.3), Vector3.ZERO, 8, 6, false)
	# Schaufenster mit Markise, Tuer, Brezel-Schild
	var zf := d * 0.5 + 0.03
	box(g, Vector3(2.0, 1.0, 0.1), flat(Color("#ffc870"), 0.3, 1.5, false), Vector3(-1.0, 1.55, zf))
	box(g, Vector3(2.2, 0.12, 0.2), wood, Vector3(-1.0, 1.0, zf + 0.1))
	for k in 5:
		box(g, Vector3(0.28, 0.18, 0.12), flat(Color("#d8a060"), 0.7), Vector3(-1.8 + k * 0.4, 1.12, zf + 0.12))
	for k in 8:
		var cc := Color("#e8445c") if k % 2 == 0 else Color("#fffaf0")
		box(g, Vector3(0.3, 0.06, 1.15), flat(cc, 0.6), Vector3(-2.0 + k * 0.28, 2.38 - 0.0, zf + 0.5), Vector3(28, 0, 0))
	box(g, Vector3(1.0, 1.6, 0.1), mat("plank", Color(0.55, 0.3, 0.2), 0.7), Vector3(1.4, 0.5 + 0.8, zf))
	cyl(g, 0.5, 0.5, 0.1, mat("plank", Color(0.55, 0.3, 0.2), 0.7), Vector3(1.4, 0.5 + 1.6, zf), Vector3(90, 0, 0), 14)
	ball(g, 0.06, flat(Color("#f0c24a"), 0.3), Vector3(1.7, 1.3, zf + 0.08), 6, 4, false)
	box(g, Vector3(1.4, 0.15, 0.5), cream, Vector3(1.4, 0.5, zf + 0.3))
	var sign := Node3D.new()
	sign.position = Vector3(2.55, 1.9, zf + 0.9)
	g.add_child(sign)
	box(sign, Vector3(0.06, 0.06, 0.9), wood, Vector3(0, 0.6, -0.4))
	torus(sign, 0.36, 0.09, flat(Color("#c8803a"), 0.5), Vector3(0, 0.1, 0.1), Vector3(90, 0, 0))
	box(sign, Vector3(0.04, 0.5, 0.04), flat(Color("#6a4020"), 0.6), Vector3(0.0, 0.4, 0.1))
	ball(sign, 0.28, flat(Color("#c8803a"), 0.5), Vector3(0.0, 0.1, 0.1), 10, 6, false).scale = Vector3(1.4, 0.2, 0.9)
	window(g, Vector3(-1.1, yu + 0.1 + h2 * 0.5, (d + 0.7) * 0.5 + 0.04), 0.0, Color("#6ad8c8"), true)
	window(g, Vector3(1.1, yu + 0.1 + h2 * 0.5, (d + 0.7) * 0.5 + 0.04), 0.0, Color("#ff7a9a"), false)
	window(g, Vector3(w * 0.5 + 0.04 + 0.35, yu + 0.15 + h2 * 0.5, 0.0), 90.0, Color("#6ad8c8"), false)
	# Backofen-Kuppel mit Glut und Kamin
	var ov_pos := Vector3(w * 0.5 + 1.7, 0.45, 0.2)
	mi(g, lathe([Vector2(1.4, 0.0), Vector2(1.6, 0.45), Vector2(1.55, 1.0), Vector2(1.2, 1.6), Vector2(0.7, 2.0), Vector2(0.3, 2.2), Vector2(0.0, 2.25)], 18), mat("plaster", Color(1.0, 0.65, 0.42), 0.3, 0.9), ov_pos)
	mi(g, extrude(arch_pts(0.9, 0.5), 0.2), flat(Color("#2a1810"), 0.6, 0.0, false), ov_pos + Vector3(0, 0.15, 1.45))
	mi(g, extrude(arch_pts(0.65, 0.4), 0.1), flat(Color("#ff8a2a"), 0.3, 2.4, false), ov_pos + Vector3(0, 0.2, 1.52), Vector3.ZERO, false)
	cyl(g, 0.3, 0.3, 2.6, mat("stone", Color(1.0, 0.85, 0.75), 0.4), ov_pos + Vector3(0.0, 2.9, -0.2), Vector3.ZERO, 10)
	cyl(g, 0.42, 0.42, 0.2, mat("stone", Color(0.8, 0.7, 0.7), 0.4), ov_pos + Vector3(0.0, 4.2, -0.2), Vector3.ZERO, 10)
	var gp := Node3D.new()
	gp.position = ov_pos + Vector3(0, 3.9, -0.2)
	g.add_child(gp)
	smoke(gp, Vector3.ZERO, Color(1.0, 0.97, 0.92, 0.6))
	# Brotkoerbe und Mehlsaecke
	for k in 3:
		var sp := ball(g, 0.38, flat(Color("#fff3d6"), 0.9), Vector3(-w * 0.5 - 0.7, 0.45 + 0.0, 0.7 + k * 0.7), 12, 8)
		sp.scale = Vector3(1.0, 0.85, 0.85)
	var bk := cyl(g, 0.5, 0.42, 0.45, mat("plank", Color(0.85, 0.6, 0.4), 0.4), Vector3(-w * 0.5 + 0.1, 0.5 + 0.22, d * 0.5 + 0.9), Vector3.ZERO, 12)
	for k in 5:
		cyl(g, 0.07, 0.07, 0.9, flat(Color("#d8a05a"), 0.6), Vector3(-w * 0.5 + 0.1 + (k - 2) * 0.12, 0.5 + 0.7, d * 0.5 + 0.9), Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-14, 14)), 8)
	return g


# ------------------------------------------------------------ HOLZFAELLER: nordisches Blockhaus mit Grasdach
func build_lumber(pos: Vector3, yaw: float) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation_degrees.y = yaw
	world.add_child(g)
	var wl := 6.6
	var dl := 4.8
	var rows := 8
	var lg := mat("bark", Color(1.0, 0.72, 0.45), 1.0, 0.85, 1.0, false)
	lg.uv1_scale = Vector3(2.0, 1.6, 1.0)
	var dark := flat(Color(0.2, 0.12, 0.1), 0.8)
	box(g, Vector3(wl + 0.5, 0.5, dl + 0.5), mat("stone", Color(0.8, 0.82, 0.78), 0.3), Vector3(0, 0.05, 0))
	box(g, Vector3(wl - 0.3, rows * 0.31, dl - 0.3), dark, Vector3(0, 0.3 + rows * 0.155, 0))
	for r in rows:
		var y := 0.42 + r * 0.31
		for s in [-1.0, 1.0]:
			cyl(g, 0.17, 0.17, wl + 0.8, lg, Vector3(0, y, s * dl * 0.5), Vector3(0, 0, 90), 10)
			cyl(g, 0.17, 0.17, dl + 0.8, lg, Vector3(s * wl * 0.5, y + 0.155, 0), Vector3(90, 0, 0), 10)
	var y0 := 0.42 + rows * 0.31 + 0.1
	var rh := 2.2
	var ov := 0.9
	var gm := mat("grass", Color(0.85, 1.05, 0.7), 1.0, 0.95, 1.0, false, true)
	mi(g, roof(wl, dl, y0, rh, ov, 0.4, 0.0, 0.42, 3.0), gm)
	var pr := PrismMesh.new()
	pr.size = Vector3(dl, rh * 0.62, wl - 0.1)
	var plk := mat("plank", Color(0.9, 0.62, 0.42), 0.5)
	mi(g, pr, plk, Vector3(0, y0 + rh * 0.31, 0), Vector3(0, 90, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var fcols := [Color("#fff4e0"), Color("#ffd84a"), Color("#ff6a9a"), Color("#b08aff"), Color("#ff9a4a")]
	for i in 60:
		var side := 1.0 if rng.randf() < 0.65 else -1.0
		var p := roof_pt(wl, dl, y0, rh, ov, 0.4, 0.0, rng.randf_range(0.03, 0.97), rng.randf_range(0.02, 0.98), side)
		var k := rng.randi() % 5
		if k < 3:
			ball(g, rng.randf_range(0.09, 0.15), flat(fcols[rng.randi() % 5], 0.6, 0.0, false), p + Vector3(0, 0.12, 0), 6, 4, false)
		else:
			var tc := cyl(g, 0.0, 0.12, 0.4, flat(Color("#4fa05a"), 0.8, 0.0, false), p + Vector3(0, 0.18, 0), Vector3(rng.randf_range(-15, 15), 0, rng.randf_range(-15, 15)), 5)
	# Kreuzbalken (Drachenhoerner) an beiden Giebeln
	for s in [-1.0, 1.0]:
		var gx: float = s * (wl * 0.5 + ov + 0.06)
		for a in [-50.0, 50.0]:
			var bm := box(g, Vector3(0.14, 3.6, 0.2), lg, Vector3(gx, y0 + rh * 0.78, 0), Vector3(a, 0, 0))
			cyl(g, 0.0, 0.17, 0.5, lg, Vector3(gx, y0 + rh * 0.78 + cos(deg_to_rad(a)) * 1.8, sin(deg_to_rad(-a)) * 1.8), Vector3(a * -1.0 * 0.0, 0, 0), 8)
		ball(g, 0.14, flat(Color("#e8c050"), 0.4), Vector3(gx, y0 + rh * 0.78, 0), 8, 6, false)
	# Tuer mit Vordach und geschnitzten Pfosten
	var zf := dl * 0.5 + 0.17
	box(g, Vector3(1.3, 2.0, 0.12), mat("plank", Color(0.55, 0.32, 0.2), 0.7), Vector3(-0.6, 0.42 + 1.0, zf))
	box(g, Vector3(0.1, 0.3, 0.14), flat(Color(0.2, 0.2, 0.22), 0.4), Vector3(-1.0, 1.7, zf + 0.05))
	box(g, Vector3(0.1, 0.3, 0.14), flat(Color(0.2, 0.2, 0.22), 0.4), Vector3(-1.0, 0.9, zf + 0.05))
	box(g, Vector3(2.6, 0.18, 1.4), plk, Vector3(-0.6, 2.7, zf + 0.6), Vector3(-10, 0, 0))
	for sx in [-1.7, 0.5]:
		cyl(g, 0.12, 0.12, 2.3, lg, Vector3(sx, 1.55, zf + 1.1), Vector3.ZERO, 8)
		ball(g, 0.15, flat(Color("#c85a3a"), 0.6), Vector3(sx, 2.8, zf + 1.1), 8, 6, false)
	ball(g, 0.11, flat(Color(1.0, 0.8, 0.4), 0.3, 2.2, false), Vector3(-0.6, 2.35, zf + 1.3), 8, 6, false)
	# Rundfenster (Giebel +x) und Fenster vorn
	var sw := Node3D.new()
	sw.position = Vector3(wl * 0.5 + 0.2, y0 + rh * 0.3, 0)
	sw.rotation_degrees.y = 90.0
	g.add_child(sw)
	torus(sw, 0.5, 0.09, lg, Vector3(0, 0, 0.08), Vector3(90, 0, 0))
	glow_disc(sw, 0.5, Color("#ffd27a"), Vector3(0, 0, 0.06), 1.8)
	window(g, Vector3(1.6, 1.75, zf + 0.02), 0.0, Color("#c85a3a"), true)
	# Schornstein aus Fels mit Grasmuetze
	var ch := Node3D.new()
	ch.position = Vector3(-wl * 0.25, y0 + rh * 0.55, -dl * 0.12)
	g.add_child(ch)
	box(ch, Vector3(0.8, 2.2, 0.8), mat("stone", Color(0.85, 0.82, 0.78), 0.4), Vector3(0, 0.5, 0))
	box(ch, Vector3(1.0, 0.2, 1.0), gm, Vector3(0, 1.7, 0))
	smoke(ch, Vector3(0, 1.8, 0))
	# Werkzeug und Holz: Hackklotz mit Axt, Holzstapel, Saegebock, Totem
	var wood := mat("bark", Color(1.0, 0.75, 0.5), 1.0, 0.85, 1.0, false)
	wood.uv1_scale = Vector3(2, 1, 1)
	cyl(g, 0.45, 0.5, 0.65, wood, Vector3(-3.4, 0.45 + 0.0, zf + 1.4), Vector3.ZERO, 14)
	var axe := Node3D.new()
	axe.position = Vector3(-3.4, 0.9, zf + 1.4)
	axe.rotation_degrees = Vector3(0, 20, -28)
	g.add_child(axe)
	box(axe, Vector3(0.07, 1.0, 0.07), flat(Color("#8a5a3a"), 0.6), Vector3(0, 0.45, 0))
	box(axe, Vector3(0.45, 0.28, 0.06), flat(Color("#aab0c0"), 0.3), Vector3(0.18, 0.88, 0))
	for lvl in 4:
		for k in 4 - lvl:
			cyl(g, 0.24, 0.24, 2.2, lg, Vector3(-wl * 0.5 - 1.3 - lvl * 0.4, 0.25 + 0.2 + lvl * 0.42, -1.2 + k * 0.5 + lvl * 0.25 + 0.4), Vector3(90, 0, 0), 10)
	cyl(g, 0.3, 0.3, 2.6, lg, Vector3(wl * 0.5 + 2.2, 0.35, 1.4), Vector3(0, 70, 90), 10)
	for k in 5:
		box(g, Vector3(1.6, 0.1, 0.35), plk, Vector3(wl * 0.5 + 1.8, 0.2 + k * 0.1, -1.6), Vector3(0, 6.0 * k, 0))
	var tm := Node3D.new()
	tm.position = Vector3(wl * 0.5 + 2.6, 0, 3.0)
	tm.rotation_degrees.y = -20.0
	g.add_child(tm)
	var tcols := [Color("#d8443a"), Color("#3a9ad8"), Color("#f0c24a"), Color("#4fa05a")]
	for k in 4:
		cyl(tm, 0.34, 0.34, 0.62, flat(tcols[k], 0.6), Vector3(0, 0.6 + k * 0.6, 0), Vector3.ZERO, 10)
		for e in [-1.0, 1.0]:
			ball(tm, 0.08, flat(Color.WHITE, 0.4, 0.0, false), Vector3(e * 0.14, 0.7 + k * 0.6, 0.31), 6, 4, false)
		cyl(tm, 0.0, 0.1, 0.28, flat(Color("#f0a030"), 0.5), Vector3(0, 0.6 + k * 0.6 - 0.08, 0.38), Vector3(90, 0, 0), 6)
	box(tm, Vector3(1.5, 0.12, 0.1), flat(tcols[1], 0.6), Vector3(0, 2.2, -0.1))
	return g


# ------------------------------------------------------------ FISCHER: Stelzenhuette mit umgedrehtem Boot als Dach
func build_fisher(pos: Vector3, yaw: float) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation_degrees.y = yaw
	world.add_child(g)
	var plk := mat("plank_h", Color(0.7, 0.88, 0.9), 0.5, 0.8)
	var deck := mat("plank_h", Color(0.9, 0.78, 0.62), 0.5, 0.85)
	var post := mat("bark", Color(0.65, 0.5, 0.4), 1.0, 0.9, 1.0, false)
	post.uv1_scale = Vector3(1, 3, 1)
	for x in [-2.6, -0.8, 1.0, 2.8]:
		for z in [-2.0, 2.0]:
			cyl(g, 0.17, 0.2, 3.4, post, Vector3(x, -1.5, z), Vector3.ZERO, 8)
	box(g, Vector3(6.4, 0.22, 4.8), deck, Vector3(0, 0.11, 0))
	# Huette
	var hp := Vector3(-0.8, 0.22 + 1.1, -0.2)
	box(g, Vector3(3.6, 2.2, 3.0), plk, hp)
	# Bootsdach (Kiel nach oben, Bug und Heck ragen hoch)
	var rm := hull(6.0, 4.6, 2.6)
	var bm := mat("plank", Color(0.95, 0.42, 0.34), 0.9, 0.7, 1.0, false)
	bm.uv1_scale = Vector3(1.0, 1.0, 1.0)
	mi(g, rm, bm, Vector3(-0.8, hp.y + 1.0, -0.2))
	for k in 5:
		var xx := -2.6 + k * 1.2
		var s := pow(maxf(1.0 - pow((xx + 0.8) / 3.0, 2.0), 0.0), 0.55)
		box(g, Vector3(0.12, 0.1, 4.6 * s * 0.98), flat(Color("#fff0d8"), 0.6), Vector3(xx, hp.y + 1.0 + 2.6 * s * 0.5 + 0.0, -0.2), Vector3(0, 0, 0)).scale = Vector3(1, 1, 0.01)
	box(g, Vector3(5.8, 0.14, 0.14), flat(Color("#fff0d8"), 0.6), Vector3(-0.8, hp.y + 1.0 + 2.62, -0.2))
	cyl(g, 0.04, 0.04, 1.6, flat(Color("#6a4a30"), 0.6), Vector3(-0.8, hp.y + 1.0 + 3.2, -0.2), Vector3.ZERO, 6)
	spire_flag(g, Vector3(-0.8, hp.y + 1.0 + 3.9, -0.2), Color("#3a9ad8"))
	# Bullaugen
	var fz := hp.z + 1.5 + 0.05
	for px in [-1.6, 0.1]:
		torus(g, 0.38, 0.08, flat(Color("#c8a050"), 0.35), Vector3(px, 1.5, fz + 0.02), Vector3(90, 0, 0))
		glow_disc(g, 0.38, Color("#ffd27a"), Vector3(px, 1.5, fz), 1.8)
	box(g, Vector3(0.9, 1.6, 0.1), mat("plank", Color(0.55, 0.32, 0.2), 0.7), Vector3(-0.8 + 1.1, 0.22 + 0.8, fz))
	ball(g, 0.06, flat(Color("#f0c24a"), 0.3), Vector3(-0.8 + 1.4, 1.0, fz + 0.08), 6, 4, false)
	for k in 3:
		ball(g, 0.2, flat(Color("#e8445c") if k % 2 == 0 else Color("#fffaf0"), 0.5), Vector3(-2.4 + k * 0.3, 1.9 - 0.0, fz + 0.15), 10, 6, false)
	# Steg ins Wasser
	var pk := mat("plank_h", Color(0.85, 0.72, 0.58), 0.5)
	box(g, Vector3(8.0, 0.18, 1.7), pk, Vector3(3.2 + 4.0, 0.0, 0.4))
	for k in 6:
		var x := 3.6 + k * 1.4
		for s in [-1.0, 1.0]:
			cyl(g, 0.13, 0.15, 2.6, post, Vector3(x, -1.0, 0.4 + s * 0.8), Vector3.ZERO, 8)
	cyl(g, 0.1, 0.1, 1.6, post, Vector3(10.9, 0.7, 0.4 - 0.7), Vector3.ZERO, 8)
	ball(g, 0.2, flat(Color(1.0, 0.8, 0.4), 0.3, 2.4, false), Vector3(10.9, 1.7, -0.3), 10, 6, false)
	# Trockengestell mit Fischen, Bojen, Reusen
	var rk := Vector3(2.0, 0.22, 2.3)
	for s in [-1.0, 1.0]:
		cyl(g, 0.06, 0.06, 2.0, post, rk + Vector3(s * 0.9, 1.0, 0), Vector3(0, 0, s * -8.0), 6)
	cyl(g, 0.05, 0.05, 2.0, post, rk + Vector3(0, 1.95, 0), Vector3(0, 0, 90), 6)
	for k in 7:
		var fx := rk.x - 0.75 + k * 0.25
		box(g, Vector3(0.012, 0.3, 0.012), flat(Color(0.3, 0.3, 0.3), 0.5, 0.0, false), Vector3(fx, 1.78, rk.z))
		var fsh := ball(g, 0.1, flat(Color("#b8d8ee"), 0.25), Vector3(fx, 1.45, rk.z), 8, 6, false)
		fsh.scale = Vector3(0.45, 1.8, 0.7)
		cyl(g, 0.0, 0.09, 0.14, flat(Color("#8ab8de"), 0.4), Vector3(fx, 1.2, rk.z), Vector3.ZERO, 4)
	for k in 3:
		ball(g, 0.3, flat(Color("#e8445c") if k % 2 == 0 else Color("#fffaf0"), 0.5), Vector3(-2.7 + k * 0.7, 0.55, 2.55), 12, 8)
	for k in 2:
		var rp := cyl(g, 0.4, 0.34, 0.7, mat("plank", Color(0.9, 0.75, 0.5), 0.6), Vector3(2.6, 0.55 + k * 0.7 * 0.0, -1.1 + k * 0.95), Vector3.ZERO, 10)
		ball(g, 0.4, mat("plank", Color(0.9, 0.75, 0.5), 0.6), Vector3(2.6, 0.9, -1.1 + k * 0.95), 10, 6, false).scale = Vector3(1, 0.7, 1)
	# Ruderboot am Steg
	var bt := mi(g, hull(2.8, 1.3, 0.75), mat("plank", Color(0.35, 0.62, 0.9), 0.8, 0.7, 1.0, false), Vector3(8.0, -0.3, 2.3), Vector3(180, 12, 0))
	box(g, Vector3(2.0, 0.05, 0.9), mat("plank_h", Color(0.9, 0.75, 0.55), 0.5), Vector3(8.0, -0.32, 2.3), Vector3(0, 12, 0))
	# Moewen
	for k in 2:
		var gp := Vector3(10.9 - k * 5.0, 1.45 + k * 0.0, -0.3 + k * 1.1)
		if k == 1:
			gp = Vector3(-3.1, 0.22 + 0.2, 2.2)
		var bd := ball(g, 0.24, flat(Color("#fffaf0"), 0.6), gp + Vector3(0, 0.25 if k == 0 else 0.0, 0), 10, 8, false)
		bd.scale = Vector3(1.2, 0.9, 0.8)
		ball(g, 0.14, flat(Color("#fffaf0"), 0.6), gp + Vector3(0.22, 0.22 + (0.25 if k == 0 else 0.0), 0), 8, 6, false)
		cyl(g, 0.0, 0.05, 0.14, flat(Color("#f0a030"), 0.5), gp + Vector3(0.38, 0.2 + (0.25 if k == 0 else 0.0), 0), Vector3(0, 0, -90), 5)
	return g


# ------------------------------------------------------------ Natur
func oak(pos: Vector3, s: float, seed: int) -> void:
	var t := Node3D.new()
	t.position = pos
	t.scale = Vector3(s, s, s)
	t.rotation.y = seed * 0.9
	world.add_child(t)
	var bark := mat("bark", Color(1, 0.9, 0.85), 0.7)
	cyl(t, 0.55, 0.3, 2.6, bark, Vector3(0, 1.3, 0), Vector3(0, 0, 5.0), 10)
	cyl(t, 0.85, 0.55, 0.5, bark, Vector3(0, 0.2, 0), Vector3.ZERO, 10)
	cyl(t, 0.14, 0.2, 1.8, bark, Vector3(-0.65, 2.9, 0.1), Vector3(0, 0, 38), 8)
	cyl(t, 0.14, 0.2, 1.7, bark, Vector3(0.65, 3.0, -0.1), Vector3(0, 0, -36), 8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var big := [[0.0, 3.9, 0.0, 1.85], [-1.4, 3.3, 0.3, 1.3], [1.5, 3.4, -0.2, 1.35], [0.2, 3.2, 1.3, 1.25], [-0.3, 5.0, -0.2, 1.25], [1.0, 4.6, 0.7, 1.05], [-0.9, 4.4, 0.9, 1.05]]
	var lm := mat("leaf", Color(0.7, 0.9, 0.7), 1.2, 0.85)
	for b in big:
		ball(t, b[3], lm, Vector3(b[0], b[1], b[2]), 14, 8)
	var cm := {}
	for k in 80:
		var b: Array = big[rng.randi() % big.size()]
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.35, 1.0), rng.randf_range(-1, 1)).normalized()
		var wd := dir.rotated(Vector3.UP, t.rotation.y)
		var l := clampf(wd.dot(sun_dir) * 0.7 + 0.45 + rng.randf_range(-0.12, 0.12), 0.0, 1.0)
		var c := Color("#2c7a5a").lerp(Color("#d4f58a"), l)
		var key := "c%d" % int(l * 8.0)
		if not cm.has(key):
			cm[key] = flat(c, 0.8)
		var p: Vector3 = Vector3(b[0], b[1], b[2]) + dir * float(b[3]) * 0.92
		ball(t, rng.randf_range(0.4, 0.7), cm[key], p, 10, 6, false)


func pine(pos: Vector3, s: float, seed: int) -> void:
	var t := Node3D.new()
	t.position = pos
	t.scale = Vector3(s, s, s)
	t.rotation.y = seed * 1.3
	world.add_child(t)
	cyl(t, 0.32, 0.22, 2.0, mat("bark", Color(0.9, 0.8, 0.8), 0.7), Vector3(0, 1.0, 0), Vector3.ZERO, 8)
	var lm := mat("leaf", Color(0.5, 0.78, 0.8), 1.4, 0.85)
	for k in 6:
		var c := CylinderMesh.new()
		c.top_radius = 0.0
		c.bottom_radius = 1.75 - k * 0.27
		c.height = 1.7
		c.radial_segments = 10
		c.rings = 1
		mi(t, c, lm, Vector3(0, 1.5 + k * 0.95, 0), Vector3(0, k * 31.0, 0))


func shroom(pos: Vector3, s: float, cap: Color) -> void:
	var t := Node3D.new()
	t.position = pos
	t.scale = Vector3(s, s, s)
	world.add_child(t)
	cyl(t, 0.2, 0.28, 1.2, flat(Color("#f6ecd6"), 0.8), Vector3(0, 0.6, 0), Vector3.ZERO, 10)
	var c := ball(t, 0.9, flat(cap, 0.55), Vector3(0, 1.3, 0), 14, 8)
	c.scale = Vector3(1.0, 0.6, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pos.x * 7.0)
	for k in 7:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.2, 0.7)
		ball(t, 0.11, flat(Color("#fff6e0"), 0.6, 0.0, false), Vector3(cos(a) * r, 1.3 + 0.52 * sqrt(maxf(1.0 - r * r / 0.81, 0.0)) * 0.95, sin(a) * r), 6, 4, false)


func window(parent: Node3D, pos: Vector3, yaw: float, shutter_col: Color, flowers: bool) -> void:
	var g := Node3D.new()
	g.position = pos
	g.rotation_degrees.y = yaw
	parent.add_child(g)
	var wood := mat("plank", Color(0.75, 0.55, 0.4), 0.6)
	box(g, Vector3(0.9, 1.0, 0.14), wood, Vector3(0, 0, 0.03))
	box(g, Vector3(0.68, 0.78, 0.05), flat(Color(1.0, 0.78, 0.38), 0.3, 1.7, false), Vector3(0, 0, 0.1))
	box(g, Vector3(0.05, 0.78, 0.07), wood, Vector3(0, 0, 0.12))
	box(g, Vector3(0.68, 0.05, 0.07), wood, Vector3(0, 0.0, 0.12))
	for s in [-1.0, 1.0]:
		box(g, Vector3(0.4, 0.86, 0.05), flat(shutter_col, 0.7), Vector3(s * 0.66, 0, 0.16), Vector3(0, -s * 28.0, 0))
	if flowers:
		box(g, Vector3(0.95, 0.2, 0.24), wood, Vector3(0, -0.72, 0.26))
		var rng := RandomNumberGenerator.new()
		rng.seed = int(pos.x * 31.0 + pos.y * 17.0)
		var fc := [Color("#ff6f9a"), Color("#ffd23a"), Color("#fff4e0"), Color("#b58cff")]
		for k in 9:
			ball(g, 0.075, flat(fc[rng.randi() % 4], 0.6, 0.0, false), Vector3(-0.4 + k * 0.1, -0.56 + rng.randf() * 0.06, 0.26), 6, 4, false)
		ball(g, 0.2, flat(Color("#3f8a5a"), 0.9), Vector3(-0.2, -0.6, 0.25), 8, 5, false)


func sparkles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var cols := [Color("#fff0a0"), Color("#ffc0e0"), Color("#c0f0ff")]
	for k in 90:
		var x := rng.randf_range(-20.0, 20.0)
		var z := rng.randf_range(-16.0, 14.0)
		var y := gh(x, z) + rng.randf_range(1.0, 5.5)
		var c: Color = cols[rng.randi() % 3]
		ball(world, rng.randf_range(0.04, 0.09), flat(c, 0.3, 3.5, false), Vector3(x, y, z), 6, 4, false)


# ------------------------------------------------------------ Aufnahme
func shot(cam: Camera3D, target: Vector3, size: float, path: String) -> void:
	cam.size = size
	var yaw := deg_to_rad(30.0)
	var pitch := deg_to_rad(41.0)
	var cp := target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * 80.0
	cam.look_at_from_position(cp, target, Vector3.UP)
	for k in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(path)
	print("saved ", path)


func door_front(p: Vector3, yaw: float, dist: float) -> Vector2:
	var v := Vector3(0, 0, dist).rotated(Vector3.UP, deg_to_rad(yaw))
	return Vector2(p.x + v.x, p.z + v.z)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix: String = args[0] if args.size() > 0 else "style3d2"
	RenderingServer.directional_shadow_atlas_set_size(4096, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	nh.seed = 4
	nh.frequency = 0.5
	vp = SubViewport.new()
	vp.size = Vector2i(1600, 900)
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	world = Node3D.new()
	vp.add_child(world)

	var osh := Shader.new()
	osh.code = "shader_type spatial;\nrender_mode cull_front, unshaded;\nuniform vec4 col : source_color = vec4(0.22, 0.13, 0.16, 1.0);\nuniform float th = 0.03;\nvoid vertex() { VERTEX += NORMAL * th; }\nvoid fragment() { ALBEDO = col.rgb; }\n"
	outline_mat = ShaderMaterial.new()
	outline_mat.shader = osh

	var hq := Vector3(0, BASE_H, -9.5)
	var bk := Vector3(-12.5, BASE_H, -1.5)
	var lj := Vector3(12.5, BASE_H, -6.0)
	var fs := Vector3(-3.4, 0.45, 8.2)
	pads = [[hq.x, hq.z, 6.0], [bk.x, bk.z, 4.0], [lj.x, lj.z, 4.4]]
	var hub := Vector2(0.5, 1.0)
	segs = [
		[Vector2(hq.x, hq.z + 5.2), hub],
		[door_front(bk, 12.0, 3.2) + Vector2(1.5, 0), hub],
		[door_front(lj, -18.0, 3.4) + Vector2(-1.8, 0.5), hub],
		[Vector2(fs.x + 1.0, fs.z - 1.8), hub],
		[Vector2(-3.0, 4.0), Vector2(-3.0, 7.6)],
	]

	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.7, 0.82, 0.95)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.92)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.ssao_intensity = 2.4
	env.ssao_power = 1.5
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 0.95
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.2
	env.adjustment_contrast = 1.04
	we.environment = env
	vp.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.89, 0.72)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	sun.shadow_blur = 1.6
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 130.0
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.2
	vp.add_child(sun)
	sun.look_at_from_position(sun_dir * 40.0, Vector3.ZERO)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.far = 300.0
	vp.add_child(cam)

	ground()
	tufts()
	build_hq(hq)
	build_bakery(bk, 12.0)
	build_lumber(lj, -18.0)
	build_fisher(fs, 0.0)
	for p in [[22.0, -3.0, 1.2], [24.0, -7.0, 1.1], [21.0, -11.5, 1.3], [-21.0, -6.0, 1.15], [-20.0, 4.0, 1.0]]:
		pine(Vector3(p[0], gh(p[0], p[1]), p[1]), p[2], int(p[0]))
	oak(Vector3(-10.0, gh(-10.0, 7.0), 7.0), 1.1, 3)
	oak(Vector3(9.5, gh(9.5, 4.0), 4.0), 1.0, 7)
	oak(Vector3(9.0, gh(9.0, -14.0), -14.0), 1.15, 11)
	shroom(Vector3(5.5, gh(5.5, -3.0), -3.0), 1.6, Color("#c05ad8"))
	shroom(Vector3(-5.5, gh(-5.5, -3.2), -3.2), 1.2, Color("#e8445c"))
	shroom(Vector3(9.5, gh(9.5, 5.0), 5.0), 1.0, Color("#3ab8c8"))
	sparkles()

	await shot(cam, Vector3(-1.5, 0, -3.5), 26.0, prefix + "_scene.png")
	await shot(cam, hq + Vector3(0, 3.5, 0), 15.0, prefix + "_hq.png")
	await shot(cam, bk + Vector3(1.0, 2.0, 0), 10.5, prefix + "_bakery.png")
	await shot(cam, lj + Vector3(0, 1.5, 0), 11.0, prefix + "_lumber.png")
	await shot(cam, fs + Vector3(3.0, 1.0, 0), 11.5, prefix + "_fisher.png")
	quit()
