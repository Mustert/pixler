extends SceneTree
# 3D-Bake-Test (Weg 1): Prozedurale 3D-Modelle + Texturen, gerendert mit schraeger Orthokamera, Sonne, Schatten, SSAO.
# godot --path . --rendering-method forward_plus --script tools/style3d.gd -- style3d
# Schreibt <prefix>_scene.png und <prefix>_hero.png

const LAKE := Vector2(12.0, 6.0)
const LAKE_R := 6.0
const BASE_H := 0.5
const SUN := Vector3(-0.35, 0.85, 0.6)

var world: Node3D
var vp: SubViewport
var cache := {}
var nh := FastNoiseLite.new()
var pads: Array = []
var sun_dir := SUN.normalized()


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


# ------------------------------------------------------------ Texturen
func tex_shingle(base: Color) -> Dictionary:
	var sz := 256
	var col := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var hi := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var nn := ntex(sz, 0.05, 3, 3)
	var rows := 8
	var cols := 8
	var th := sz / rows
	var tw := sz / cols
	for y in sz:
		for x in sz:
			var r := y / th
			var xo := (x + (r % 2) * (tw / 2)) % sz
			var c := xo / tw
			var fx := float(xo % tw) / tw
			var fy := float(y % th) / th
			var id := hsh(c, r, 1.0)
			var shade := 0.72 + 0.34 * fy
			var edge := minf(fx, 1.0 - fx)
			if edge < 0.07:
				shade *= 0.55 + edge * 6.4
			if fy > 0.9:
				shade *= 0.8
			var rr := fy > 0.8 and edge < (fy - 0.8) * 0.6   # abgerundete Ecken
			var nv := nn.get_pixel(x, y).r
			var cc := Color(base.r * (0.85 + id * 0.3), base.g * (0.85 + id * 0.3), base.b * (0.85 + id * 0.3)) * (shade * (0.85 + 0.3 * nv))
			cc.a = 1.0
			col.set_pixel(x, y, cc)
			var h := fy * 0.75 + minf(edge * 6.0, 0.25)
			if rr:
				h = 0.0
			hi.set_pixel(x, y, gray(clampf(h, 0.0, 1.0)))
	return finish(col, hi, 4.0)


func tex_stone() -> Dictionary:
	var sz := 256
	var col := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var hi := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var nn := ntex(sz, 0.06, 3, 5)
	var th := sz / 6
	for y in sz:
		for x in sz:
			var r := y / th
			var tw := 56 + int(hsh(r, 0.0, 2.0) * 24.0)
			var xo := (x + int(hsh(r, 1.0, 2.0) * 60.0)) % sz
			var c := xo / tw
			var fx := float(xo % tw)
			var fy := float(y % th)
			var d := minf(minf(fx, tw - fx), minf(fy, th - fy))
			var id := hsh(c, r, 7.0)
			var nv := nn.get_pixel(x, y).r
			var cc: Color
			var h: float
			if d < 2.5:
				cc = Color(0.26, 0.24, 0.25)
				h = 0.0
			else:
				var b := 0.52 + id * 0.22
				cc = Color(b * 1.02, b * 0.97, b * 0.9) * (0.8 + 0.4 * nv)
				h = clampf(0.5 + nv * 0.5 + minf(d - 2.5, 5.0) * 0.06, 0.0, 1.0)
			cc.a = 1.0
			col.set_pixel(x, y, cc)
			hi.set_pixel(x, y, gray(h))
	return finish(col, hi, 5.0)


func tex_plaster() -> Dictionary:
	var sz := 256
	var col := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var hi := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var n1 := ntex(sz, 0.015, 3, 21)
	var n2 := ntex(sz, 0.2, 2, 22)
	for y in sz:
		for x in sz:
			var a := n1.get_pixel(x, y).r
			var b := n2.get_pixel(x, y).r
			var c := Color(0.95, 0.89, 0.76) * (0.82 + 0.28 * a + 0.1 * b)
			if hsh(x, y, 5.0) > 0.985:
				c = c.darkened(0.12)
			c.a = 1.0
			col.set_pixel(x, y, c)
			hi.set_pixel(x, y, gray(b))
	return finish(col, hi, 1.5)


func tex_plank() -> Dictionary:
	var sz := 256
	var col := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var hi := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var nn := ntex(sz, 0.1, 3, 31)
	for y in sz:
		for x in sz:
			var p := x / 32
			var fx := x % 32
			var id := hsh(p, 0.0, 3.0)
			var g := nn.get_pixel((x * 3) % sz, (y / 9 + p * 17) % sz).r
			var b := 0.5 + id * 0.18
			var c := Color(b * 0.95, b * 0.66, b * 0.4) * (0.75 + 0.5 * g)
			var h := 0.6 + g * 0.2
			if fx < 2 or fx > 29:
				c = Color(0.16, 0.1, 0.07)
				h = 0.0
			c.a = 1.0
			col.set_pixel(x, y, c)
			hi.set_pixel(x, y, gray(h))
	return finish(col, hi, 3.0)


