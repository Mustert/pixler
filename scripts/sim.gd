class_name Sim
extends RefCounted
# Welt + Simulation: Karte, Wege, frei laufende Träger, Warenverteilung, Gebäude, Tiere.
# Testvariante ohne Flaggen und Wegträger: Waren liegen in den Gebäuden (Eingang = inbox, Ausgang = outbox).
# Träger sitzen im Langhaus und in Trägerlagern und holen Waren frei laufend aus den Betrieben im Umkreis.

const MW := Data.MW
const MH := Data.MH
const NT := MW * MH
const CH := 16            # Chunk-Kantenlaenge (Zellen) fuer den Objekt-Index
const NCX := MW / CH
const NCY := MH / CH
const K := Data.K
const WALK_MULT := 0.75    # Lauftempo aller Pixler
const OFFROAD := 0.6       # Tempo-Faktor abseits von Wegen
const ROAD_SPEED := 1.0    # Tempo-Faktor auf einem Weg (spaeter: gepflasterte Wege schneller)
const OUT_CAP := 8         # Waren, die in einem Gebaeude auf Abholung warten duerfen
static var CARRY_N := 1        # Waren pro Traeger
static var BARROW_N := 3       # Waren pro Traeger mit Schubkarre
const BARROWS_START := 10
const HQ_POS := Vector2i(93 * K, 90 * K)
const BUILDERS_BASE := 3
const BUILDERS_PER_LAGER := 2
const IDLERS_MAX := 0      # sichtbare freie Pixler am Langhaus
const SEATS := 10         # Sitzplaetze im Traegerlager
const DIG_T := 3.0         # Sekunden, bis der Wegebauer eine Wegzelle geschaufelt hat

class Road:
	var id: int
	var cells: Array = []
	var bb := Rect2i()                # Zellen-Umriss (Rendering)
	var pts := PackedVector2Array()   # Rendering-Cache: Weg-Polylinie in Weltkoordinaten
	var bends := PackedVector2Array()
	var own_from: int = 0             # Index in cells, ab dem dieses Wegstueck neu zu graben ist
	var n_own: int = 0                # Anzahl zu grabender Zellen
	var dug: int = 0                  # davon schon gegraben (der Wegebauer schaufelt Zelle fuer Zelle)
	var worker: int = 0               # Wegebauer-Gebaeude, das hier gerade arbeitet

class Bld:
	var id: int
	var type: String
	var x: int
	var y: int
	var w: int
	var h: int
	var door := Vector2i(0, 0)      # Zelle vor der Tuer (hier werden Waren uebergeben)
	var done: bool = false
	var prog: float = 0.0
	var build_t: float = 8.0
	var inbox: Dictionary = {}
	var incoming: Dictionary = {}
	var cap: Dictionary = {}
	var stock: Dictionary = {}
	var outbox: Dictionary = {}     # fertige Waren, die auf einen Traeger warten
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
	var d0: float = 1.0        # Weglaenge der aktuellen Etappe (Fortschrittsanzeige)
	var ptot: float = 1.0      # Gesamtdauer der aktuellen Phase (Fortschrittsanzeige)
	var design: int = 0        # Traegerlager: 0 Steinkreis, 1 Lagerfeuer mit Staemmen, 2 Pilze
	var cn: int = 0            # gewuenschte Anzahl Traeger (0-10)
	var barrows: int = 0       # Schubkarren im Haus (hoechstens so viele wie Traeger)
	var carriers: Array = []
	var job: int = 0           # Wegebauer: Weg, der gerade gegraben wird

class Carrier:
	var hub: int
	var x: float = 0.0
	var y: float = 0.0
	var st: String = "enter"   # sit | exit | go | pick | carry | drop | ret | enter
	var seat: int = 0
	var path: Array = []
	var k: float = 0.0
	var load: Array = []       # [{t, dst}] bereits reserviert
	var src: int = 0           # Gebaeude, aus dem die Ware geholt wird (0 = schon aufgeladen)
	var to: int = 0            # Ziel der aktuellen Etappe
	var t: float = 0.0
	var face: int = 1
	var barrow: bool = false

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
var plan := PackedInt32Array()    # Zelle -> Weg, der dort noch gegraben werden soll
var doorc := PackedInt32Array()  # Zelle -> Gebaeude, dessen Tuer-Zelle sie ist
var field := PackedInt32Array()
var chunk_obj: Array = []     # pro Chunk: Dictionary Zelle -> true fuer alle Zellen mit Objekt
var chunk_stump: Array = []

