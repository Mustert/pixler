extends SceneTree
# Entwicklerwerkzeug: rendert alle prozeduralen Sprites in ein Kontaktbild.
# godot --headless --path . --script tools/sheet.gd -- out.png [scale]

var st := {"x": 4, "y": 4, "rowh": 0}
var sheet: Image
const W := 1500

func put(t: Texture2D) -> void:
	var im := t.get_image()
	if im == null:
		return
	if st.x + im.get_width() + 4 > W:
		st.x = 4
		st.y += st.rowh + 6
		st.rowh = 0
	sheet.blend_rect(im, Rect2i(0, 0, im.get_width(), im.get_height()), Vector2i(st.x, st.y))
	st.x += im.get_width() + 6
	st.rowh = maxi(st.rowh, im.get_height())

func newrow() -> void:
	st.x = 4
	st.y += st.rowh + 10
	st.rowh = 0

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "sheet.png"
	var sc: int = int(args[1]) if args.size() > 1 else 2
	var what: String = args[2] if args.size() > 2 else "all"
	Art.build()
	sheet = Image.create(W, 2400, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.42, 0.68, 0.34))
	if what == "goods":
		for g in Art.goods:
			put(Art.goods[g])
		newrow()
		for g in Art.goods_w:
			put(Art.goods_w[g])
		newrow()
	if what == "all" or what == "bld":
		for k in Data.BD:
			put(Art.bld[k][0])
		newrow()
	if what == "all" or what == "man":
		for k in Art.man:
			for f in [0, 1, 2, 4]:
				put(Art.man[k][f])
		newrow()
	if what == "all" or what == "obj":
		for o in Art.objs:
			for v in Art.objs[o]:
				if v is Array and v.size() == 4 and v[0] is Array:
					put(v[3][0])
				elif v is Array:
					for vv in v:
						if vv is Array and vv.size() > 3:
							put(vv[3][0])
		for a in Art.an:
			put(Art.an[a][0])
		for g in Art.goods:
			put(Art.goods[g])
		newrow()
	sheet = sheet.get_region(Rect2i(0, 0, W, mini(2400, st.y + st.rowh + 10)))
	if sc > 1:
		sheet.resize(sheet.get_width() * sc, sheet.get_height() * sc, Image.INTERPOLATE_NEAREST)
	sheet.save_png(out)
	print("saved ", out)
	quit()