func tex_bark() -> Dictionary:
	var sz := 256
	var col := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var hi := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var nn := ntex(sz, 0.08, 3, 41)
	for y in sz:
		for x in sz:
			var g := nn.get_pixel((x * 4) % sz, (y / 12) % sz).r
			var c := Color(0.42, 0.29, 0.2) * (0.55 + g * 0.8)
			c.a = 1.0
			col.set_pixel(x, y, c)
			hi.set_pixel(x, y, gray(g))
	return finish(col, hi, 4.0)


func tex_leaf() -> Dictionary:
	var sz := 256
	var col := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var nn := ntex(sz, 0.05, 3, 51)
	for y in sz:
		for x in sz:
			var v := nn.get_pixel(x, y).r * 0.55 + hsh(x / 6, y / 6, 2.0) * 0.45
			var c := Color("#2d6b2e").lerp(Color("#a8dc5a"), clampf(v * 1.25 - 0.1, 0.0, 1.0))
			if hsh(x, y, 9.0) > 0.97:
				c = c.lightened(0.18)
			c.a = 1.0
			col.set_pixel(x, y, c)
	return finish(col, null, 0.0)


func tex_dirt() -> Dictionary:
	var sz := 256
	var col := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var n1 := ntex(sz, 0.03, 3, 61)
	for y in sz:
		for x in sz:
			var v := n1.get_pixel(x, y).r
			var c := Color("#8a6a42").lerp(Color("#c9a870"), v)
			var h := hsh(x / 3, y / 3, 4.0)
			if h > 0.9:
				c = Color("#b9b0a0") * (0.8 + hsh(x, y, 1.0) * 0.4)   # Kiesel
			elif h < 0.05:
				c = c.darkened(0.2)
			c.a = 1.0
			col.set_pixel(x, y, c)
	return finish(col, null, 0.0)


func tex_sand() -> Dictionary:
	var sz := 256
	var col := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var n1 := ntex(sz, 0.04, 3, 71)
	for y in sz:
		for x in sz:
			var v := n1.get_pixel(x, y).r
			var c := Color("#c8b078").lerp(Color("#f0dfa8"), v)
			if hsh(x, y, 2.0) > 0.97:
				c = c.lightened(0.1)
			c.a = 1.0
			col.set_pixel(x, y, c)
	return finish(col, null, 0.0)


func tex_grass() -> Dictionary:
	var sz := 256
	var col := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var n1 := ntex(sz, 0.02, 3, 11)
	var n2 := ntex(sz, 0.12, 2, 12)
	for y in sz:
		for x in sz:
			var t := clampf(n1.get_pixel(x, y).r * 0.8 + n2.get_pixel(x, y).r * 0.5 - 0.15, 0.0, 1.0)
			var c := Color("#2f6a28").lerp(Color("#82c248"), t)
			var h := hsh(x, y, 3.0)
			if h > 0.93:
				c = c.lightened(0.12)
			elif h < 0.07:
				c = c.darkened(0.16)
			c.a = 1.0
			col.set_pixel(x, y, c)
	return finish(col, null, 0.0)


func tex(kind: String) -> Dictionary:
	if cache.has("t_" + kind):
		return cache["t_" + kind]
	var d: Dictionary
	match kind:
		"shingle_r": d = tex_shingle(Color(0.72, 0.3, 0.2))
		"shingle_s": d = tex_shingle(Color(0.3, 0.45, 0.55))
		"shingle_h": d = tex_shingle(Color(0.78, 0.62, 0.3))
		"stone": d = tex_stone()
		"plaster": d = tex_plaster()
		"plank": d = tex_plank()
		"bark": d = tex_bark()
		"leaf": d = tex_leaf()
		"dirt": d = tex_dirt()
		"sand": d = tex_sand()
		_: d = tex_grass()
	cache["t_" + kind] = d
	return d


func mat(kind: String, tint: Color = Color.WHITE, sc: float = 0.5, rough: float = 0.9, nrm: float = 1.0, tri: bool = true) -> StandardMaterial3D:
	var key := "m_%s_%s_%s_%s_%s" % [kind, tint, sc, rough, tri]
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
	m.uv1_scale = Vector3(sc, sc, sc) if tri else Vector3.ONE
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	cache[key] = m
	return m


