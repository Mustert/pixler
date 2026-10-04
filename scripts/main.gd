extends Node2D
# Pixlers - Rendering, Eingabe, UI.

const TS := 16
const MW := Data.MW
const MH := Data.MH
const GOOD_GROUPS := [["holz", "bretter", "stein", "steinblock", "wasser"], ["fisch", "fleisch", "schwein", "weizen", "mehl", "brot", "pilz", "kraut", "gemuese", "gericht"], ["feenstaub", "obsidian", "gluehpilz", "sand", "glas", "eis"]]
const LM_ORDER := ["schrein", "obelisk", "glaspalast", "eispavillon", "laterne"]

var sim: Sim
var cam: Camera2D
var terrain: ColorRect
var night_layer: Node2D
var glow_layer: Node2D
var time := 0.0
var speed := 1.0
const ZOOMS := [0.5, 1.0, 1.5, 2.0, 3.0, 4.0]
var zoom_i := 1
var lava_chunks := {}      # Chunk -> Zellen (jeder 2x2-Block mit Lava bekommt ein Gluehen)
var mode := "select"
var build_type := ""
var road_start = null
var hover := Vector2i(-1, -1)
var hover_ui := false
var sel = null
var road_prev: Array = []
var road_prev_key := ""
var ghost_err := ""
var parts: Array = []
var birds: Array = []
var flies: Array = []
var pan_drag := false
var won_shown := false
var font: Font
var rng := RandomNumberGenerator.new()
var shot_path := ""
var shot_frames := 0
var frame_count := 0

# UI
var ui: CanvasLayer
var lab_pop: Label
var lab_res := {}
var lab_time: Label
var lab_lm := {}
var toast: Label
var toast_t := 0.0
var hint: Label
var info_panel: PanelContainer
var info_label: Label
var info_pause: Button
var menu_grid: GridContainer
var cat_buttons: Array = []
var mini_tex: TextureRect
var mini_img: Image
var mini_base: Image
var mini_t := 0.0
var ui_t := 0.0
var tool_buttons := {}
var win_panel: PanelContainer
var sfx: Sfx
var tut := 2          # Tutorial-Popups sind aus (0 = Tutorial-Ablauf wieder an)
var popups: Array = []
var popup_panel: PanelContainer
var popup_title: Label
var popup_text: Label
var objective: Label
var road_undo: Array = []
var lab_barrow: Label
var lab_builder: Label
var info_hub: HBoxContainer
var info_prio: Button
var info_up: Button
var last_st := {}
var hammer_t := 0.0
var mute_btn: Button
var last_starve_msg := -100.0
var pop_warned := false
var pop_warned2 := false
var last_low_msg := -100.0
var info_goods: HFlowContainer
var info_sig := "-"
var info_labs: Array = []
var select_type := ""
var speed_btns: Array = []
var info_bar: ProgressBar
var info_demo: Button
var demo_pending := -1       # Gebaeude-ID, die auf Bestaetigung zum Abriss wartet
var demo_pending_t := 0.0
var menu_cat := "Basis"
const TUT_UNLOCK := [
	["holzfaeller", "saegewerk", "steinbruch", "steinmetz"],
	["holzfaeller", "saegewerk", "steinbruch", "steinmetz", "brunnen", "fischer", "taverne", "haus"],
]

func _ready() -> void:
	rng.randomize()
	font = ThemeDB.fallback_font
	Art.build()
	sim = Sim.new()
	var seed := int(rng.randi() % 100000)
	var demo := false
	var ff := 0.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed = int(a.substr(7))
		elif a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a == "--demo":
			demo = true
		elif a.begins_with("--ff="):
			ff = float(a.substr(5))
		elif a.begins_with("--frames="):
			shot_frames = int(a.substr(9))
		elif a.begins_with("--zoom="):
			zoom_i = _zoom_index(float(a.substr(7)))
		elif a.begins_with("--select="):
			select_type = a.substr(9)
		elif a.begins_with("--carry="):
			Sim.CARRY_N = int(a.substr(8))
		elif a.begins_with("--barrow="):
			Sim.BARROW_N = int(a.substr(9))
		elif a.begins_with("--cam="):
			var p := a.substr(6).split(",")
			call_deferred("_set_cam", Vector2(float(p[0]), float(p[1])))
	if demo or OS.get_cmdline_user_args().has("--selftest") or OS.get_cmdline_user_args().has("--notut"):
		tut = 2
	sim.start_game(seed)
	sfx = Sfx.new()
	add_child(sfx)
	_setup_world()
	_setup_ui()
	_set_cam(Vector2(Sim.HQ_POS.x + 2, Sim.HQ_POS.y + 2) * TS)
	if demo:
		_demo()
	var t := 0.0
	while t < ff:
		sim.update(0.1)
		t += 0.1
	cam.zoom = Vector2(ZOOMS[zoom_i], ZOOMS[zoom_i])
	if select_type != "":
		for sb in sim.blds.values():
			if sb.type == select_type:
				sel = sb
				_set_cam(Vector2(sb.x + sb.w / 2.0, sb.y + sb.h / 2.0) * TS)
				break
	_update_mini()
	if shot_frames == 0 and shot_path != "":
		shot_frames = 20
	if OS.get_cmdline_user_args().has("--selftest"):
		_selftest()
	if demo:
		var s := "STOCK:"
		for g in Data.GOODS:
			s += " %s=%d" % [g, sim.total_stock(g)]
		print(s, " pop=", sim.pop, " used=", sim.used_workers())
		for bl in sim.balloons:
			print("BALLOON ", bl.phase, " h=", bl.h, " pos=", bl.x, ",", bl.y)
		for bb in sim.blds.values():
			if bb.type == "ballon":
				print("BALLOONHAUS ", bb.x, ",", bb.y, " done=", bb.done, " st=", bb.st, " msg=", bb.msg, " timer=", bb.timer)
		var stc := {}
		for b in sim.blds.values():
			for c in b.carriers:
				stc[c.st] = stc.get(c.st, 0) + 1
		print("CARRIERS=", sim.carrier_count(), " states=", stc, " barrows free=", sim.barrows_free, "/", sim.barrows_total, " roads=", sim.roads.size(), " stations=", sim.stations.size())
		for b in sim.blds.values():
			print("  ", b.type, " done=", b.done, " st=", b.st, " msg=", b.msg, " inbox=", b.inbox, " outbox=", b.outbox, " stock=", b.stock if b.type == "hq" else "")

func _set_cam(p: Vector2) -> void:
	cam.position = p

# ------------------------------------------------------------ Aufbau
func _setup_world() -> void:
	var tm := Image.create(MW, MH, false, Image.FORMAT_R8)
	for y in MH:
		for x in MW:
			tm.set_pixel(x, y, Color(sim.ground[y * MW + x] / 255.0, 0, 0, 1))
	var sh := Shader.new()
	sh.code = FileAccess.get_file_as_string("res://scripts/terrain.gdshader")
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("tmap", ImageTexture.create_from_image(tm))
	mat.set_shader_parameter("msize", Vector2(MW, MH))
	terrain = ColorRect.new()
	terrain.size = Vector2(MW * TS, MH * TS)
	terrain.material = mat
	terrain.z_index = -10
	terrain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(terrain)
	cam = Camera2D.new()
	cam.zoom = Vector2(ZOOMS[zoom_i], ZOOMS[zoom_i])
	add_child(cam)
	var LayerS := preload("res://scripts/layer.gd")
	night_layer = LayerS.new()
	night_layer.z_index = 50
	night_layer.cb = _draw_night
	var m1 := CanvasItemMaterial.new()
	m1.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	night_layer.material = m1
	add_child(night_layer)
	glow_layer = LayerS.new()
	glow_layer.z_index = 51
	glow_layer.cb = _draw_glow
	var m2 := CanvasItemMaterial.new()
	m2.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow_layer.material = m2
	add_child(glow_layer)
	for k in 6:
		birds.append({"x": rng.randf() * MW * TS, "y": rng.randf() * MH * TS, "v": rng.randf_range(14.0, 24.0), "f": rng.randf() * 6.0})
	for k in 26:
		flies.append({"x": rng.randf() * MW * TS, "y": rng.randf() * MH * TS, "a": rng.randf() * TAU, "c": ["#f5a0d0", "#a0d8f5", "#f5e070"][k % 3]})
	# Minimap-Basis
	mini_base = Image.create(MW, MH, false, Image.FORMAT_RGB8)
	var cols := ["#2c5aa0", "#4a90d0", "#e6d29a", "#6fb05a", "#8b8794", "#ff6a1a", "#4a4552", "#8fd6b0", "#4f6b45", "#3d5e4c", "#e8c87a", "#eef3fa", "#a9dcf2"]
	var ccols: Array = []
	for c in cols:
		ccols.append(Color(c))
	for y in MH:
		for x in MW:
			var g: int = sim.ground[y * MW + x]
			mini_base.set_pixel(x, y, ccols[g])
			if g == Data.T.LAVA and x % 2 == 0 and y % 2 == 0 and ((x >> 1) + (y >> 1)) % 2 == 0:
				var ci: int = (y / Sim.CH) * Sim.NCX + x / Sim.CH
				if not lava_chunks.has(ci):
					lava_chunks[ci] = []
				lava_chunks[ci].append(y * MW + x)

func _spot(type: String, cx: int, cy: int, r0: int = 3, r1: int = 70) -> Vector2i:
	# freier, gueltiger Bauplatz (linke obere Ecke) in wachsenden Ringen um (cx, cy)
	var d: Dictionary = Data.BD[type]
	for r in range(r0, r1):
		for a in 24:
			var ang := a * TAU / 24.0 + r
			var x: int = cx + int(cos(ang) * r) - d.w / 2
			var y: int = cy + int(sin(ang) * r * 0.8) - d.h / 2
			if sim.inb(x, y) and sim.can_place(type, x, y) == "":
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func _run(secs: float) -> void:
	for i in int(secs * 10.0):
		sim.update(0.1)

