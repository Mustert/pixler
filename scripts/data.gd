class_name Data
extends RefCounted

const TS := 16
# Feinheit des Rasters: 1 Kachel der Entwurfswerte (BD_T) = K x K Zellen.
# Wege, Flaggen und Pixler leben auf dem feinen Raster, Gebaeude sind entsprechend groesser.
const K := 2
const MW := 192 * K
const MH := 192 * K
const WORK_MULT := 1.6      # Dauer aller Taetigkeiten (Faktor auf die Entwurfswerte "t")
const TAVERN_MULT := 2.5    # zusaetzlich fuer die Taverne: Einwanderung soll ein Ereignis sein
const START_POP := 30
const HQ_CAP := 50
# Weiche Objekte (Leuchtblume, Glühpilz, Kraut, Pilz): blockieren weder Bauplätze noch Wege,
# sie werden beim Bauen einfach weggeräumt.
const SOFT := [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 1]
const HOUSE_CAP := [0, 4, 8, 14]
const HOUSE_NAME := ["", "Hütte", "Haus", "Stadthaus"]
# Ausbau von Stufe N auf N+1: Material + wie oft die Bewohner versorgt worden sein müssen
const HOUSE_UP := {
	1: {"cost": {"bretter": 3, "steinblock": 2}, "fed": 3},
	2: {"cost": {"bretter": 4, "steinblock": 4}, "fed": 5},
}
enum T { DEEP, WATER, SAND, GRASS, ROCK, LAVA, ASH, FAIRY, SWAMP, MARSH, DESERT, SNOW, ICE }
enum O { NONE, TREE, PINE, FTREE, DEAD, PALM, CACTUS, ROCK, GMUSH, GFLOWER, GSHROOM, OBSC, HERB, SHROOM }
const WALK := [0, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 0]
const CHOP := [0, 1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0]

const GOODS := ["holz", "bretter", "stein", "steinblock", "wasser", "fisch", "weizen", "mehl", "brot", "fleisch", "feenstaub", "obsidian", "gluehpilz", "sand", "glas", "eis", "schwein", "pilz", "kraut", "gemuese", "gericht"]
const GNAME := {
	"holz": "Holz", "bretter": "Bretter", "stein": "Stein", "steinblock": "Steinblöcke", "wasser": "Wasser",
	"fisch": "Fisch", "weizen": "Weizen", "mehl": "Mehl", "brot": "Brot", "fleisch": "Fleisch",
	"feenstaub": "Feenstaub", "obsidian": "Obsidian", "gluehpilz": "Glühpilze", "sand": "Sand", "glas": "Glas", "eis": "Eis",
	"schwein": "Schweine", "pilz": "Pilze", "kraut": "Kräuter", "gemuese": "Gemüse", "gericht": "Gerichte",
}

const CATS := ["Basis", "Nahrung", "Biome", "Wahrzeichen"]