func flat(c: Color, rough: float = 0.7, emit: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
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


func cyl(parent: Node3D, rb: float, rt: float, h: float, m: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, seg: int = 12) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.bottom_radius = rb
	c.top_radius = rt
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return mi(parent, c, m, pos, rot)


func ball(parent: Node3D, r: float, m: Material, pos: Vector3, seg: int = 14, rings: int = 8, shadow: bool = true) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = rings
	return mi(parent, s, m, pos, Vector3.ZERO, shadow)


func tri(st: SurfaceTool, a: Vector3, ua: Vector2, b: Vector3, ub: Vector2, c: Vector3, uc: Vector2, out: Vector3, sg: int) -> void:
	# Godot: Vorderseite = im Uhrzeigersinn. Reihenfolge wird passend zur gewuenschten Aussenrichtung gewaehlt.
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


# ------------------------------------------------------------ Gelaende
func gh(x: float, z: float) -> float:
	var h := BASE_H + nh.get_noise_2d(x * 0.55, z * 0.55) * 0.6
	for p in pads:
		var d := Vector2(x - p[0], z - p[1]).length()
		var w := 1.0 - smoothstep(p[2], p[2] + 2.5, d)
		h = lerpf(h, BASE_H, w)
	var dl := Vector2(x - LAKE.x, z - LAKE.y).length()
	h -= (1.0 - smoothstep(LAKE_R - 3.5, LAKE_R + 3.0, dl)) * 2.4
	return h


func path_z(x: float) -> float:
	return 3.2 + 2.0 * sin(x * 0.22)


func dseg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return (p - (a + ab * t)).length()


var branches: Array = []   # [Vector2, Vector2]


func path_dist(x: float, z: float) -> float:
	var d := absf(z - path_z(x)) * 0.93
	for b in branches:
		d = minf(d, dseg(Vector2(x, z), b[0], b[1]))
	return d


func ground() -> void:
	var half := 34.0
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
			var y := gh(x, z)
			verts[j * n + i] = Vector3(x, y, z)
			var dx := (gh(x + e, z) - gh(x - e, z)) / (2.0 * e)
			var dz := (gh(x, z + e) - gh(x, z - e)) / (2.0 * e)
			norms[j * n + i] = Vector3(-dx, 1.0, -dz).normalized()
			var m := nh.get_noise_2d(x * 0.12 + 40.0, z * 0.12)
			var tint := Color(1.0 + m * 0.18, 1.0 + m * 0.1, 1.0 - m * 0.2)
			var jit := nh.get_noise_2d(x * 1.7, z * 1.7) * 0.25
			tint.a = 1.0 - smoothstep(0.7, 1.25, path_dist(x, z) + jit)
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
	vec2 uv = wpos.xz * 0.2;
	vec3 g = mix(texture(grass_tex, uv).rgb, texture(grass_tex, uv * 0.21 + 0.37).rgb, 0.45);
	vec3 p = texture(path_tex, uv * 1.3).rgb;
	vec3 s = texture(sand_tex, uv).rgb;
	float pm = smoothstep(0.4, 0.6, COLOR.a + (g.g - 0.45) * 0.35);
	vec3 col = mix(g * COLOR.rgb, p, pm);
	float sm = 1.0 - smoothstep(-0.38, -0.12, wpos.y + (g.r - 0.3) * 0.25);
	col = mix(col, s, sm);
	col *= mix(1.0, 0.55, 1.0 - smoothstep(-1.5, -0.55, wpos.y));
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	sm.set_shader_parameter("grass_tex", tex("grass")["a"])
	sm.set_shader_parameter("path_tex", tex("dirt")["a"])
	sm.set_shader_parameter("sand_tex", tex("sand")["a"])
	var g := MeshInstance3D.new()
	g.mesh = am
	g.material_override = sm
	world.add_child(g)
	# Wasser
	var pl := PlaneMesh.new()
	pl.size = Vector2(70, 70)
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.12, 0.45, 0.62, 0.78)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.08
	wm.metallic = 0.2
	wm.metallic_specular = 0.9
	var w := mi(world, pl, wm, Vector3(0, -0.6, 0), Vector3.ZERO, false)