func _selftest() -> void:
	var log := func(m): print("SELFTEST: ", m)
	var hq: Sim.Bld = sim.blds.values()[0]
	var hc := sim.bcenter(hq)
	log.call("hq door=%s carriers want=%d" % [str(hq.door), hq.cn])
	# Holzfaeller ueber die Bedienlogik setzen (Hover ist die Gebaeudemitte)
	_set_mode("build", "holzfaeller")
	var hd: Dictionary = Data.BD["holzfaeller"]
	var sp := _spot("holzfaeller", hc.x - 6, hc.y + 10, 6)
	hover = Vector2i(sp.x + hd.w / 2, sp.y + hd.h / 2)
	_update_hint()
	log.call("ghost_err=[%s]" % ghost_err)
	_click()
	var hf: Sim.Bld = null
	for bb in sim.blds.values():
		if bb.type == "holzfaeller":
			hf = bb
	log.call("blds=%d holzfaeller=%s" % [sim.blds.size(), str(hf != null)])
	# Wege und Traegerstationen gibt es erst mit dem Wegebauer
	_set_mode("road", "")
	log.call("road tool without roadbuilder -> mode=%s" % mode)
	_set_mode("select", "")
	var wsp := _spot("wegebauer", hc.x - 8, hc.y + 8)
	var wb := sim.place_building("wegebauer", wsp.x, wsp.y)
	var tsp := _spot("traeger", hc.x + 8, hc.y + 10)
	var tl := sim.place_building("traeger", tsp.x, tsp.y)
	sim.set_carriers(tl, 4)
	var ssp := _spot("saegewerk", hc.x - 4, hc.y + 12)
	var sw := sim.place_building("saegewerk", ssp.x, ssp.y)
	log.call("traeger design=%d spots wb=%s tl=%s saeg=%s" % [tl.design, str(wsp), str(tsp), str(ssp)])
	var t_done := -1.0
	var stock0 := sim.total_stock("bretter")
	for i in 3000:
		sim.update(0.1)
		if hf.done and sw.done and wb.done and tl.done and t_done < 0.0:
			t_done = sim.t
	log.call("done: holzfaeller=%s saegewerk=%s wegebauer=%s traeger=%s at t=%.0f" % [hf.done, sw.done, wb.done, tl.done, t_done])
	log.call("hq carriers=%d tl carriers=%d builders cap=%d pop=%d/%d free=%d" % [hq.carriers.size(), tl.carriers.size(), sim.builder_cap(), sim.pop, sim.pop_cap(), sim.free_pixlers()])
	log.call("holz stock=%d bretter %d -> %d  holzfaeller msg=%s out=%s sawmill msg=%s in=%s out=%s" % [sim.total_stock("holz"), stock0, sim.total_stock("bretter"), hf.msg, str(hf.outbox), sw.msg, str(sw.inbox), str(sw.outbox)])
	log.call("roads_unlocked=%s" % sim.roads_unlocked())
	# Weg per Bedienlogik: vom Wegebauer zum Langhaus
	_set_mode("road", "")
	hover = Vector2i(wb.door.x, wb.door.y)
	_click()
	log.call("road_start=%s" % str(road_start))
	hover = Vector2i(hq.door.x, hq.door.y)
	_update_hint()
	log.call("prev=%d" % road_prev.size())
	_click()
	log.call("roads=%d" % sim.roads.size())
	var pth := sim.route(wb.door.x, wb.door.y, hq.door.x, hq.door.y)
	log.call("route len=%d" % pth.size())
	# Traegerstation mitten auf den Weg
	_set_mode("station", "")
	var mc := Vector2i(-1, -1)
	if sim.roads.size() > 0:
		var rd: Sim.Road = sim.roads.values()[0]
		var m: Array = rd.cells[rd.cells.size() / 2]
		mc = Vector2i(m[0], m[1])
		hover = mc
		_click()
	log.call("stations=%d" % sim.stations.size())
	_run(60.0)
	log.call("station manned=%s speed at mid=%.2f" % [str(sim.stations.values()[0].manned) if sim.stations.size() > 0 else "-", sim.spd_at(mc.y * MW + mc.x) if mc.x >= 0 else 0.0])
	# Schubkarren im Traegerlager
	sim.set_barrows(tl, 2)
	log.call("barrows tl=%d free=%d" % [tl.barrows, sim.barrows_free])
	# Bauarbeiter: Pause/Abriss-Rueckgabe pruefen
	var before := sim.total_stock("bretter")
	var hsp := _spot("haus", hc.x + 4, hc.y + 6)
	var hz := sim.place_building("haus", hsp.x, hsp.y)
	hz.paused = true
	_run(30.0)
	log.call("paused haus inbox=%s prog=%.2f" % [str(hz.inbox), hz.prog])
	hz.paused = false
	_run(150.0)
	log.call("haus done=%s msg=%s" % [hz.done, hz.msg])
	var bs := sim.total_stock("bretter")
	sim.demolish(hz)
	log.call("refund bretter %d -> %d (before %d)" % [bs, sim.total_stock("bretter"), before])
	# Ranch, Lager, Landmarks
	sim.pop = 80
	for t in ["ranch", "lager", "schrein", "obelisk", "glaspalast", "eispavillon", "laterne"]:
		var s2 := _spot(t, hc.x, hc.y + 16, 3, 40)
		if s2.x >= 0:
			var b := sim.place_building(t, s2.x, s2.y)
			if Data.BD[t].kind == "lm" or t == "ranch":
				for k in Data.BD[t].cost:
					b.inbox[k] = Data.BD[t].cost[k]
				b.prog = 0.99
		log.call("placed %s = %s" % [t, str(s2.x >= 0)])
	_run(40.0)
	log.call("landmarks=%d pop=%d animals=%d" % [sim.landmarks.size(), sim.pop, sim.animals.size()])
	# Auswahl + UI (auch Traegerlager-Panel)
	_set_mode("select", "")
	hover = Vector2i(tl.x + 1, tl.y + 1)
	_click()
	_update_ui()
	log.call("sel=%s" % (sel.type if sel else "none"))
	hover = Vector2i(hq.x + 1, hq.y + 1)
	_click()
	_update_ui()
	log.call("sel=%s" % (sel.type if sel else "none"))
	# Abriss: Holzfaeller, Traegerlager (Karren zurueck), Station, Weg
	_set_mode("demolish", "")
	hover = Vector2i(hf.x, hf.y)
	_click()
	var bf := sim.barrows_free
	hover = Vector2i(tl.x + 1, tl.y + 1)
	_click()
	_click()
	log.call("tl demolished=%s barrows free %d -> %d" % [str(not sim.blds.has(tl.id)), bf, sim.barrows_free])
	if mc.x >= 0:
		hover = mc
		_click()
		log.call("after station click stations=%d roads=%d" % [sim.stations.size(), sim.roads.size()])
		_click()
	_run(10.0)
	_update_mini()
	log.call("after demolish blds=%d roads=%d stations=%d carriers=%d" % [sim.blds.size(), sim.roads.size(), sim.stations.size(), sim.carrier_count()])
	_set_mode("select", "")
	sel = null

func _demo() -> void:
	var hq: Sim.Bld = sim.blds.values()[0]
	sim.pop = 200
	for k in ["bretter", "steinblock", "stein", "holz", "wasser", "brot", "fisch", "fleisch", "weizen", "gericht"]:
		hq.stock[k] = hq.stock.get(k, 0) * 3 + 20
	if OS.get_environment("PIX_NOWATER") != "":
		hq.stock["wasser"] = 0   # Debug: Brunnen soll arbeiten statt "Genug auf Lager"
	hq.cn = 8
	sim.set_barrows(hq, 3)
	var list := [
		["wegebauer", 95, 92], ["traeger", 95, 92], ["traeger", 95, 92], ["traeger", 95, 92],
		["holzfaeller", 95, 92], ["foerster", 95, 92], ["saegewerk", 95, 92], ["steinbruch", 108, 106], ["steinmetz", 95, 92], ["brunnen", 95, 92],
		["fischer", 84, 98], ["farm", 95, 92], ["muehle", 95, 92], ["baeckerei", 95, 92], ["taverne", 95, 92], ["jaeger", 95, 92], ["wagner", 95, 92], ["ballon", 99, 96],
		["haus", 95, 92], ["haus", 95, 92], ["haus", 95, 92], ["lager", 95, 92], ["ranch", 95, 92], ["metzger", 95, 92], ["garten", 95, 92],
		["kraeuter", 95, 92], ["pilzsammler", 95, 92], ["kueche", 95, 92],
		["traeger", 57, 62], ["lager", 57, 62], ["feensammler", 57, 62],
		["traeger", 147, 105], ["lager", 147, 105], ["obsidian", 147, 105],
		["traeger", 54, 138], ["lager", 54, 138], ["pilzhuette", 54, 138],
		["traeger", 129, 147], ["lager", 129, 147], ["sandgrube", 129, 147], ["glashuette", 129, 147],
		["traeger", 112, 38], ["lager", 112, 38], ["eishauer", 112, 38],
	]
	for entry in list:
		var type: String = entry[0]
		var sp := _spot(type, entry[1] * 2, entry[2] * 2, 0, 56)
		if sp.x < 0:
			continue
		# die Wege-Infrastruktur steht sofort, der Rest wird gebaut
		var b := sim.place_building(type, sp.x, sp.y, type in ["traeger", "lager"])
		if type == "traeger":
			sim.set_carriers(b, 3)
		elif type == "lager":
			for k in ["bretter", "steinblock", "stein", "holz", "wasser"]:
				b.stock[k] = 20
		elif type == "wegebauer":
			# Beispielweg vom Wegebauer zum Langhaus, mit Trägerstation in der Mitte
			var wp := sim.find_path(b.door.x, b.door.y, hq.door.x, hq.door.y)
			if wp.size() > 1:
				sim.add_road(wp)
				sim.place_station(wp[wp.size() / 2][0], wp[wp.size() / 2][1])


# ------------------------------------------------------------ UI
func _panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	return s

func _make_theme() -> Theme:
	var th := Theme.new()
	th.set_stylebox("panel", "PanelContainer", _panel_style(Color("#3b2a24ea"), Color("#8a6a44")))
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var bg := Color("#5a4030")
		if st == "hover": bg = Color("#7a5a3c")
		if st == "pressed": bg = Color("#c89a50")
		var b := _panel_style(bg, Color("#2a1c18"))
		b.content_margin_left = 6
		b.content_margin_right = 6
		th.set_stylebox(st, "Button", b)
	th.set_color("font_color", "Button", Color("#f6e7c8"))
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_pressed_color", "Button", Color("#2a1c18"))
	th.set_color("font_color", "Label", Color("#f6e7c8"))
	th.set_font_size("font_size", "Button", 13)
	th.set_font_size("font_size", "Label", 14)
	th.set_stylebox("panel", "TooltipPanel", _panel_style(Color("#2a1c18f2"), Color("#c89a50")))
	th.set_color("font_color", "TooltipLabel", Color("#f6e7c8"))
	return th