var t: float = 0.0
var nid: int = 1
var blds: Dictionary = {}
var roads: Dictionary = {}
var claims: Dictionary = {}
var growing: Dictionary = {}
var animals: Array = []
var balloons: Array = []
var idlers: Array = []
var net_ver: int = 0           # zaehlt jede Aenderung an Gebaeuden/Wegen (macht gemerkte Laufwege ungueltig)
var pop: int = Data.START_POP
var free_now: int = Data.START_POP
var builders: Array = []
var barrows_free: int = BARROWS_START
var barrows_total: int = BARROWS_START
var meals: int = 0
var landmarks: Dictionary = {}
var events: Array = []   # [kind, text, x, y]  fuer UI/Partikel
var _rcache: Dictionary = {}
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
	for arr in [ground, obj, stage, amt, stump]:
		arr.resize(NT)
		arr.fill(0)
	age.resize(NT)
	age.fill(0.0)
	for arr in [occ, road, plan, doorc, field]:
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
		if k != "store" and k != "lm" and k != "house" and k != "hub" and k != "pile":
			n += 1
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
	# Pixler, die als Traeger arbeiten: sitzende und laufende Traeger (Langhaus und Traegerlager)
	var n := 0
	for b in blds.values():
		n += b.carriers.size()
	return n

func free_pixlers() -> int:
	return pop - used_workers() - carrier_count() - builders_active()

func waiting_for_pixler() -> int:
	# Traeger-Plaetze, die ohne freien Pixler leer bleiben
	var n := 0
	for b in blds.values():
		if b.done and Data.BD[b.type].has("hub"):
			n += maxi(0, b.cn - b.carriers.size())
	return n

func no_obj(i: int) -> bool:
	# true, wenn nichts Festes auf der Zelle steht (Kraeuter, Pilze & Co. zaehlen als frei)
	var o := obj[i]
	return o == 0 or Data.SOFT[o] == 1

func clear_soft(i: int) -> void:
	if obj[i] != 0 and Data.SOFT[obj[i]] == 1:
		set_obj(i, 0)

func free_ground(i: int) -> bool:
	return Data.WALK[ground[i]] == 1 and no_obj(i) and occ[i] == 0 and road[i] == 0 and field[i] == 0

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
				"fish": ok = standable(i) and road[i] == 0 and near_ground(xx, yy, [T.DEEP, T.WATER])
				"ice": ok = standable(i) and road[i] == 0 and near_ground(xx, yy, [T.ICE])
				"lava": ok = standable(i) and road[i] == 0 and near_ground(xx, yy, [T.LAVA])
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

# ---------------------------------------------------------------- Wege
func roads_unlocked() -> bool:
	# Wege gibt es erst, wenn ein Wegebauer steht
	for b in blds.values():
		if b.type == "wegebauer" and b.done:
			return true
	return false

func spd_at(i: int) -> float:
	# Tempo-Faktor der Zelle: abseits von Wegen langsamer
	return OFFROAD if road[i] == 0 else ROAD_SPEED

func _mk_road(cells: Array) -> Road:
	var r := Road.new()
	r.id = nid
	nid += 1
	r.cells = cells
	var mnx := 99999
	var mny := 99999
	var mxx := -1
	var mxy := -1
	for c in cells:
		mnx = mini(mnx, c[0])
		mny = mini(mny, c[1])
		mxx = maxi(mxx, c[0])
		mxy = maxi(mxy, c[1])
	r.bb = Rect2i(mnx, mny, mxx - mnx + 1, mxy - mny + 1)
	roads[r.id] = r
	net_ver += 1
	return r

func add_road(cells: Array) -> Array:
	# Plant den Weg, aber nur auf Zellen ohne Weg (Abschnitte, die schon Weg sind, bleiben wie sie sind).
	# Gegraben wird spaeter von einem Wegebauer (siehe _upd_digger). Gibt die IDs der neuen Wegstuecke zurueck.
	var ids: Array = []
	var n := cells.size()
	var k := 0
	while k < n:
		var i0: int = cells[k][1] * MW + cells[k][0]
		if road[i0] != 0 or plan[i0] != 0:
			k += 1
			continue
		var e := k
		while e + 1 < n and road[cells[e + 1][1] * MW + cells[e + 1][0]] == 0 and plan[cells[e + 1][1] * MW + cells[e + 1][0]] == 0:
			e += 1
		var r := _mk_road(cells.slice(maxi(k - 1, 0), mini(e + 2, n)))
		r.own_from = 1 if k > 0 else 0
		r.n_own = e - k + 1
		for q in range(k, e + 1):
			var ci: int = cells[q][1] * MW + cells[q][0]
			plan[ci] = r.id
			field[ci] = 0
			clear_soft(ci)
		ids.append(r.id)
		k = e + 1
	return ids

func road_done(r: Road) -> bool:
	return r.dug >= r.n_own

func _dig_cell(r: Road) -> Vector2i:
	var c: Array = r.cells[r.own_from + r.dug]
	return Vector2i(c[0], c[1])

