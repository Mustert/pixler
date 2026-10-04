class_name Sfx
extends Node
# Komplett prozedural erzeugter Sound: Ambiente-Teppich + Effekte. Keine Audiodateien.

const RATE := 22050

var loops := {}      # name -> AudioStreamPlayer
var vols := {}       # name -> aktuelle Lautstaerke (linear)
var streams := {}    # name -> AudioStreamWAV (Effekte)
var pool: Array = []
var pool_i := 0
var muted := false
var master := 0.8
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 4242
	_make_loops()
	_make_effects()
	_load_files()
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)
	music_thread = Thread.new()
	music_thread.start(_make_music)

# ------------------------------------------------------------ Erzeugung
func _wav(smp: PackedFloat32Array, loop: bool, rate: int = RATE) -> AudioStreamWAV:
	var d := PackedByteArray()
	d.resize(smp.size() * 2)
	for i in smp.size():
		d.encode_s16(i * 2, int(clampf(smp[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = d
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = smp.size()
	return w

func _buf(sec: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(int(sec * RATE))
	return a

func _add_loop(name: String, stream: AudioStreamWAV) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = -60.0
	add_child(p)
	p.play()
	loops[name] = p
	vols[name] = 0.0

func _noise_lp(n: int, a: float, gain: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		y += a * (rng.randf_range(-1.0, 1.0) - y)
		out[i] = y * gain
	return out

func _make_loops() -> void:
	# Wind: gefiltertes Rauschen, Lautstaerke schwillt an und ab (an den Enden Null -> nahtlos)
	# Wind: nur ein luftiges Zischen (keine tiefen Anteile), nur in kargen Gegenden hoerbar
	var n := int(10.0 * RATE)
	var w := _noise_lp(n, 0.12, 1.6)
	for i in n:
		var t := float(i) / n
		var env := 0.5 + 0.5 * sin(t * TAU * 2.0)
		w[i] = w[i] * (0.35 + 0.65 * env) * pow(sin(t * PI), 0.25)
	_add_loop("wind", _wav(w, true))
	# Wellen: leises, weiches Plaetschern, nur direkt am Ufer
	n = int(8.0 * RATE)
	var wv := _noise_lp(n, 0.22, 1.2)
	for i in n:
		var t := float(i) / n
		var env := 0.5 + 0.5 * sin(t * TAU * 2.0 - 1.2)
		wv[i] = wv[i] * (0.25 + 0.75 * env) * pow(sin(t * PI), 0.25)
	_add_loop("waves", _wav(wv, true))
	# Voegel: mehrere Zwitscher-Phrasen, dazwischen Stille
	n = int(12.0 * RATE)
	var b := PackedFloat32Array()
	b.resize(n)
	for k in 9:
		var start := rng.randf_range(0.3, 11.0)
		var base := rng.randf_range(2400.0, 4200.0)
		var notes := rng.randi_range(2, 5)
		var t0 := start
		for nn in notes:
			var dur := rng.randf_range(0.05, 0.11)
			var f0 := base * rng.randf_range(0.85, 1.3)
			var f1 := f0 * rng.randf_range(0.7, 1.4)
			var s0 := int(t0 * RATE)
			var len := int(dur * RATE)
			var ph := 0.0
			for j in len:
				var u := float(j) / len
				var f := lerpf(f0, f1, u) + sin(u * 40.0) * 60.0
				ph += TAU * f / RATE
				var e := sin(u * PI)
				if s0 + j < n:
					b[s0 + j] += sin(ph) * e * e * 0.22
			t0 += dur + rng.randf_range(0.03, 0.08)
			if t0 > 11.8:
				break
	_add_loop("birds", _wav(b, true))
	# Grillen: gepulste Hochtoene
	n = int(6.0 * RATE)
	var c := PackedFloat32Array()
	c.resize(n)
	var ph2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var burst := fposmod(t, 0.9)
		var gate := 0.0
		if burst < 0.36:
			gate = maxf(0.0, sin(burst / 0.06 * PI)) * (0.6 if burst > 0.0 else 0.0)
		var fm := 4300.0 + sin(t * 3.0) * 40.0
		ph2 += TAU * fm / RATE
		var env := pow(sin(float(i) / n * PI), 0.5)
		c[i] = sin(ph2) * gate * 0.12 * env
	_add_loop("crickets", _wav(c, true))

# ------------------------------------------------------------ Musik (Playlist: Spieluhr, Kora, Banjo)
const MR := 16000
const TAIL := 2.5            # Ausklang am Ende jedes Stuecks (Sekunden)
var music_thread: Thread
var music_streams: Array = []
var music_names: Array = ["Spieluhr", "Kora", "Banjo", "Klarinette (Nacht)", "Handpan"]
var music_tags: Array = ["any", "any", "day", "night", "any"]   # day: nur tagsueber, night: nur nachts
var night := 0.0             # 0 = Tag, 1 = tiefe Nacht (setzt main.gd)
var music_player: AudioStreamPlayer
var music_last := -1
var music_bag: Array = []
var music_state := "off"     # off | play | gap
var music_t := 0.0
var music_len := 0.0
var music_gap := 0.0
var music_fade := 0.0        # 0..1, wird beim Ein- und Ausblenden in set_mix eingerechnet
const MUSIC_MIN := 60.0      # jedes Stueck laeuft als Schleife 1 bis 3 Minuten
const MUSIC_MAX := 180.0
const MUSIC_FADE := 8.0      # Sekunden fuer Ein- und Ausblenden
const MUSIC_GAP := 10.0      # Pause zwischen zwei Stuecken
var _note_cache := {}

func _mtof(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)

func _pluck(midi: int, dur: float, decay: float) -> PackedFloat32Array:
	# Spieluhr/Kalimba
	var key := "p%d_%d_%d" % [midi, int(dur * 10.0), int(decay * 10.0)]
	if _note_cache.has(key):
		return _note_cache[key]
	var f := _mtof(midi)
	var n := int(dur * MR)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / MR
		var e := exp(-t * decay) * minf(1.0, t / 0.008)
		out[i] = (sin(TAU * f * t) + 0.28 * sin(TAU * f * 2.0 * t) * exp(-t * 4.0) + 0.1 * sin(TAU * f * 5.4 * t) * exp(-t * 14.0)) * e
	_note_cache[key] = out
	return out

func _kora(midi: int, dur: float) -> PackedFloat32Array:
	# Kora: Harfenlaute. Warm, weich angezupft, lange nachklingend, hohe Teiltoene verklingen schneller.
	var key := "k%d_%d" % [midi, int(dur * 10.0)]
	if _note_cache.has(key):
		return _note_cache[key]
	var f := _mtof(midi)
	var n := int(dur * MR)
	var out := PackedFloat32Array()
	out.resize(n)
	var ratios := [1.0, 2.0, 3.0, 4.0, 5.02]
	var amps := [1.0, 0.55, 0.3, 0.17, 0.09]
	var decs := [1.5, 2.6, 4.0, 5.5, 7.5]
	var trng := RandomNumberGenerator.new()
	trng.seed = 1000 + midi
	var lp := 0.0
	for i in n:
		var t := float(i) / MR
		var v := 0.0
		for p in 5:
			v += amps[p] * sin(TAU * f * ratios[p] * t) * exp(-t * decs[p])
		if t < 0.012:
			lp += 0.3 * (trng.randf_range(-1.0, 1.0) - lp)
			v += lp * 0.5 * (1.0 - t / 0.012)
		out[i] = v * minf(1.0, t / 0.003) * 0.5
	_note_cache[key] = out
	return out

func _banjo(midi: int, dur: float) -> PackedFloat32Array:
	# Banjo: helles, kurzes Zupfen mit Fellklopfer und leichtem Tonhoehen-Zwitschern beim Anschlag.
	var key := "j%d_%d" % [midi, int(dur * 10.0)]
	if _note_cache.has(key):
		return _note_cache[key]
	var f := _mtof(midi)
	var n := int(dur * MR)
	var out := PackedFloat32Array()
	out.resize(n)
	var amps := [1.0, 0.8, 0.65, 0.45, 0.32, 0.2]
	var decs := [5.0, 6.0, 7.5, 9.0, 10.5, 12.0]
	var trng := RandomNumberGenerator.new()
	trng.seed = 2000 + midi
	var lp := 0.0
	for i in n:
		var t := float(i) / MR
		var fb := f * (1.0 + 0.012 * exp(-t * 40.0))
		var v := 0.0
		for p in 6:
			v += amps[p] * sin(TAU * fb * (p + 1.0) * t) * exp(-t * decs[p])
		if t < 0.06:
			lp += 0.25 * (trng.randf_range(-1.0, 1.0) - lp)
			v += 0.5 * sin(TAU * 190.0 * t) * exp(-t * 70.0) + lp * 0.5 * exp(-t * 80.0)
		out[i] = v * minf(1.0, t / 0.002) * 0.42
	_note_cache[key] = out
	return out

func _put(out: PackedFloat32Array, note: PackedFloat32Array, start: int, gain: float) -> void:
	var n := out.size()
	for i in note.size():
		var j := start + i
		if j >= n:
			break
		out[j] += note[i] * gain

func _finish_track(out: PackedFloat32Array, taps: Array) -> AudioStreamWAV:
	# Echo, Normalisierung, kurze Ein- und Ausblendung
	var n := out.size()
	var src := out.duplicate()
	for tap in taps:
		var d := int(tap[0] * MR)
		for i in range(d, n):
			out[i] += src[i - d] * tap[1]
	# Ausklang auf den Anfang falten: dadurch laeuft das Stueck nahtlos in einer Schleife
	var nl := n - int(TAIL * MR)
	for i in range(nl, n):
		out[i - nl] += out[i]
	out.resize(nl)
	var peak := 0.001
	for i in nl:
		peak = maxf(peak, absf(out[i]))
	var g := 0.7 / peak
	for i in nl:
		out[i] = out[i] * g
	return _wav(out, true, MR)

func _track_spieluhr() -> AudioStreamWAV:
	# 8 Takte in C-Dur, ruhig (78 BPM): Harfen-Arpeggio + Melodie
	var beat := 60.0 / 78.0
	var bars := 8
	var n := int((bars * 4 * beat + TAIL) * MR)
	var out := PackedFloat32Array()
	out.resize(n)
	var chords := [
		[48, 55, 64, 67], [43, 50, 59, 62], [45, 52, 60, 64], [40, 47, 55, 59],
		[41, 48, 57, 60], [48, 55, 64, 67], [41, 48, 57, 60], [43, 50, 59, 62],
	]
	var pattern := [0, 2, 1, 3, 2, 1, 3, 1]
	for bar in bars:
		var ch: Array = chords[bar]
		for k in 8:
			var idx: int = pattern[k]
			var st := int((bar * 4 + k * 0.5) * beat * MR)
			var g := 0.20 if k == 0 else (0.12 if k == 4 else 0.10)
			_put(out, _pluck(ch[idx], 1.3, 4.2), st, g)
	var mel := [
		[0, 0.0, 76, 1.5], [0, 1.5, 74, 0.5], [0, 2.0, 72, 1.0], [0, 3.0, 67, 1.0],
		[1, 0.0, 71, 1.5], [1, 1.5, 69, 0.5], [1, 2.0, 67, 2.0],
		[2, 0.0, 69, 1.0], [2, 1.0, 72, 1.0], [2, 2.0, 76, 1.5], [2, 3.5, 74, 0.5],
		[3, 0.0, 76, 2.0], [3, 2.0, 79, 1.0], [3, 3.0, 76, 1.0],
		[4, 0.0, 72, 1.0], [4, 1.0, 69, 1.0], [4, 2.0, 72, 1.5], [4, 3.5, 74, 0.5],
		[5, 0.0, 76, 1.0], [5, 1.0, 79, 1.5], [5, 2.5, 76, 0.5], [5, 3.0, 74, 1.0],
		[6, 0.0, 72, 1.5], [6, 1.5, 69, 0.5], [6, 2.0, 65, 2.0],
		[7, 0.0, 74, 1.0], [7, 1.0, 71, 1.0], [7, 2.0, 67, 1.0],
	]
	for m in mel:
		_put(out, _pluck(m[2], 2.4, 1.9), int((m[0] * 4 + m[1]) * beat * MR), 0.26)
	return _finish_track(out, [[0.29, 0.30], [0.55, 0.20], [0.86, 0.12]])

func _track_kora() -> AudioStreamWAV:
	# Kora in D-Dur, ca. 72 BPM: perlende Arpeggien ueber zwei Oktaven, dazu eine schlichte Melodie
	var beat := 60.0 / 72.0
	var bars := 8
	var n := int((bars * 4 * beat + TAIL) * MR)
	var out := PackedFloat32Array()
	out.resize(n)
	var D := [50, 57, 62, 66, 69, 74]
	var A := [45, 52, 57, 61, 64, 69]
	var Bm := [47, 54, 59, 62, 66, 71]
	var G := [43, 50, 55, 59, 62, 67]
	var chords := [D, A, Bm, G, D, A, G, D]
	var pat_a := [0, 2, 3, 4, 5, 4, 3, 2]
	var pat_b := [1, 2, 3, 5, 4, 3, 2, 1]
	for bar in bars:
		var ch: Array = chords[bar]
		var pat: Array = pat_a if bar % 2 == 0 else pat_b
		for k in 8:
			var st := int((bar * 4 + k * 0.5) * beat * MR)
			var g := 0.20 if k == 0 else (0.14 if k % 2 == 0 else 0.11)
			_put(out, _kora(ch[pat[k]], 2.0), st, g)
		# tiefer Basston auf Schlag 1
		_put(out, _kora(ch[0] - 12, 2.4), int(bar * 4 * beat * MR), 0.20)
	var mel := [
		[0, 0.0, 78, 1.5], [0, 1.5, 76, 0.5], [0, 2.0, 74, 2.0],
		[1, 0.0, 76, 1.5], [1, 1.5, 78, 0.5], [1, 2.0, 81, 2.0],
		[2, 0.0, 78, 1.5], [2, 1.5, 74, 0.5], [2, 2.0, 71, 2.0],
		[3, 0.0, 74, 1.0], [3, 1.0, 71, 1.0], [3, 2.0, 67, 2.0],
		[4, 0.0, 74, 1.0], [4, 1.0, 78, 1.0], [4, 2.0, 81, 1.5], [4, 3.5, 78, 0.5],
		[5, 0.0, 81, 1.5], [5, 1.5, 78, 0.5], [5, 2.0, 76, 2.0],
		[6, 0.0, 74, 1.0], [6, 1.0, 79, 1.5], [6, 2.5, 76, 0.5], [6, 3.0, 74, 1.0],
		[7, 0.0, 78, 2.0], [7, 2.0, 74, 2.0],
	]
	for m in mel:
		_put(out, _kora(m[2], 3.0), int((m[0] * 4 + m[1]) * beat * MR), 0.34)
	return _finish_track(out, [[0.35, 0.25], [0.6, 0.18], [0.95, 0.12]])

func _track_banjo() -> AudioStreamWAV:
	# Banjo in G-Dur, ca. 108 BPM: Vorwaerts-Roll in Achteln, Melodie obenauf, Bass auf 1 und 3
	var beat := 60.0 / 108.0
	var bars := 8
	var n := int((bars * 4 * beat + TAIL) * MR)
	var out := PackedFloat32Array()
	out.resize(n)
	var G := [62, 67, 71, 74]
	var C := [64, 67, 72, 76]
	var D := [62, 66, 69, 74]
	var chords := [G, C, G, D, G, C, D, G]
	var roots := [43, 48, 43, 50, 43, 48, 50, 43]
	var roll := [2, 0, 1, 2, 0, 1, 2, 1]
	for bar in bars:
		var ch: Array = chords[bar]
		for k in 8:
			var st := int((bar * 4 + k * 0.5) * beat * MR)
			_put(out, _banjo(ch[roll[k]], 0.9), st, 0.10 if k % 4 == 0 else 0.07)
		_put(out, _kora(roots[bar], 1.4), int(bar * 4 * beat * MR), 0.20)
		_put(out, _kora(roots[bar] + (7 if bar % 2 == 0 else 0), 1.2), int((bar * 4 + 2) * beat * MR), 0.14)
	var mel := [
		[0, 0.0, 79, 1.0], [0, 1.0, 83, 1.0], [0, 2.0, 86, 1.0], [0, 3.0, 83, 1.0],
		[1, 0.0, 84, 1.0], [1, 1.0, 81, 0.5], [1, 1.5, 84, 0.5], [1, 2.0, 79, 2.0],
		[2, 0.0, 79, 1.0], [2, 1.0, 83, 1.0], [2, 2.0, 81, 1.0], [2, 3.0, 79, 1.0],
		[3, 0.0, 78, 1.5], [3, 1.5, 81, 0.5], [3, 2.0, 81, 2.0],
		[4, 0.0, 83, 1.0], [4, 1.0, 86, 1.0], [4, 2.0, 88, 1.0], [4, 3.0, 86, 1.0],
		[5, 0.0, 84, 1.0], [5, 1.0, 81, 0.5], [5, 1.5, 84, 0.5], [5, 2.0, 76, 1.0], [5, 3.0, 79, 1.0],
		[6, 0.0, 78, 1.0], [6, 1.0, 81, 1.0], [6, 2.0, 78, 1.0], [6, 3.0, 74, 1.0],
		[7, 0.0, 79, 2.0], [7, 2.0, 67, 2.0],
	]
	for m in mel:
		_put(out, _banjo(m[2], 1.4), int((m[0] * 4 + m[1]) * beat * MR), 0.20)
	return _finish_track(out, [[0.16, 0.20], [0.34, 0.12]])

func _clar(midi: int, dur: float) -> PackedFloat32Array:
	# Klarinette: Obertoene fast nur ungerade, weicher Ansatz, zartes Vibrato, ein Hauch Atem
	var key := "c%d_%d" % [midi, int(dur * 10.0)]
	if _note_cache.has(key):
		return _note_cache[key]
	var f := _mtof(midi)
	var n := int(dur * MR)
	var out := PackedFloat32Array()
	out.resize(n)
	var amps := [1.0, 0.04, 0.55, 0.03, 0.3, 0.03, 0.12]
	var trng := RandomNumberGenerator.new()
	trng.seed = 3000 + midi
	var lp := 0.0
	for i in n:
		var t := float(i) / MR
		var ph := TAU * f * t + 0.37 * (f / 440.0) * sin(TAU * 4.8 * t) * minf(1.0, t / 0.8)
		var v := 0.0
		for h in 7:
			v += amps[h] * sin((h + 1.0) * ph)
		lp += 0.2 * (trng.randf_range(-1.0, 1.0) - lp)
		v += lp * 0.05
		var env := minf(1.0, t / 0.11) * minf(1.0, (dur - t) / 0.45)
		out[i] = v * env * 0.4
	_note_cache[key] = out
	return out

func _pad(midi: int, dur: float) -> PackedFloat32Array:
	# weicher, langsamer Haltton
	var key := "d%d_%d" % [midi, int(dur * 10.0)]
	if _note_cache.has(key):
		return _note_cache[key]
	var f := _mtof(midi)
	var n := int(dur * MR)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / MR
		var env := minf(1.0, t / 0.9) * minf(1.0, (dur - t) / 1.2)
		out[i] = (sin(TAU * f * t) + 0.25 * sin(TAU * f * 2.0 * t) + 0.08 * sin(TAU * f * 3.0 * t)) * env * 0.4
	_note_cache[key] = out
	return out

func _handpan(midi: int, dur: float) -> PackedFloat32Array:
	# Handpan: Grundton, deutliche Oktave und Duodezime, rundes Glocken-Pling mit weichem Klopfer
	var key := "h%d_%d" % [midi, int(dur * 10.0)]
	if _note_cache.has(key):
		return _note_cache[key]
	var f := _mtof(midi)
	var n := int(dur * MR)
	var out := PackedFloat32Array()
	out.resize(n)
	var ratios := [1.0, 2.0, 3.01, 4.2]
	var amps := [1.0, 0.65, 0.22, 0.08]
	var decs := [1.5, 2.2, 3.6, 6.0]
	for i in n:
		var t := float(i) / MR
		var v := 0.0
		for p in 4:
			v += amps[p] * sin(TAU * f * ratios[p] * t) * exp(-t * decs[p])
		v += 0.35 * sin(TAU * f * 0.5 * t) * exp(-t * 30.0)
		out[i] = v * minf(1.0, t / 0.004) * 0.5
	_note_cache[key] = out
	return out

func _track_klarinette() -> AudioStreamWAV:
	# Nachtstueck: Klarinette ueber leisen Kora-Tropfen und einem weichen Haltton, ca. 54 BPM, a-Moll/C-Dur
	var beat := 60.0 / 54.0
	var bars := 8
	var n := int((bars * 4 * beat + TAIL) * MR)
	var out := PackedFloat32Array()
	out.resize(n)
	var chords := [
		[45, 52, 57, 60, 64], [41, 48, 53, 57, 60], [48, 55, 60, 64, 67], [43, 50, 55, 59, 62],
		[45, 52, 57, 60, 64], [41, 48, 53, 57, 60], [43, 50, 55, 59, 62], [48, 55, 60, 64, 67],
	]
	var drops := [0, 2, 4, 3]
	for bar in bars:
		var ch: Array = chords[bar]
		_put(out, _pad(ch[0] - 12, 4.6 * 1.0 + 1.0), int(bar * 4 * beat * MR), 0.20)
		_put(out, _pad(ch[2], 4.6 + 1.0), int(bar * 4 * beat * MR), 0.12)
		for k in 4:
			_put(out, _kora(ch[drops[k]] + 12, 2.6), int((bar * 4 + k) * beat * MR), 0.075 if k > 0 else 0.10)
	# [Takt, Schlag, Ton, Laenge in Schlaegen]
	var mel := [
		[0, 0.0, 76, 2.0], [0, 2.0, 74, 1.0], [0, 3.0, 72, 1.0],
		[1, 0.0, 69, 3.0], [1, 3.0, 72, 1.0],
		[2, 0.0, 76, 2.0], [2, 2.0, 79, 1.0], [2, 3.0, 76, 1.0],
		[3, 0.0, 74, 3.0], [3, 3.0, 71, 1.0],
		[4, 0.0, 72, 2.0], [4, 2.0, 76, 2.0],
		[5, 0.0, 77, 2.0], [5, 2.0, 76, 1.0], [5, 3.0, 72, 1.0],
		[6, 0.0, 74, 2.0], [6, 2.0, 71, 2.0],
		[7, 0.0, 72, 4.0],
	]
	for m in mel:
		var dur: float = m[3] * beat * 0.94
		_put(out, _clar(m[2], dur), int((m[0] * 4 + m[1]) * beat * MR), 0.30)
	return _finish_track(out, [[0.5, 0.28], [0.9, 0.20], [1.4, 0.13]])

func _track_handpan() -> AudioStreamWAV:
	# Handpan in d-Moll (Kurd-Stimmung), ca. 84 BPM, wiegender Achtel-Groove
	var beat := 60.0 / 84.0
	var bars := 8
	var n := int((bars * 4 * beat + TAIL) * MR)
	var out := PackedFloat32Array()
	out.resize(n)
	var S := [50, 57, 58, 60, 62, 64, 65, 69]
	var p1 := [0, -1, 4, 5, 6, -1, 5, 4]
	var p2 := [0, 4, -1, 5, 3, 4, -1, 2]
	var p3 := [0, -1, 6, 7, 6, 5, 4, -1]
	var p4 := [0, 4, 5, 4, 2, -1, 1, -1]
	var order := [p1, p2, p1, p3, p1, p2, p4, p3]
	for bar in bars:
		var pat: Array = order[bar]
		for k in 8:
			var idx: int = pat[k]
			if idx < 0:
				continue
			var st := int((bar * 4 + k * 0.5) * beat * MR)
			var g := 0.24 if idx == 0 else (0.15 if k % 2 == 0 else 0.12)
			_put(out, _handpan(S[idx], 2.4), st, g)
	return _finish_track(out, [[0.21, 0.22], [0.43, 0.14], [0.8, 0.10]])

func _make_music() -> void:
	# laeuft im Thread; die Stuecke stehen nach und nach bereit
	var res: Array = []
	res.append(_track_spieluhr())
	res.append(_track_kora())
	res.append(_track_banjo())
	res.append(_track_klarinette())
	res.append(_track_handpan())
	music_streams = res

func _exit_tree() -> void:
	if music_thread != null:
		music_thread.wait_to_finish()
		music_thread = null

func _track_ok(idx: int) -> bool:
	var tag: String = music_tags[idx]
	return tag == "any" or (tag == "day" and night < 0.5) or (tag == "night" and night >= 0.5)

func _music_next() -> void:
	# Stuecke werden durchgewechselt (gemischter Stapel); dasselbe Stueck nie zweimal hintereinander.
	# Tagstuecke spielen nur am Tag, das Klarinetten-Nachtstueck nur in der Nacht (dort bevorzugt).
	var idx := -1
	var night_idx := music_tags.find("night")
	if night >= 0.5 and night_idx >= 0 and night_idx != music_last and rng.randf() < 0.5:
		idx = night_idx
	var guard := 0
	while idx < 0 and guard < 40:
		guard += 1
		if music_bag.is_empty():
			music_bag = range(music_streams.size())
			music_bag.shuffle()
		var c: int = music_bag.pop_front()
		if c != music_last and _track_ok(c):
			idx = c
	if idx < 0:
		for c in music_streams.size():
			if c != music_last and _track_ok(c):
				idx = c
				break
	music_last = idx
	music_player.stream = music_streams[idx]
	music_t = 0.0
	music_len = rng.randf_range(MUSIC_MIN, MUSIC_MAX)
	music_fade = 0.0
	music_state = "play"
	music_player.play()

func _process(delta: float) -> void:
	if music_thread != null and not music_thread.is_alive():
		music_thread.wait_to_finish()
		music_thread = null
		music_player = AudioStreamPlayer.new()
		music_player.volume_db = -60.0
		add_child(music_player)
		loops["music"] = music_player
		vols["music"] = 0.0
		_music_next()
		var total := 0.0
		for s in music_streams:
			total += float(s.data.size() / 2) / MR
		print("SFX files loaded: %d groups. MUSIC ready: %d Stuecke (Schleifen je %.0f-%.0f s), Gesamtlaenge einmal %.1f s" % [variants.size(), music_streams.size(), MUSIC_MIN, MUSIC_MAX, total])
	if music_state == "play":
		music_t += delta
		# Kippt die Tageszeit, wird das unpassende Stueck sanft beendet
		var tag: String = music_tags[music_last]
		var misfit: bool = (tag == "night" and night < 0.3) or (tag == "day" and night > 0.7)
		if misfit and music_len - music_t > MUSIC_FADE:
			music_len = music_t + MUSIC_FADE
		var fi := smoothstep(0.0, MUSIC_FADE, music_t)
		var fo := smoothstep(0.0, MUSIC_FADE, music_len - music_t)
		music_fade = fi * fo
		if music_t >= music_len:
			music_player.stop()
			music_state = "gap"
			music_gap = MUSIC_GAP
			music_fade = 0.0
	elif music_state == "gap":
		music_gap -= delta
		if music_gap <= 0.0:
			_music_next()

func _tone(dur: float, f0: float, f1: float, decay: float, vol: float, noise: float = 0.0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	var lp := 0.0
	for i in n:
		var u := float(i) / n
		var f := lerpf(f0, f1, u)
		ph += TAU * f / RATE
		var e := exp(-u * decay) * minf(1.0, float(i) / 60.0)
		lp += 0.25 * (rng.randf_range(-1.0, 1.0) - lp)
		out[i] = (sin(ph) * (1.0 - noise) + lp * noise * 2.5) * e * vol
	return out

func _cat(a: PackedFloat32Array, b: PackedFloat32Array, gap: float = 0.0) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.append_array(a)
	var g := int(gap * RATE)
	for i in g:
		out.append(0.0)
	out.append_array(b)
	return out

func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var n := maxi(a.size(), b.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = (a[i] if i < a.size() else 0.0) + (b[i] if i < b.size() else 0.0)
	return out

func _make_effects() -> void:
	streams["axe"] = _wav(_mix(_tone(0.14, 200.0, 110.0, 7.0, 0.5, 0.2), _tone(0.05, 900.0, 500.0, 12.0, 0.35, 0.9)), false)
	streams["pick"] = _wav(_mix(_tone(0.09, 1100.0, 800.0, 9.0, 0.35, 0.15), _tone(0.05, 2400.0, 1800.0, 12.0, 0.2, 0.7)), false)
	var hit := _mix(_tone(0.08, 420.0, 300.0, 10.0, 0.45, 0.25), _tone(0.03, 1400.0, 900.0, 14.0, 0.2, 0.8))
	streams["hammer"] = _wav(_cat(hit, hit, 0.12), false)
	# Saege: zackiger Ton mit Modulation
	var sn := int(0.7 * RATE)
	var sw := PackedFloat32Array()
	sw.resize(sn)
	var ph := 0.0
	var lp := 0.0
	for i in sn:
		var u := float(i) / sn
		ph += 95.0 / RATE
		var saw := fposmod(ph, 1.0) * 2.0 - 1.0
		var gate := 0.5 + 0.5 * sin(u * TAU * 2.0)
		# Tiefpass: weich statt kratzig
		lp += 0.12 * ((saw * 0.5 + rng.randf_range(-0.25, 0.25)) - lp)
		sw[i] = lp * gate * sin(u * PI) * 0.35
	streams["saw"] = _wav(sw, false)
	streams["splash"] = _wav(_tone(0.25, 700.0, 300.0, 5.0, 0.3, 0.85), false)
	streams["click"] = _wav(_tone(0.04, 1200.0, 900.0, 8.0, 0.3), false)
	streams["place"] = _wav(_mix(_tone(0.12, 260.0, 140.0, 8.0, 0.5, 0.15), _tone(0.05, 1000.0, 700.0, 10.0, 0.2, 0.6)), false)
	streams["deny"] = _wav(_tone(0.14, 200.0, 150.0, 5.0, 0.35), false)
	streams["pop"] = _wav(_cat(_tone(0.12, 523.0, 523.0, 5.0, 0.3), _tone(0.28, 784.0, 784.0, 4.0, 0.3), 0.0), false)
	# warmer, weicher Klang (tiefere Toene, langsames Ausklingen)
	var bell := _mix(_tone(1.2, 587.0, 587.0, 3.5, 0.22), _tone(1.2, 880.0, 880.0, 5.0, 0.08))
	streams["bell"] = _wav(_mix(bell, _tone(1.2, 294.0, 294.0, 3.0, 0.14)), false)
	var mug := _mix(_tone(0.35, 392.0, 380.0, 6.0, 0.16), _tone(0.35, 196.0, 190.0, 5.0, 0.12))
	streams["tavern"] = _wav(_cat(mug, _mix(_tone(0.4, 330.0, 320.0, 6.0, 0.14), _tone(0.4, 165.0, 160.0, 5.0, 0.1)), 0.18), false)
	streams["clink"] = _wav(_mix(_tone(0.3, 740.0, 720.0, 8.0, 0.1), _tone(0.3, 370.0, 360.0, 7.0, 0.08)), false)
	streams["fanfare"] = _wav(_cat(_cat(_tone(0.18, 523.0, 523.0, 3.0, 0.3), _tone(0.18, 659.0, 659.0, 3.0, 0.3)), _tone(0.7, 784.0, 784.0, 2.5, 0.35)), false)
	streams["barrow"] = _wav(_cat(_tone(0.08, 300.0, 300.0, 6.0, 0.3), _tone(0.16, 450.0, 450.0, 5.0, 0.3)), false)

# ------------------------------------------------------------ Steuerung
func play(name: String, vol: float = 1.0, pitch_var: float = 0.08) -> void:
	if muted or vol <= 0.01:
		return
	var st: AudioStream = null
	var gain := 1.0
	var pitch := 1.0
	if variants.has(name):
		var arr: Array = variants[name]
		st = arr[rng.randi() % arr.size()]
		gain = FILE_GAIN.get(name, 1.0)
		pitch = FILE_PITCH.get(name, 1.0)
	elif streams.has(name):
		st = streams[name]
	if st == null:
		return
	var p: AudioStreamPlayer = pool[pool_i]
	pool_i = (pool_i + 1) % pool.size()
	p.stream = st
	p.volume_db = linear_to_db(clampf(vol * gain, 0.0, 1.0) * master)
	p.pitch_scale = pitch * (1.0 + rng.randf_range(-pitch_var, pitch_var))
	p.play()

# ------------------------------------------------------------ Echte Sounds (CC0, Kenney) aus res://audio/
const FILES := {
	"axe": ["chop.ogg", "impactWood_heavy_000.ogg", "impactWood_heavy_001.ogg", "impactWood_heavy_002.ogg"],
	"pick": ["impactMining_000.ogg", "impactMining_001.ogg", "impactMining_002.ogg", "impactMining_003.ogg"],
	"hammer": ["impactWood_light_000.ogg", "impactWood_light_001.ogg", "impactWood_light_002.ogg", "impactPlank_medium_000.ogg", "impactPlank_medium_001.ogg"],
	"saw": ["drawKnife1.ogg", "drawKnife2.ogg", "drawKnife3.ogg"],
	"splash": ["impactSoft_medium_000.ogg", "impactSoft_medium_001.ogg"],
	"click": ["metalClick.ogg"],
	"place": ["impactWood_medium_000.ogg", "impactWood_medium_001.ogg", "doorClose_1.ogg"],
	"deny": ["metalLatch.ogg"],
	"pop": ["impactGlass_light_000.ogg", "impactGlass_light_001.ogg"],
	"bell": ["impactBell_heavy_000.ogg", "impactBell_heavy_002.ogg"],
	"tavern": ["handleCoins.ogg", "handleCoins2.ogg"],
	"clink": ["metalPot1.ogg", "metalPot2.ogg", "metalPot3.ogg"],
	"barrow": ["creak1.ogg", "creak2.ogg"],
}
const FILE_GAIN := {"axe": 0.9, "saw": 0.55, "click": 0.5, "pop": 0.6, "bell": 0.55, "splash": 0.8, "tavern": 0.8, "hammer": 0.85, "pick": 0.85}
const FILE_PITCH := {"splash": 0.75, "bell": 1.1, "saw": 0.9}
var variants := {}

func _load_files() -> void:
	for name in FILES:
		var arr: Array = []
		for f in FILES[name]:
			var path: String = "res://audio/" + f
			var s: AudioStream = null
			if ResourceLoader.exists(path):
				s = load(path)
			elif FileAccess.file_exists(path):
				s = AudioStreamOggVorbis.load_from_file(ProjectSettings.globalize_path(path))
			if s != null:
				arr.append(s)
		if arr.size() > 0:
			variants[name] = arr

func set_mix(target: Dictionary, delta: float) -> void:
	# target: name -> Ziel-Lautstaerke (linear); wird weich angeglichen
	for k in loops:
		var t: float = target.get(k, 0.0)
		vols[k] = lerpf(vols[k], t, clampf(delta * 0.8, 0.0, 1.0))
		var v: float = 0.0 if muted else vols[k] * master * (music_fade if k == "music" else 1.0)
		loops[k].volume_db = linear_to_db(maxf(v, 0.0001))
