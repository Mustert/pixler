class_name Sim
extends RefCounted
# Welt + Simulation: Karte, Straßennetz (Flaggen/Segmente), Träger, Warenrouting, Gebäude, Tiere.

const MW := Data.MW
const MH := Data.MH
const NT := MW * MH
const CH := 16            # Chunk-Kantenlaenge (Zellen) fuer den Objekt-Index
const NCX := MW / CH
const NCY := MH / CH
const K := Data.K
const WALK_MULT := 0.75    # Lauftempo aller Pixler
static var FLAG_CAP := 20    # Balance-Regler (per Kommandozeile ueberschreibbar, siehe main.gd)
static var BARROW_AT := 4
static var CARRY_N := 1        # Waren pro Traeger
static var BARROW_N := 3       # Waren pro Traeger mit Schubkarre
const BARROWS_START := 10
static var ROAD_SEG := 10      # Zellen bis zur naechsten automatischen Zwischenflagge
const HQ_POS := Vector2i(93 * K, 90 * K)
const BUILDERS_BASE := 3
const BUILDERS_PER_LAGER := 2

class Flag:
	var id: int
	var x: int
	var y: int
	var goods: Array = []
	var segs: Array = []
	var bld: int = 0

class Good:
	var t: String
	var dest: int = 0
	var fid: int = 0

class Seg:
	var id: int
	var a: int
	var b: int
	var cells: Array = []
	var L: int = 1
	var p: float = 0.0
	var st: String = "idle"
	var load: Array = []
	var end: int = 0
	var chk: float = 0.0
	var barrow: bool = false
	var idle_t: float = 0.0
	var bb := Rect2i()          # Zellen-Umriss (Rendering)
	var pts := PackedVector2Array()   # Rendering-Cache: Weg-Polylinie in Weltkoordinaten
	var bends := PackedVector2Array()
	var arr: Array = []      # Anmarschweg des Traegers (Zellen)
	var arr_d: float = 0.0

class Bld:
	var id: int
	var type: String
	var x: int
	var y: int
	var w: int
	var h: int
	var fid: int
	var fids: Array = []
	var done: bool = false
	var prog: float = 0.0
	var build_t: float = 8.0
	var inbox: Dictionary = {}
	var incoming: Dictionary = {}
	var cap: Dictionary = {}
	var stock: Dictionary = {}
	var st: String = "idle"
	var timer: float = 0.0
	var paused: bool = false
	var msg: String = ""
	var wx: float = 0.0
	var wy: float = 0.0
	var carry: String = ""
	var tg = null
	var face: int = 1
	var fields: Array = []
	var busy: bool = false
	var prio: int = 0          # -1 niedrig, 0 normal, 1 hoch (Baustellen)
	var level: int = 1         # Wohnhaus-Stufe
	var upg: bool = false      # Ausbau laeuft (done=false, Gebaeude steht noch)
	var fed: int = 0           # Wie oft versorgt (Ausbau-Bedingung)
	var feed_t: float = 20.0
	var bw: bool = false       # Bauarbeiter arbeitet gerade hier
	var retry: float = 0.0
	var keepers: Array = []    # Lagerarbeiter (Langhaus 3, Lagerhaus 1)
	var out_q: Array = []      # Auslieferungen, die noch vor die Tuer getragen werden muessen
	var d0: float = 1.0        # Weglaenge der aktuellen Etappe (Fortschrittsanzeige)
	var ptot: float = 1.0      # Gesamtdauer der aktuellen Phase (Fortschrittsanzeige)

class Keeper:
	# Lagerarbeiter: tragen Waren aus dem Lager Stueck fuer Stueck vor die Tuer
	var home: Vector2          # Punkt im Gebaeude (hinter der Tuer)
	var x: float = 0.0
	var y: float = 0.0
	var st: String = "idle"    # idle | load | go | drop | back
	var t: float = 0.0
	var job = null             # {t, dest, fid}
	var face: int = 1

class Builder:
	var site: int
	var path: Array = []
	var k: float = 0.0
	var st: String = "go"      # go | work | back
	var x: float = 0.0
	var y: float = 0.0
	var face: int = 1

class Balloon:
	var b: int                  # Gebaeude-ID (Ballonfahrer)
	var x: float
	var y: float
	var h: float = 0.0          # Flughoehe 0..1
	var phase: String = "up"    # up | fly | down
	var wp: Array = []
	var face: int = 1
	var t: float = 0.0

class Animal:
	var kind: String
	var x: float
	var y: float
	var tx: float
	var ty: float
	var moving: bool = false
	var timer: float = 0.0
	var home = null
	var frozen: bool = false
	var face: int = 1
	var dead: bool = false

var seed_: int = 1
var ground := PackedByteArray()
var obj := PackedByteArray()
var stage := PackedByteArray()
var amt := PackedByteArray()
var stump := PackedByteArray()
var age := PackedFloat32Array()
var occ := PackedInt32Array()
var road := PackedInt32Array()
var flag := PackedInt32Array()
var field := PackedInt32Array()
var chunk_obj: Array = []     # pro Chunk: Dictionary Zelle -> true fuer alle Zellen mit Objekt
var chunk_stump: Array = []

var t: float = 0.0
var nid: int = 1
var blds: Dictionary = {}
var flags: Dictionary = {}
var segs: Dictionary = {}
var claims: Dictionary = {}
var growing: Dictionary = {}
var animals: Array = []
var balloons: Array = []
var idlers: Array = []
var net_ver: int = 0
var pop: int = Data.START_POP
var free_now: int = Data.START_POP
var builders: Array = []
var dlink := PackedByteArray()   # Bit1: Weg nach (x+1,y+1), Bit2: Weg nach (x-1,y+1)
var barrows_free: int = BARROWS_START
var barrows_total: int = BARROWS_START
var meals: int = 0
var landmarks: Dictionary = {}
var events: Array = []   # [kind, text, x, y]  fuer UI/Partikel
var _dcache: Dictionary = {}
var _acc_disp: float = 0.0
var _acc_eco: float = 0.0
var rng := RandomNumberGenerator.new()

# ---------------------------------------------------------------- Welt
func _mk(s: int, f: float) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = s
	n.frequency = f
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 3
	return n

func _nz(n: FastNoiseLite, x: float, y: float) -> float:
	return clampf(0.5 + 0.75 * n.get_noise_2d(x, y), 0.0, 1.0)