func _upd_digger(b: Bld, dt: float) -> void:
	# Der Wegebauer-Pixler laeuft zu einem geplanten Weg und schaufelt ihn Zelle fuer Zelle frei
	var dp := door_pos(b)
	var r = roads.get(b.job)
	if b.st != "idle" and b.st != "back" and (r == null or road_done(r)):
		if r != null:
			r.worker = 0
		b.job = 0
		b.st = "back"
	match b.st:
		"idle":
			b.busy = false
			b.timer -= dt
			if b.timer > 0.0:
				return
			b.timer = 1.0
			var best = null
			var bv := 1e9
			for q in roads.values():
				if road_done(q) or (q.worker != 0 and blds.has(q.worker)):
					continue
				var v := Vector2(_dig_cell(q)).distance_to(Vector2(b.door))
				if v < bv:
					bv = v
					best = q
			if best == null:
				b.msg = "Bereit: Wege (R) möglich"
				return
			best.worker = b.id
			b.job = best.id
			b.wx = dp.x
			b.wy = dp.y
			b.st = "walk"
			b.msg = "Geht zum neuen Weg"
		"walk", "back":
			b.busy = true
			var tgt := dp
			if b.st == "walk":
				var c := _dig_cell(r)
				tgt = Vector2(c.x + 0.5, c.y + 0.5)
			var dv := tgt - Vector2(b.wx, b.wy)
			var step := 2.3 * K * WALK_MULT * dt
			if dv.length() <= step:
				b.wx = tgt.x
				b.wy = tgt.y
				if b.st == "walk":
					b.st = "act"
					b.timer = DIG_T
					b.ptot = DIG_T
					b.msg = "Schaufelt den Weg"
				else:
					b.st = "idle"
					b.timer = 0.5
					b.busy = false
			else:
				dv = dv.normalized() * step
				b.wx += dv.x
				b.wy += dv.y
				if absf(dv.x) > 0.01:
					b.face = 1 if dv.x > 0 else -1
		"act":
			b.busy = true
			b.timer -= dt
			if b.timer <= 0.0:
				var c := _dig_cell(r)
				var ci := c.y * MW + c.x
				road[ci] = r.id
				plan[ci] = 0
				r.dug += 1
				r.pts = PackedVector2Array()
				net_ver += 1
				if road_done(r):
					r.worker = 0
					b.job = 0
					b.st = "back"
				else:
					b.st = "walk"

func _del_road(r: Road) -> void:
	for c in r.cells:
		var i: int = c[1] * MW + c[0]
		if road[i] == r.id:
			road[i] = 0
		if plan[i] == r.id:
			plan[i] = 0
	roads.erase(r.id)
	net_ver += 1

func undo_road(ids: Array) -> bool:
	var any := false
	for id in ids:
		var r = roads.get(id)
		if r != null:
			_del_road(r)
			any = true
	return any

func remove_road_at(x: int, y: int) -> bool:
	var rid: int = road[y * MW + x]
	if rid == 0:
		return false
	_del_road(roads[rid])
	return true

# ---------------------------------------------------------------- Laufwege
func passable(x: int, y: int) -> bool:
	if not inb(x, y):
		return false
	var i := y * MW + x
	return Data.WALK[ground[i]] == 1 and no_obj(i) and occ[i] == 0

const DIRS8 := [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [-1, 1], [1, -1], [-1, -1]]

func find_path(sx: int, sy: int, gx: int, gy: int, build: bool = true, margin: int = 80) -> Array:
	# 8 Richtungen (Diagonalen wie bei Siedler 2).
	# build=true: Wegebau (Kurvenstrafe, vorhandene Wege sind guenstig). build=false: Laufweg (schnellste Zeit).
	if sx == gx and sy == gy:
		return []
	if not passable(gx, gy):
		return []
	var bx0 := maxi(0, mini(sx, gx) - margin)
	var bx1 := mini(MW - 1, maxi(sx, gx) + margin)
	var by0 := maxi(0, mini(sy, gy) - margin)
	var by1 := mini(MH - 1, maxi(sy, gy) + margin)
	var open: Array = []
	_hpush(open, 0.0, sy * MW + sx)
	var came := {}
	var gs := {sy * MW + sx: 0.0}
	var goal := gy * MW + gx
	var closed := {}
	var expanded := 0
	var hf := 0.6 if build else 1.0 / ROAD_SPEED
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
			if nx < bx0 or nx > bx1 or ny < by0 or ny > by1:
				continue
			var ni := ny * MW + nx
			if closed.has(ni) or not passable(nx, ny):
				continue
			var sl := 1.0
			if d[0] != 0 and d[1] != 0:
				# Diagonale: keine Ecken schneiden
				if not passable(cx + d[0], cy) or not passable(cx, cy + d[1]):
					continue
				sl = 1.4142
			var cost := sl
			if build:
				if road[ni] != 0:
					cost *= 0.6
			else:
				cost = sl / spd_at(ni)
			# Kleine Kurvenstrafe: Wege bleiben gerade statt zu zacken
			if (d[0] != pdx or d[1] != pdy) and (pdx != 0 or pdy != 0):
				cost += 0.12 if build else 0.03
			var ng: float = gs[cur] + cost
			if not gs.has(ni) or ng < gs[ni]:
				gs[ni] = ng
				came[ni] = cur
				var ddx: float = abs(gx - nx)
				var ddy: float = abs(gy - ny)
				var hh: float = ((ddx + ddy) - 0.5858 * minf(ddx, ddy)) * hf
				_hpush(open, ng + hh, ni)
	return []

