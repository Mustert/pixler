extends SceneTree
# Entwicklerwerkzeug: prueft den Ablauf der Musik-Playlist im Zeitraffer, inklusive Tag/Nacht-Zyklus (10 Min.).
# godot --headless --path . --script tools/musictest.gd

func _night_at(t: float) -> float:
	var p := fposmod(0.15 + t / 600.0, 1.0)
	if p < 0.5:
		return 1.0 - smoothstep(-0.04, 0.04, p)
	return smoothstep(0.56, 0.64, p) * (1.0 - smoothstep(-0.04, 0.04, p - 1.0))

func _init() -> void:
	var s := Sfx.new()
	root.add_child(s)
	var waited := 0
	while s.music_player == null and waited < 600:
		await process_frame
		OS.delay_msec(100)
		waited += 1
	var last_state := ""
	var last_idx := -1
	var log := []
	var bad := 0
	var t := 0.0
	for k in 6000:
		s.night = _night_at(t)
		s._process(1.0)
		t += 1.0
		if s.music_state == "play" and s.music_last == last_idx and last_state == "gap":
			bad += 1
		if s.music_state != last_state or (s.music_state == "play" and s.music_last != last_idx):
			var tag: String = s.music_tags[s.music_last]
			log.append("%4ds %s %-18s tag=%-5s nacht=%.2f len=%.0f" % [int(t), s.music_state, s.music_names[s.music_last], tag, s.night, s.music_len])
			if s.music_state == "play" and ((tag == "night" and s.night < 0.5) or (tag == "day" and s.night >= 0.5)):
				bad += 1
			last_state = s.music_state
			last_idx = s.music_last
	for l in log.slice(0, 22):
		print(l)
	print("Regelverstoesse: ", bad)
	print("Schleifenlaenge je Stueck (s): ", s.music_streams.map(func(w): return snappedf(float(w.data.size() / 2) / Sfx.MR, 0.1)))
	quit()