func _icon_for(tx: Texture2D, box: int) -> Texture2D:
	var im := tx.get_image()
	var k := minf(float(box) / im.get_width(), float(box) / im.get_height())
	var nk := maxf(1.0, floorf(k)) if k >= 1.0 else k
	im.resize(maxi(1, int(im.get_width() * nk)), maxi(1, int(im.get_height() * nk)), Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(im)

func _cost_text(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	for k in cost:
		parts.append("%d× %s" % [cost[k], Data.GNAME[k]])
	return ", ".join(parts)

func _alt_text(d: Dictionary) -> String:
	var p := PackedStringArray()
	for k in d.alt:
		p.append(Data.GNAME[k])
	var n: int = d.get("altn", 1)
	return ("%d verschiedene aus " % n if n > 1 else "eins aus ") + ", ".join(p)

func _tip(type: String) -> String:
	var d: Dictionary = Data.BD[type]
	var s: String = d.n + "\n" + d.get("d", "")
	if d.has("ins") and d.ins.size() > 0:
		var p := PackedStringArray()
		for k in d.ins:
			p.append("%d× %s" % [d.ins[k], Data.GNAME[k]])
		s += "\nBraucht: " + ", ".join(p)
		if d.has("alt"):
			s += " + " + _alt_text(d)
	elif d.has("alt"):
		s += "\nBraucht: " + _alt_text(d)
	if d.get("out", "") != "":
		s += "\nErzeugt: %d× %s" % [d.get("outn", 1), Data.GNAME[d.out]]
	s += "\nKosten: " + _cost_text(d.cost)
	return s

func _setup_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	ui.add_child(root)
	# Topbar
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	root.add_child(top)
	var topv := VBoxContainer.new()
	topv.add_theme_constant_override("separation", 2)
	top.add_child(topv)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	topv.add_child(hb)
	var hb2 := HBoxContainer.new()
	hb2.add_theme_constant_override("separation", 6)
	topv.add_child(hb2)
	var title := Label.new()
	title.text = "PIXLERS"
	title.add_theme_color_override("font_color", Color("#ffd070"))
	title.add_theme_font_size_override("font_size", 18)
	hb.add_child(title)
	for grp in GOOD_GROUPS:
		if grp != GOOD_GROUPS[0]:
			hb2.add_child(VSeparator.new())
		for g in grp:
			var c := HBoxContainer.new()
			c.add_theme_constant_override("separation", 3)
			var tr := TextureRect.new()
			tr.texture = _icon_for(Art.goods[g], 20)
			tr.tooltip_text = Data.GNAME[g]
			tr.mouse_filter = Control.MOUSE_FILTER_PASS
			c.add_child(tr)
			var l := Label.new()
			l.text = "0"
			l.custom_minimum_size = Vector2(18, 0)
			c.add_child(l)
			hb2.add_child(c)
			lab_res[g] = l
	hb.add_child(VSeparator.new())
	lab_pop = Label.new()
	lab_pop.tooltip_text = "Pixler im Dorf."
	lab_pop.add_theme_font_size_override("font_size", 16)
	lab_pop.mouse_filter = Control.MOUSE_FILTER_PASS
	hb.add_child(lab_pop)
	lab_barrow = Label.new()
	lab_barrow.tooltip_text = "Schubkarren (frei/gesamt). Im Info-Panel von Langhaus und Trägerlager bekommt jeder Träger eine Karre und trägt 3 statt 1 Ware. Baue den Schubkarrenbauer für mehr."
	lab_barrow.mouse_filter = Control.MOUSE_FILTER_PASS
	hb.add_child(lab_barrow)
	lab_builder = Label.new()
	lab_builder.tooltip_text = "Bauarbeiter (im Einsatz/gesamt). Sie laufen vom Lager zu den Baustellen, sobald alle Materialien da sind. Jedes Lagerhaus bringt 2 weitere."
	lab_builder.mouse_filter = Control.MOUSE_FILTER_PASS
	hb.add_child(lab_builder)
	hb.add_child(VSeparator.new())
	for lm in LM_ORDER:
		var l := Label.new()
		l.text = "★"
		l.tooltip_text = Data.BD[lm].n
		l.modulate = Color(1, 1, 1, 0.3)
		hb.add_child(l)
		lab_lm[lm] = l
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)
	lab_time = Label.new()
	hb.add_child(lab_time)
	mute_btn = Button.new()
	mute_btn.text = "Ton an"
	mute_btn.tooltip_text = "Ton ein/aus (M)"
	mute_btn.pressed.connect(_toggle_mute)
	hb.add_child(mute_btn)
	for sdef in [["II", 0.0], ["1x", 1.0], ["2x", 2.0], ["4x", 4.0]]:
		var b := Button.new()
		b.text = sdef[0]
		b.toggle_mode = true
		b.tooltip_text = "Spielgeschwindigkeit" if sdef[1] > 0.0 else "Pause (Leertaste)"
		b.pressed.connect(func(): speed = sdef[1])
		hb.add_child(b)
		speed_btns.append([b, sdef[1]])
	# Baumenü
	var menu := PanelContainer.new()
	menu.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	menu.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(menu)
	var vb := VBoxContainer.new()
	menu.add_child(vb)
	var tools := HBoxContainer.new()
	vb.add_child(tools)
	for tdef in [["select", "Auswahl (Esc)"], ["road", "Weg (R)"], ["station", "Trägerstation (T)"], ["demolish", "Abriss (X)"]]:
		var b := Button.new()
		b.text = tdef[1]
		b.toggle_mode = true
		b.pressed.connect(func(): _set_mode(tdef[0], ""))
		tools.add_child(b)
		tool_buttons[tdef[0]] = b
	var ub := Button.new()
	ub.text = "Weg zurück (Z)"
	ub.tooltip_text = "Letzten gebauten Weg rückgängig machen (Z oder Strg+Z)"
	ub.pressed.connect(_undo_road)
	tools.add_child(ub)
	var tabs := HBoxContainer.new()
	vb.add_child(tabs)
	for c in Data.CATS:
		var b := Button.new()
		b.text = c
		b.toggle_mode = true
		b.pressed.connect(func(): _show_cat(c))
		tabs.add_child(b)
		cat_buttons.append(b)
	menu_grid = GridContainer.new()
	menu_grid.columns = 6
	vb.add_child(menu_grid)
	_show_cat("Basis")
	# Info
	info_panel = PanelContainer.new()
	info_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	info_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	info_panel.visible = false
	root.add_child(info_panel)
	var iv := VBoxContainer.new()
	info_panel.add_child(iv)
	info_label = Label.new()
	info_label.custom_minimum_size = Vector2(230, 0)
	iv.add_child(info_label)
	info_goods = HFlowContainer.new()
	info_goods.custom_minimum_size = Vector2(230, 0)
	info_goods.add_theme_constant_override("h_separation", 10)
	info_goods.add_theme_constant_override("v_separation", 2)
	iv.add_child(info_goods)
	info_bar = ProgressBar.new()
	info_bar.custom_minimum_size = Vector2(0, 14)
	info_bar.min_value = 0.0
	info_bar.max_value = 1.0
	info_bar.step = 0.001
	info_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#241812")
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color("#e0a840")
	fg.set_corner_radius_all(3)
	info_bar.add_theme_stylebox_override("background", bg)
	info_bar.add_theme_stylebox_override("fill", fg)
	iv.add_child(info_bar)
	info_hub = HBoxContainer.new()
	iv.add_child(info_hub)
	for hdef in [["Träger −", -1, 0, "Einen Träger weniger (0 bis 10)."], ["Träger +", 1, 0, "Einen Träger mehr (0 bis 10). Er braucht einen freien Pixler."], ["Karre −", 0, -1, "Eine Schubkarre zurück in den Vorrat."], ["Karre +", 0, 1, "Eine Schubkarre aus dem Vorrat: Der Träger trägt 3 statt 1 Ware. Höchstens so viele Karren wie Träger."]]:
		var hbtn := Button.new()
		hbtn.text = hdef[0]
		hbtn.tooltip_text = hdef[3]
		hbtn.pressed.connect(func():
			if sel != null and sel.done and Data.BD[sel.type].has("hub"):
				if hdef[1] != 0:
					sim.set_carriers(sel, sel.cn + hdef[1])
				else:
					sim.set_barrows(sel, sel.barrows + hdef[2]))
		info_hub.add_child(hbtn)
	var ib := HBoxContainer.new()
	iv.add_child(ib)
	info_pause = Button.new()
	info_pause.text = "Pause"
	info_pause.tooltip_text = "Hält Bau bzw. Produktion an. Angehaltene Gebäude fordern keine Waren mehr an."
	info_pause.pressed.connect(func():
		if sel != null: sel.paused = not sel.paused)
	ib.add_child(info_pause)
	info_prio = Button.new()
	info_prio.tooltip_text = "Priorität der Baustelle: Bei knappen Waren werden Baustellen mit hoher Priorität zuerst beliefert und bekommen zuerst Bauarbeiter."
	info_prio.pressed.connect(func():
		if sel != null:
			sel.prio = 1 if sel.prio == 0 else (-1 if sel.prio == 1 else 0))
	ib.add_child(info_prio)
	info_up = Button.new()
	info_up.text = "Ausbauen"
	info_up.pressed.connect(func():
		if sel != null:
			var err := sim.start_upgrade(sel)
			if err != "":
				say(err, 3.0)
				sfx.play("deny", 0.5)
			else:
				sfx.play("place", 0.9))
	ib.add_child(info_up)
	var idb := Button.new()
	idb.text = "Abreißen"
	idb.pressed.connect(func():
		if sel != null and _try_demolish(sel):
			sel = null)
	ib.add_child(idb)
	info_demo = idb
	# Minimap
	var mp := PanelContainer.new()
	mp.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	mp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	mp.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(mp)
	mini_tex = TextureRect.new()
	mini_tex.custom_minimum_size = Vector2(192, 192)
	mini_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mini_tex.stretch_mode = TextureRect.STRETCH_SCALE
	mini_tex.gui_input.connect(_mini_input)
	mp.add_child(mini_tex)
	# Toast + Hint
	toast = Label.new()
	toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.position.y = 100
	toast.add_theme_font_size_override("font_size", 20)
	toast.add_theme_color_override("font_shadow_color", Color.BLACK)
	toast.add_theme_constant_override("shadow_offset_x", 2)
	toast.add_theme_constant_override("shadow_offset_y", 2)
	toast.visible = false
	root.add_child(toast)
	hint = Label.new()
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.position.y = -230
	hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	hint.add_theme_constant_override("shadow_offset_x", 1)
	hint.add_theme_constant_override("shadow_offset_y", 1)
	root.add_child(hint)
	win_panel = PanelContainer.new()
	win_panel.set_anchors_preset(Control.PRESET_CENTER)
	win_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	win_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	win_panel.visible = false
	root.add_child(win_panel)
	var wv := VBoxContainer.new()
	win_panel.add_child(wv)
	var wl := Label.new()
	wl.text = "Das Tal blüht!\n\nAlle fünf Wahrzeichen stehen. Deine Pixler feiern ein Fest.\nDu kannst einfach weiterspielen."
	wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wl.add_theme_font_size_override("font_size", 18)
	wv.add_child(wl)
	var wb := Button.new()
	wb.text = "Weiter wuseln"
	wb.pressed.connect(func(): win_panel.visible = false)
	wv.add_child(wb)
	# Aufgabe (links oben) + Tutorial-Popup
	var op := PanelContainer.new()
	op.position = Vector2(10, 84)
	op.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(op)
	objective = Label.new()
	objective.custom_minimum_size = Vector2(320, 0)
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective.mouse_filter = Control.MOUSE_FILTER_IGNORE
	op.add_child(objective)
	popup_panel = PanelContainer.new()
	popup_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	popup_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	popup_panel.position.y = 120
	popup_panel.visible = false
	popup_panel.add_theme_stylebox_override("panel", _panel_style(Color("#2f211cf5"), Color("#ffd070")))
	root.add_child(popup_panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 10)
	popup_panel.add_child(pv)
	popup_title = Label.new()
	popup_title.add_theme_font_size_override("font_size", 20)
	popup_title.add_theme_color_override("font_color", Color("#ffd070"))
	pv.add_child(popup_title)
	popup_text = Label.new()
	popup_text.custom_minimum_size = Vector2(520, 0)
	popup_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pv.add_child(popup_text)
	var pb := Button.new()
	pb.text = "Verstanden"
	pb.custom_minimum_size = Vector2(0, 32)
	pb.pressed.connect(_popup_next)
	pv.add_child(pb)
	_set_mode("select", "")
	_tut_start()

# ------------------------------------------------------------ Tutorial
func _unlocked(type: String) -> bool:
	return tut >= 2 or type in TUT_UNLOCK[tut]

func _popup(title: String, text: String) -> void:
	popups.append([title, text])
	if not popup_panel.visible:
		_popup_next()

func _popup_next() -> void:
	if popups.is_empty():
		popup_panel.visible = false
		return
	var p: Array = popups.pop_front()
	popup_title.text = p[0]
	popup_text.text = p[1]
	popup_panel.visible = true
	sfx.play("click", 0.5)

func _tut_start() -> void:
	if tut >= 2:
		objective.get_parent().visible = false
		return
	_popup("Träger", "Fertige Waren bleiben im Gebäude liegen, bis ein Träger sie holt. Träger sitzen im Langhaus und in Trägerlagern. Sie laufen frei über die Karte, holen Waren aus Gebäuden im Umkreis und bringen sie dorthin, wo sie gebraucht werden, sonst ins Lager.\n\nIm Info-Panel stellst du ein, wie viele Träger (0 bis 10) und Schubkarren ein Haus hat. Pixler laufen ohne Wege langsamer. Mit dem Wegebauer kannst du Wege (R) und Trägerstationen (T) bauen.")
	_popup("Deine Pixler", "Im Dorf leben am Anfang 30 Pixler, das Langhaus bietet Platz für 50. Jeder Träger, jeder Bauarbeiter, jedes Produktionshaus und jedes Lagerhaus (im Langhaus arbeiten drei) braucht einen Pixler. Oben siehst du, wie viele noch frei sind.\n\nIst keiner mehr frei, bekommen neue Wegstücke keinen Träger und neue Häuser können nicht gebaut werden.\n\nNeue Pixler ziehen ein, wenn in der Taverne Mahlzeiten serviert werden (Wasser und Brot, Fisch oder Fleisch) und noch Wohnraum frei ist. Mehr Wohnraum bringen Wohnhäuser.")
	_popup("Bauarbeiter", "Neue Häuser sind Baustellen. Sind alle Materialien geliefert, laufen Bauarbeiter vom nächsten Lager zur Baustelle und bauen. Am Anfang gibt es nur wenige, jedes Lagerhaus bringt zwei weitere.\n\nWähle eine Baustelle an: Dort kannst du sie anhalten oder ihre Priorität erhöhen. Beim Abriss bekommst du Waren zurück.")
	_popup("Holz und Stein", "Der Holzfäller fällt Bäume, das Sägewerk macht daraus Bretter. Der Steinbruch bricht Steine aus Felsen, der Steinmetz macht daraus Steinblöcke.\n\nBretter und Steinblöcke werden für jedes weitere Haus gebraucht. Setze den Holzfäller neben Bäume und den Steinbruch neben Felsen. Bleibe im Umkreis eines Trägerlagers (oder des Langhauses), dann werden Material und Waren geliefert.")
	_tut_objective()

func _tut_objective() -> void:
	if tut == 0:
		objective.text = "Aufgabe 1: Baue Holzfäller, Sägewerk, Steinbruch und Steinmetz. Baue sie in Reichweite eines Trägerlagers."
	elif tut == 1:
		objective.text = "Aufgabe 2: Baue Fischer (am Wasser), Brunnen und Taverne. Ziel: die erste Mahlzeit."
	objective.get_parent().visible = tut < 2

func _done_count(type: String) -> int:
	var n := 0
	for b in sim.blds.values():
		if b.type == type and b.done:
			n += 1
	return n

func _tut_update() -> void:
	if tut == 0:
		if _done_count("holzfaeller") > 0 and _done_count("saegewerk") > 0 and _done_count("steinbruch") > 0 and _done_count("steinmetz") > 0:
			tut = 1
			_popup("Essen und Taverne", "Der Fischer fängt Fisch am Ufer, der Brunnen liefert Wasser. Die Taverne macht aus Wasser und Fisch Mahlzeiten, jede Mahlzeit lockt einen neuen Pixler ins Dorf.\n\nSetze den Fischer direkt ans Wasser. Baue Brunnen und Taverne dazu und achte darauf, dass ein Trägerlager alles erreicht.")
			_tut_objective()
			_show_cat(menu_cat)
	elif tut == 1:
		if _done_count("taverne") > 0 and sim.meals >= 1:
			tut = 2
			_popup("Das Dorf läuft", "Die Taverne hat die erste Mahlzeit serviert und ein Pixler ist eingezogen.\n\nDu kannst jetzt bauen: Wohnhäuser (mehr Platz für Pixler, ausbaubar wenn sie mit Gerichten und Wasser versorgt sind), Weizenfarm, Mühle und Bäckerei (Brot), Viehzucht und Metzgerei (Fleisch), Gärtner (Gemüse), Kräuterkundler, Pilzsammler und die Küche (Gerichte), Förster (pflanzt Bäume), Jäger, Lagerhaus (mehr Bauarbeiter) und Schubkarrenbauer. Träger mit Schubkarre tragen 3 Waren statt 1; die Karren verteilst du im Info-Panel der Trägerlager. Wegebauer und Trägerlager erweitern dein Transportnetz.\n\nAus den Landschaften kommen besondere Waren: Feenstaub aus dem Feenwald, Obsidian vom Vulkan, Glühpilze aus dem Sumpf, Sand aus der Wüste (in der Glashütte mit Holz zu Glas) und Eis vom gefrorenen See.\n\nZiel: Baue die fünf Wahrzeichen. Jedes braucht eine dieser besonderen Waren.")
			_tut_objective()
			_show_cat(menu_cat)
	# Warnung vor Pixler-Mangel
	var free := sim.free_pixlers()
	if sim.waiting_for_pixler() > 0 and free <= 0 and time - last_starve_msg > 25.0:
		last_starve_msg = time
		say("%d Träger-Platz/Plätze unbesetzt: keine freien Pixler. Baue die Taverne." % sim.waiting_for_pixler(), 5.0)
	var has_tavern := false
	for tb in sim.blds.values():
		if tb.type == "taverne":
			has_tavern = true
	if not pop_warned and free <= 3 and tut < 2 and not has_tavern:
		pop_warned = true
		_popup("Nur noch %d Pixler frei", "Jeder Träger und jedes Produktionshaus braucht einen Pixler. Es sind fast alle im Einsatz. Neue Pixler ziehen ein, wenn die Taverne Mahlzeiten serviert. Baue sie als Nächstes." % sim.free_pixlers())
	if tut >= 2 and free > 0 and free <= 2 and time - last_low_msg > 90.0:
		last_low_msg = time
		say("Nur noch %d freie Pixler. Die Taverne holt neue ins Dorf, Wohnhäuser schaffen Platz." % free, 5.0)
	if not pop_warned2 and free <= 0 and tut >= 2 and sim.meals < 3:
		pop_warned2 = true
		say("Alle Pixler sind im Einsatz. Die Taverne holt neue ins Dorf, Wohnhäuser schaffen Platz.", 5.0)

func _toggle_mute() -> void:
	sfx.muted = not sfx.muted
	mute_btn.text = "Ton aus" if sfx.muted else "Ton an"

func _set_info_goods(items: Array) -> void:
	# Ware als kleines Icon, dahinter die Anzahl (vorhanden oder vorhanden/benoetigt)
	var sig := ""
	for it in items:
		sig += it[0] + ","
	if sig != info_sig:
		info_sig = sig
		for ch in info_goods.get_children():
			ch.queue_free()
		info_labs = []
		for it in items:
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", 3)
			var tr := TextureRect.new()
			tr.texture = Art.goods[it[0]]
			tr.custom_minimum_size = Vector2(20, 20)
			tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			tr.tooltip_text = Data.GNAME[it[0]]
			tr.mouse_filter = Control.MOUSE_FILTER_PASS
			hb.add_child(tr)
			var lb := Label.new()
			lb.add_theme_font_size_override("font_size", 14)
			hb.add_child(lb)
			info_goods.add_child(hb)
			info_labs.append(lb)
	for k in items.size():
		var it2: Array = items[k]
		var lab: Label = info_labs[k]
		lab.text = str(it2[1]) if it2[2] < 0 else "%d/%d" % [it2[1], it2[2]]
		lab.modulate = Color(1, 0.62, 0.55) if (it2[2] >= 0 and it2[1] < it2[2]) else Color.WHITE
	info_goods.visible = not items.is_empty()

func _content_count(b: Sim.Bld) -> int:
	var n := 0
	for k in b.stock:
		n += b.stock[k]
	for k in b.inbox:
		n += b.inbox[k]
	return n

func _try_demolish(b: Sim.Bld) -> bool:
	# true, wenn das Gebaeude abgerissen wurde. Gebaeude mit Inhalt oder Ausbau fragen nach.
	if not sim.can_demolish(b):
		say("Das %s lässt sich nicht abreißen." % ("Langhaus" if b.type == "hq" else "Lagerhaus"), 2.5)
		sfx.play("deny", 0.5)
		return false
	var n := _content_count(b) if b.done else 0
	var lv: int = b.level if b.type == "haus" and b.done else 1
	if (n > 0 or lv > 1) and not (demo_pending == b.id and time - demo_pending_t < 4.0):
		demo_pending = b.id
		demo_pending_t = time
		var why := PackedStringArray()
		if n > 0:
			why.append("%d Waren" % n)
		if lv > 1:
			why.append("Ausbaustufe %d" % lv)
		say("%s enthält %s (Waren gehen zurück ins Lager, Ausbau nur zur Hälfte). Nochmal klicken zum Abreißen." % [Data.BD[b.type].n, " und ".join(why)], 4.0)
		sfx.play("deny", 0.4)
		return false
	demo_pending = -1
	sim.demolish(b)
	return true

func _undo_road() -> void:
	if road_undo.is_empty():
		say("Kein Weg zum Zurücknehmen.", 1.5)
		return
	var last: Dictionary = road_undo.pop_back()
	sim.undo_road(last.ids)
	road_start = last.start if mode == "road" else null
	road_prev = []
	road_prev_key = ""
	sfx.play("deny", 0.5)
	say("Weg zurückgenommen.", 1.2)

func _show_cat(c: String) -> void:
	# Kategorien ohne freigeschaltete Gebaeude verschwinden im Tutorial
	for b in cat_buttons:
		var any := tut >= 2
		for k in Data.BD:
			if Data.BD[k].cat == b.text and _unlocked(k):
				any = true
		b.visible = any
	if not cat_buttons[Data.CATS.find(c)].visible:
		c = "Basis"
	menu_cat = c
	for b in cat_buttons:
		b.set_pressed_no_signal(b.text == c)
	for ch in menu_grid.get_children():
		ch.queue_free()
	for k in Data.BD:
		var d: Dictionary = Data.BD[k]
		if d.cat != c:
			continue
		if tut < 2 and not _unlocked(k):
			continue   # im Tutorial nur die aktuell benoetigten Gebaeude zeigen
		var b := Button.new()
		b.icon = _icon_for(Art.bld[k][0], 44)
		b.text = d.n
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.custom_minimum_size = Vector2(112, 84)
		b.tooltip_text = _tip(k)
		b.add_theme_font_size_override("font_size", 11)
		if not _unlocked(k):
			b.disabled = true
			b.tooltip_text = "Wird freigeschaltet, sobald die Aufgabe links oben erledigt ist.\n\n" + _tip(k)
		b.pressed.connect(func(): _set_mode("build", k))
		menu_grid.add_child(b)

func _set_mode(m: String, bt: String) -> void:
	if (m == "road" or m == "station") and not sim.roads_unlocked():
		say("Dafür brauchst du zuerst einen Wegebauer.", 2.5)
		if sfx != null:
			sfx.play("deny", 0.5)
		m = "select"
	elif sfx != null:
		sfx.play("click", 0.4)
	mode = m
	build_type = bt
	road_start = null
	road_prev = []
	road_prev_key = ""
	for k in tool_buttons:
		tool_buttons[k].set_pressed_no_signal(k == m)
	if m != "select":
		sel = null

func say(t: String, dur: float = 3.0) -> void:
	toast.text = t
	toast.visible = true
	toast_t = dur

func _mini_input(ev: InputEvent) -> void:
	if (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0):
		var p: Vector2 = ev.position / mini_tex.size * Vector2(MW, MH) * TS
		cam.position = p

func _update_ui() -> void:
	for g in lab_res:
		lab_res[g].text = str(sim.total_stock(g))
	var used := sim.used_workers()
	var free := sim.free_pixlers()
	var pcap := sim.pop_cap()
	lab_pop.text = "Pixler %d/%d   Häuser %d · Träger %d · Bau %d · frei %d" % [sim.pop, pcap, used, sim.carrier_count(), sim.builders_active(), free]
	for sb in speed_btns:
		sb[0].set_pressed_no_signal(is_equal_approx(speed, sb[1]))
	lab_pop.tooltip_text = "%d von %d Wohnplätzen belegt:\n%d arbeiten als Träger (Langhaus, Trägerlager, Stationen)\n%d arbeiten in Häusern\n%d sind Bauarbeiter im Einsatz\n%d sind frei\nNeue Pixler ziehen ein, wenn die Taverne Mahlzeiten serviert und Wohnraum frei ist (Wohnhäuser)." % [sim.pop, pcap, sim.carrier_count(), used, sim.builders_active(), free]
	lab_builder.text = "Bauarbeiter %d/%d" % [sim.builders_active(), sim.builder_cap()]
	lab_pop.modulate = Color(1, 0.55, 0.45) if free <= 0 else (Color(1, 0.9, 0.5) if free == 1 else Color(0.85, 1, 0.8))
	lab_barrow.text = "Karren %d/%d" % [sim.barrows_free, sim.barrows_total]
	_tut_update()
	for lm in LM_ORDER:
		lab_lm[lm].modulate = Color(1, 0.9, 0.4, 1.0) if sim.landmarks.has(lm) else Color(1, 1, 1, 0.3)
	var dt := _day_t()
	var h := int(dt * 24.0)
	var m := int(fposmod(dt * 24.0, 1.0) * 60.0)
	lab_time.text = "%02d:%02d" % [h, m]
	if sel != null and not sim.blds.has(sel.id):
		sel = null
	info_panel.visible = sel != null
	if sel != null:
		var d: Dictionary = Data.BD[sel.type]
		var s: String = d.n + "\n"
		var is_site: bool = not sel.done
		var items: Array = []   # [Ware, vorhanden, benoetigt (-1 = keine Grenze)]
		if is_site:
			s += ("Ausbau: %d%%\n" if sel.upg else "Baustelle: %d%%\n") % int(sel.prog * 100.0)
			s += "Status: " + sel.msg + "\n"
			var sc := sim.site_cost(sel)
			for k in sc:
				items.append([k, sel.inbox.get(k, 0), sc[k]])
			s += "Priorität: " + ("Hoch" if sel.prio > 0 else ("Niedrig" if sel.prio < 0 else "Normal"))
		elif d.kind == "house":
			s += "%s (Stufe %d, %d Plätze)\n" % [Data.HOUSE_NAME[sel.level], sel.level, Data.HOUSE_CAP[sel.level]]
			s += "Status: " + (sel.msg if sel.msg != "" else "bereit")
			for k in sel.cap:
				items.append([k, sel.inbox.get(k, 0), sel.cap[k]])
			if sel.level < 3:
				s += "\nVersorgung für Ausbau: %d/%d" % [mini(sel.fed, Data.HOUSE_UP[sel.level].fed), Data.HOUSE_UP[sel.level].fed]
		elif d.kind == "store":
			s += "Lager"
			for k in Data.GOODS:
				if sel.stock.get(k, 0) > 0:
					items.append([k, sel.stock[k], -1])
		elif d.kind == "hub":
			s += "Reichweite: %d Zellen\n" % int(d.R)
			s += "Status: " + ("%d Träger unterwegs oder sitzen bereit" % sel.carriers.size() if sel.carriers.size() > 0 else "Keine Träger")
		else:
			s += "Status: " + (sel.msg if sel.msg != "" else "bereit")
			for k in sel.cap:
				items.append([k, sel.inbox.get(k, 0), sel.cap[k]])
			for k in sel.outbox:
				if sel.outbox[k] > 0:
					items.append([k, sel.outbox[k], -1])
		if d.has("hub") and sel.done:
			s += ("\n" if d.kind == "hub" else "\n\n") + "Träger: %d von %d besetzt\nSchubkarren: %d" % [sel.carriers.size(), sel.cn, sel.barrows]
			for k in Data.GOODS:
				if d.kind == "hub" and sel.stock.get(k, 0) > 0:
					items.append([k, sel.stock[k], -1])
		_set_info_goods(items)
		info_hub.visible = d.has("hub") and sel.done
		info_label.text = s
		info_pause.text = "Weiter" if sel.paused else "Pause"
		info_pause.visible = d.kind != "store" and d.kind != "lm" and d.kind != "hub" and d.kind != "service" and (is_site or d.kind != "house")
		info_prio.visible = is_site
		info_prio.text = "Priorität: " + ("Hoch" if sel.prio > 0 else ("Niedrig" if sel.prio < 0 else "Normal"))
		var pr := sim.progress(sel)
		info_bar.visible = pr >= 0.0
		info_bar.value = maxf(pr, 0.0)
		info_demo.visible = sim.can_demolish(sel)
		info_up.visible = sel.type == "haus" and sel.done and sel.level < 3
		if info_up.visible:
			var up = Data.HOUSE_UP[sel.level]
			info_up.disabled = sim.upgrade_error(sel) != ""
			info_up.tooltip_text = "Ausbau zu %s (%d Plätze)\nKosten: %s\nBedingung: %d× mit Gerichten und Wasser versorgt (jetzt %d)." % [Data.HOUSE_NAME[sel.level + 1], Data.HOUSE_CAP[sel.level + 1], _cost_text(up.cost), up.fed, sel.fed]
	if sim.landmarks.size() >= 5 and not won_shown:
		won_shown = true
		win_panel.visible = true

func _update_mini() -> void:
	mini_img = mini_base.duplicate() as Image
	for s in sim.roads.values():
		for c in s.cells:
			mini_img.set_pixel(c[0], c[1], Color("#c39a5e"))
	for b in sim.blds.values():
		var col := Color("#ffffff") if b.done else Color("#ffd070")
		for yy in range(b.y, b.y + b.h):
			for xx in range(b.x, b.x + b.w):
				mini_img.set_pixel(xx, yy, col)
	var vs := get_viewport_rect().size / cam.zoom.x / TS
	var c := cam.position / TS
	var r := Rect2i(int(c.x - vs.x / 2), int(c.y - vs.y / 2), int(vs.x), int(vs.y))
	for x in range(r.position.x, r.end.x + 1):
		for y in [r.position.y, r.end.y]:
			if sim.inb(x, y): mini_img.set_pixel(x, y, Color.WHITE)
	for y in range(r.position.y, r.end.y + 1):
		for x in [r.position.x, r.end.x]:
			if sim.inb(x, y): mini_img.set_pixel(x, y, Color.WHITE)
	mini_tex.texture = ImageTexture.create_from_image(mini_img)

# ------------------------------------------------------------ Zeit
# Ein Tag dauert 10 Minuten: 6 Minuten Tag, 4 Minuten Nacht (Daemmerung inklusive, je ca. 50 s).
const DAY_LEN := 360.0
const NIGHT_LEN := 240.0

func _phase() -> float:
	# 0 = Morgendaemmerung (halbhell), 0.6 = Abenddaemmerung, davor Tag, danach Nacht
	return fposmod(0.15 + sim.t / (DAY_LEN + NIGHT_LEN), 1.0)

func _day_t() -> float:
	# Uhrzeit als Bruchteil von 24 h: Tag 06:00-20:00, Nacht 20:00-06:00
	var p := _phase()
	var h := 6.0 + p / 0.6 * 14.0 if p < 0.6 else 20.0 + (p - 0.6) / 0.4 * 10.0
	return fposmod(h / 24.0, 1.0)

func _night() -> float:
	var p := _phase()
	if p < 0.5:
		return 1.0 - smoothstep(-0.04, 0.04, p)
	return smoothstep(0.56, 0.64, p) * (1.0 - smoothstep(-0.04, 0.04, p - 1.0))

# ------------------------------------------------------------ Eingabe
func _zoom_index(z: float) -> int:
	var best := 0
	for k in ZOOMS.size():
		if absf(ZOOMS[k] - z) < absf(ZOOMS[best] - z):
			best = k
	return best

func _bo() -> Vector2i:
	# Bauplatz: das Gebaeude haengt zentriert am Mauszeiger
	var d: Dictionary = Data.BD[build_type]
	return Vector2i(hover.x - d.w / 2, hover.y - d.h / 2)

func _set_zoom(d: int) -> void:
	zoom_i = clampi(zoom_i + d, 0, ZOOMS.size() - 1)
	cam.zoom = Vector2(ZOOMS[zoom_i], ZOOMS[zoom_i])

func _unhandled_input(ev: InputEvent) -> void:
	if popup_panel != null and popup_panel.visible:
		if ev is InputEventKey and ev.pressed and not ev.echo and (ev.keycode == KEY_ENTER or ev.keycode == KEY_KP_ENTER):
			_popup_next()
		return
	if ev is InputEventMouseButton:
		if ev.pressed:
			match ev.button_index:
				MOUSE_BUTTON_WHEEL_UP: _set_zoom(1)
				MOUSE_BUTTON_WHEEL_DOWN: _set_zoom(-1)
				MOUSE_BUTTON_MIDDLE: pan_drag = true
				MOUSE_BUTTON_RIGHT:
					if mode == "select":
						pan_drag = true
					elif mode == "road" and road_start != null:
						road_start = null
						road_prev = []
					else:
						_set_mode("select", "")
				MOUSE_BUTTON_LEFT: _click()
		else:
			if ev.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
				pan_drag = false
	elif ev is InputEventMouseMotion and pan_drag:
		cam.position -= ev.relative / cam.zoom.x
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_ESCAPE: _set_mode("select", "")
			KEY_R: _set_mode("road", "")
			KEY_T: _set_mode("station", "")
			KEY_X: _set_mode("demolish", "")
			KEY_F5: get_tree().reload_current_scene()
			KEY_Z: _undo_road()
			KEY_M: _toggle_mute()
			KEY_SPACE: speed = 0.0 if speed > 0.0 else 1.0
			KEY_EQUAL, KEY_KP_ADD: _set_zoom(1)
			KEY_MINUS, KEY_KP_SUBTRACT: _set_zoom(-1)

func _tile_at(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / TS)), int(floor(p.y / TS)))