# ------------------------------------------------------------ Haus
func roof(w: float, d: float, y0: float, rh: float, ov: float, sag: float, curl: float, thick: float, tile: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nu := 14
	var nv := 6
	var slope_len := sqrt(pow(d * 0.5 + ov, 2.0) + rh * rh)
	for si in 2:
		var side := 1.0 if si == 0 else -1.0
		var P: Array = []
		for i in nu + 1:
			var row: Array = []
			for j in nv + 1:
				var u := float(i) / nu
				var v := float(j) / nv
				var x := (u - 0.5) * (w + 2.0 * ov)
				var zabs := lerpf(d * 0.5 + ov, 0.0, v)
				var y := y0 + (d * 0.5 - zabs) * (rh / (d * 0.5)) - sag * sin(PI * u) * v + curl * pow(1.0 - v, 4.0)
				row.append(Vector3(x, y, side * zabs))
			P.append(row)
		var low := Vector3(0, -thick, 0)
		var sgt := 1 + si
		var sgb := 3 + si
		for i in nu:
			for j in nv:
				var a: Vector3 = P[i][j]
				var b: Vector3 = P[i + 1][j]
				var c: Vector3 = P[i + 1][j + 1]
				var dd: Vector3 = P[i][j + 1]
				var ua := Vector2(float(i) / nu * (w + 2.0 * ov) / tile, float(j) / nv * slope_len / tile)
				var ub := Vector2(float(i + 1) / nu * (w + 2.0 * ov) / tile, float(j) / nv * slope_len / tile)
				var uc := Vector2(float(i + 1) / nu * (w + 2.0 * ov) / tile, float(j + 1) / nv * slope_len / tile)
				var ud := Vector2(float(i) / nu * (w + 2.0 * ov) / tile, float(j + 1) / nv * slope_len / tile)
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


func window(parent: Node3D, pos: Vector3, yaw: float, shutter_col: Color, flowers: bool) -> void:
	var g := Node3D.new()
	g.position = pos
	g.rotation_degrees.y = yaw
	parent.add_child(g)
	var wood := mat("plank", Color(0.62, 0.45, 0.3), 0.6)
	box(g, Vector3(0.9, 1.0, 0.14), wood, Vector3(0, 0, 0.03))
	box(g, Vector3(0.68, 0.78, 0.05), flat(Color(1.0, 0.78, 0.38), 0.3, 1.6), Vector3(0, 0, 0.1))
	box(g, Vector3(0.05, 0.78, 0.07), wood, Vector3(0, 0, 0.12))
	box(g, Vector3(0.68, 0.05, 0.07), wood, Vector3(0, 0.0, 0.12))
	box(g, Vector3(1.05, 0.1, 0.28), mat("stone", Color.WHITE, 0.5), Vector3(0, -0.55, 0.1))
	for s in [-1.0, 1.0]:
		box(g, Vector3(0.4, 0.86, 0.05), flat(shutter_col, 0.7), Vector3(s * 0.66, 0, 0.16), Vector3(0, -s * 28.0, 0))
	if flowers:
		box(g, Vector3(0.95, 0.2, 0.24), wood, Vector3(0, -0.72, 0.26))
		var rng := RandomNumberGenerator.new()
		rng.seed = int(pos.x * 31.0 + pos.y * 17.0)
		var fc := [Color("#ff6f9a"), Color("#ffd23a"), Color("#fff4e0"), Color("#b58cff")]
		for k in 9:
			var fx := -0.4 + k * 0.1
			ball(g, 0.075, flat(fc[rng.randi() % 4], 0.6), Vector3(fx, -0.56 + rng.randf() * 0.06, 0.26 + rng.randf_range(-0.05, 0.05)), 6, 4, false)
		ball(g, 0.2, flat(Color("#3f8a3a"), 0.9), Vector3(-0.2, -0.6, 0.25), 8, 5, false)
		ball(g, 0.17, flat(Color("#4f9a3a"), 0.9), Vector3(0.22, -0.6, 0.27), 8, 5, false)


func house(pos: Vector3, yaw: float, w: float, d: float, o: Dictionary) -> Node3D:
	var h := Node3D.new()
	h.position = pos
	h.rotation_degrees.y = yaw
	world.add_child(h)
	var h1: float = o.get("h1", 1.9)
	var h2: float = o.get("h2", 1.5)
	var plaster := mat("plaster", o.get("plaster", Color.WHITE), 0.35, 0.95, 1.0)
	var wood := mat("plank", Color(0.5, 0.36, 0.26), 0.55)
	var stone := mat("stone", Color.WHITE, 0.4)
	var rk: String = o.get("roof", "shingle_r")
	# Sockel + Erdgeschoss + ueberkragendes Obergeschoss
	box(h, Vector3(w + 0.3, 1.1, d + 0.3), stone, Vector3(0, 0.05, 0))
	box(h, Vector3(w, h1, d), plaster, Vector3(0, 0.6 + h1 * 0.5, 0))
	var yu := 0.6 + h1
	box(h, Vector3(w + 0.55, 0.2, d + 0.55), wood, Vector3(0, yu + 0.05, 0))
	var up := box(h, Vector3(w + 0.5, h2, d + 0.5), plaster, Vector3(0, yu + 0.1 + h2 * 0.5, 0), Vector3(0, 1.2, 0))
	var wu := w + 0.5
	var du := d + 0.5
	# Fachwerk Obergeschoss: Vorder- und Seitenseite
	var zf := du * 0.5 + 0.02
	var xs := wu * 0.5 + 0.02
	var yb := yu + 0.15
	for px in [-wu * 0.5 + 0.08, -wu * 0.17, wu * 0.17, wu * 0.5 - 0.08]:
		box(h, Vector3(0.14, h2 - 0.05, 0.1), wood, Vector3(px, yb + h2 * 0.5, zf))
	box(h, Vector3(wu * 0.33, 0.12, 0.1), wood, Vector3(-wu * 0.33, yb + h2 * 0.5, zf), Vector3(0, 0, 38))
	box(h, Vector3(wu * 0.33, 0.12, 0.1), wood, Vector3(wu * 0.33, yb + h2 * 0.5, zf), Vector3(0, 0, -38))
	for pz in [-du * 0.5 + 0.08, 0.0, du * 0.5 - 0.08]:
		box(h, Vector3(0.1, h2 - 0.05, 0.14), wood, Vector3(xs, yb + h2 * 0.5, pz))
	# Ecken und Balken Erdgeschoss
	for px in [-w * 0.5 + 0.06, w * 0.5 - 0.06]:
		box(h, Vector3(0.13, h1, 0.13), wood, Vector3(px, 0.6 + h1 * 0.5, d * 0.5 - 0.02))
	for pz in [-d * 0.5 + 0.06, d * 0.5 - 0.06]:
		box(h, Vector3(0.13, h1, 0.13), wood, Vector3(w * 0.5 - 0.02, 0.6 + h1 * 0.5, pz))
	# Tuer mit Rundbogen
	var dz := d * 0.5 + 0.03
	var dm := mat("plank", Color(0.45, 0.28, 0.18), 0.7)
	box(h, Vector3(1.2, 1.55, 0.1), stone, Vector3(0, 0.6 + 0.775, dz - 0.03))
	box(h, Vector3(0.96, 1.5, 0.1), dm, Vector3(-0.0, 0.6 + 0.75, dz + 0.02))
	cyl(h, 0.48, 0.48, 0.1, dm, Vector3(0, 0.6 + 1.5, dz + 0.02), Vector3(90, 0, 0), 14)
	ball(h, 0.05, flat(Color("#e8c050"), 0.3), Vector3(0.3, 0.6 + 0.75, dz + 0.1), 6, 4, false)
	box(h, Vector3(1.5, 0.18, 0.7), stone, Vector3(0, 0.64, dz + 0.3))
	# Laterne neben der Tuer
	box(h, Vector3(0.06, 0.06, 0.3), wood, Vector3(0.95, 0.6 + 1.55, dz + 0.12))
	ball(h, 0.11, flat(Color(1.0, 0.8, 0.4), 0.3, 2.2), Vector3(0.95, 0.6 + 1.42, dz + 0.26), 8, 6, false)
	# Fenster
	var sc: Color = o.get("shutter", Color("#3d8a7a"))
	window(h, Vector3(-wu * 0.34, yb + h2 * 0.5, zf + 0.04), 0.0, sc, true)
	window(h, Vector3(wu * 0.34, yb + h2 * 0.5, zf + 0.04), 0.0, sc, false)
	window(h, Vector3(-w * 0.32, 0.6 + h1 * 0.5 + 0.1, d * 0.5 + 0.03), 0.0, sc, true)
	window(h, Vector3(w * 0.32, 0.6 + h1 * 0.5 + 0.1, d * 0.5 + 0.03), 0.0, sc, false)
	window(h, Vector3(wu * 0.5 + 0.04, yb + h2 * 0.5, 0.0), 90.0, sc, false)
	# Dach (schief, leicht durchhaengend) + Giebelfuellung
	var y0 := yu + 0.1 + h2 - 0.05
	var rh: float = o.get("rh", 1.9)
	var rm := roof(wu, du, y0, rh, 0.5, 0.22, 0.12, 0.14, 1.1)
	var rmat := mat(rk, o.get("roof_tint", Color.WHITE), 1.0, 0.85, 1.0, false)
	mi(h, rm, rmat, Vector3.ZERO, Vector3(0, 0, 0.0))
	var pr := PrismMesh.new()
	pr.size = Vector3(du, rh * 0.74, wu - 0.1)
	mi(h, pr, plaster, Vector3(0, y0 + rh * 0.37, 0), Vector3(0, 90, 0))
	# Schornstein mit Rauch
	var ch := Node3D.new()
	ch.position = Vector3(wu * 0.22, y0 + rh * 0.55, -du * 0.12)
	ch.rotation_degrees.z = 3.0
	h.add_child(ch)
	box(ch, Vector3(0.62, 1.8, 0.62), stone, Vector3(0, 0.5, 0))
	box(ch, Vector3(0.82, 0.16, 0.82), stone, Vector3(0, 1.45, 0))
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.96, 0.96, 1.0, 0.55)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.roughness = 1.0
	for k in 4:
		ball(ch, 0.26 + k * 0.1, sm, Vector3(0.12 * k, 1.9 + k * 0.62, 0.05 * k), 10, 6, false)
	# Fass und Kiste
	var bar := cyl(h, 0.36, 0.36, 0.7, mat("plank", Color(0.7, 0.5, 0.32), 0.6), Vector3(w * 0.5 + 0.7, 0.35 + 0.15, d * 0.5 - 0.4), Vector3.ZERO, 14)
	cyl(h, 0.385, 0.385, 0.06, flat(Color(0.2, 0.18, 0.18), 0.5), Vector3(w * 0.5 + 0.7, 0.35 + 0.35, d * 0.5 - 0.4), Vector3.ZERO, 14)
	cyl(h, 0.385, 0.385, 0.06, flat(Color(0.2, 0.18, 0.18), 0.5), Vector3(w * 0.5 + 0.7, 0.35 + 0.0, d * 0.5 - 0.4), Vector3.ZERO, 14)
	box(h, Vector3(0.6, 0.5, 0.6), wood, Vector3(w * 0.5 + 0.55, 0.3 + 0.25, d * 0.5 + 0.35), Vector3(0, 18, 0))
	return h