func route(sx: int, sy: int, gx: int, gy: int) -> Array:
	# Gemerkter Laufweg (Zellen). Leer = nicht erreichbar. Das Ergebnis darf nicht veraendert werden.
	if sx == gx and sy == gy:
		return [[sx, sy]]
	var key: int = ((sy * MW + sx) << 20) | (gy * MW + gx)
	var c = _rcache.get(key)
	if c != null and c.v == net_ver and t - c.t < 40.0:
		return c.p
	if _rcache.size() > 800:
		_rcache.clear()
	var p := find_path(sx, sy, gx, gy, false, 40)
	_rcache[key] = {"v": net_ver, "t": t, "p": p}
	return p

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

func _follow(o, dt: float, base: float) -> bool:
	# Laeuft o (Traeger oder Bauarbeiter) entlang o.path. true, wenn das Ende erreicht ist.
	var n: int = o.path.size()
	if n < 2:
		return true
	var k := clampi(int(floor(o.k)), 0, n - 2)
	var a: Array = o.path[k]
	var b: Array = o.path[k + 1]
	var sl := 1.0 if (a[0] == b[0] or a[1] == b[1]) else 1.4142
	o.k = minf(o.k + base * spd_at(b[1] * MW + b[0]) * dt / sl, float(n - 1))
	k = clampi(int(floor(o.k)), 0, n - 2)
	a = o.path[k]
	b = o.path[k + 1]
	var fr: float = o.k - k
	var nx: float = lerpf(a[0], b[0], fr) + 0.5
	var ny: float = lerpf(a[1], b[1], fr) + 0.5
	if absf(nx - o.x) > 0.001:
		o.face = 1 if nx > o.x else -1
	o.x = nx
	o.y = ny
	return o.k >= n - 1 - 0.0001

func _glide(o, tgt: Vector2, dt: float) -> bool:
	# geradeaus im Gebaeude (Sitzplatz <-> Tuer), true bei Ankunft
	var dv := tgt - Vector2(o.x, o.y)
	var step := 2.3 * K * WALK_MULT * dt
	if dv.length() <= step:
		o.x = tgt.x
		o.y = tgt.y
		return true
	dv = dv.normalized() * step
	o.x += dv.x
	o.y += dv.y
	if absf(dv.x) > 0.01:
		o.face = 1 if dv.x > 0 else -1
	return false

# ---------------------------------------------------------------- Traeger
func door_pos(b) -> Vector2:
	return Vector2(b.door.x + 0.5, b.door.y + 0.5)

func is_hub(b) -> bool:
	return b.done and Data.BD[b.type].has("hub")

static func seat_off(i: int) -> Vector2:
	# Sitzplaetze liegen auf einer Ellipse um die Mitte (in Zellen); Art.gd zeichnet die Sitze an denselben Stellen
	var a := TAU * (float(i) + 0.5) / SEATS + 0.2
	return Vector2(cos(a) * 1.7, sin(a) * 1.0 + 0.15)

func seat_pos(b, i: int) -> Vector2:
	return Vector2(b.x + b.w * 0.5, b.y + b.h * 0.5) + seat_off(i)

func hub_covers(b) -> bool:
	# Gibt es ein besetztes Traegerlager (oder das Langhaus), das dieses Gebaeude erreicht?
	var c := Vector2(b.x + b.w * 0.5, b.y + b.h * 0.5)
	for h in blds.values():
		if is_hub(h) and h.carriers.size() > 0:
			if Vector2(h.x + h.w * 0.5, h.y + h.h * 0.5).distance_to(c) <= float(Data.BD[h.type].R):
				return true
	return false

func set_carriers(b, n: int) -> void:
	b.cn = clampi(n, 0, Data.CARRIERS_MAX)
	if b.barrows > b.cn:
		set_barrows(b, b.cn)

func set_barrows(b, n: int) -> void:
	# Schubkarren kommen aus dem gemeinsamen Vorrat; hoechstens so viele wie Traeger
	n = clampi(n, 0, b.cn)
	var delta: int = n - b.barrows
	if delta > 0:
		delta = mini(delta, barrows_free)
	barrows_free -= delta
	b.barrows += delta

func outbox_total(b) -> int:
	var n := 0
	for k in b.outbox:
		n += b.outbox[k]
	return n

func _goods_of(s) -> Dictionary:
	return s.stock if Data.BD[s.type].kind == "store" else s.outbox

func _reach(pos: Vector2, s) -> bool:
	return not route(int(pos.x), int(pos.y), s.door.x, s.door.y).is_empty()