func _click() -> void:
	var t := hover
	if not sim.inb(t.x, t.y):
		return
	var i := t.y * MW + t.x
	match mode:
		"select":
			sel = sim.blds.get(sim.occ[i]) if sim.occ[i] != 0 else null
		"build":
			var o := _bo()
			var err := sim.can_place(build_type, o.x, o.y)
			if err != "":
				say(err, 2.5)
				sfx.play("deny", 0.5)
			elif not _unlocked(build_type):
				say("Noch gesperrt.", 2.0)
			else:
				sim.place_building(build_type, o.x, o.y)
				sfx.play("place", 0.9)
				say(Data.BD[build_type].n + " wird gebaut.", 3.0)
		"road":
			var cell := _road_cell(t)
			if road_start == null:
				if cell.x < 0 or not sim.passable(cell.x, cell.y):
					say("Hier kann kein Weg beginnen.", 2.0)
				else:
					road_start = cell
			else:
				if road_prev.size() > 1:
					var ids := sim.add_road(road_prev)
					if ids.is_empty():
						say("Dort ist schon ein Weg.", 2.0)
					else:
						road_undo.append({"ids": ids, "start": Vector2i(road_prev[0][0], road_prev[0][1])})
						if road_undo.size() > 40:
							road_undo.pop_front()
						sfx.play("place", 0.6)
					var last: Array = road_prev[road_prev.size() - 1]
					road_start = Vector2i(last[0], last[1])
					road_prev = []
					road_prev_key = ""
				else:
					say("Kein Weg dorthin möglich.", 2.0)
		"station":
			var err := sim.station_error(t.x, t.y)
			if err != "":
				say(err, 2.5)
				sfx.play("deny", 0.5)
			else:
				sim.place_station(t.x, t.y)
				sfx.play("place", 0.9)
				say("Trägerstation gebaut: ein Pixler sitzt auf dem Fliegenpilz und beschleunigt den Weg.", 3.0)
		"demolish":
			if sim.occ[i] != 0:
				var b = sim.blds.get(sim.occ[i])
				if b != null:
					_try_demolish(b)
			else:
				sim.remove_road_at(t.x, t.y)