# ------------------------------------------------------------ Natur
func oak(pos: Vector3, s: float, seed: int) -> void:
	var t := Node3D.new()
	t.position = pos
	t.scale = Vector3(s, s, s)
	t.rotation.y = seed * 0.9
	world.add_child(t)
	var bark := mat("bark", Color(1, 1, 1), 0.7)
	cyl(t, 0.5, 0.3, 2.6, bark, Vector3(0, 1.3, 0), Vector3(0, 0, 3.0), 10)
	cyl(t, 0.8, 0.5, 0.5, bark, Vector3(0, 0.2, 0), Vector3.ZERO, 10)
	cyl(t, 0.14, 0.2, 1.8, bark, Vector3(-0.65, 2.9, 0.1), Vector3(0, 0, 38), 8)
	cyl(t, 0.14, 0.2, 1.7, bark, Vector3(0.65, 3.0, -0.1), Vector3(0, 0, -36), 8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var big := [[0.0, 3.9, 0.0, 1.75], [-1.35, 3.3, 0.3, 1.25], [1.4, 3.4, -0.2, 1.3], [0.2, 3.2, 1.2, 1.2], [-0.3, 4.9, -0.2, 1.2], [0.9, 4.5, 0.7, 1.0], [-0.9, 4.3, 0.9, 1.0]]
	var lm := mat("leaf", Color(0.7, 0.85, 0.65), 1.2, 0.85)
	for b in big:
		ball(t, b[3], lm, Vector3(b[0], b[1], b[2]), 14, 8)
	var cm := {}
	for k in 90:
		var b: Array = big[rng.randi() % big.size()]
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.35, 1.0), rng.randf_range(-1, 1)).normalized()
		var wd := dir.rotated(Vector3.UP, t.rotation.y)
		var l := clampf(wd.dot(sun_dir) * 0.7 + 0.45 + rng.randf_range(-0.12, 0.12), 0.0, 1.0)
		var c := Color("#235c2c").lerp(Color("#b6e866"), l)
		var key := "c%d" % int(l * 8.0)
		if not cm.has(key):
			cm[key] = flat(c, 0.8)
		var r := rng.randf_range(0.36, 0.62)
		var p: Vector3 = Vector3(b[0], b[1], b[2]) + dir * float(b[3]) * 0.92
		ball(t, r, cm[key], p, 8, 5, false)