func _reach_b(s, d) -> bool:
	return not route(s.door.x, s.door.y, d.door.x, d.door.y).is_empty()

func _take(s, g: String, d) -> void:
	# Die Ware wird fest eingeplant: aus dem Ausgang der Quelle genommen, beim Ziel als unterwegs vermerkt
	var goods: Dictionary = _goods_of(s)
	goods[g] = goods.get(g, 0) - 1
	d.incoming[g] = d.incoming.get(g, 0) + 1

func _find_work(hub: Bld, c: Carrier, pos: Vector2):
	# Sucht Waren im Umkreis des Lagers, die jemand braucht (oder die ins Lager sollen).
	# Rueckgabe: {"src": Gebaeude-ID, "items": [{t, dst}]} (bereits reserviert) oder null.
	var R: float = Data.BD[hub.type].R
	var hc := Vector2(hub.x + hub.w * 0.5, hub.y + hub.h * 0.5)
	var cap: int = BARROW_N if c.barrow else CARRY_N
	var demand: Array = []     # [Gebaeude, Ware]
	var stores: Array = []
	for b in blds.values():
		if Vector2(b.x + b.w * 0.5, b.y + b.h * 0.5).distance_to(hc) > R:
			continue
		if b.done and Data.BD[b.type].kind == "store":
			stores.append(b)
			continue
		for g in b.cap:
			if miss(b, g) > 0:
				demand.append([b, g])
	var cands: Array = []      # [Schluessel, Quelle, Ware, Ziel]
	for s in blds.values():
		if not s.done or Vector2(s.x + s.w * 0.5, s.y + s.h * 0.5).distance_to(hc) > R:
			continue
		var is_store: bool = Data.BD[s.type].kind == "store"
		var goods: Dictionary = _goods_of(s)
		var sdp := door_pos(s)
		var sv := pos.distance_to(sdp)
		for g in goods:
			if goods[g] <= 0:
				continue
			var best = null
			var bk := 1e9
			for dm in demand:
				if dm[1] != g or dm[0] == s:
					continue
				var dd: Bld = dm[0]
				# Baustellen zuerst (Prioritaet), sonst der naechste Abnehmer
				var key := sdp.distance_to(door_pos(dd)) - (40.0 if not dd.done else 0.0) - 15.0 * dd.prio
				if key < bk:
					bk = key
					best = dd
			if best == null and not is_store:
				for st in stores:
					if st == s:
						continue
					var key2 := sdp.distance_to(door_pos(st)) + 60.0
					if key2 < bk:
						bk = key2
						best = st
			if best != null:
				cands.append([sv + bk, s, g, best])
	if cands.is_empty():
		return null
	cands.sort_custom(func(p, q): return p[0] < q[0])
	var checked := {}
	for cd in cands:
		var s: Bld = cd[1]
		if checked.has(s.id):
			continue
		checked[s.id] = true
		if checked.size() > 5:
			break
		if not _reach(pos, s):
			continue
		var items: Array = []
		for cd2 in cands:
			if cd2[1] != s:
				continue
			var g2: String = cd2[2]
			var d2: Bld = cd2[3]
			var d2_store: bool = d2.done and Data.BD[d2.type].kind == "store"
			while items.size() < cap and _goods_of(s).get(g2, 0) > 0 and (d2_store or miss(d2, g2) > 0):
				if not _reach_b(s, d2):
					break
				_take(s, g2, d2)
				items.append({"t": g2, "dst": d2.id})
		if not items.is_empty():
			return {"src": s.id, "items": items}
	return null

func _dump(it: Dictionary, pos: Vector2) -> void:
	# Ware, die ihr Ziel nicht mehr erreicht, kommt ins naechste Lager (oder geht verloren)
	var db = blds.get(it.dst)
	if db != null:
		db.incoming[it.t] = maxi(0, db.incoming.get(it.t, 0) - 1)
	var s = _nearest_store(pos.x, pos.y)
	if s != null:
		s.stock[it.t] = s.stock.get(it.t, 0) + 1

func _deliver(it: Dictionary, b: Bld) -> void:
	if b.done and Data.BD[b.type].kind == "store":
		b.stock[it.t] = b.stock.get(it.t, 0) + 1
	else:
		b.inbox[it.t] = b.inbox.get(it.t, 0) + 1
	b.incoming[it.t] = maxi(0, b.incoming.get(it.t, 0) - 1)

func _cell_of(c) -> Vector2i:
	return Vector2i(int(c.x), int(c.y))

func _go_src(hub: Bld, c: Carrier) -> void:
	var s = blds.get(c.src)
	if s == null:
		_abort(hub, c)
		return
	var cc := _cell_of(c)
	var p := route(cc.x, cc.y, s.door.x, s.door.y)
	if p.is_empty():
		_abort(hub, c)
		return
	c.path = p
	c.k = 0.0
	c.st = "go" if p.size() > 1 else "pick"
	c.t = 0.5