func _road_cell(t: Vector2i) -> Vector2i:
	if not sim.inb(t.x, t.y):
		return Vector2i(-1, -1)
	var i := t.y * MW + t.x
	if sim.occ[i] != 0:
		var b = sim.blds.get(sim.occ[i])
		if b != null:
			return b.door
		return Vector2i(-1, -1)
	return t

# ------------------------------------------------------------ Sound
var mix_t := 0.0
var mix_target := {}

func _audio(delta: float) -> void:
	mix_t -= delta
	if mix_t <= 0.0:
		mix_t = 0.4
		var c := Vector2i(int(cam.position.x / TS), int(cam.position.y / TS))
		var water := 0
		for yy in range(c.y - 12, c.y + 13, 2):
			for xx in range(c.x - 16, c.x + 17, 2):
				if sim.inb(xx, yy):
					var g := sim.ground[yy * MW + xx]
					if g <= Data.T.WATER:
						water += 1
		var g0 := sim.ground[clampi(c.y, 0, MH - 1) * MW + clampi(c.x, 0, MW - 1)]
		var night := _night()
		sfx.night = night
		var day := 1.0 - night
		var cold: bool = g0 == Data.T.SNOW or g0 == Data.T.ICE
		var harsh: bool = cold or g0 == Data.T.ROCK or g0 == Data.T.ASH or g0 == Data.T.DESERT
		var zk := 0.7 + 0.08 * zoom_i
		mix_target = {
			"music": 0.32,
			"wind": (0.10 if harsh else 0.0) * zk,
			"birds": (0.14 * day if not (cold or g0 == Data.T.DESERT or g0 == Data.T.ASH) else 0.0) * zk,
			"crickets": (0.2 * night if not cold else 0.0) * zk,
			"waves": clampf((water - 20) / 120.0, 0.0, 1.0) * 0.16 * zk,
		}
	sfx.set_mix(mix_target, delta)
	# Gebaeude-Geraeusche
	hammer_t -= delta
	var vr := _view_rect().grow(48)
	var hammer_now := false
	if hammer_t <= 0.0:
		hammer_t = 1.4
		hammer_now = true
	for b in sim.blds.values():
		var pos := Vector2((b.x + b.w * 0.5) * TS, (b.y + b.h * 0.5) * TS)
		var vol := _vol_at(pos, 1.0)
		if not b.done:
			if b.busy and hammer_now:
				sfx.play("hammer", vol * 0.8)
			continue
		var old: String = last_st.get(b.id, "")
		if b.st != old:
			last_st[b.id] = b.st
			if vol <= 0.01:
				continue
			if b.st == "act":
				match b.type:
					"holzfaeller": sfx.play("axe", vol)
					"steinbruch", "eishauer", "sandgrube", "obsidian": sfx.play("pick", vol)
					"fischer": sfx.play("splash", vol * 0.8)
			elif b.st == "work":
				match b.type:
					"saegewerk": sfx.play("saw", vol * 0.6)
					"steinmetz": sfx.play("pick", vol)
					"wagner", "glashuette": sfx.play("hammer", vol)
					"taverne": sfx.play("tavern", vol * 0.8)
					"kueche", "metzger": sfx.play("clink", vol * 0.7)

func _vol_at(pos: Vector2, base: float) -> float:
	# Geraeusche sind nur nah dran und reingezoomt gut zu hoeren, sonst sehr leise
	var zf: float = [0.0, 0.1, 0.3, 0.55, 0.8, 1.0][clampi(zoom_i, 0, 5)]
	var vs := get_viewport_rect().size / cam.zoom.x
	var reach := vs.length() * 0.6
	var k := clampf(1.0 - pos.distance_to(cam.position) / reach, 0.0, 1.0)
	return base * zf * k * k