func pine(pos: Vector3, s: float, seed: int) -> void:
	var t := Node3D.new()
	t.position = pos
	t.scale = Vector3(s, s, s)
	t.rotation.y = seed * 1.3
	world.add_child(t)
	cyl(t, 0.32, 0.22, 2.0, mat("bark", Color(0.8, 0.8, 0.8), 0.7), Vector3(0, 1.0, 0), Vector3.ZERO, 8)
	var lm := mat("leaf", Color(0.45, 0.7, 0.62), 1.4, 0.85)
	for k in 6:
		var r := 1.75 - k * 0.27
		var c := CylinderMesh.new()
		c.top_radius = 0.0
		c.bottom_radius = r
		c.height = 1.7
		c.radial_segments = 9
		c.rings = 1
		mi(t, c, lm, Vector3(0, 1.5 + k * 0.95, 0), Vector3(0, k * 31.0, 0))


func rock_mesh(seed: int) -> ArrayMesh:
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 7
	sm.rings = 5
	var st0 := SurfaceTool.new()
	st0.create_from(sm, 0)
	var arrays := st0.commit().surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var ids: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var pv := PackedVector3Array()
	for i in verts.size():
		var p := verts[i]
		var nz := hsh(roundf(p.x * 6.0), roundf(p.y * 6.0) + roundf(p.z * 6.0) * 7.0, seed)
		pv.append(p * (0.78 + nz * 0.5))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in range(0, ids.size(), 3):
		for q in 3:
			st.set_smooth_group(-1)
			st.set_uv(uvs[ids[k + q]])
			st.add_vertex(pv[ids[k + q]])
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


func rock(pos: Vector3, s: float, seed: int) -> void:
	var m := mat("stone", Color(0.82, 0.8, 0.9), 0.45, 0.9, 2.0)
	var n := mi(world, rock_mesh(seed), m, pos + Vector3(0, s * 0.35, 0), Vector3(0, seed * 47.0, 0))
	n.scale = Vector3(s, s * 0.72, s * 0.9)
	var n2 := mi(world, rock_mesh(seed + 5), m, pos + Vector3(s * 0.9, s * 0.2, s * 0.35), Vector3(0, seed * 20.0, 0))
	n2.scale = Vector3(s * 0.55, s * 0.4, s * 0.5)