func _next_leg(hub: Bld, c: Carrier) -> void:
	# naechstes Ziel unter den geladenen Waren: das naechstgelegene
	while not c.load.is_empty():
		var pos := Vector2(c.x, c.y)
		var best := -1
		var bv := 1e9
		for k in c.load.size():
			var db = blds.get(c.load[k].dst)
			if db == null:
				continue
			var v := pos.distance_to(door_pos(db))
			if v < bv:
				bv = v
				best = k
		if best < 0:
			for it in c.load:
				_dump(it, pos)
			c.load = []
			break
		var dst: Bld = blds[c.load[best].dst]
		var cc := _cell_of(c)
		var p := route(cc.x, cc.y, dst.door.x, dst.door.y)
		if p.is_empty():
			# nicht erreichbar: alle Waren fuer dieses Ziel ins Lager
			var rest: Array = []
			for it in c.load:
				if it.dst == dst.id:
					_dump(it, pos)
				else:
					rest.append(it)
			c.load = rest
			continue
		c.to = dst.id
		c.path = p
		c.k = 0.0
		c.st = "carry" if p.size() > 1 else "drop"
		c.t = 0.4
		return
	_finish_trip(hub, c)

func _finish_trip(hub: Bld, c: Carrier) -> void:
	# Weiter zum naechsten Auftrag in der Naehe, sonst zurueck ins Lager
	var job = _find_work(hub, c, Vector2(c.x, c.y))
	if job != null:
		c.src = job.src
		c.load = job.items
		_go_src(hub, c)
		return
	_return(hub, c)

func _return(hub: Bld, c: Carrier) -> void:
	var cc := _cell_of(c)
	var p := route(cc.x, cc.y, hub.door.x, hub.door.y)
	if p.size() > 1:
		c.path = p
		c.k = 0.0
		c.st = "ret"
	else:
		var dp := door_pos(hub)
		c.x = dp.x
		c.y = dp.y
		c.st = "enter"

func _abort(hub: Bld, c: Carrier) -> void:
	var pos := Vector2(c.x, c.y)
	for it in c.load:
		_dump(it, pos)
	c.load = []
	c.src = 0
	c.t = 0.0
	if c.st == "exit":
		c.st = "enter"
	else:
		_return(hub, c)

func _upd_carrier(hub: Bld, c: Carrier, dt: float) -> void:
	match c.st:
		"enter":
			if _glide(c, seat_pos(hub, c.seat), dt):
				c.st = "sit"
				c.t = rng.randf_range(0.2, 1.0)
		"sit":
			c.t -= dt
			if c.t > 0.0:
				return
			c.t = 0.5
			var job = _find_work(hub, c, door_pos(hub))
			if job != null:
				c.src = job.src
				c.load = job.items
				c.st = "exit"
		"exit":
			if c.src != 0 and not blds.has(c.src):
				_abort(hub, c)
			elif _glide(c, door_pos(hub), dt):
				_go_src(hub, c)
		"go":
			if not blds.has(c.src):
				_abort(hub, c)
			elif _follow(c, dt, 3.0 * K * WALK_MULT):
				c.st = "pick"
				c.t = 0.5
		"pick":
			c.t -= dt
			if c.t <= 0.0:
				c.src = 0
				_next_leg(hub, c)
		"carry":
			if not blds.has(c.to):
				_next_leg(hub, c)
			elif _follow(c, dt, 2.2 * K * WALK_MULT):
				c.st = "drop"
				c.t = 0.4
		"drop":
			c.t -= dt
			if c.t > 0.0:
				return
			var db = blds.get(c.to)
			var rest: Array = []
			for it in c.load:
				if it.dst == c.to and db != null:
					_deliver(it, db)
				elif it.dst == c.to:
					_dump(it, Vector2(c.x, c.y))
				else:
					rest.append(it)
			c.load = rest
			_next_leg(hub, c)
		"ret":
			if _follow(c, dt, 3.0 * K * WALK_MULT):
				c.st = "enter"

func _upd_hub(b: Bld, dt: float) -> void:
	# Soll-Besetzung herstellen, dann arbeiten die Traeger
	if b.carriers.size() < b.cn and free_now > 0:
		var cr := Carrier.new()
		cr.hub = b.id
		var taken := {}
		for o in b.carriers:
			taken[o.seat] = true
		for s in SEATS:
			if not taken.has(s):
				cr.seat = s
				break
		var dp := door_pos(b)
		cr.x = dp.x
		cr.y = dp.y
		b.carriers.append(cr)
		free_now -= 1
	elif b.carriers.size() > b.cn:
		for o in b.carriers:
			if o.st == "sit":
				b.carriers.erase(o)
				break
	for idx in b.carriers.size():
		var c: Carrier = b.carriers[idx]
		if c.st == "sit":
			c.barrow = idx < b.barrows
		_upd_carrier(b, c, dt)