# ------------------------------------------------------------ Update
func _process(delta: float) -> void:
	time += delta
	var d := delta * speed
	if popup_panel != null and popup_panel.visible:
		d = 0.0
	_audio(delta)
	while d > 0.0:
		var st := minf(d, 0.1)
		sim.update(st)
		d -= st
	# Kamera
	var dir := Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	if Input.is_key_pressed(KEY_A): dir.x -= 1
	if Input.is_key_pressed(KEY_D): dir.x += 1
	if Input.is_key_pressed(KEY_W): dir.y -= 1
	if Input.is_key_pressed(KEY_S): dir.y += 1
	if dir != Vector2.ZERO:
		cam.position += dir.normalized() * 520.0 * delta / cam.zoom.x
	var vs := get_viewport_rect().size / cam.zoom.x
	cam.position = cam.position.clamp(Vector2(vs.x * 0.25, vs.y * 0.25), Vector2(MW * TS - vs.x * 0.25, MH * TS - vs.y * 0.25))
	hover = _tile_at(get_global_mouse_position())
	hover_ui = get_viewport().gui_get_hovered_control() != null
	_events()
	_ambient(delta)
	for b in birds:
		b.x += b.v * delta
		if b.x > MW * TS + 40:
			b.x = -40
			b.y = rng.randf() * MH * TS
	for f in flies:
		f.a += rng.randf_range(-3.0, 3.0) * delta
		f.x += cos(f.a) * 9.0 * delta
		f.y += sin(f.a) * 9.0 * delta
		f.x = fposmod(f.x, MW * TS)
		f.y = fposmod(f.y, MH * TS)
	_upd_parts(delta)
	ui_t += delta
	if ui_t > 0.25:
		ui_t = 0.0
		_update_ui()
	mini_t += delta
	if mini_t > 0.5:
		mini_t = 0.0
		_update_mini()
	if toast_t > 0.0:
		toast_t -= delta
		if toast_t <= 0.0:
			toast.visible = false
	_update_hint()
	queue_redraw()
	night_layer.queue_redraw()
	glow_layer.queue_redraw()
	frame_count += 1
	if shot_path != "" and frame_count == shot_frames:
		get_viewport().get_texture().get_image().save_png(shot_path)
		get_tree().quit()

func _update_hint() -> void:
	ghost_err = ""
	var h := ""
	if mode == "build" and sim.inb(hover.x, hover.y):
		var bo := _bo()
		ghost_err = sim.can_place(build_type, bo.x, bo.y)
		h = ghost_err if ghost_err != "" else Data.BD[build_type].n + ": Klick zum Bauen"
	elif mode == "road":
		h = "Weg: Klick auf ein Gebäude oder eine freie Stelle als Start, dann das Ziel anklicken. Rechtsklick beendet." if road_start == null else "Ziel anklicken (Kette möglich). Rechtsklick/Esc beendet."
	elif mode == "station":
		h = "Trägerstation: Klick auf einen Weg. Der Fliegenpilz kommt in die Mitte des Weges, ein Pixler macht ihn schneller."
	elif mode == "demolish":
		h = "Klick auf Gebäude, Weg oder Trägerstation zum Abreißen."
	hint.text = h
	if mode == "road" and road_start != null and sim.inb(hover.x, hover.y):
		var goal := _road_cell(hover)
		var key := "%d,%d,%d,%d,%d" % [road_start.x, road_start.y, goal.x, goal.y, sim.net_ver]
		if key != road_prev_key:
			road_prev_key = key
			road_prev = sim.find_path(road_start.x, road_start.y, goal.x, goal.y) if goal.x >= 0 else []
	elif mode != "road":
		road_prev = []

func _events() -> void:
	for e in sim.events:
		match e[0]:
			"up":
				sfx.play("pop", _vol_at(Vector2(e[2] * TS, e[3] * TS), 0.8))
				say(e[1], 3.5)
				for k in 8:
					_part("spark", e[2] * TS + rng.randf_range(-24, 24), e[3] * TS + rng.randf_range(-12, 20), Color("#ffe9a8"))
			"refund":
				say(e[1], 2.5)
			"done":
				sfx.play("pop", _vol_at(Vector2(e[2] * TS, e[3] * TS), 0.8))
				for k in 8:
					_part("spark", e[2] * TS + rng.randf_range(-24, 24), e[3] * TS + rng.randf_range(-12, 20), Color("#ffe9a8"))
			"barrow":
				sfx.play("barrow", _vol_at(Vector2(e[2] * TS, e[3] * TS), 0.7))
				say(e[1], 2.5)
			"meal":
				sfx.play("bell", _vol_at(Vector2(e[2] * TS, e[3] * TS), 0.7))
				say(e[1], 3.0)
				for k in 5:
					_part("heart", e[2] * TS + rng.randf_range(-16, 16), e[3] * TS + 30, Color("#ff7a9a"))
			"lm":
				sfx.play("fanfare", 0.9)
				say("Wahrzeichen vollendet: " + e[1] + "!  +4 Wohnplätze", 5.0)
				for k in 30:
					_part("spark", e[2] * TS + rng.randf_range(-48, 48), e[3] * TS + rng.randf_range(-40, 40), Color("#ffd0ff"))
	sim.events.clear()

# ------------------------------------------------------------ Partikel
func _part(kind: String, x: float, y: float, col: Color) -> void:
	if parts.size() > 500:
		return
	var p := {"k": kind, "x": x, "y": y, "vx": 0.0, "vy": 0.0, "life": 1.5, "max": 1.5, "c": col, "s": 1.0}
	match kind:
		"smoke":
			p.vx = rng.randf_range(2.0, 6.0)
			p.vy = -rng.randf_range(6.0, 11.0)
			p.life = 2.2
			p.max = 2.2
		"snow":
			p.vx = rng.randf_range(-3.0, 3.0)
			p.vy = rng.randf_range(10.0, 18.0)
			p.life = 3.0
			p.max = 3.0
		"ember":
			p.vx = rng.randf_range(-4.0, 4.0)
			p.vy = -rng.randf_range(8.0, 16.0)
			p.life = 2.0
			p.max = 2.0
		"spark":
			p.vx = rng.randf_range(-12.0, 12.0)
			p.vy = -rng.randf_range(6.0, 22.0)
			p.life = 1.2
			p.max = 1.2
		"heart":
			p.vx = rng.randf_range(-4.0, 4.0)
			p.vy = -rng.randf_range(12.0, 20.0)
			p.life = 1.6
			p.max = 1.6
		"mote":
			p.vx = rng.randf_range(-3.0, 3.0)
			p.vy = -rng.randf_range(2.0, 7.0)
			p.life = 3.0
			p.max = 3.0
	parts.append(p)

func _upd_parts(dt: float) -> void:
	for p in parts:
		p.life -= dt
		p.x += p.vx * dt
		p.y += p.vy * dt
		if p.k == "smoke":
			p.s += dt * 2.0
	parts = parts.filter(func(p): return p.life > 0.0)

func _view_rect() -> Rect2:
	var vs := get_viewport_rect().size / cam.zoom.x
	return Rect2(cam.position - vs / 2.0, vs)

func _ambient(delta: float) -> void:
	var vr := _view_rect()
	var x0 := maxi(0, int(vr.position.x / TS))
	var y0 := maxi(0, int(vr.position.y / TS))
	var x1 := mini(MW - 1, int(vr.end.x / TS))
	var y1 := mini(MH - 1, int(vr.end.y / TS))
	var n := int(vr.size.x * vr.size.y / 5000.0 * delta * 6.0) + 1
	for k in n:
		var x := rng.randi_range(x0, x1)
		var y := rng.randi_range(y0, y1)
		var g := sim.ground[y * MW + x]
		var px := x * TS + rng.randf() * TS
		var py := y * TS + rng.randf() * TS
		match g:
			Data.T.SNOW:
				if rng.randf() < 0.5: _part("snow", px, y0 * TS - 8 + rng.randf() * 10.0 + (py - y0 * TS) * 0.0, Color.WHITE)
			Data.T.LAVA:
				if rng.randf() < 0.35: _part("ember", px, py, Color("#ff9a30"))
			Data.T.FAIRY:
				if rng.randf() < 0.25: _part("mote", px, py, Color("#ffd8ff") if rng.randf() < 0.5 else Color("#a8f4ff"))
			Data.T.SWAMP, Data.T.MARSH:
				if rng.randf() < 0.1: _part("mote", px, py, Color("#b8ff80"))
			Data.T.ASH:
				if rng.randf() < 0.05: _part("ember", px, py, Color("#ff8a30"))
	for b in sim.blds.values():
		if b.done and b.busy and Data.BD[b.type].kind == "process" and rng.randf() < delta * 1.4:
			if b.type in ["baeckerei", "saegewerk", "glashuette", "taverne", "steinmetz", "kueche", "metzger"]:
				_part("smoke", (b.x + b.w) * TS - 24 + rng.randf() * 4.0, (b.y + b.h) * TS - 70, Color(0.9, 0.9, 0.95))

# ------------------------------------------------------------ Zeichnen
func spr(tx: Texture2D, foot: Vector2, flip: bool = false, mod: Color = Color.WHITE) -> void:
	var w := tx.get_width()
	var h := tx.get_height()
	var fx := roundf(foot.x)
	var fy := roundf(foot.y)
	if flip:
		draw_set_transform(Vector2(fx, 0), 0.0, Vector2(-1, 1))
		draw_texture(tx, Vector2(-(w >> 1), fy - h), mod)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_texture(tx, Vector2(fx - (w >> 1), fy - h), mod)

const ROAD_EDGE := Color("#a2774a")
const ROAD_FILL := Color("#d3a96c")
const ROAD_LIGHT := Color("#e3bd82")
const ROAD_W := 8.0

func _seg_pts(s: Sim.Road) -> void:
	# Weg als Polylinie ueber die Zellmitten; Knickpunkte bekommen runde Gelenke
	var pts := PackedVector2Array()
	var bends := PackedVector2Array()
	var n: int = s.cells.size()
	for k in n:
		var c: Array = s.cells[k]
		var p := Vector2(c[0] * TS + TS * 0.5, c[1] * TS + TS * 0.5)
		pts.append(p)
		if k == 0 or k == n - 1:
			continue
		var a: Array = s.cells[k - 1]
		var b: Array = s.cells[k + 1]
		if (c[0] - a[0]) != (b[0] - c[0]) or (c[1] - a[1]) != (b[1] - c[1]):
			bends.append(p)
	s.pts = pts
	s.bends = bends

func _draw_roads(x0: int, y0: int, x1: int, y1: int) -> void:
	var vis: Array = []
	for s in sim.roads.values():
		var bb: Rect2i = s.bb
		if bb.position.x > x1 or bb.end.x < x0 or bb.position.y > y1 or bb.end.y < y0:
			continue
		if s.pts.is_empty():
			_seg_pts(s)
		vis.append(s)
	# 1. Rand, 2. Fuellung, 3. Glanz: alle Wege einer Ebene zusammen, damit Abzweige ohne Naht verschmelzen
	for s in vis:
		draw_polyline(s.pts, ROAD_EDGE, ROAD_W + 2.0)
		for p in s.bends:
			draw_circle(p, ROAD_W * 0.5 + 1.0, ROAD_EDGE)
		draw_circle(s.pts[0], ROAD_W * 0.5 + 1.0, ROAD_EDGE)
		draw_circle(s.pts[s.pts.size() - 1], ROAD_W * 0.5 + 1.0, ROAD_EDGE)
	for s in vis:
		draw_polyline(s.pts, ROAD_FILL, ROAD_W)
		for p in s.bends:
			draw_circle(p, ROAD_W * 0.5, ROAD_FILL)
		draw_circle(s.pts[0], ROAD_W * 0.5, ROAD_FILL)
		draw_circle(s.pts[s.pts.size() - 1], ROAD_W * 0.5, ROAD_FILL)
	for s in vis:
		draw_polyline(s.pts, ROAD_LIGHT, 3.0)
		for c in s.cells:
			var h := Data.hsh(c[0], c[1], 7.0)
			if h < 0.45:
				var qx: float = c[0] * TS + 3.0 + floorf(Data.hsh(c[1], c[0], 2.0) * 10.0)
				var qy: float = c[1] * TS + 4.0 + floorf(Data.hsh(c[0] * 3.0, c[1], 4.0) * 8.0)
				draw_rect(Rect2(qx, qy, 1 + (1 if h < 0.15 else 0), 1), ROAD_EDGE if h < 0.3 else Color("#f0d3a0"))