func windmill(pos: Vector3, s: float) -> void:
	var t := Node3D.new()
	t.position = pos
	t.scale = Vector3(s, s, s)
	t.rotation_degrees.y = -8.0
	world.add_child(t)
	cyl(t, 1.7, 1.15, 4.6, mat("plaster", Color(1.0, 0.95, 0.86), 0.3), Vector3(0, 2.3, 0), Vector3.ZERO, 16)
	cyl(t, 1.85, 1.85, 0.9, mat("stone", Color.WHITE, 0.4), Vector3(0, 0.1, 0), Vector3.ZERO, 16)
	cyl(t, 0.0, 1.45, 1.9, mat("shingle_r", Color(0.9, 0.85, 0.8), 0.5), Vector3(0, 5.5, 0), Vector3.ZERO, 16)
	var dm := mat("plank", Color(0.45, 0.28, 0.18), 0.7)
	box(t, Vector3(0.9, 1.5, 0.2), dm, Vector3(0.0, 1.2, 1.55))
	for wy in [3.4]:
		box(t, Vector3(0.5, 0.6, 0.12), flat(Color(1.0, 0.78, 0.38), 0.3, 1.5), Vector3(0.0, wy, 1.15))
	var hub := Node3D.new()
	hub.position = Vector3(0, 4.3, 1.45)
	hub.rotation_degrees.z = 18.0
	t.add_child(hub)
	ball(hub, 0.3, dm, Vector3.ZERO, 10, 6)
	for k in 4:
		var arm := Node3D.new()
		arm.rotation_degrees.z = k * 90.0
		hub.add_child(arm)
		box(arm, Vector3(0.13, 3.8, 0.12), dm, Vector3(0, 1.9, 0.05))
		box(arm, Vector3(0.85, 1.9, 0.05), flat(Color(0.97, 0.92, 0.8), 0.9), Vector3(0.48, 2.3, 0.0))
		for r in 5:
			box(arm, Vector3(0.85, 0.05, 0.06), dm, Vector3(0.48, 1.4 + r * 0.45, 0.02))


func flag(pos: Vector3, yaw: float) -> void:
	var f := Node3D.new()
	f.position = pos
	f.rotation_degrees.y = yaw
	world.add_child(f)
	cyl(f, 0.04, 0.05, 2.0, flat(Color("#6b4a30"), 0.6), Vector3(0, 1.0, 0), Vector3.ZERO, 6)
	ball(f, 0.08, flat(Color("#e8c050"), 0.3), Vector3(0, 2.05, 0), 8, 5, false)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nu := 10
	var nv := 4
	for i in nu:
		for j in nv:
			var pts: Array = []
			for q in [[0, 0], [1, 0], [1, 1], [0, 1]]:
				var u := float(i + q[0]) / nu
				var v := float(j + q[1]) / nv
				pts.append(Vector3(0.05 + u * 0.9, 1.95 - v * 0.55 - u * 0.06, sin(u * 5.5) * 0.09 * u))
			quad(st, pts[0], pts[1], pts[2], pts[3], Vector3(0, 0, 1), 1)
			quad(st, pts[0], pts[1], pts[2], pts[3], Vector3(0, 0, -1), 2)
	st.generate_normals()
	var fm := flat(Color("#2f6ad8"), 0.6)
	mi(f, st.commit(), fm)


func fence(a: Vector3, b: Vector3) -> void:
	var wood := mat("plank", Color(0.62, 0.45, 0.3), 0.6)
	var len := a.distance_to(b)
	var n := int(len / 0.85)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(a.x * 10.0)
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		p.y = gh(p.x, p.z)
		box(world, Vector3(0.13, 0.9 + rng.randf() * 0.15, 0.13), wood, p + Vector3(0, 0.45, 0), Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4)))
	var ang := rad_to_deg(atan2(b.x - a.x, b.z - a.z))
	for i in n:
		var p0 := a.lerp(b, float(i) / n)
		var p1 := a.lerp(b, float(i + 1) / n)
		for hy in [0.35, 0.7]:
			var m := (p0 + p1) * 0.5
			m.y = gh(m.x, m.z) + hy
			var tilt := rad_to_deg(atan2(gh(p1.x, p1.z) - gh(p0.x, p0.z), p0.distance_to(p1)))
			var bx := box(world, Vector3(0.07, 0.09, p0.distance_to(p1) * 1.02), wood, m, Vector3(0, ang, 0))
			bx.rotate_object_local(Vector3.RIGHT, deg_to_rad(-tilt))