func miss(b, g: String) -> int:
	if b.paused:
		return 0
	return b.cap.get(g, 0) - b.inbox.get(g, 0) - b.incoming.get(g, 0)

# ---------------------------------------------------------------- Gebäude
func _door_ok(dx: int, dy: int, force: bool) -> bool:
	if not inb(dx, dy):
		return false
	var di := dy * MW + dx
	if Data.WALK[ground[di]] == 0 or occ[di] != 0 or doorc[di] != 0:
		return false
	if not force and not no_obj(di):
		return false
	return true

func door_offsets(type: String, x: int, y: int, force: bool = false) -> Array:
	# Tuer-Zelle als Offset zur linken oberen Gebaeudeecke: die beste freie Zelle unter der Vorderseite (Mitte zuerst).
	var d: Dictionary = Data.BD[type]
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
			if not no_obj(i) or occ[i] != 0 or doorc[i] != 0:
				return "Der Platz ist belegt"
			if road[i] != 0:
				return "Weg im Weg"
	if door_offsets(type, x, y).is_empty():
		return "Vor der Tür ist kein Platz"
	if (d.kind == "gather" or d.kind == "process" or d.kind == "service") and used_workers() + carrier_count() >= pop:
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
	var dd: Array = doors[0]
	b.door = Vector2i(x + dd[0], y + dd[1])
	var di := b.door.y * MW + b.door.x
	if obj[di] != 0:
		set_obj(di, 0)
	doorc[di] = b.id
	if d.has("hub"):
		b.cn = d.get("cn", 0)
		b.design = rng.randi() % 3
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
	elif d.kind != "pile":
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
	# Nur das Langhaus (und Abrisshaufen) lassen sich nicht abreissen; Baustellen aller Art gehen immer
	return b.type != "hq" and b.type != "haufen"

func progress(b: Bld) -> float:
	# Fortschritt der laufenden Taetigkeit 0..1, -1 wenn nichts laeuft
	var d: Dictionary = Data.BD[b.type]
	if not b.done:
		return b.prog if b.bw or b.prog > 0.0 else -1.0
	if d.kind == "house":
		return 1.0 - clampf(b.feed_t / 30.0, 0.0, 1.0)
	if d.kind == "store" or d.kind == "lm" or d.kind == "hub" or d.kind == "service" or b.paused:
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
			var dst2 := Vector2(b.door.x + 0.5 - b.wx, b.door.y + 0.5 - b.wy).length()
			return 0.7 + 0.2 * (1.0 - clampf(dst2 / b.d0, 0.0, 1.0))
		"rest":
			return 0.9 + 0.1 * (1.0 - clampf(b.timer / maxf(b.ptot, 0.01), 0.0, 1.0))
	return -1.0

func demolish(b: Bld) -> void:
	if not can_demolish(b):
		return
	var d: Dictionary = Data.BD[b.type]
	# Waren zurueck ins naechste Lager: Inhalt, Lager- und Ausgangsbestand, halbe Baukosten fertiger Gebaeude
	# Alles bleibt als Haufen an der Abrissstelle liegen; Träger sammeln ihn ein.
	# Die Baukosten fertiger Gebäude gibt es voll zurück, aber roh (Bretter -> Holz, Steinblöcke -> Stein).
	var refund := {}
	for k in b.inbox:
		refund[k] = refund.get(k, 0) + b.inbox[k]
	if b.done or b.upg:
		for k in d.cost:
			var rk: String = Data.RAW.get(k, k)
			refund[rk] = refund.get(rk, 0) + d.cost[k]
		if b.type == "haus":
			for lv in range(1, b.level):
				for k in Data.HOUSE_UP[lv].cost:
					var rk2: String = Data.RAW.get(k, k)
					refund[rk2] = refund.get(rk2, 0) + Data.HOUSE_UP[lv].cost[k]
	for k in b.stock:
		refund[k] = refund.get(k, 0) + b.stock[k]
	for k in b.outbox:
		refund[k] = refund.get(k, 0) + b.outbox[k]
	# Traeger des Hauses gehen nach Hause, ihre Last kommt ins Lager, die Karren zurueck in den Vorrat
	for c in b.carriers:
		for it in c.load:
			_dump(it, Vector2(c.x, c.y))
	b.carriers = []
	barrows_free += b.barrows
	b.barrows = 0
	var n_back := 0
	for k in refund:
		n_back += refund[k]
	if d.kind == "lm":
		landmarks.erase(b.type)
	for yy in range(b.y, b.y + b.h):
		for xx in range(b.x, b.x + b.w):
			occ[yy * MW + xx] = 0
	var di := b.door.y * MW + b.door.x
	if doorc[di] == b.id:
		doorc[di] = 0
	for i in b.fields:
		if field[i] == b.id:
			field[i] = 0
	if b.tg != null:
		if b.tg.has("i"):
			claims.erase(b.tg.i)
		if b.tg.has("animal"):
			b.tg.animal.frozen = false
	blds.erase(b.id)
	for a in animals.duplicate():
		if a.home == b:
			animals.erase(a)
	if n_back > 0:
		var pile := place_building("haufen", b.x, b.y, true)
		for k in refund:
			if refund[k] > 0:
				pile.outbox[k] = refund[k]
		events.append(["refund", "%d Waren liegen an der Abrissstelle" % n_back, b.x + b.w * 0.5, b.y + b.h * 0.5])
	net_ver += 1