func inb(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < MW and y < MH

func set_obj(i: int, o: int) -> void:
	var c: int = ((i / MW) / CH) * NCX + (i % MW) / CH
	if o == 0:
		chunk_obj[c].erase(i)
	else:
		chunk_obj[c][i] = true
	obj[i] = o

func set_stump(i: int, v: int) -> void:
	var c: int = ((i / MW) / CH) * NCX + (i % MW) / CH
	if v == 0:
		chunk_stump[c].erase(i)
	else:
		chunk_stump[c][i] = true
	stump[i] = v

func gen(s: int) -> void:
	seed_ = s
	rng.seed = s
	dlink.resize(NT)
	dlink.fill(0)
	for arr in [ground, obj, stage, amt, stump]:
		arr.resize(NT)
		arr.fill(0)
	age.resize(NT)
	age.fill(0.0)
	for arr in [occ, road, flag, field]:
		arr.resize(NT)
		arr.fill(0)
	chunk_obj = []
	chunk_stump = []
	for c in NCX * NCY:
		chunk_obj.append({})
		chunk_stump.append({})
	# Alle Entwurfswerte (Biome, Seen, Rauschen) sind in Kachel-Einheiten; die Zellen tasten sie fein ab.
	var nE := _mk(s + 1, 1.0 / 22.0)
	var nB := _mk(s + 7, 1.0 / 6.0)
	var nF := _mk(s + 20, 1.0 / 8.0)
	var nL := _mk(s + 3, 1.0 / 6.0)
	var nM := _mk(s + 11, 1.0 / 5.0)
	var A := {
		"fairy": [57, 60, 23], "snow": [108, 39, 24], "volc": [147, 105, 16], "desert": [129, 147, 23],
		"swamp": [54, 138, 23], "mtn": [116, 84, 11], "hill": [108, 106, 6],
	}
	var T := Data.T
	var KK := float(K * K)
	for y in MH:
		var fy := float(y) / K
		for x in MW:
			var fx := float(x) / K
			var i := y * MW + x
			var rx := fx - 95.5
			var ry := fy - 95.5
			var r := sqrt(rx * rx + ry * ry) / 90.0
			var sc := 1.0 - r * r * 1.1 + (_nz(nE, fx, fy) - 0.5) * 0.9
			for k in A:
				var a = A[k]
				var ax: float = fx - a[0]
				var ay: float = fy - a[1]
				var dd: float = a[2] + 5.0
				if absf(ax) < dd and absf(ay) < dd:
					sc += 0.7 * maxf(0.0, 1.0 - sqrt(ax * ax + ay * ay) / dd)
			ground[i] = T.DEEP if sc < 0.0 else (T.WATER if sc < 0.14 else (T.SAND if sc < 0.2 else T.GRASS))
	# Biome
	for y in MH:
		var fy := float(y) / K
		for x in MW:
			var fx := float(x) / K
			var i := y * MW + x
			if ground[i] < T.SAND:
				continue
			var best := ""
			var bq := 1.0
			var jn := (_nz(nB, fx, fy) - 0.5) * 0.6
			for k in A:
				var a = A[k]
				var ax: float = fx - a[0]
				var ay: float = fy - a[1]
				var q: float = sqrt(ax * ax + ay * ay) / a[2] + jn
				if q < bq:
					bq = q
					best = k
			var beach: bool = ground[i] == T.SAND
			match best:
				"fairy":
					if not beach: ground[i] = T.FAIRY
				"snow": ground[i] = T.SNOW
				"desert": ground[i] = T.DESERT
				"swamp":
					if not beach: ground[i] = T.MARSH if _nz(nM, fx, fy) > 0.66 else T.SWAMP
				"volc":
					if not beach:
						ground[i] = T.LAVA if bq < 0.3 else (T.ASH if bq < 0.62 else (T.ROCK if bq < 0.9 else ground[i]))
				"mtn":
					if bq < 0.85 and not beach: ground[i] = T.ROCK
				"hill":
					if bq < 0.8 and not beach: ground[i] = T.ROCK
	# Features: See, Oase, Feenteich, Eissee
	for y in MH:
		var fy := float(y) / K
		for x in MW:
			var fx := float(x) / K
			var i := y * MW + x
			if ground[i] < T.SAND:
				continue
			var nl := (_nz(nL, fx, fy) - 0.5)
			var d := Vector2(fx - 80, fy - 100).length() / 8.0 + nl * 0.7
			if d < 1.0:
				ground[i] = T.DEEP if d < 0.5 else T.WATER
			elif d < 1.25 and ground[i] == T.GRASS:
				ground[i] = T.SAND
			var od := Vector2(fx - 129, fy - 150).length() + nl * 3.0
			if od < 4.4:
				ground[i] = T.WATER
			elif od < 6.0 and ground[i] == T.DESERT:
				ground[i] = T.SAND
			var fd := Vector2(fx - 57, fy - 60).length() + nl * 3.0
			if fd < 4.2:
				ground[i] = T.WATER
			var idd := Vector2(fx - 116, fy - 36).length() + nl * 5.0
			if idd < 8.0:
				ground[i] = T.ICE
	# Startwiese
	for y in MH:
		var fy := float(y) / K
		for x in MW:
			if Vector2(float(x) / K - 95, fy - 92).length() < 11.0:
				ground[y * MW + x] = T.GRASS
	# Objekte. Wahrscheinlichkeiten sind pro Kachel entworfen: rr ist daher mit K*K skaliert.
	for y in MH:
		var fy := float(y) / K
		for x in MW:
			var fx := float(x) / K
			var i := y * MW + x
			var g := ground[i]
			var u := rng.randf()
			var rr := u * KK
			var fb := 0.3 * maxf(0.0, 1.0 - Vector2(fx - 86, fy - 82).length() / 10.0) + 0.3 * maxf(0.0, 1.0 - Vector2(fx - 105, fy - 99).length() / 9.0)
			var f := _nz(nF, fx, fy) + fb
			var o := 0
			match g:
				Data.T.GRASS:
					if f > 0.6 and rr < 0.62: o = Data.O.TREE
					elif rr < 0.012: o = Data.O.TREE
					else:
						# Kraeuter (Wiesen, Waldrand) und Pilze (im Wald zwischen den Baeumen)
						var r2 := rng.randf() * KK
						if f > 0.6 and r2 < 0.09: o = Data.O.SHROOM
						elif f > 0.3 and r2 < 0.05: o = Data.O.HERB
						elif r2 < 0.012: o = Data.O.HERB
				Data.T.ROCK:
					# Weniger, dafuer ergiebigere Felsen
					if _nz(nF, fx * 2.0, fy * 2.0) > 0.42 and rr < 0.2:
						o = Data.O.ROCK
						amt[i] = 18 + int(rng.randf() * 16)
				Data.T.ASH:
					if rr < 0.05: o = Data.O.OBSC
					elif u > 1.0 - 0.012 / KK:
						o = Data.O.ROCK
						amt[i] = 14 + int(rng.randf() * 10)
				Data.T.FAIRY:
					if f > 0.55 and rr < 0.5: o = Data.O.FTREE
					elif rr < 0.06: o = Data.O.GFLOWER
					elif rr < 0.085: o = Data.O.GMUSH
				Data.T.SWAMP:
					if rr < 0.05: o = Data.O.DEAD
					elif rr < 0.1: o = Data.O.GSHROOM
				Data.T.DESERT:
					var od := Vector2(fx - 129, fy - 150).length()
					if od < 12.0 and rr < 0.12: o = Data.O.PALM
					elif rr < 0.02: o = Data.O.CACTUS
				Data.T.SNOW:
					if f > 0.55 and rr < 0.55: o = Data.O.PINE
					elif rr < 0.007:
						o = Data.O.ROCK
						amt[i] = 12 + int(rng.randf() * 10)
			if o == Data.O.TREE and Vector2(fx - 95, fy - 92).length() < 11.0 and rr > 0.03:
				o = 0
			if o != 0:
				set_obj(i, o)
			stage[i] = 3
	# Tiere
	for k in 44:
		spawn_animal("deer")
	for k in 30:
		spawn_animal("rabbit")

func spawn_animal(kind: String) -> Animal:
	for tries in 30:
		var x := rng.randi_range(2, MW - 3)
		var y := rng.randi_range(2, MH - 3)
		var i := y * MW + x
		var g := ground[i]
		if (g == Data.T.GRASS or g == Data.T.FAIRY) and no_obj(i) and occ[i] == 0:
			var a := Animal.new()
			a.kind = kind
			a.x = x + 0.5
			a.y = y + 0.5
			a.tx = a.x
			a.ty = a.y
			a.timer = rng.randf() * 3.0
			animals.append(a)
			return a
	return null

func start_game(s: int) -> void:
	gen(s)
	var hq := place_building("hq", HQ_POS.x, HQ_POS.y, true)
	var st := {"bretter": 26, "steinblock": 16, "stein": 6, "holz": 6, "wasser": 4, "brot": 4, "fisch": 2, "fleisch": 2}
	for k in st:
		hq.stock[k] = st[k]

# ---------------------------------------------------------------- Hilfen
func used_workers() -> int:
	var n := 0
	for b in blds.values():
		var k: String = Data.BD[b.type].kind
		if k != "store" and k != "lm" and k != "house":
			n += 1
		elif k == "store":
			n += b.keepers.size()
	return n

func pop_cap() -> int:
	var n := Data.HQ_CAP + 4 * landmarks.size()
	for b in blds.values():
		if b.type == "haus" and (b.done or b.upg):
			n += Data.HOUSE_CAP[b.level]
	return n

func builder_cap() -> int:
	var n := BUILDERS_BASE
	for b in blds.values():
		if b.type == "lager" and b.done:
			n += BUILDERS_PER_LAGER
	return n

func builders_active() -> int:
	var n := 0
	for bd in builders:
		if bd.st != "back":
			n += 1
	return n

func site_cost(b) -> Dictionary:
	if b.upg:
		return Data.HOUSE_UP[b.level].cost
	return Data.BD[b.type].cost

func total_stock(g: String) -> int:
	var n := 0
	for b in blds.values():
		if b.done and Data.BD[b.type].kind == "store":
			n += b.stock.get(g, 0)
	return n

func carrier_count() -> int:
	var n := 0
	for s in segs.values():
		if s.st != "wait_car":
			n += 1
	return n

func free_pixlers() -> int:
	return pop - used_workers() - carrier_count() - builders_active()

func waiting_for_pixler() -> int:
	var n := 0
	for s in segs.values():
		if s.st == "wait_car":
			n += 1
	return n

func no_obj(i: int) -> bool:
	# true, wenn nichts Festes auf der Zelle steht (Kraeuter, Pilze & Co. zaehlen als frei)
	var o := obj[i]
	return o == 0 or Data.SOFT[o] == 1

func clear_soft(i: int) -> void:
	if obj[i] != 0 and Data.SOFT[obj[i]] == 1:
		set_obj(i, 0)

func free_ground(i: int) -> bool:
	return Data.WALK[ground[i]] == 1 and no_obj(i) and occ[i] == 0 and road[i] == 0 and flag[i] == 0 and field[i] == 0

func standable(i: int) -> bool:
	return Data.WALK[ground[i]] == 1 and no_obj(i) and occ[i] == 0

func near_ground(x: int, y: int, types: Array) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = x + d.x
		var ny: int = y + d.y
		if inb(nx, ny) and ground[ny * MW + nx] in types:
			return true
	return false

func bcenter(b) -> Vector2i:
	return Vector2i(b.x + (b.w >> 1), b.y + (b.h >> 1))

# ---------------------------------------------------------------- Ressourcen-Suche
func scan(kind: String, cx: int, cy: int, R: int) -> Array:
	var out: Array = []
	var T := Data.T
	for yy in range(cy - R, cy + R + 1):
		for xx in range(cx - R, cx + R + 1):
			if not inb(xx, yy):
				continue
			if (xx - cx) * (xx - cx) + (yy - cy) * (yy - cy) > R * R:
				continue
			var i := yy * MW + xx
			if claims.has(i):
				continue
			var ok := false
			match kind:
				"tree": ok = Data.CHOP[obj[i]] == 1 and stage[i] == 3
				"rock": ok = obj[i] == Data.O.ROCK and amt[i] > 0
				"fairy": ok = obj[i] == Data.O.GFLOWER and stage[i] == 3
				"shroom": ok = obj[i] == Data.O.GSHROOM and stage[i] == 3
				"herb": ok = obj[i] == Data.O.HERB and stage[i] == 3
				"mush": ok = obj[i] == Data.O.SHROOM and stage[i] == 3
				"plant": ok = free_ground(i) and (ground[i] == T.GRASS or ground[i] == T.SNOW or ground[i] == T.SWAMP)
				"sand": ok = ground[i] == T.DESERT and free_ground(i)
				"field": ok = ground[i] == T.GRASS and free_ground(i)
				"fish": ok = standable(i) and road[i] == 0 and flag[i] == 0 and near_ground(xx, yy, [T.DEEP, T.WATER])
				"ice": ok = standable(i) and road[i] == 0 and flag[i] == 0 and near_ground(xx, yy, [T.ICE])
				"lava": ok = standable(i) and road[i] == 0 and flag[i] == 0 and near_ground(xx, yy, [T.LAVA])
			if ok:
				out.append(Vector2i(xx, yy))
	return out

func has_resource(type: String, x: int, y: int) -> bool:
	var d: Dictionary = Data.BD[type]
	if not d.has("need"):
		return true
	var cx: int = x + (d.w >> 1)
	var cy: int = y + (d.h >> 1)
	if d.need == "deer":
		for a in animals:
			if a.kind == "deer" and not a.dead and Vector2(a.x - cx, a.y - cy).length() <= d.R:
				return true
		return false
	return scan(d.need, cx, cy, d.R).size() > 0

# ---------------------------------------------------------------- Straßen
func get_flag_at(x: int, y: int):
	var f: int = flag[y * MW + x]
	return flags[f] if f != 0 else null

func _mk_seg(a: Flag, b: Flag, cells: Array, instant: bool = true) -> Seg:
	var s := Seg.new()
	s.id = nid
	nid += 1
	s.a = a.id
	s.b = b.id
	s.cells = cells
	s.L = cells.size() - 1
	s.p = s.L * 0.5
	s.chk = rng.randf() * 0.3
	if not instant:
		s.st = "wait_car"
	var mnx := 99999
	var mny := 99999
	var mxx := -1
	var mxy := -1
	for c in cells:
		mnx = mini(mnx, c[0])
		mny = mini(mny, c[1])
		mxx = maxi(mxx, c[0])
		mxy = maxi(mxy, c[1])
	s.bb = Rect2i(mnx, mny, mxx - mnx + 1, mxy - mny + 1)
	for k in range(1, cells.size() - 1):
		road[cells[k][1] * MW + cells[k][0]] = s.id
	_set_dlinks(cells, true)
	a.segs.append(s)
	b.segs.append(s)
	segs[s.id] = s
	net_ver += 1
	return s

func _set_dlinks(cells: Array, on: bool) -> void:
	for k in range(cells.size() - 1):
		var c1: Array = cells[k]
		var c2: Array = cells[k + 1]
		if c1[0] == c2[0] or c1[1] == c2[1]:
			continue
		# obere Zelle + Richtung der unteren
		var top: Array = c1 if c1[1] < c2[1] else c2
		var bot: Array = c2 if c1[1] < c2[1] else c1
		var bit := 1 if bot[0] > top[0] else 2
		var i: int = top[1] * MW + top[0]
		if on:
			dlink[i] |= bit
		else:
			dlink[i] &= ~bit

func create_flag(x: int, y: int) -> Flag:
	var i := y * MW + x
	if flag[i] != 0:
		return flags[flag[i]]
	var f := Flag.new()
	f.id = nid
	nid += 1
	f.x = x
	f.y = y
	field[i] = 0
	if road[i] != 0:
		var s: Seg = segs[road[i]]
		var k := 0
		for c in range(s.cells.size()):
			if s.cells[c][0] == x and s.cells[c][1] == y:
				k = c
				break
		var fa: Flag = flags[s.a]
		var fb: Flag = flags[s.b]
		var c1: Array = s.cells.slice(0, k + 1)
		var c2: Array = s.cells.slice(k)
		var carried: Array = s.load
		s.load = []
		_del_seg(s, false)
		road[i] = 0
		flag[i] = f.id
		flags[f.id] = f
		_mk_seg(fa, f, c1)
		_mk_seg(f, fb, c2)
		for cg in carried:
			cg.fid = fa.id
			fa.goods.append(cg)
	else:
		flag[i] = f.id
		flags[f.id] = f
		net_ver += 1
	return f

func _del_seg(s: Seg, cleanup: bool) -> void:
	_set_dlinks(s.cells, false)
	for k in range(1, s.cells.size() - 1):
		var i: int = s.cells[k][1] * MW + s.cells[k][0]
		if road[i] == s.id:
			road[i] = 0
	var fa = flags.get(s.a)
	var fb = flags.get(s.b)
	if fa: fa.segs.erase(s)
	if fb: fb.segs.erase(s)
	segs.erase(s.id)
	if s.barrow:
		barrows_free += 1
		s.barrow = false
	if cleanup:
		for lg in s.load:
			kill_good(lg)
		s.load = []
	net_ver += 1
	if cleanup:
		for f in [fa, fb]:
			if f != null and f.segs.is_empty() and f.bld == 0:
				remove_flag(f)

func remove_flag(f: Flag) -> void:
	if f.bld != 0:
		return
	for s in f.segs.duplicate():
		_del_seg(s, false)
		for lg in s.load:
			kill_good(lg)
		s.load = []
		var o = flags.get(s.b if s.a == f.id else s.a)
		if o != null and o.segs.is_empty() and o.bld == 0:
			remove_flag(o)
	for g in f.goods:
		kill_good(g)
	flag[f.y * MW + f.x] = 0
	flags.erase(f.id)
	net_ver += 1

func remove_seg_at(x: int, y: int) -> bool:
	var i := y * MW + x
	if road[i] != 0:
		_del_seg(segs[road[i]], true)
		return true
	if flag[i] != 0:
		var f: Flag = flags[flag[i]]
		if f.bld == 0:
			remove_flag(f)
			return true
	return false

func kill_good(g: Good) -> void:
	var b = blds.get(g.dest)
	if b != null:
		b.incoming[g.t] = maxi(0, b.incoming.get(g.t, 0) - 1)
	g.dest = -1

func passable(x: int, y: int, goal: bool, walk: bool = false) -> bool:
	if not inb(x, y):
		return false
	var i := y * MW + x
	if Data.WALK[ground[i]] == 0 or not no_obj(i) or occ[i] != 0:
		return false
	if road[i] != 0 and not goal and not walk:
		return false
	return true

const DIRS8 := [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [-1, 1], [1, -1], [-1, -1]]

func find_path(sx: int, sy: int, gx: int, gy: int, walk: bool = false) -> Array:
	# 8 Richtungen (Diagonalen wie bei Siedler 2). walk=true: Pixler laufen auch ueber Wege.
	if sx == gx and sy == gy:
		return []
	if not passable(gx, gy, true, walk):
		return []
	var open: Array = []
	_hpush(open, 0.0, sy * MW + sx)
	var came := {}
	var gs := {sy * MW + sx: 0.0}
	var goal := gy * MW + gx
	var closed := {}
	var expanded := 0
	while open.size() > 0:
		var cur: int = _hpop(open)
		if closed.has(cur):
			continue
		closed[cur] = true
		if cur == goal:
			var path: Array = []
			var c := cur
			while true:
				path.push_front([c % MW, c / MW])
				if not came.has(c):
					break
				c = came[c]
			return path
		var cx := cur % MW
		var cy := cur / MW
		expanded += 1
		if expanded > 60000:
			return []
		var pdx := 0
		var pdy := 0
		if came.has(cur):
			pdx = cx - came[cur] % MW
			pdy = cy - came[cur] / MW
		for d in DIRS8:
			var nx: int = cx + d[0]
			var ny: int = cy + d[1]
			var ni := ny * MW + nx
			if closed.has(ni) or not passable(nx, ny, ni == goal, walk):
				continue
			var cost := 1.0
			# Kleine Kurvenstrafe: Wege bleiben gerade statt zu zacken
			if not walk and (d[0] != pdx or d[1] != pdy) and (pdx != 0 or pdy != 0):
				cost += 0.12
			if d[0] != 0 and d[1] != 0:
				# Diagonale: keine Ecken schneiden, keine X-Kreuzung mit anderen Wegen
				if not passable(cx + d[0], cy, true, true) or not passable(cx, cy + d[1], true, true):
					continue
				if not walk:
					var sa: int = cy * MW + cx + d[0]
					var sb: int = (cy + d[1]) * MW + cx
					if (road[sa] != 0 or flag[sa] != 0) and (road[sb] != 0 or flag[sb] != 0):
						continue
				cost += 0.4142
			if walk and (road[ni] != 0 or flag[ni] != 0):
				cost *= 0.6
			var ng: float = gs[cur] + cost
			if not gs.has(ni) or ng < gs[ni]:
				gs[ni] = ng
				came[ni] = cur
				var ddx: float = abs(gx - nx)
				var ddy: float = abs(gy - ny)
				var hh: float = ((ddx + ddy) - 0.5858 * minf(ddx, ddy)) * (0.6 if walk else 1.001)
				_hpush(open, ng + hh, ni)
	return []

func _hpush(h: Array, f: float, v: int) -> void:
	h.append([f, v])
	var i := h.size() - 1
	while i > 0:
		var p := (i - 1) >> 1
		if h[p][0] <= h[i][0]:
			break
		var tmp = h[p]
		h[p] = h[i]
		h[i] = tmp
		i = p

func _hpop(h: Array) -> int:
	var top: int = h[0][1]
	var last = h.pop_back()
	if h.size() > 0:
		h[0] = last
		var i := 0
		var n := h.size()
		while true:
			var l := i * 2 + 1
			var r := l + 1
			var m := i
			if l < n and h[l][0] < h[m][0]:
				m = l
			if r < n and h[r][0] < h[m][0]:
				m = r
			if m == i:
				break
			var tmp = h[m]
			h[m] = h[i]
			h[i] = tmp
			i = m
	return top

func add_road(cells: Array) -> bool:
	var n := cells.size()
	if n < 2:
		return false
	var bp: Array = [0]
	var last := 0
	for k in range(1, n):
		var isf: bool = flag[cells[k][1] * MW + cells[k][0]] != 0
		if isf or k == n - 1:
			bp.append(k)
			last = k
		elif k - last >= ROAD_SEG and n - 1 - k >= ROAD_SEG / 2:
			bp.append(k)
			last = k
		clear_soft(cells[k][1] * MW + cells[k][0])
	var fl: Array = []
	for k in bp:
		fl.append(create_flag(cells[k][0], cells[k][1]))
	for j in range(bp.size() - 1):
		_mk_seg(fl[j], fl[j + 1], cells.slice(bp[j], bp[j + 1] + 1), false)
		# Segmentzellen, die noch als Feld markiert waren, freigeben
		for k in range(bp[j], bp[j + 1] + 1):
			field[cells[k][1] * MW + cells[k][0]] = 0
	return true

func undo_road(cells: Array) -> bool:
	var any := false
	for c in cells:
		var i: int = c[1] * MW + c[0]
		if road[i] != 0:
			_del_seg(segs[road[i]], true)
			any = true
	# uebrig gebliebene, unverbundene Endflaggen ohne Gebaeude entfernen
	for c in cells:
		var i: int = c[1] * MW + c[0]
		if flag[i] != 0:
			var f: Flag = flags[flag[i]]
			if f.segs.is_empty() and f.bld == 0:
				remove_flag(f)
				any = true
	return any

# ---------------------------------------------------------------- Routing
func dist_map(src: int) -> Dictionary:
	var c = _dcache.get(src)
	if c != null and c.ver == net_ver:
		return c.d
	var d := {src: 0.0}
	var open: Array = [src]
	var done := {}
	while open.size() > 0:
		var bi := 0
		var bv: float = d[open[0]]
		for i in range(1, open.size()):
			if d[open[i]] < bv:
				bv = d[open[i]]
				bi = i
		var u: int = open[bi]
		open.remove_at(bi)
		if done.has(u):
			continue
		done[u] = true
		for s in flags[u].segs:
			var o: int = s.b if s.a == u else s.a
			var nd: float = bv + s.L
			if not d.has(o) or nd < d[o]:
				d[o] = nd
				open.append(o)
	_dcache[src] = {"ver": net_ver, "d": d}
	return d

func _dd(b, fid: int) -> float:
	# kleinste Wegdistanz von Flagge fid zu einer Tuer von Gebaeude b
	var best := 1e9
	for k in b.fids:
		var v: float = dist_map(k).get(fid, 1e9)
		if v < best:
			best = v
	return best

func _dd2(b1, b2) -> Array:
	# [distanz, flagge_an_b2] zwischen den Tueren zweier Gebaeude
	var best := 1e9
	var bf := -1
	for k2 in b2.fids:
		var dm := dist_map(k2)
		for k1 in b1.fids:
			var v: float = dm.get(k1, 1e9)
			if v < best:
				best = v
				bf = k2
	return [best, bf]

func next_seg(g: Good, f: Flag):
	var b = blds.get(g.dest)
	if b == null or f.id in b.fids:
		return null
	if _dd(b, f.id) >= 1e8:
		return null
	var best = null
	var bv := 1e9
	for s in f.segs:
		var o: int = s.b if s.a == f.id else s.a
		var v: float = s.L + _dd(b, o)
		if v < bv:
			bv = v
			best = s
	return best if bv < 1e8 else null

func wants(g: Good, f: Flag, s: Seg) -> bool:
	if g.dest <= 0:
		return false
	if next_seg(g, f) != s:
		return false
	var o: Flag = flags[s.b] if s.a == f.id else flags[s.a]
	if o.goods.size() < FLAG_CAP:
		return true
	var b = blds.get(g.dest)
	return b != null and o.id in b.fids

func miss(b, g: String) -> int:
	if b.paused:
		return 0
	return b.cap.get(g, 0) - b.inbox.get(g, 0) - b.incoming.get(g, 0)

func deliver(g: Good, b) -> void:
	if b.done and Data.BD[b.type].kind == "store":
		b.stock[g.t] = b.stock.get(g.t, 0) + 1
	else:
		b.inbox[g.t] = b.inbox.get(g.t, 0) + 1
		b.incoming[g.t] = maxi(0, b.incoming.get(g.t, 0) - 1)
	g.dest = -1

func assign_dest(g: Good, f: Flag) -> void:
	var best = null
	var bv := 1e9
	for b in blds.values():
		if Data.BD[b.type].kind == "store" and b.done:
			continue
		if miss(b, g.t) > 0:
			var d := _dd(b, f.id)
			if d < 1e8:
				var v: float = d - (25.0 if not b.done else 0.0)
				if v < bv:
					bv = v
					best = b
	if best != null:
		g.dest = best.id
		best.incoming[g.t] = best.incoming.get(g.t, 0) + 1
		return
	for b in blds.values():
		if Data.BD[b.type].kind == "store" and b.done:
			var d := _dd(b, f.id)
			if d < 1e8 and (d < bv or best == null):
				bv = d
				best = b
	if best != null:
		g.dest = best.id

func spawn_good(t: String, f: Flag, dest: int = 0) -> Good:
	var g := Good.new()
	g.t = t
	g.fid = f.id
	g.dest = dest
	f.goods.append(g)
	return g

func emit(b, tp: String, n: int) -> void:
	var f: Flag = flags[b.fid]
	for i in n:
		var g := spawn_good(tp, f)
		assign_dest(g, f)
		_arrive_check(g, f)

func _arrive_check(g: Good, f: Flag) -> void:
	var b = blds.get(g.dest)
	if b != null and f.id in b.fids:
		f.goods.erase(g)
		deliver(g, b)

func dispatch() -> void:
	for f in flags.values():
		for g in f.goods.duplicate():
			if g.dest == 0:
				assign_dest(g, f)
				_arrive_check(g, f)
			elif g.dest > 0 and not blds.has(g.dest):
				g.dest = 0
	var reqs: Array = []
	for b in blds.values():
		if b.done and Data.BD[b.type].kind == "store":
			continue
		for g in b.cap:
			if miss(b, g) > 0:
				reqs.append([0 if not b.done else 1, b, g])
	# Baustellen zuerst, dort nach Prioritaet (hoch zuerst), dann aelteste zuerst
	reqs.sort_custom(func(p, q):
		if p[0] != q[0]:
			return p[0] < q[0]
		if p[1].prio != q[1].prio:
			return p[1].prio > q[1].prio
		return p[1].id < q[1].id)
	for r in reqs:
		var b = r[1]
		var g: String = r[2]
		# aeltester Bedarf wird komplett bedient, bevor der naechste drankommt
		var guard := 0
		while miss(b, g) > 0 and guard < 6:
			guard += 1
			var best = null
			var bv := 1e9
			var bflag := -1
			for s in blds.values():
				if s.done and Data.BD[s.type].kind == "store" and s.stock.get(g, 0) > 0:
					var res := _dd2(b, s)
					if res[0] < 1e8 and res[0] < bv and flags[res[1]].goods.size() < FLAG_CAP - 2:
						bv = res[0]
						best = s
						bflag = res[1]
			if best == null:
				break
			best.stock[g] -= 1
			b.incoming[g] = b.incoming.get(g, 0) + 1
			best.out_q.append({"t": g, "dest": b.id, "fid": bflag})

# ---------------------------------------------------------------- Träger
func seg_pos(s: Seg) -> Vector2:
	if s.st == "arrive":
		var n := s.arr.size()
		var k := clampi(int(floor(s.arr_d)), 0, n - 1)
		var k2 := mini(k + 1, n - 1)
		var fr := s.arr_d - k
		return Vector2(lerpf(s.arr[k][0], s.arr[k2][0], fr) + 0.5, lerpf(s.arr[k][1], s.arr[k2][1], fr) + 0.5)
	var k := clampi(int(floor(s.p)), 0, s.L)
	var k2 := mini(k + 1, s.L)
	var fr := s.p - k
	var c1 = s.cells[k]
	var c2 = s.cells[k2]
	return Vector2(lerpf(c1[0], c2[0], fr) + 0.5, lerpf(c1[1], c2[1], fr) + 0.5)

func _sc(s: Seg, tp: float) -> float:
	# Diagonale Wegstuecke sind laenger: Traeger laufen dort entsprechend langsamer pro Zelle
	var k := clampi(int(floor(s.p)), 0, s.L - 1)
	if tp < s.p and absf(s.p - floorf(s.p)) < 0.0001:
		k = clampi(k - 1, 0, s.L - 1)
	var a: Array = s.cells[k]
	var b: Array = s.cells[k + 1]
	return 1.0 if (a[0] == b[0] or a[1] == b[1]) else 0.7071

func cap_of(s: Seg) -> int:
	return BARROW_N if s.barrow else CARRY_N

func _waiting(s: Seg, f: Flag) -> int:
	var n := 0
	for g in f.goods:
		if wants(g, f, s):
			n += 1
	return n

func find_job(s: Seg) -> int:
	var fa: Flag = flags[s.a]
	var fb: Flag = flags[s.b]
	var na := _waiting(s, fa)
	var nb := _waiting(s, fb)
	if na + nb == 0:
		return -1
	if not s.barrow and barrows_free > 0 and (fa.goods.size() > BARROW_AT or fb.goods.size() > BARROW_AT) and maxi(na, nb) >= 2:
		barrows_free -= 1
		s.barrow = true
	return 0 if na >= nb else 1

func _pick(s: Seg, f: Flag) -> void:
	var i := 0
	while i < f.goods.size() and s.load.size() < cap_of(s):
		var g: Good = f.goods[i]
		if wants(g, f, s):
			s.load.append(g)
			f.goods.remove_at(i)
		else:
			i += 1

func _unload(s: Seg, f: Flag) -> void:
	var rest: Array = []
	for g in s.load:
		var b = blds.get(g.dest)
		if b != null and f.id in b.fids:
			deliver(g, b)
		else:
			rest.append(g)
	var back: Array = []
	if rest.size() > 0:
		var room := FLAG_CAP - f.goods.size()
		var need := rest.size() - room
		if need > 0:
			# Flagge voll: ablegen nur, wenn gleich Gegenware mitgenommen wird
			var cand: Array = []
			for i in f.goods.size():
				var og: Good = f.goods[i]
				if og.dest > 0 and next_seg(og, f) == s:
					cand.append(i)
			if cand.size() < need:
				s.load = rest
				return
			for k in need:
				var og2: Good = f.goods[cand[k]]
				var g2: Good = rest[k]
				g2.fid = f.id
				f.goods[cand[k]] = g2
				back.append(og2)
			rest = rest.slice(need)
		for g in rest:
			g.fid = f.id
			f.goods.append(g)
	s.load = back
	_pick(s, f)
	if s.load.size() > 0:
		s.st = "carry"
		s.end = 1 - s.end
	else:
		s.st = "mid"

func arrival_path(s: Seg) -> Array:
	# Weg vom naechsten Lager (Tuerflagge) bis zur Mitte des Segments
	var starts: Array = []
	for b in blds.values():
		if b.done and Data.BD[b.type].kind == "store":
			for k in b.fids:
				starts.append(k)
	if starts.is_empty():
		return []
	var mid: int = s.L / 2
	var best: Array = []
	for side in 2:
		var from_fid: int = s.a if side == 0 else s.b
		var seg_cells: Array
		if side == 0:
			seg_cells = s.cells.slice(0, mid + 1)
			seg_cells.pop_front()
		else:
			seg_cells = s.cells.slice(mid, s.L + 1)
			seg_cells.reverse()
			seg_cells.pop_front()
		var d := {from_fid: 0.0}
		var prev := {}
		var open: Array = [from_fid]
		var done := {}
		var hit := -1
		while open.size() > 0:
			var bi := 0
			for i in range(1, open.size()):
				if d[open[i]] < d[open[bi]]:
					bi = i
			var u: int = open[bi]
			open.remove_at(bi)
			if done.has(u):
				continue
			done[u] = true
			if u in starts:
				hit = u
				break
			for sg in flags[u].segs:
				if sg == s:
					continue
				var o: int = sg.b if sg.a == u else sg.a
				var nd: float = d[u] + sg.L
				if not d.has(o) or nd < d[o]:
					d[o] = nd
					prev[o] = [u, sg]
					open.append(o)
		if hit < 0:
			continue
		var cells: Array = [[flags[hit].x, flags[hit].y]]
		var cur := hit
		while cur != from_fid:
			var pr: Array = prev[cur]
			var sg: Seg = pr[1]
			var cc: Array = sg.cells.duplicate()
			# Zellen von cur nach pr[0] laufen
			if sg.a != cur:
				cc.reverse()
			cc.pop_front()
			cells.append_array(cc)
			cur = pr[0]
		cells.append_array(seg_cells)
		if best.is_empty() or cells.size() < best.size():
			best = cells
	return best

func upd_seg(s: Seg, dt: float) -> void:
	if s.st == "wait_car":
		s.chk -= dt
		if s.chk <= 0.0:
			s.chk = 0.6
			if free_now <= 0:
				return   # kein freier Pixler fuer diesen Traeger
			var p := arrival_path(s)
			if p.size() > 0:
				s.arr = p
				s.arr_d = 0.0
				s.st = "arrive"
				free_now -= 1
		return
	if s.st == "arrive":
		s.arr_d += 3.2 * K * WALK_MULT * dt
		if s.arr_d >= s.arr.size() - 1:
			s.p = float(s.L / 2)
			s.st = "idle"
			s.arr = []
		return
	var spd := (2.2 if s.load.size() > 0 else 3.0) * K * WALK_MULT * dt
	match s.st:
		"idle", "mid":
			if s.st == "mid":
				s.p = move_toward(s.p, s.L * 0.5, spd * _sc(s, s.L * 0.5))
			s.chk -= dt
			if s.chk <= 0.0:
				s.chk = 0.15
				var e := find_job(s)
				if e >= 0:
					s.end = e
					s.st = "pick"
					s.idle_t = 0.0
					return
				s.idle_t += 0.15
				if s.barrow and s.idle_t > 8.0:
					s.barrow = false
					barrows_free += 1
			if s.st == "mid" and absf(s.p - s.L * 0.5) < 0.01:
				s.st = "idle"
		"pick":
			var tp := 0.0 if s.end == 0 else float(s.L)
			s.p = move_toward(s.p, tp, spd * _sc(s, tp))
			if absf(s.p - tp) < 0.001:
				var f: Flag = flags[s.a] if s.end == 0 else flags[s.b]
				_pick(s, f)
				if s.load.size() > 0:
					s.st = "carry"
					s.end = 1 - s.end
				else:
					s.st = "mid"
		"carry":
			var tp := 0.0 if s.end == 0 else float(s.L)
			s.p = move_toward(s.p, tp, spd * _sc(s, tp))
			if absf(s.p - tp) < 0.001:
				var f: Flag = flags[s.a] if s.end == 0 else flags[s.b]
				_unload(s, f)

# ---------------------------------------------------------------- Gebäude
func _door_ok(dx: int, dy: int, force: bool) -> bool:
	if not inb(dx, dy):
		return false
	var di := dy * MW + dx
	if Data.WALK[ground[di]] == 0 or occ[di] != 0:
		return false
	if not force and not no_obj(di):
		return false
	if flag[di] != 0 and flags[flag[di]].bld != 0:
		return false
	return true

func door_offsets(type: String, x: int, y: int, force: bool = false) -> Array:
	# Tuer-Flaggen als Offsets zur linken oberen Gebaeudeecke. Bei Gebaeuden mit einer Tuer wird die
	# beste freie Zelle unter der Vorderseite gewaehlt (Mitte zuerst), vorhandene Wege duerfen angedockt werden.
	var d: Dictionary = Data.BD[type]
	if d.has("doors"):
		var res: Array = []
		for dd in d.doors:
			if not _door_ok(x + dd[0], y + dd[1], force):
				return []
			res.append(dd)
		return res
	var mid: int = d.w / 2
	var order: Array = [mid, mid - 1, mid + 1, mid - 2, mid + 2]
	for k in range(d.w):
		if not k in order:
			order.append(k)
	for ox in order:
		if ox >= 0 and ox < d.w and _door_ok(x + ox, y + d.h, force):
			return [[ox, d.h]]
	return []

func can_place(type: String, x: int, y: int) -> String:
	var d: Dictionary = Data.BD[type]
	for yy in range(y, y + d.h):
		for xx in range(x, x + d.w):
			if not inb(xx, yy):
				return "Außerhalb der Karte"
			var i := yy * MW + xx
			if Data.WALK[ground[i]] == 0:
				return "Hier ist kein fester Boden"
			if not no_obj(i) or occ[i] != 0:
				return "Der Platz ist belegt"
			if road[i] != 0 or flag[i] != 0:
				return "Straße im Weg"
	if door_offsets(type, x, y).is_empty():
		return "Vor der Tür ist kein Platz für die Flagge"
	if (d.kind == "gather" or d.kind == "process" or type == "lager") and used_workers() + carrier_count() >= pop:
		return "Keine freien Pixler! Baue Wohnhäuser und die Taverne, dann ziehen neue ein."
	if d.has("need") and not has_resource(type, x, y):
		match d.need:
			"tree": return "Hier gibt es keine Bäume in Reichweite"
			"rock": return "Hier gibt es keine Felsen in Reichweite"
			"fish": return "Hier ist kein Wasser in Reichweite"
			"deer": return "Hier gibt es kein Wild in Reichweite"
			"field": return "Hier ist kein freies Grasland"
			"fairy": return "Keine Leuchtblumen in Reichweite (Feenwald)"
			"shroom": return "Keine Glühpilze in Reichweite (Sumpf)"
			"herb": return "Keine Kräuter in Reichweite"
			"mush": return "Keine Pilze in Reichweite (Wald)"
			"lava": return "Keine Lava in Reichweite"
			"ice": return "Kein Eis in Reichweite"
			"sand": return "Kein Wüstensand in Reichweite"
			"plant": return "Kein freier Boden zum Pflanzen"
	return ""

func place_building(type: String, x: int, y: int, instant: bool = false) -> Bld:
	var d: Dictionary = Data.BD[type]
	var b := Bld.new()
	b.id = nid
	nid += 1
	b.type = type
	b.x = x
	b.y = y
	b.w = d.w
	b.h = d.h
	for yy in range(y, y + d.h):
		for xx in range(x, x + d.w):
			occ[yy * MW + xx] = b.id
			field[yy * MW + xx] = 0
			if obj[yy * MW + xx] != 0:
				set_obj(yy * MW + xx, 0)   # Kraeuter & Co. werden einfach weggeraeumt
	var doors := door_offsets(type, x, y, instant)
	if doors.is_empty():
		doors = [[d.w / 2, d.h]]
	for dd in doors:
		if obj[(y + dd[1]) * MW + x + dd[0]] != 0:
			set_obj((y + dd[1]) * MW + x + dd[0], 0)
		var f := create_flag(x + dd[0], y + dd[1])
		f.bld = b.id
		b.fids.append(f.id)
	b.fid = b.fids[b.fids.size() / 2]
	blds[b.id] = b
	var tot := 0
	for k in d.cost:
		tot += d.cost[k]
	b.build_t = 5.0 + tot * 1.2
	if instant:
		_finish(b)
	else:
		b.cap = d.cost.duplicate()
	net_ver += 1
	return b

func _finish(b: Bld) -> void:
	var d: Dictionary = Data.BD[b.type]
	var upgraded := b.upg
	if b.upg:
		b.level += 1
		b.upg = false
		b.fed = 0
	b.done = true
	b.inbox = {}
	b.incoming = {}
	b.cap = {}
	b.bw = false
	if d.has("ins"):
		for k in d.ins:
			b.cap[k] = maxi(2, d.ins[k] * 2)
	if d.has("alt"):
		for k in d.alt:
			b.cap[k] = 2
	if d.kind == "house":
		b.cap = {"gericht": 2, "wasser": 2}
		b.feed_t = 20.0
	b.st = "idle"
	b.timer = 0.5
	if d.has("keepers") and b.keepers.is_empty():
		for k in d.keepers:
			var kp := Keeper.new()
			kp.home = Vector2(b.x + b.w * 0.5, b.y + b.h * 0.5)
			kp.x = kp.home.x
			kp.y = kp.home.y
			b.keepers.append(kp)
	if d.kind == "lm":
		landmarks[b.type] = true
		events.append(["lm", d.n, b.x + b.w * 0.5, b.y + b.h * 0.5])
	if b.type == "ranch":
		for k in 3:
			var a := Animal.new()
			a.kind = "sheep" if k < 2 else "pig"
			a.x = b.x + rng.randf_range(1.0, b.w - 1.0)
			a.y = b.y + b.h + 1.0 + rng.randf() * 2.0
			a.tx = a.x
			a.ty = a.y
			a.home = b
			animals.append(a)
	if upgraded:
		events.append(["up", "%s: jetzt %s (%d Plätze)" % [d.n, Data.HOUSE_NAME[b.level], Data.HOUSE_CAP[b.level]], b.x + b.w * 0.5, b.y + b.h * 0.5])
	else:
		events.append(["done", d.n, b.x + b.w * 0.5, b.y + b.h * 0.5])

func upgrade_error(b: Bld) -> String:
	if b.type != "haus" or not b.done:
		return "Hier gibt es nichts auszubauen."
	if b.level >= 3:
		return "Das ist schon die höchste Stufe."
	if b.fed < Data.HOUSE_UP[b.level].fed:
		return "Die Bewohner müssen erst besser versorgt werden (Gerichte und Wasser)."
	return ""

func start_upgrade(b: Bld) -> String:
	var err := upgrade_error(b)
	if err != "":
		return err
	b.upg = true
	b.done = false
	b.prog = 0.0
	b.inbox = {}
	b.incoming = {}
	b.cap = Data.HOUSE_UP[b.level].cost.duplicate()
	var tot := 0
	for k in b.cap:
		tot += b.cap[k]
	b.build_t = 5.0 + tot * 1.2
	b.msg = ""
	return ""

func _nearest_store(x: float, y: float, skip = null):
	var best = null
	var bv := 1e9
	for s in blds.values():
		if s != skip and s.done and Data.BD[s.type].kind == "store":
			var v := Vector2(s.x + s.w * 0.5 - x, s.y + s.h * 0.5 - y).length()
			if v < bv:
				bv = v
				best = s
	return best

func can_demolish(b: Bld) -> bool:
	# Langhaus und Lagerhaeuser sind der Kern der Logistik und lassen sich nicht abreissen
	return b.type != "hq" and b.type != "lager"

func progress(b: Bld) -> float:
	# Fortschritt der laufenden Taetigkeit 0..1, -1 wenn nichts laeuft
	var d: Dictionary = Data.BD[b.type]
	if not b.done:
		return b.prog if b.bw or b.prog > 0.0 else -1.0
	if d.kind == "house":
		return 1.0 - clampf(b.feed_t / 30.0, 0.0, 1.0)
	if d.kind == "store" or d.kind == "lm" or b.paused:
		return -1.0
	match b.st:
		"work":
			return 1.0 - clampf(b.timer / maxf(b.ptot, 0.01), 0.0, 1.0)
		"walk":
			var dst := Vector2(b.tg.x + 0.5 - b.wx, b.tg.y + 0.5 - b.wy).length() if b.tg != null and not b.tg.has("animal") else b.d0 * 0.5
			return 0.4 * (1.0 - clampf(dst / b.d0, 0.0, 1.0))
		"act":
			return 0.4 + 0.3 * (1.0 - clampf(b.timer / maxf(b.ptot, 0.01), 0.0, 1.0))
		"back":
			var f: Flag = flags[b.fid]
			var dst2 := Vector2(f.x + 0.5 - b.wx, f.y + 0.5 - b.wy).length()
			return 0.7 + 0.2 * (1.0 - clampf(dst2 / b.d0, 0.0, 1.0))
		"rest":
			return 0.9 + 0.1 * (1.0 - clampf(b.timer / maxf(b.ptot, 0.01), 0.0, 1.0))
		"out", "ret":
			return 1.0
	return -1.0

func demolish(b: Bld) -> void:
	if not can_demolish(b):
		return
	var d: Dictionary = Data.BD[b.type]
	# Waren zurueck ins naechste Lager: Inhalt, Lagerbestand, halbe Baukosten fertiger Gebaeude
	var refund := {}
	for k in b.inbox:
		refund[k] = refund.get(k, 0) + b.inbox[k]
	if b.done:
		for k in d.cost:
			refund[k] = refund.get(k, 0) + (d.cost[k] + 1) / 2
		if b.type == "haus":
			for lv in range(1, b.level):
				for k in Data.HOUSE_UP[lv].cost:
					refund[k] = refund.get(k, 0) + (Data.HOUSE_UP[lv].cost[k] + 1) / 2
	for k in b.stock:
		refund[k] = refund.get(k, 0) + b.stock[k]
	var rs = _nearest_store(b.x + b.w * 0.5, b.y + b.h * 0.5, b)
	var n_back := 0
	if rs != null:
		for k in refund:
			if refund[k] > 0:
				rs.stock[k] = rs.stock.get(k, 0) + refund[k]
				n_back += refund[k]
	if n_back > 0:
		events.append(["refund", "%d Waren zurück ins Lager" % n_back, b.x + b.w * 0.5, b.y + b.h * 0.5])
	if d.kind == "lm":
		landmarks.erase(b.type)
	for yy in range(b.y, b.y + b.h):
		for xx in range(b.x, b.x + b.w):
			occ[yy * MW + xx] = 0
	for i in b.fields:
		if field[i] == b.id:
			field[i] = 0
	if b.tg != null:
		if b.tg.has("i"):
			claims.erase(b.tg.i)
		if b.tg.has("animal"):
			b.tg.animal.frozen = false
	blds.erase(b.id)
	for fk in b.fids:
		var f: Flag = flags[fk]
		f.bld = 0
		if f.segs.is_empty():
			remove_flag(f)
	for a in animals.duplicate():
		if a.home == b:
			animals.erase(a)
	for fl in flags.values():
		for g in fl.goods:
			if g.dest == b.id:
				g.dest = 0
	for s in segs.values():
		for lg in s.load:
			if lg.dest == b.id:
				lg.dest = 0
	net_ver += 1

func has_inputs(b: Bld) -> bool:
	var d: Dictionary = Data.BD[b.type]
	if d.has("ins"):
		for k in d.ins:
			if b.inbox.get(k, 0) < d.ins[k]:
				return false
	if d.has("alt"):
		var n := 0
		for k in d.alt:
			if b.inbox.get(k, 0) >= 1:
				n += 1
		if n < d.get("altn", 1):
			return false
	return true

func take_inputs(b: Bld) -> void:
	var d: Dictionary = Data.BD[b.type]
	if d.has("ins"):
		for k in d.ins:
			b.inbox[k] -= d.ins[k]
	if d.has("alt"):
		var left: int = d.get("altn", 1)
		for k in d.alt:
			if left > 0 and b.inbox.get(k, 0) >= 1:
				b.inbox[k] -= 1
				left -= 1

func pick_target(b: Bld):
	var d: Dictionary = Data.BD[b.type]
	var c := bcenter(b)
	if d.need == "deer":
		var best = null
		var bv := 1e9
		for a in animals:
			if a.kind == "deer" and not a.dead and not a.frozen:
				var v := Vector2(a.x - c.x, a.y - c.y).length()
				if v <= d.R and v < bv:
					bv = v
					best = a
		if best == null:
			return null
		best.frozen = true
		return {"animal": best, "x": int(best.x), "y": int(best.y)}
	if d.need == "field":
		var own: Array = b.fields.filter(func(i): return field[i] == b.id and not claims.has(i))
		if own.size() > 0 and (b.fields.size() >= 5 * K * K or rng.randf() < 0.6):
			var i: int = own[rng.randi() % own.size()]
			claims[i] = b.id
			return {"x": i % MW, "y": i / MW, "i": i, "new": false}
		if b.fields.size() >= 5 * K * K:
			return null
	var cands := scan(d.need, c.x, c.y, d.R)
	if cands.is_empty():
		return null
	var pick: Vector2i = cands[rng.randi() % cands.size()]
	for k in 2:
		var q: Vector2i = cands[rng.randi() % cands.size()]
		if Vector2(q - c).length() < Vector2(pick - c).length():
			pick = q
	var i := pick.y * MW + pick.x
	claims[i] = b.id
	return {"x": pick.x, "y": pick.y, "i": i, "new": true}

func harvest(b: Bld, tg: Dictionary) -> void:
	var d: Dictionary = Data.BD[b.type]
	if tg.has("animal"):
		tg.animal.dead = true
		animals.erase(tg.animal)
		return
	var i: int = tg.i
	claims.erase(i)
	match d.need:
		"tree":
			set_obj(i, 0)
			set_stump(i, 1)
		"rock":
			amt[i] = maxi(0, amt[i] - 1)
			if amt[i] == 0:
				set_obj(i, 0)
		"fairy", "shroom", "herb", "mush":
			stage[i] = 0
			age[i] = 0.0
			growing[i] = true
		"plant":
			if free_ground(i):
				var g := ground[i]
				set_obj(i, Data.O.PINE if g == Data.T.SNOW else (Data.O.DEAD if g == Data.T.SWAMP else Data.O.TREE))
				set_stump(i, 0)
				stage[i] = 0
				age[i] = 0.0
				growing[i] = true
		"field":
			if tg.new and free_ground(i):
				if obj[i] != 0:
					set_obj(i, 0)
				field[i] = b.id
				b.fields.append(i)

func _upd_house(b: Bld, dt: float) -> void:
	# Bewohner essen und trinken regelmaessig; jede Versorgung zaehlt fuer den Ausbau
	b.feed_t -= dt
	if b.feed_t > 0.0:
		return
	b.feed_t = 30.0
	var has_food: bool = b.inbox.get("gericht", 0) > 0
	var has_water: bool = b.inbox.get("wasser", 0) > 0
	if has_food and has_water:
		b.inbox["gericht"] -= 1
		b.inbox["wasser"] -= 1
		b.fed = mini(b.fed + 1, 9)
		b.msg = "Versorgt"
	else:
		b.msg = "Braucht " + ("Gerichte" if not has_food else "Wasser")
		if not has_food and not has_water:
			b.msg = "Braucht Gerichte und Wasser"

func upd_bld(b: Bld, dt: float) -> void:
	var d: Dictionary = Data.BD[b.type]
	if not b.done:
		var cost := site_cost(b)
		var ok := true
		for k in cost:
			if b.inbox.get(k, 0) < cost[k]:
				ok = false
		b.busy = false
		if b.paused:
			b.msg = "Pausiert"
		elif not ok:
			b.msg = "Wartet auf Material"
		elif not b.bw:
			b.msg = "Kein Weg für Bauarbeiter: Straße zum Lager bauen" if b.retry > 0.0 else "Wartet auf Bauarbeiter"
		else:
			b.msg = "Wird gebaut"
			b.prog += dt / b.build_t
			b.busy = true
			if b.prog >= 1.0:
				_finish(b)
		return
	if d.kind == "store" or d.kind == "lm":
		return
	if d.kind == "house":
		_upd_house(b, dt)
		return
	if b.paused:
		b.msg = "Pausiert"
		b.busy = false
		return
	var f: Flag = flags[b.fid]
	match b.st:
		"idle":
			b.busy = false
			b.timer -= dt
			if b.timer > 0.0:
				return
			b.timer = 0.4
			if f.goods.size() >= FLAG_CAP - 1:
				b.msg = "Flagge voll: Straße frei machen"
				return
			if b.type == "ballon":
				for bl in balloons:
					if bl.b == b.id:
						b.msg = "Ballon ist unterwegs"
						return
			if b.type == "wagner" and barrows_total >= 30:
				b.msg = "Genug Schubkarren"
				return
			if b.type == "taverne" and pop >= pop_cap():
				b.msg = "Kein Wohnraum frei: baue Wohnhäuser"
				return
			if d.out != "" and total_stock(d.out) >= (16 if d.out in ["feenstaub", "obsidian", "gluehpilz", "sand", "glas", "eis"] else 30):
				b.msg = "Genug auf Lager"
				return
			if not has_inputs(b):
				b.msg = "Wartet auf Waren"
				return
			if d.kind == "gather":
				var tg = pick_target(b)
				if tg == null:
					b.msg = "Nichts zu tun in Reichweite"
					return
				take_inputs(b)
				b.tg = tg
				b.st = "walk"
				b.wx = f.x + 0.5
				b.wy = f.y + 0.5
				b.carry = ""
				b.msg = "Unterwegs"
				var ttx: float = tg.x + 0.5
				var tty: float = tg.y + 0.5
				if tg.has("animal"):
					ttx = tg.animal.x
					tty = tg.animal.y
				b.d0 = maxf(0.5, Vector2(ttx - b.wx, tty - b.wy).length())
			else:
				take_inputs(b)
				b.st = "work"
				b.timer = d.t
				b.ptot = d.t
				b.msg = "Arbeitet"
		"work":
			b.busy = true
			b.timer -= dt
			if b.timer <= 0.0:
				b.busy = false
				if b.type == "ballon":
					var bl := Balloon.new()
					bl.b = b.id
					var hm := balloon_home(b)
					bl.x = hm.x
					bl.y = hm.y
					balloons.append(bl)
				if b.type == "wagner":
					barrows_free += 1
					barrows_total += 1
					events.append(["barrow", "Neue Schubkarre!", b.x + b.w * 0.5, b.y])
				if b.type == "taverne":
					if pop < pop_cap():
						pop += 1
					meals += 1
					events.append(["meal", "Ein neuer Pixler zieht ein!", b.x + b.w * 0.5, b.y])
				if d.out != "":
					# Ware wird vom Pixler selbst vor die Tuer gelegt
					var sp := _keeper_start(b, f)
					b.wx = sp.x
					b.wy = sp.y
					b.carry = d.out
					b.st = "out"
					b.msg = "Liefert aus"
				else:
					b.st = "idle"
					b.timer = 0.3
		"out":
			b.busy = false
			var ftx := f.x + 0.5
			var fty := f.y + 0.5
			var odv := Vector2(ftx - b.wx, fty - b.wy)
			var ostep := 2.3 * K * WALK_MULT * dt
			if odv.length() <= ostep:
				if f.goods.size() >= FLAG_CAP:
					b.msg = "Flagge voll: Straße frei machen"
					return
				b.wx = ftx
				b.wy = fty
				emit(b, d.out, d.outn)
				b.carry = ""
				b.st = "ret"
			else:
				odv = odv.normalized() * ostep
				b.wx += odv.x
				b.wy += odv.y
				if absf(odv.x) > 0.01:
					b.face = 1 if odv.x > 0 else -1
		"ret":
			var rp := _keeper_start(b, f)
			var rdv := rp - Vector2(b.wx, b.wy)
			var rstep := 2.3 * K * WALK_MULT * dt
			if rdv.length() <= rstep:
				b.st = "idle"
				b.timer = 0.3
			else:
				rdv = rdv.normalized() * rstep
				b.wx += rdv.x
				b.wy += rdv.y
				if absf(rdv.x) > 0.01:
					b.face = 1 if rdv.x > 0 else -1
		"walk":
			b.busy = true
			var tx: float = b.tg.x + 0.5
			var ty: float = b.tg.y + 0.5
			if b.tg.has("animal"):
				var an = b.tg.animal
				tx = an.x
				ty = an.y
			var dv := Vector2(tx - b.wx, ty - b.wy)
			var step := 2.3 * K * WALK_MULT * dt
			if dv.length() <= step:
				b.wx = tx
				b.wy = ty
				b.st = "act"
				b.timer = d.t * 0.4
				b.ptot = b.timer
			else:
				dv = dv.normalized() * step
				b.wx += dv.x
				b.wy += dv.y
				if absf(dv.x) > 0.01:
					b.face = 1 if dv.x > 0 else -1
		"act":
			b.timer -= dt
			if b.timer <= 0.0:
				harvest(b, b.tg)
				b.tg = null
				b.carry = d.out
				b.st = "back"
				b.d0 = maxf(0.5, Vector2(f.x + 0.5 - b.wx, f.y + 0.5 - b.wy).length())
		"back":
			var tx := f.x + 0.5
			var ty := f.y + 0.5
			var dv := Vector2(tx - b.wx, ty - b.wy)
			var step := 2.3 * K * WALK_MULT * dt
			if dv.length() <= step:
				b.wx = tx
				b.wy = ty
				if d.out != "":
					emit(b, d.out, 1)
				b.carry = ""
				b.st = "rest"
				b.timer = d.t * 0.5
				b.ptot = b.timer
			else:
				dv = dv.normalized() * step
				b.wx += dv.x
				b.wy += dv.y
				if absf(dv.x) > 0.01:
					b.face = 1 if dv.x > 0 else -1
		"rest":
			b.busy = false
			b.timer -= dt
			if b.timer <= 0.0:
				b.st = "idle"
				b.timer = 0.2

# ---------------------------------------------------------------- Ökologie & Tiere
func upd_eco() -> void:
	for i in growing.keys():
		age[i] += 1.0
		var need := 22.0
		if age[i] >= need:
			age[i] = 0.0
			stage[i] += 1
			if stage[i] >= 3:
				growing.erase(i)
	for k in 24 * K * K:
		var i := rng.randi() % NT
		var o := obj[i]
		if (o == Data.O.TREE or o == Data.O.PINE or o == Data.O.DEAD) and stage[i] == 3 and rng.randf() < 0.05:
			var x := i % MW + rng.randi_range(-2 * K, 2 * K)
			var y := i / MW + rng.randi_range(-2 * K, 2 * K)
			if inb(x, y):
				var j := y * MW + x
				var want := Data.T.GRASS if o == Data.O.TREE else (Data.T.SNOW if o == Data.O.PINE else Data.T.SWAMP)
				if ground[j] == want and free_ground(j):
					set_obj(j, o)
					stage[j] = 0
					age[j] = 0.0
					growing[j] = true
	var deer := 0
	var rab := 0
	for a in animals:
		if a.kind == "deer": deer += 1
		elif a.kind == "rabbit": rab += 1
	if deer < 44 and rng.randf() < 0.2:
		spawn_animal("deer")
	if rab < 32 and rng.randf() < 0.2:
		spawn_animal("rabbit")
	# Idle-Pixler um das HQ
	var want_idle := clampi(free_pixlers(), 0, 12)
	while idlers.size() < want_idle:
		var a := Animal.new()
		a.kind = "idler"
		a.x = HQ_POS.x + 4.0 + rng.randf() * 3.0
		a.y = HQ_POS.y + 6.0 + rng.randf() * 2.0
		a.tx = a.x
		a.ty = a.y
		a.home = blds.get(blds.keys()[0])
		idlers.append(a)
	while idlers.size() > want_idle:
		idlers.pop_back()

func _wander(a: Animal, dt: float) -> void:
	if a.frozen or a.dead:
		return
	var speed := (1.2 if a.kind == "deer" else (1.6 if a.kind == "rabbit" else 0.7)) * K
	if a.kind == "idler":
		speed = 1.1 * K * WALK_MULT
	if a.moving:
		var dv := Vector2(a.tx - a.x, a.ty - a.y)
		var st := speed * dt
		if dv.length() <= st:
			a.x = a.tx
			a.y = a.ty
			a.moving = false
			a.timer = rng.randf_range(1.0, 5.0)
		else:
			dv = dv.normalized() * st
			a.x += dv.x
			a.y += dv.y
			if absf(dv.x) > 0.01:
				a.face = 1 if dv.x > 0 else -1
		return
	a.timer -= dt
	if a.timer > 0.0:
		return
	a.timer = 1.0
	for tries in 4:
		var nx := a.x + rng.randf_range(-2.5 * K, 2.5 * K)
		var ny := a.y + rng.randf_range(-2.5 * K, 2.5 * K)
		var ix := int(nx)
		var iy := int(ny)
		if not inb(ix, iy) or not standable(iy * MW + ix):
			continue
		if a.home != null:
			var hc: Vector2 = Vector2(a.home.x + a.home.w * 0.5, a.home.y + a.home.h + float(K))
			var lim := 4.0 * K if a.kind != "idler" else 5.0 * K
			if Vector2(nx, ny).distance_to(hc) > lim:
				continue
		a.tx = nx
		a.ty = ny
		a.moving = true
		break

# ---------------------------------------------------------------- Bauarbeiter
func _site_ready(b: Bld) -> bool:
	if b.done or b.paused:
		return false
	var cost := site_cost(b)
	for k in cost:
		if b.inbox.get(k, 0) < cost[k]:
			return false
	return true

func _has_builder(id: int) -> bool:
	for bd in builders:
		if bd.site == id and bd.st != "back":
			return true
	return false

func _send_builder(b: Bld) -> bool:
	var fl: Flag = flags[b.fid]
	var best_f = null
	var bv := 1e9
	for s in blds.values():
		if s.done and Data.BD[s.type].kind == "store":
			for fk in s.fids:
				var sf: Flag = flags[fk]
				var v := Vector2(sf.x - fl.x, sf.y - fl.y).length()
				if v < bv:
					bv = v
					best_f = sf
	if best_f == null:
		return false
	var path: Array = [[fl.x, fl.y]] if (best_f.x == fl.x and best_f.y == fl.y) else find_path(best_f.x, best_f.y, fl.x, fl.y, true)
	if path.is_empty():
		return false
	var bd := Builder.new()
	bd.site = b.id
	bd.path = path
	bd.x = path[0][0] + 0.5
	bd.y = path[0][1] + 0.5
	if path.size() == 1:
		bd.st = "work"
	builders.append(bd)
	return true

func _walk_path(bd: Builder, dt: float, fwd: bool) -> bool:
	# true, wenn am Ende des Weges angekommen
	var n := bd.path.size()
	var k := clampi(int(floor(bd.k)), 0, n - 1)
	var k2 := mini(k + 1, n - 1)
	var stepl := 1.0
	if k2 != k and bd.path[k][0] != bd.path[k2][0] and bd.path[k][1] != bd.path[k2][1]:
		stepl = 1.4142
	bd.k = minf(bd.k + 2.8 * K * WALK_MULT * dt / stepl, float(n - 1))
	k = clampi(int(floor(bd.k)), 0, n - 1)
	k2 = mini(k + 1, n - 1)
	var fr := bd.k - k
	var nx: float = lerpf(bd.path[k][0], bd.path[k2][0], fr) + 0.5
	var ny: float = lerpf(bd.path[k][1], bd.path[k2][1], fr) + 0.5
	if absf(nx - bd.x) > 0.001:
		bd.face = 1 if nx > bd.x else -1
	bd.x = nx
	bd.y = ny
	return bd.k >= n - 1

func update_builders(dt: float) -> void:
	for b in blds.values():
		b.bw = false
	for bd in builders.duplicate():
		var b = blds.get(bd.site)
		if bd.st != "back" and (b == null or b.done or b.paused):
			# Baustelle fertig, pausiert oder abgerissen: zurueck zum Lager
			var walked: Array = bd.path.slice(0, int(floor(bd.k)) + 1)
			walked.reverse()
			bd.path = walked
			bd.k = 0.0
			bd.st = "back"
		match bd.st:
			"go":
				if _walk_path(bd, dt, true):
					bd.st = "work"
			"work":
				b.bw = true
			"back":
				if bd.path.size() < 2 or _walk_path(bd, dt, false):
					builders.erase(bd)
	var active := builders_active()
	if active >= builder_cap() or free_pixlers() <= 0:
		return
	var cands: Array = []
	for b in blds.values():
		if b.retry > 0.0:
			b.retry -= dt
		elif _site_ready(b) and not _has_builder(b.id):
			cands.append(b)
	if cands.is_empty():
		return
	cands.sort_custom(func(p, q): return p.prio > q.prio or (p.prio == q.prio and p.id < q.id))
	for b in cands:
		if builders_active() >= builder_cap() or free_pixlers() <= 0:
			break
		if not _send_builder(b):
			b.retry = 4.0
			b.msg = "Bauarbeiter finden keinen Weg: Straße zum Lager bauen"

func _keeper_move(k: Keeper, tgt: Vector2, dt: float) -> bool:
	var dv := tgt - Vector2(k.x, k.y)
	var step := 2.3 * K * WALK_MULT * dt
	if dv.length() <= step:
		k.x = tgt.x
		k.y = tgt.y
		return true
	dv = dv.normalized() * step
	k.x += dv.x
	k.y += dv.y
	if absf(dv.x) > 0.01:
		k.face = 1 if dv.x > 0 else -1
	return false

func _keeper_start(b: Bld, fl: Flag, idx: int = 0) -> Vector2:
	# Punkt zwei Zellen hinter der Tuer, im Gebaeude. Mehrere Lagerarbeiter stehen nebeneinander.
	var fp := Vector2(fl.x + 0.5, fl.y + 0.5)
	var c := Vector2(b.x + b.w * 0.5, b.y + b.h * 0.5)
	var dir := (c - fp).normalized()
	var spread := 0.0
	if b.keepers.size() > 1 and idx >= 0:
		spread = (idx - (b.keepers.size() - 1) / 2.0) * 0.9
	return fp + dir * 2.0 + Vector2(-dir.y, dir.x) * spread

func upd_keepers(dt: float) -> void:
	for b in blds.values():
		if b.keepers.is_empty():
			continue
		for k in b.keepers:
			match k.st:
				"idle":
					if b.out_q.is_empty():
						continue
					var job = b.out_q.pop_front()
					if not flags.has(job.fid):
						# Tuerflagge existiert nicht mehr: Ware zurueck ins Regal
						b.stock[job.t] = b.stock.get(job.t, 0) + 1
						var db = blds.get(job.dest)
						if db != null:
							db.incoming[job.t] = maxi(0, db.incoming.get(job.t, 0) - 1)
						continue
					k.job = job
					k.st = "load"
					k.t = 1.0
					k.x = k.home.x
					k.y = k.home.y
				"load":
					k.t -= dt
					if k.t <= 0.0:
						var fl: Flag = flags[k.job.fid]
						var s := _keeper_start(b, fl, b.keepers.find(k))
						k.x = s.x
						k.y = s.y
						k.st = "go"
				"go":
					var fl2: Flag = flags.get(k.job.fid)
					if fl2 == null:
						k.st = "back"
						continue
					if _keeper_move(k, Vector2(fl2.x + 0.5, fl2.y + 0.5), dt):
						k.st = "drop"
						k.t = 0.4
				"drop":
					k.t -= dt
					if k.t > 0.0:
						continue
					var fl3: Flag = flags.get(k.job.fid)
					if fl3 == null:
						b.stock[k.job.t] = b.stock.get(k.job.t, 0) + 1
						k.job = null
						k.st = "back"
					elif fl3.goods.size() >= FLAG_CAP:
						k.t = 0.5   # Flagge voll: warten
					else:
						var dest: int = k.job.dest if blds.has(k.job.dest) else 0
						var gd := spawn_good(k.job.t, fl3, dest)
						_arrive_check(gd, fl3)
						k.job = null
						k.st = "back"
				"back":
					if _keeper_move(k, k.home, dt):
						k.st = "idle"

func balloon_home(b) -> Vector2:
	# Hinterhof: hinter (ueber) dem Gebaeude
	return Vector2(b.x + b.w * 0.5, b.y - 4.0)

func upd_balloons(dt: float) -> void:
	for bl in balloons.duplicate():
		var b = blds.get(bl.b)
		if b == null:
			balloons.erase(bl)
			continue
		var home := balloon_home(b)
		bl.t += dt
		match bl.phase:
			"up":
				bl.h = minf(1.0, bl.h + dt / 6.0)
				bl.x = home.x
				bl.y = home.y
				if bl.h >= 1.0:
					bl.phase = "fly"
					for k in 2:
						var far := Vector2(rng.randf_range(24, MW - 24), rng.randf_range(24, MH - 24))
						while far.distance_to(home) < 100.0:
							far = Vector2(rng.randf_range(24, MW - 24), rng.randf_range(24, MH - 24))
						bl.wp.append(far)
					bl.wp.append(home)
			"fly":
				var tgt: Vector2 = bl.wp[0]
				var dv := tgt - Vector2(bl.x, bl.y)
				var st := 4.0 * dt
				if dv.length() <= st:
					bl.x = tgt.x
					bl.y = tgt.y
					bl.wp.pop_front()
					if bl.wp.is_empty():
						bl.phase = "down"
				else:
					dv = dv.normalized() * st
					bl.x += dv.x
					bl.y += dv.y
					if absf(dv.x) > 0.01:
						bl.face = 1 if dv.x > 0 else -1
			"down":
				bl.h -= dt / 6.0
				bl.x = home.x
				bl.y = home.y
				if bl.h <= 0.0:
					balloons.erase(bl)
					events.append(["barrow", "Der Ballon ist wieder gelandet.", b.x + b.w * 0.5, b.y])

func update(dt: float) -> void:
	t += dt
	_acc_disp += dt
	_acc_eco += dt
	if _acc_disp >= 0.35:
		_acc_disp = 0.0
		dispatch()
	if _acc_eco >= 1.0:
		_acc_eco = 0.0
		upd_eco()
	update_builders(dt)
	free_now = free_pixlers()
	for s in segs.values():
		upd_seg(s, dt)
	for b in blds.values():
		upd_bld(b, dt)
	for a in animals:
		_wander(a, dt)
	upd_balloons(dt)
	upd_keepers(dt)
	for a in idlers:
		_wander(a, dt)