func _draw() -> void:
	var vr := _view_rect()
	var x0 := maxi(0, int(vr.position.x / TS) - 3)
	var y0 := maxi(0, int(vr.position.y / TS) - 1)
	var x1 := mini(MW - 1, int(vr.end.x / TS) + 3)
	var y1 := mini(MH - 1, int(vr.end.y / TS) + 1)
	var yb := mini(MH - 1, y1 + 6)    # Objekte unterhalb des Bildes ragen mit der Krone noch hinein
	var rows: Array = []
	for r in range(y0, yb + 3):
		rows.append([])
	# Boden-Ebene: Felder, Wege, Stuempfe
	for b in sim.blds.values():
		if b.fields.is_empty():
			continue
		var tx: Array = Art.fieldt2 if b.type == "garten" else Art.fieldt
		for i in b.fields:
			if sim.field[i] != b.id:
				continue
			var fx: int = i % MW
			var fy: int = i / MW
			if fx < x0 or fx > x1 or fy < y0 or fy > y1:
				continue
			var stg := int(fposmod(time * 0.1 + Data.hsh(fx, fy) * 4.0, 4.0))
			draw_texture(tx[stg], Vector2(fx * TS, fy * TS))
	_draw_roads(x0, y0, x1, y1)
	var cx0 := x0 / Sim.CH
	var cx1 := x1 / Sim.CH
	var cy0 := y0 / Sim.CH
	var cy1 := yb / Sim.CH
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			var ci: int = cy * Sim.NCX + cx
			for i in sim.chunk_stump[ci]:
				var sx: int = i % MW
				var sy: int = i / MW
				if sx >= x0 and sx <= x1 and sy >= y0 and sy <= y1 and sim.obj[i] == 0:
					spr(Art.stumpt, Vector2(sx * TS + 8, sy * TS + 14))
			for i in sim.chunk_obj[ci]:
				var ox: int = i % MW
				var oy: int = i / MW
				if ox >= x0 and ox <= x1 and oy >= y0 and oy <= yb:
					rows[oy - y0].append([0, i])
	var rmax := rows.size() - 1
	for b in sim.blds.values():
		var r: int = b.y + b.h - 1 - y0
		if r >= -6 and r <= rmax + 6 and b.x + b.w >= x0 - 2 and b.x <= x1 + 2 and b.y + b.h >= y0 - 2 and b.y <= yb + 8:
			rows[clampi(r, 0, rmax)].append([1, b])
			if b.st in ["walk", "act", "back", "out", "ret"]:
				var wr := clampi(int(b.wy) - y0, 0, rmax)
				rows[wr].append([3, b])
	for s in sim.stations.values():
		if s.x >= x0 - 1 and s.x <= x1 + 1 and s.y >= y0 - 1 and s.y <= y1 + 1:
			rows[clampi(s.y - y0, 0, rmax)].append([2, s])
	for a in sim.animals:
		if a.x >= x0 - 1 and a.x <= x1 + 2 and a.y >= y0 - 1 and a.y <= y1 + 2:
			rows[clampi(int(a.y) - y0, 0, rmax)].append([5, a])
	for a in sim.idlers:
		if a.x >= x0 - 1 and a.x <= x1 + 2 and a.y >= y0 - 1 and a.y <= y1 + 2:
			rows[clampi(int(a.y) - y0, 0, rmax)].append([5, a])
	for b in sim.blds.values():
		for c in b.carriers:
			if c.x >= x0 - 1 and c.x <= x1 + 2 and c.y >= y0 - 1 and c.y <= y1 + 2:
				# sitzende Traeger liegen in der Reihe des Gebaeudes, damit sie vor den Sitzen gezeichnet werden
				var cy: int = (b.y + b.h - 1) if c.st == "sit" else int(c.y)
				rows[clampi(cy - y0, 0, rmax)].append([4, c])
	for bd in sim.builders:
		if bd.x >= x0 - 1 and bd.x <= x1 + 2 and bd.y >= y0 - 1 and bd.y <= y1 + 2:
			rows[clampi(int(bd.y) - y0, 0, rmax)].append([6, bd])
	for ri in rows.size():
		for e in rows[ri]:
			match e[0]:
				6: _draw_builder(e[1])
				0: _draw_obj(e[1])
				1: _draw_bld(e[1])
				2: _draw_station(e[1])
				3: _draw_worker(e[1])
				4: _draw_carrier(e[1])
				5: _draw_animal(e[1])
	# Vögel (mit Schatten), Schmetterlinge
	for b in birds:
		if vr.has_point(Vector2(b.x, b.y)):
			var fr := int(time * 5.0 + b.f) % 2
			draw_circle(Vector2(b.x, b.y + 40.0), 3.0, Color(0, 0, 0, 0.18))
			draw_texture(Art.an["bird"][fr], Vector2(roundf(b.x), roundf(b.y)))
	_draw_balloons()
	for f in flies:
		var g := sim.ground[clampi(int(f.y / TS), 0, MH - 1) * MW + clampi(int(f.x / TS), 0, MW - 1)]
		if vr.has_point(Vector2(f.x, f.y)) and g in [Data.T.GRASS, Data.T.FAIRY, Data.T.SWAMP]:
			draw_texture(Art.an["fly" + f.c][int(time * 6.0 + f.a) % 2], Vector2(roundf(f.x), roundf(f.y)))
	# Partikel
	for p in parts:
		var a: float = clampf(p.life / p.max, 0.0, 1.0)
		match p.k:
			"smoke":
				draw_circle(Vector2(p.x, p.y), 2.0 + p.s, Color(0.92, 0.92, 0.96, a * 0.5))
			"snow":
				draw_rect(Rect2(roundf(p.x), roundf(p.y), 1, 1), Color(1, 1, 1, 0.9))
			"ember":
				draw_rect(Rect2(roundf(p.x), roundf(p.y), 1, 1), Color(p.c.r, p.c.g, p.c.b, a))
			"spark", "mote":
				var c: Color = p.c
				draw_rect(Rect2(roundf(p.x), roundf(p.y), 1, 1), Color(c.r, c.g, c.b, a))
				if p.k == "spark":
					draw_rect(Rect2(roundf(p.x) - 1, roundf(p.y), 3, 1), Color(c.r, c.g, c.b, a * 0.6))
					draw_rect(Rect2(roundf(p.x), roundf(p.y) - 1, 1, 3), Color(c.r, c.g, c.b, a * 0.6))
			"heart":
				draw_string(font, Vector2(p.x, p.y), "♥", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(p.c.r, p.c.g, p.c.b, a))
	_draw_overlays()

func _draw_balloons() -> void:
	var tx: Array = Art.balloon
	var fr := int(time * 3.0) % 2
	var w: int = tx[0].get_width()
	var h: int = tx[0].get_height()
	# Aufpumpen im Hinterhof
	for b in sim.blds.values():
		if b.type == "ballon" and b.done and b.st == "work":
			var hm := sim.balloon_home(b)
			var prog := clampf(1.0 - b.timer / float(Data.BD["ballon"].t), 0.0, 1.0)
			var s := 0.12 + 0.88 * prog
			var foot := Vector2(hm.x * TS, hm.y * TS + 8)
			draw_texture_rect(tx[fr], Rect2(foot.x - w * s / 2.0, foot.y - h * s, w * s, h * s), false)
	# Fahrt ueber die Karte
	for bl in sim.balloons:
		var gp := Vector2(bl.x * TS, bl.y * TS)
		var alt: float = bl.h * 80.0 + sin(time * 1.3 + bl.b) * 3.0 * bl.h
		var sh: float = 1.0 - 0.35 * bl.h
		draw_set_transform(gp + Vector2(0, 8), 0.0, Vector2(1, 0.4))
		draw_circle(Vector2.ZERO, 14.0 * sh, Color(0, 0, 0, 0.2))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		spr(tx[fr], gp + Vector2(0, 8 - alt), bl.face < 0)

func _draw_obj(i: int) -> void:
	var o: int = sim.obj[i]
	var x := i % MW
	var y := i / MW
	var st: int = sim.stage[i]
	var h := Data.hsh(x, y, 3.0)
	var frame := int(time * 1.2 + h * 4.0) % 2
	var tx: Texture2D
	if o == Data.O.ROCK:
		var big := 1 if sim.amt[i] > 22 else 0
		var vs: Array = Art.objs[o][big]
		tx = vs[int(h * vs.size())][3][0]
	else:
		var vs: Array = Art.objs[o]
		tx = vs[int(h * vs.size())][st][frame]
	# leichte Streuung innerhalb der Zelle, damit Waelder nicht wie ein Gitter aussehen
	var jx := floorf((Data.hsh(x, y, 1.0) - 0.5) * 7.0)
	var jy := floorf((Data.hsh(x, y, 2.0) - 0.5) * 3.0)
	spr(tx, Vector2(x * TS + 8 + jx, y * TS + 15 + jy))