func _upd_pile(b: Bld) -> void:
	# Abrisshaufen verschwindet, sobald alles abgeholt ist (und kein Traeger mehr auf dem Weg dorthin ist)
	if outbox_total(b) > 0:
		return
	for o in blds.values():
		for c in o.carriers:
			if c.src == b.id:
				return
	for yy in range(b.y, b.y + b.h):
		for xx in range(b.x, b.x + b.w):
			occ[yy * MW + xx] = 0
	var di := b.door.y * MW + b.door.x
	if doorc[di] == b.id:
		doorc[di] = 0
	blds.erase(b.id)
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
			b.msg = "Wartet auf Material" if hub_covers(b) else "Wartet auf Material: Kein Trägerlager in Reichweite"
		elif not b.bw:
			b.msg = "Bauarbeiter finden keinen Weg" if b.retry > 0.0 else "Wartet auf Bauarbeiter"
		else:
			b.msg = "Wird gebaut"
			b.prog += dt / b.build_t
			b.busy = true
			if b.prog >= 1.0:
				_finish(b)
		return
	if d.has("hub"):
		_upd_hub(b, dt)
	if d.kind == "pile":
		_upd_pile(b)
		return
	if d.kind == "store" or d.kind == "lm" or d.kind == "hub":
		return
	if d.kind == "service":
		if b.paused:
			b.msg = "Pausiert"
			b.busy = false
			return
		_upd_digger(b, dt)
		return
	if d.kind == "house":
		_upd_house(b, dt)
		return
	if b.paused:
		b.msg = "Pausiert"
		b.busy = false
		return
	var dp := door_pos(b)
	match b.st:
		"idle":
			b.busy = false
			b.timer -= dt
			if b.timer > 0.0:
				return
			b.timer = 0.4
			if outbox_total(b) >= OUT_CAP:
				b.msg = "Ausgang voll: Träger kommen nicht nach" if hub_covers(b) else "Kein Trägerlager in Reichweite"
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
				b.msg = "Wartet auf Waren" if hub_covers(b) else "Wartet auf Waren: Kein Trägerlager in Reichweite"
				return
			if d.kind == "gather":
				var tg = pick_target(b)
				if tg == null:
					b.msg = "Nichts zu tun in Reichweite"
					return
				take_inputs(b)
				b.tg = tg
				b.st = "walk"
				b.wx = dp.x
				b.wy = dp.y
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
					# fertige Ware wartet im Ausgang auf einen Traeger
					b.outbox[d.out] = b.outbox.get(d.out, 0) + d.outn
				b.st = "idle"
				b.timer = 0.3
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
				b.d0 = maxf(0.5, Vector2(dp.x - b.wx, dp.y - b.wy).length())
		"back":
			var dv := Vector2(dp.x - b.wx, dp.y - b.wy)
			var step := 2.3 * K * WALK_MULT * dt
			if dv.length() <= step:
				b.wx = dp.x
				b.wy = dp.y
				if d.out != "":
					b.outbox[d.out] = b.outbox.get(d.out, 0) + 1
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
	# Freie Pixler laufen nicht durchs Dorf (zu unübersichtlich); IDLERS_MAX > 0 schaltet sie wieder ein
	var want_idle := mini(clampi(free_pixlers(), 0, 12), IDLERS_MAX)
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
	var best_s = null
	var bv := 1e9
	for s in blds.values():
		if s.done and Data.BD[s.type].kind == "store":
			var v := Vector2(s.door - b.door).length()
			if v < bv:
				bv = v
				best_s = s
	if best_s == null:
		return false
	var path: Array = route(best_s.door.x, best_s.door.y, b.door.x, b.door.y)
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
				if _follow(bd, dt, 2.8 * K * WALK_MULT):
					bd.st = "work"
			"work":
				b.bw = true
			"back":
				if bd.path.size() < 2 or _follow(bd, dt, 2.8 * K * WALK_MULT):
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
			b.msg = "Bauarbeiter finden keinen Weg"

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
	_acc_eco += dt
	if _acc_eco >= 1.0:
		_acc_eco = 0.0
		upd_eco()
	update_builders(dt)
	free_now = free_pixlers()
	for b in blds.values():
		upd_bld(b, dt)
	for a in animals:
		_wander(a, dt)
	upd_balloons(dt)
	for a in idlers:
		_wander(a, dt)