func mushrooms(pos: Vector3, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var stem := flat(Color("#f3ead2"), 0.8)
	var cap := flat(Color("#d8453a"), 0.6)
	var dot := flat(Color("#fff6e0"), 0.7)
	for k in 5:
		var p := pos + Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
		p.y = gh(p.x, p.z)
		var s := rng.randf_range(0.6, 1.3)
		cyl(world, 0.07 * s, 0.1 * s, 0.35 * s, stem, p + Vector3(0, 0.17 * s, 0), Vector3.ZERO, 8)
		var c := ball(world, 0.26 * s, cap, p + Vector3(0, 0.37 * s, 0), 10, 5, false)
		c.scale = Vector3(1, 0.62, 1)
		for q in 4:
			var a := rng.randf() * TAU
			ball(world, 0.04 * s, dot, p + Vector3(cos(a) * 0.15 * s, 0.5 * s, sin(a) * 0.15 * s), 5, 3, false)


func tufts() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 4:
		var c := CylinderMesh.new()
		c.top_radius = 0.0
		c.bottom_radius = 0.05
		c.height = 0.55
		c.radial_segments = 4
		c.rings = 1
		var tf := Transform3D(Basis.from_euler(Vector3(deg_to_rad(-14.0 + k * 9.0), k * 1.7, deg_to_rad(10.0 - k * 6.0))), Vector3(0, 0.25, 0))
		st.append_from(c, 0, tf)
	var tm := st.commit()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = tm
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var xf: Array = []
	var cl: Array = []
	var fl_xf: Array = []
	var fl_cl: Array = []
	var gcols := [Color("#2f6a28"), Color("#3f8a30"), Color("#4f9a38"), Color("#2a5f26"), Color("#5aa83a")]
	var fcols := [Color("#fff4e0"), Color("#ffd23a"), Color("#ff7aa8"), Color("#9ab8ff"), Color("#ffffff")]
	for k in 9000:
		var x := rng.randf_range(-30.0, 30.0)
		var z := rng.randf_range(-30.0, 30.0)
		var y := gh(x, z)
		if y < -0.1 or path_dist(x, z) < 1.2:
			continue
		var blocked := false
		for p in pads:
			if Vector2(x - p[0], z - p[1]).length() < p[2] * 0.85:
				blocked = true
				break
		if blocked:
			continue
		var s := rng.randf_range(0.7, 1.5)
		xf.append(Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3(s, s * rng.randf_range(0.8, 1.4), s)), Vector3(x, y, z)))
		cl.append(gcols[rng.randi() % gcols.size()])
		if rng.randf() < 0.07:
			fl_xf.append(Transform3D(Basis.IDENTITY, Vector3(x, y + 0.42, z)))
			fl_cl.append(fcols[rng.randi() % fcols.size()])
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		mm.set_instance_color(i, cl[i])
	var gm := flat(Color.WHITE, 0.9)
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
	sp.radius = 0.07
	sp.height = 0.14
	sp.radial_segments = 6
	sp.rings = 3
	fm.mesh = sp
	fm.instance_count = fl_xf.size()
	for i in fl_xf.size():
		fm.set_instance_transform(i, fl_xf[i])
		fm.set_instance_color(i, fl_cl[i])
	var fmi := MultiMeshInstance3D.new()
	fmi.multimesh = fm
	fmi.material_override = gm
	fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(fmi)


# ------------------------------------------------------------ Aufnahme
func shot(cam: Camera3D, target: Vector3, size: float, path: String) -> void:
	cam.size = size
	var yaw := deg_to_rad(30.0)
	var pitch := deg_to_rad(36.0)
	var cp := target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * 80.0
	cam.look_at_from_position(cp, target, Vector3.UP)
	for k in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var im := vp.get_texture().get_image()
	im.save_png(path)
	print("saved ", path)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix: String = args[0] if args.size() > 0 else "style3d"
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

	pads = [[-6.0, -4.0, 3.4], [3.5, -7.0, 3.1], [-13.0, -6.0, 2.8]]
	branches = [[Vector2(-6.0, -1.6), Vector2(-6.0, path_z(-6.0))], [Vector2(3.5, -4.6), Vector2(3.5, path_z(3.5))]]

	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.78, 0.92)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.52, 0.6, 0.86)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 2.6
	env.ssao_power = 1.6
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.18
	env.adjustment_contrast = 1.06
	we.environment = env
	vp.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.92, 0.78)
	sun.light_energy = 1.55
	sun.shadow_enabled = true
	sun.shadow_blur = 1.4
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 120.0
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
	var ha := house(Vector3(-6, gh(-6, -4), -4), 0.0, 4.3, 3.3, {"roof": "shingle_r", "shutter": Color("#3d8a7a")})
	var hb := house(Vector3(3.5, gh(3.5, -7), -7), -6.0, 3.7, 3.0, {"roof": "shingle_s", "shutter": Color("#d8643a"), "plaster": Color(0.9, 0.97, 1.0), "rh": 1.7})
	windmill(Vector3(-13, gh(-13, -6), -6), 1.0)
	oak(Vector3(9.5, gh(9.5, -1.5), -1.5), 1.15, 3)
	oak(Vector3(-10.5, gh(-10.5, 4.5), 4.5), 1.0, 7)
	oak(Vector3(0.5, gh(0.5, -11.5), -11.5), 1.1, 11)
	for p in [[14.0, -5.0, 1.15], [16.0, -2.0, 1.0], [12.5, -9.0, 1.25], [-17.0, 1.0, 1.1]]:
		pine(Vector3(p[0], gh(p[0], p[1]), p[1]), p[2], int(p[0]))
	rock(Vector3(8.0, gh(8.0, 6.5), 6.5), 1.1, 1)
	rock(Vector3(-9.0, gh(-9.0, -1.0), -1.0), 0.8, 2)
	rock(Vector3(-2.0, gh(-2.0, -8.5), -8.5), 0.9, 3)
	flag(Vector3(-4.2, gh(-4.2, 0.2), 0.2), 0.0)
	flag(Vector3(5.3, gh(5.3, -3.2), -3.2), 20.0)
	fence(Vector3(-10.5, 0, -2.2), Vector3(-8.6, 0, -0.2))
	fence(Vector3(-3.0, 0, -1.6), Vector3(0.4, 0, -2.4))
	mushrooms(Vector3(8.0, 0, -4.2), 5)
	mushrooms(Vector3(-8.5, 0, 6.5), 9)

	await shot(cam, Vector3(0, 0, -2), 20.0, prefix + "_scene.png")
	await shot(cam, Vector3(-6, 2.0, -4), 8.5, prefix + "_hero.png")
	quit()