func _draw_bld(b: Sim.Bld) -> void:
	var d: Dictionary = Data.BD[b.type]
	var key := str(b.w) + "x" + str(b.h)
	var frs: Array = Art.bld[b.type]
	var W: int = b.w * TS
	var foot := Vector2(b.x * TS + W / 2.0, (b.y + b.h) * TS + 2)
	if not b.done:
		var cost := sim.site_cost(b)
		var tx: Texture2D = frs[b.design * 2] if b.type == "traeger" else frs[0]
		var top := foot.y - tx.get_height()
		if b.upg:
			tx = frs[b.level - 1]
			spr(tx, foot, false, Color(1, 1, 1, 0.8))
			var sct: Texture2D = Art.scaffold[key]
			top = foot.y - sct.get_height()
			draw_texture(sct, Vector2(b.x * TS, top), Color(1, 1, 1, 0.85))
			draw_rect(Rect2(b.x * TS, top - 4, W * b.prog, 2), Color("#ffd070"))
		else:
			var H := tx.get_height()
			var vis := int(H * b.prog)
			if vis > 0:
				draw_texture_rect_region(tx, Rect2(b.x * TS, top + H - vis, tx.get_width(), vis), Rect2(0, H - vis, tx.get_width(), vis))
			draw_texture(Art.scaffold[key], Vector2(b.x * TS, top), Color(1, 1, 1, 0.9))
		if not b.busy:
			var k := 0
			for g in cost:
				if b.inbox.get(g, 0) < cost[g]:
					draw_texture(Art.goods_w[g], Vector2(b.x * TS + 2 + k * 12, top - 10 + sin(time * 3.0 + k) * 1.5))
					k += 1
		if b == sel:
			draw_rect(Rect2(b.x * TS - 2, top - 2, W + 4, foot.y - top + 4), Color(1, 0.9, 0.4, 0.5 + 0.3 * sin(time * 6.0)), false, 1.0)
		if b.paused:
			draw_string(font, Vector2(b.x * TS + W / 2.0 - 5, top - 2), "II", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
		elif b.prio != 0:
			draw_string(font, Vector2(b.x * TS + W - 8, top - 2), "▲" if b.prio > 0 else "▼", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#ffd070") if b.prio > 0 else Color("#9ab8d8"))
		return
	var fr := (int(time * 3.0) % 2) if b.busy else 0
	var tx2: Texture2D = frs[fr] if b.type in ["muehle", "taverne", "glashuette", "hq", "obelisk", "brunnen"] else frs[0]
	if b.type == "haus":
		tx2 = frs[b.level - 1]
	elif b.type == "traeger":
		tx2 = frs[b.design * 2 + (int(time * 4.0 + b.id) % 2)]
	var mod := Color(1, 1, 1, 0.55) if b.paused else Color.WHITE
	spr(tx2, foot, false, mod)
	_draw_outbox(b)
	if b.type == "brunnen" and b.st == "work":
		# Der Brunnenpixler kurbelt das Wasser aus dem Boden
		var wc := Vector2(b.x * TS + W * 0.5, foot.y - 30)
		var ang := time * 5.0
		var hnd := wc + Vector2(cos(ang), sin(ang)) * 6.0
		draw_line(wc, hnd, Color("#5a3a22"), 2.0)
		draw_circle(hnd, 1.6, Color("#c8a070"))
		var pf := Vector2(b.x * TS + W + 7, foot.y - 3 + absf(sin(ang)) * 1.5)
		spr(Art.man["brunnen"][4], pf, true)
		draw_line(pf + Vector2(-9, -14), hnd, Color("#f2c9a0"), 2.0)   # Arm zur Kurbel
	if b == sel:
		var r := Rect2(b.x * TS - 2, foot.y - tx2.get_height() - 2, W + 4, tx2.get_height() + 4)
		draw_rect(r, Color(1, 0.9, 0.4, 0.5 + 0.3 * sin(time * 6.0)), false, 1.0)
		if d.has("hub"):
			draw_arc(Vector2((b.x + b.w / 2.0) * TS, (b.y + b.h / 2.0) * TS), d.R * TS, 0, TAU, 96, Color(1, 0.9, 0.4, 0.4), 1.0)
		var pr := sim.progress(b)
		if pr >= 0.0:
			draw_rect(Rect2(b.x * TS, r.position.y - 7, W, 4), Color(0, 0, 0, 0.6))
			draw_rect(Rect2(b.x * TS + 1, r.position.y - 6, (W - 2) * pr, 2), Color("#e0a840"))
	if d.kind == "process" or d.kind == "gather" or d.kind == "house":
		if b.st == "idle" and b.msg != "" and not b.paused and (b.msg.begins_with("Wartet") or b.msg.begins_with("Ausgang") or b.msg.begins_with("Kein Träger") or b.msg.begins_with("Nichts") or b.msg.begins_with("Braucht")):
			var pp := Vector2(b.x * TS + W / 2.0, foot.y - tx2.get_height() - 4 + sin(time * 4.0) * 1.5)
			draw_circle(pp, 5.0, Color("#3b2a24"))
			draw_circle(pp, 4.0, Color("#e8a040") if not (b.msg.begins_with("Ausgang") or b.msg.begins_with("Kein Träger")) else Color("#e8453c"))
			draw_string(font, pp + Vector2(-2, 3), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)
		if b.paused:
			draw_string(font, Vector2(b.x * TS + W / 2.0 - 5, foot.y - tx2.get_height() - 2), "II", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)

func _draw_outbox(b: Sim.Bld) -> void:
	# fertige Waren liegen neben der Tuer, bis ein Traeger sie holt
	var k := 0
	for g in b.outbox:
		for n in b.outbox[g]:
			if k >= 10 or not Art.goods_w.has(g):
				return
			draw_texture(Art.goods_w[g], Vector2(b.door.x * TS + 10 + (k % 5) * 3, b.door.y * TS + 5 - (k / 5) * 4))
			k += 1

func _sit_draw(foot: Vector2, flip: bool) -> void:
	# sitzender Pixler: nur Oberkoerper (die Beine verdeckt der Sitz)
	var tx: Texture2D = Art.man["carrier"][4]
	var w := tx.get_width()
	var fx := roundf(foot.x)
	var fy := roundf(foot.y)
	var src := Rect2(0, 0, w, 25)
	if flip:
		draw_set_transform(Vector2(fx, 0), 0.0, Vector2(-1, 1))
		draw_texture_rect_region(tx, Rect2(-(w >> 1), fy - 25, w, 25), src)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_texture_rect_region(tx, Rect2(fx - (w >> 1), fy - 25, w, 25), src)

func _draw_station(s: Sim.Station) -> void:
	var foot := Vector2(s.x * TS + 8, s.y * TS + 14)
	spr(Art.station, foot)
	if s.manned:
		_sit_draw(foot + Vector2(0, -12 + sin(time * 2.0 + s.id) * 0.5), s.id % 2 == 0)

func _walk_fr(speed_f: float, seed_f: float) -> int:
	return int(time * speed_f + seed_f) % 4

func _draw_worker(b: Sim.Bld) -> void:
	var walking: bool = b.st in ["walk", "back", "out", "ret"]
	var fr := _walk_fr(8.0, 0.0) if walking else 4
	var foot := Vector2(b.wx * TS, b.wy * TS + 5)
	if b.st == "act":
		foot.y += sin(time * 14.0) * 1.0
	var key: String = b.type
	spr(Art.man[key][fr], foot, b.face < 0)
	if b.carry != "":
		draw_texture(Art.goods_w[b.carry], Vector2(roundf(foot.x) - 5, roundf(foot.y) - 42))

func _draw_builder(bd: Sim.Builder) -> void:
	var working: bool = bd.st == "work"
	var fr := _walk_fr(8.0, bd.site) if not working else 4
	var foot := Vector2(bd.x * TS, bd.y * TS + 5)
	if working:
		foot.y += sin(time * 12.0) * 1.0
		if int(time * 4.0) % 2 == 0:
			draw_rect(Rect2(roundf(foot.x) + (13 if bd.face > 0 else -14), roundf(foot.y) - 26, 2, 2), Color("#fff0b0"))
	spr(Art.man["builder"][fr], foot, bd.face < 0)

func _draw_carrier(c: Sim.Carrier) -> void:
	if c.st == "sit":
		_sit_draw(Vector2(c.x * TS, c.y * TS + 2), c.face < 0)
		return
	var moving: bool = c.st != "pick" and c.st != "drop"
	var fr := _walk_fr(8.0, c.seat * 1.7) if moving else 4
	var foot := Vector2(c.x * TS, c.y * TS + 5)
	var fl: bool = c.face < 0
	spr(Art.man["carrier"][fr], foot, fl)
	var n_load: int = c.load.size() if (c.st == "carry" or c.st == "drop") else 0
	if c.barrow and c.st != "enter" and c.st != "exit":
		# Schubkarre vor dem Traeger; Waren liegen darin
		var bx := roundf(foot.x) + (-17 if fl else 3)
		var by := roundf(foot.y) - 9
		draw_texture(Art.an["barrow"][0], Vector2(bx, by))
		for k3 in n_load:
			if Art.goods_w.has(c.load[k3].t):
				draw_texture(Art.goods_w[c.load[k3].t], Vector2(bx + 1 + k3 * 4, by - 8 - (k3 % 2) * 2))
	else:
		for k3 in n_load:
			if Art.goods_w.has(c.load[k3].t):
				draw_texture(Art.goods_w[c.load[k3].t], Vector2(roundf(foot.x) - 5 + (k3 * 7 - 3), roundf(foot.y) - 42 - k3 * 2))

func _draw_animal(a: Sim.Animal) -> void:
	var kind := a.kind
	var foot := Vector2(a.x * TS, a.y * TS + 3)
	if kind == "idler":
		var fr := _walk_fr(7.0, a.x * 3.0) if a.moving else 4
		spr(Art.man["idler"][fr], foot + Vector2(0, 2), a.face < 0)
		return
	var arr: Array = Art.an[kind]
	var fr2 := int(time * (7.0 if kind == "rabbit" else 5.0) + a.x * 3.0) % 2 if a.moving else 0
	if kind == "rabbit" and a.moving:
		foot.y -= absf(sin(time * 12.0)) * 2.0
	spr(arr[fr2], foot, a.face < 0)

func _draw_overlays() -> void:
	if hover_ui:
		return
	var t := hover
	if not sim.inb(t.x, t.y):
		return
	match mode:
		"build":
			var d: Dictionary = Data.BD[build_type]
			var o := _bo()
			var ok := ghost_err == ""
			var col := Color(0.4, 1, 0.5, 0.5) if ok else Color(1, 0.4, 0.4, 0.5)
			var foot := Vector2(o.x * TS + d.w * TS / 2.0, (o.y + d.h) * TS + 2)
			spr(Art.bld[build_type][0], foot, false, Color(col.r, col.g, col.b, 0.75))
			draw_rect(Rect2(o.x * TS, o.y * TS, d.w * TS, d.h * TS), col, false, 1.0)
			# Tuer (hier werden Waren uebergeben)
			var doors := sim.door_offsets(build_type, o.x, o.y)
			if doors.is_empty():
				doors = [[d.w / 2, d.h]]
			for dd in doors:
				var fp := Vector2((o.x + dd[0]) * TS, (o.y + dd[1]) * TS)
				draw_rect(Rect2(fp.x + 4, fp.y + 4, 8, 8), Color(1, 0.9, 0.3, 0.7))
			# Reichweite
			if d.has("R"):
				draw_arc(Vector2((o.x + d.w / 2.0) * TS, (o.y + d.h / 2.0) * TS), d.R * TS, 0, TAU, 64, Color(1, 1, 1, 0.25), 1.0)
		"road":
			if road_prev.size() > 1:
				var pp := PackedVector2Array()
				for c in road_prev:
					pp.append(Vector2(c[0] * TS + TS * 0.5, c[1] * TS + TS * 0.5))
				draw_polyline(pp, Color(1, 0.9, 0.3, 0.5), ROAD_W)
				draw_circle(pp[pp.size() - 1], ROAD_W * 0.5, Color(1, 0.9, 0.3, 0.5))
			if road_start != null:
				draw_rect(Rect2(road_start.x * TS + 1, road_start.y * TS + 1, 14, 14), Color(0.4, 1, 0.5, 0.7), false, 1.0)
			draw_rect(Rect2(t.x * TS, t.y * TS, TS, TS), Color(1, 1, 1, 0.5), false, 1.0)
		"station":
			var mc := sim.station_cell(t.x, t.y)
			if mc.x >= 0:
				var scol := Color(0.4, 1, 0.5, 0.8) if sim.station_error(t.x, t.y) == "" else Color(1, 0.4, 0.4, 0.8)
				draw_rect(Rect2(mc.x * TS - 2, mc.y * TS - 2, TS + 4, TS + 4), scol, false, 1.0)
				spr(Art.station, Vector2(mc.x * TS + 8, mc.y * TS + 14), false, Color(1, 1, 1, 0.6))
			draw_rect(Rect2(t.x * TS, t.y * TS, TS, TS), Color(1, 1, 1, 0.4), false, 1.0)
		"demolish", "select":
			var col := Color(1, 0.4, 0.4, 0.6) if mode == "demolish" else Color(1, 1, 1, 0.4)
			draw_rect(Rect2(t.x * TS, t.y * TS, TS, TS), col, false, 1.0)

func _draw_night(n: Node2D) -> void:
	var nt := _night()
	var warm := clampf(4.0 * nt * (1.0 - nt), 0.0, 1.0)
	var col := Color.WHITE.lerp(Color(1.0, 0.86, 0.72), warm * 0.55).lerp(Color(0.42, 0.48, 0.78), nt * 0.9)
	var vr := _view_rect()
	n.draw_rect(vr.grow(32), col)

func _draw_glow(n: Node2D) -> void:
	var nt := _night()
	var a := 0.12 + 0.75 * nt
	var vr := _view_rect()
	var x0 := maxi(0, int(vr.position.x / TS) - 4)
	var y0 := maxi(0, int(vr.position.y / TS) - 4)
	var x1 := mini(MW - 1, int(vr.end.x / TS) + 4)
	var y1 := mini(MH - 1, int(vr.end.y / TS) + 6)
	for cy in range(y0 / Sim.CH, y1 / Sim.CH + 1):
		for cx in range(x0 / Sim.CH, x1 / Sim.CH + 1):
			var ci: int = cy * Sim.NCX + cx
			for i in sim.chunk_obj[ci]:
				var o: int = sim.obj[i]
				if o != Data.O.GFLOWER and o != Data.O.FTREE and o != Data.O.GSHROOM and o != Data.O.OBSC:
					continue
				var x: int = i % MW
				var y: int = i / MW
				if x < x0 or x > x1 or y < y0 or y > y1:
					continue
				var c := Vector2(x * TS + 8, y * TS + 8)
				var pulse := 0.8 + 0.2 * sin(time * 2.0 + x * 1.7 + y)
				match o:
					Data.O.GFLOWER:
						if sim.stage[i] == 3: _glow(n, "cyan", c, 0.55, a * pulse)
					Data.O.FTREE:
						_glow(n, "pink", c + Vector2(0, -16), 1.8, a * 0.7 * pulse)
					Data.O.GSHROOM:
						if sim.stage[i] == 3: _glow(n, "teal", c, 0.6, a * pulse)
					Data.O.OBSC:
						_glow(n, "violet", c + Vector2(0, -8), 1.2, a * 0.8)
			for i in lava_chunks.get(ci, []):
				var lx: int = i % MW
				var ly: int = i / MW
				if lx < x0 or lx > x1 or ly < y0 or ly > y1:
					continue
				_glow(n, "lava", Vector2(lx * TS + TS, ly * TS + TS), 1.5, (0.25 + 0.6 * nt) * (0.85 + 0.15 * sin(time * 3.0 + lx)))
	for b in sim.blds.values():
		if not b.done:
			continue
		var d: Dictionary = Data.BD[b.type]
		var c := Vector2((b.x + b.w / 2.0) * TS, (b.y + b.h - 0.5) * TS)
		match b.type:
			"schrein": _glow(n, "pink", c + Vector2(0, -48), 4.8, 0.4 + a)
			"obelisk": _glow(n, "violet", c + Vector2(0, -48), 4.4, 0.35 + a)
			"glaspalast": _glow(n, "cyan", c + Vector2(0, -40), 4.8, 0.35 + a)
			"eispavillon": _glow(n, "cyan", c + Vector2(0, -32), 4.4, 0.3 + a)
			"laterne": _glow(n, "teal", c + Vector2(0, -52), 5.2, 0.45 + a)
			"feensammler": _glow(n, "pink", c + Vector2(0, -24), 2.4, a * 0.8)
			"pilzhuette": _glow(n, "teal", c + Vector2(0, -24), 2.4, a * 0.8)
			"obsidian": _glow(n, "lava", c + Vector2(0, -12), 2.0, a)
			_:
				if d.kind != "store" or b.type == "hq":
					_glow(n, "warm", c + Vector2(0, -12), 2.2, a * 0.6)

func _glow(n: Node2D, name: String, c: Vector2, s: float, a: float) -> void:
	var tx: Texture2D = Art.glow[name]
	n.draw_texture_rect(tx, Rect2(c - Vector2(24, 24) * s, Vector2(48, 48) * s), false, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