# kind: store | gather | process | lm | house
# Entwurfswerte in Kachel-Einheiten (w, h, R); BD ist die auf Zellen hochgerechnete Fassung.
const BD_T := {
	"hq": {"n": "Langhaus (Hauptquartier)", "w": 5, "h": 2, "cost": {}, "kind": "store", "keepers": 3, "cat": ""},
	"haus": {"n": "Wohnhaus", "w": 2, "h": 2, "cost": {"bretter": 3, "steinblock": 1}, "kind": "house", "cat": "Basis", "d": "Wohnraum für 4 Pixler. Mit Gerichten und Wasser versorgt, kann es zu Haus (8) und Stadthaus (14) ausgebaut werden."},
	"wagner": {"n": "Schubkarrenbauer", "w": 2, "h": 2, "cost": {"bretter": 3}, "kind": "process", "ins": {"bretter": 2}, "out": "", "t": 10.0, "cat": "Basis", "d": "Baut Schubkarren. Bei belegten Flaggen holt sich ein Träger eine Karre und trägt 3 statt 1 Ware.", "col": "#c9a06a"},
	"lager": {"n": "Lagerhaus", "w": 2, "h": 2, "cost": {"bretter": 3, "steinblock": 2}, "kind": "store", "keepers": 1, "cat": "Basis", "d": "Lagert Waren an einem zweiten Ort. Ein fest angestellter Lagerarbeiter trägt Waren nach und nach vor die Tür. Jedes Lagerhaus bringt 2 weitere Bauarbeiter."},
	"holzfaeller": {"n": "Holzfäller", "w": 2, "h": 2, "cost": {"bretter": 2}, "kind": "gather", "need": "tree", "R": 6, "out": "holz", "t": 9.0, "cat": "Basis", "d": "Fällt ausgewachsene Bäume in der Nähe.", "col": "#4f9a55"},
	"foerster": {"n": "Förster", "w": 2, "h": 2, "cost": {"bretter": 2}, "kind": "gather", "need": "plant", "R": 5, "out": "", "t": 10.0, "cat": "Basis", "d": "Pflanzt neue Bäume. Der Wald wächst nach.", "col": "#7bbd4a"},
	"saegewerk": {"n": "Sägewerk", "w": 2, "h": 2, "cost": {"bretter": 2, "steinblock": 2}, "kind": "process", "ins": {"holz": 1}, "out": "bretter", "outn": 1, "t": 5.0, "cat": "Basis", "d": "Holz wird zu Brettern.", "col": "#a67c52"},
	"steinbruch": {"n": "Steinbruch", "w": 2, "h": 2, "cost": {"bretter": 3}, "kind": "gather", "need": "rock", "R": 6, "out": "stein", "t": 10.0, "cat": "Basis", "d": "Bricht Stein aus Felsen.", "col": "#8a8794"},
	"steinmetz": {"n": "Steinmetz", "w": 2, "h": 2, "cost": {"bretter": 2, "steinblock": 1}, "kind": "process", "ins": {"stein": 1}, "out": "steinblock", "outn": 1, "t": 7.0, "cat": "Basis", "d": "Stein wird zu Steinblöcken.", "col": "#c9c6d1"},
	"brunnen": {"n": "Brunnen", "w": 1, "h": 1, "cost": {"stein": 2}, "kind": "process", "ins": {}, "out": "wasser", "outn": 1, "t": 5.0, "cat": "Basis", "d": "Liefert frisches Wasser.", "col": "#4aa3e8"},
	"ballon": {"n": "Ballonfahrer", "w": 3, "h": 2, "cost": {"bretter": 4, "steinblock": 1}, "kind": "process", "ins": {}, "out": "", "t": 16.0, "cat": "Basis", "d": "Im Hinterhof wird ein Heißluftballon aufgepumpt. Dann fährt ein Pixler damit quer über die Karte. Noch ohne Nutzen, aber niedlich.", "col": "#e8453c"},
	"fischer": {"n": "Fischer", "w": 2, "h": 2, "cost": {"bretter": 2}, "kind": "gather", "need": "fish", "R": 6, "out": "fisch", "t": 10.0, "cat": "Nahrung", "d": "Angelt am Ufer. Braucht Wasser in der Nähe.", "col": "#4a7fc0"},
	"jaeger": {"n": "Jäger", "w": 2, "h": 2, "cost": {"bretter": 2}, "kind": "gather", "need": "deer", "R": 11, "out": "fleisch", "t": 14.0, "cat": "Nahrung", "d": "Jagt frei laufendes Wild in Wald und Wiese und liefert Fleisch.", "col": "#8a5a3a"},
	"farm": {"n": "Weizenfarm", "w": 2, "h": 2, "cost": {"bretter": 3}, "kind": "gather", "need": "field", "R": 4, "ins": {"wasser": 1}, "out": "weizen", "t": 10.0, "cat": "Nahrung", "d": "Baut Weizen an. Braucht Wasser und freies Grasland.", "col": "#e0b84a"},
	"muehle": {"n": "Mühle", "w": 2, "h": 2, "cost": {"bretter": 3, "steinblock": 2}, "kind": "process", "ins": {"weizen": 1}, "out": "mehl", "outn": 1, "t": 7.0, "cat": "Nahrung", "d": "Weizen wird zu Mehl.", "col": "#e8e0d0"},
	"baeckerei": {"n": "Bäckerei", "w": 2, "h": 2, "cost": {"bretter": 2, "steinblock": 2}, "kind": "process", "ins": {"mehl": 1, "wasser": 1}, "out": "brot", "outn": 2, "t": 9.0, "cat": "Nahrung", "d": "Mehl und Wasser werden zu Brot.", "col": "#e8b070"},
	"ranch": {"n": "Viehzucht", "w": 3, "h": 2, "cost": {"bretter": 4, "steinblock": 1}, "kind": "process", "ins": {"weizen": 1, "wasser": 1}, "out": "schwein", "outn": 1, "t": 14.0, "cat": "Nahrung", "d": "Züchtet Schweine aus Weizen und Wasser. In der Metzgerei werden sie zu Fleisch.", "col": "#d89a9a"},
	"metzger": {"n": "Metzgerei", "w": 2, "h": 2, "cost": {"bretter": 2, "steinblock": 2}, "kind": "process", "ins": {"schwein": 1}, "out": "fleisch", "outn": 3, "t": 8.0, "cat": "Nahrung", "d": "Macht aus Schweinen Fleisch.", "col": "#d8a0a0"},
	"garten": {"n": "Gärtner", "w": 2, "h": 2, "cost": {"bretter": 3}, "kind": "gather", "need": "field", "R": 4, "ins": {"wasser": 1}, "out": "gemuese", "t": 10.0, "cat": "Nahrung", "d": "Zieht Gemüse. Braucht Wasser und freies Grasland.", "col": "#6fbf5a"},
	"kraeuter": {"n": "Kräuterkundler", "w": 2, "h": 2, "cost": {"bretter": 2}, "kind": "gather", "need": "herb", "R": 8, "out": "kraut", "t": 10.0, "cat": "Nahrung", "d": "Sammelt wilde Kräuter auf Wiesen und am Waldrand.", "col": "#9a7ac8"},
	"pilzsammler": {"n": "Pilzsammler", "w": 2, "h": 2, "cost": {"bretter": 2}, "kind": "gather", "need": "mush", "R": 8, "out": "pilz", "t": 10.0, "cat": "Nahrung", "d": "Sammelt Pilze im Wald.", "col": "#b8794a"},
	"kueche": {"n": "Küche", "w": 2, "h": 2, "cost": {"bretter": 3, "steinblock": 2}, "kind": "process", "ins": {"wasser": 1}, "alt": ["fleisch", "fisch", "pilz", "kraut", "gemuese"], "altn": 2, "out": "gericht", "outn": 2, "t": 10.0, "cat": "Nahrung", "d": "Kocht aus zwei verschiedenen Zutaten (Fleisch, Fisch, Pilze, Kräuter, Gemüse) und Wasser Gerichte. Wohnhäuser brauchen sie für den Ausbau.", "col": "#e8e0d0"},
	"taverne": {"n": "Taverne", "w": 3, "h": 2, "cost": {"bretter": 4, "steinblock": 3}, "kind": "process", "ins": {"wasser": 1}, "alt": ["brot", "fisch", "fleisch"], "altn": 1, "out": "", "t": 8.0, "cat": "Nahrung", "d": "Wasser und eine Mahlzeit (Brot, Fisch oder Fleisch): Neue Pixler ziehen ein, solange Wohnraum frei ist.", "col": "#c58b5c"},
	"feensammler": {"n": "Feenhain-Hütte", "w": 2, "h": 2, "cost": {"bretter": 3}, "kind": "gather", "need": "fairy", "R": 6, "out": "feenstaub", "t": 14.0, "cat": "Biome", "d": "Sammelt Feenstaub von Leuchtblumen im Feenwald.", "col": "#e59af0"},
	"obsidian": {"n": "Obsidianbrecher", "w": 2, "h": 2, "cost": {"bretter": 3, "steinblock": 2}, "kind": "gather", "need": "lava", "R": 6, "ins": {"wasser": 1}, "out": "obsidian", "t": 12.0, "cat": "Biome", "d": "Kühlt Lava mit Wasser zu Obsidian.", "col": "#5a4a7a"},
	"pilzhuette": {"n": "Glühpilz-Sammler", "w": 2, "h": 2, "cost": {"bretter": 3}, "kind": "gather", "need": "shroom", "R": 6, "out": "gluehpilz", "t": 12.0, "cat": "Biome", "d": "Erntet Glühpilze im Sumpf.", "col": "#3fbf9f"},
	"sandgrube": {"n": "Sandgrube", "w": 2, "h": 2, "cost": {"bretter": 2}, "kind": "gather", "need": "sand", "R": 4, "out": "sand", "t": 8.0, "cat": "Biome", "d": "Gräbt Sand in der Wüste.", "col": "#e0a060"},
	"glashuette": {"n": "Glashütte", "w": 2, "h": 2, "cost": {"bretter": 3, "steinblock": 3}, "kind": "process", "ins": {"sand": 2, "holz": 1}, "out": "glas", "outn": 1, "t": 12.0, "cat": "Biome", "d": "Sand und Holz werden zu Glas.", "col": "#5a9ab5"},
	"eishauer": {"n": "Eishauer", "w": 2, "h": 2, "cost": {"bretter": 3}, "kind": "gather", "need": "ice", "R": 6, "out": "eis", "t": 12.0, "cat": "Biome", "d": "Haut Eisblöcke aus gefrorenen Seen.", "col": "#a8d8f0"},
	"schrein": {"n": "Feenbaum-Schrein", "w": 3, "h": 3, "cost": {"feenstaub": 5, "bretter": 4, "steinblock": 4}, "kind": "lm", "cat": "Wahrzeichen", "d": "Wahrzeichen: +4 Wohnplätze."},
	"obelisk": {"n": "Obsidian-Obelisk", "w": 3, "h": 3, "cost": {"obsidian": 5, "steinblock": 6, "stein": 4}, "kind": "lm", "cat": "Wahrzeichen", "d": "Wahrzeichen: +4 Wohnplätze."},
	"glaspalast": {"n": "Glaspalast", "w": 3, "h": 3, "cost": {"glas": 5, "bretter": 4, "steinblock": 4}, "kind": "lm", "cat": "Wahrzeichen", "d": "Wahrzeichen: +4 Wohnplätze."},
	"eispavillon": {"n": "Eis-Pavillon", "w": 3, "h": 3, "cost": {"eis": 5, "bretter": 4, "steinblock": 4}, "kind": "lm", "cat": "Wahrzeichen", "d": "Wahrzeichen: +4 Wohnplätze."},
	"laterne": {"n": "Leuchtpilz-Laterne", "w": 3, "h": 3, "cost": {"gluehpilz": 5, "bretter": 4, "steinblock": 4}, "kind": "lm", "cat": "Wahrzeichen", "d": "Wahrzeichen: +4 Wohnplätze."},
}

static var BD: Dictionary = _build_bd()

static func _build_bd() -> Dictionary:
	var out := {}
	for k in BD_T:
		var d: Dictionary = BD_T[k].duplicate(true)
		d.w = d.w * K
		d.h = d.h * K
		if d.has("R"):
			d.R = d.R * K
		if d.has("t"):
			d.t = d.t * WORK_MULT * (TAVERN_MULT if k == "taverne" else 1.0)
		out[k] = d
	return out

static func hsh(x: float, y: float, s: float = 0.0) -> float:
	return fposmod(sin(x * 127.1 + y * 311.7 + s * 74.7) * 43758.5453, 1.0)
