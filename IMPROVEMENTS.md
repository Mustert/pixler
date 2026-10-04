# Pixlers – Verbesserungsideen

Stand: 2026-10-03. Gesammelt aus Feedback (👤) und Code-Analyse (🔍).
Aufwand: S = Stunden, M = ein bis zwei Tage, L = mehrere Tage. Prio: ★★★ zuerst.
Status: ✅ umgesetzt, 🟡 teilweise umgesetzt, ⬜ offen.

## 0. Bereits umgesetzt (Stand 2026-10-03)
- ✅ **Pixler-Start:** 30 Pixler, Langhaus-Platz 50 (`START_POP`, `HQ_CAP` in `data.gd`). Tutorial-Texte angepasst.
- ✅ **Träger-Kapazität:** 1 Ware pro Träger, Schubkarre 3 (`CARRY_N`, `BARROW_N` in `sim.gd`). 10 Schubkarren am Start, Karre schon ab mehr als 4 Waren an einer Flagge (`BARROW_AT`), Schubkarrenbauer bis 30.
- ✅ **Felsen:** deutlich weniger Felsen, dafür ca. dreimal so viel Stein pro Fels. Der Sprite schrumpft beim Abbauen (groß ab 22 Resten).
- ✅ **Feineres Raster (K = 2):** 384×384 Zellen, Gebäude 4×4 statt 2×2. Entwurfswerte stehen in `Data.BD_T` (Kachel-Einheiten), `Data.BD` ist die hochgerechnete Fassung. Weltgenerierung tastet die Kachel-Entwürfe fein ab. Geschwindigkeiten, Reichweiten und Spawnraten sind mit K skaliert.
- ✅ **Höhere Auflösung:** Gebäude, Bäume, Felsen mit Faktor 2 (`Art.S`), kleine Pflanzen, Tiere und Pixler in Echtauflösung. Standard-Zoom weiter draußen, Stufen 0.5 / 1 / 1.5 / 2 / 3 / 4. Terrain-Shader weicher abgestimmt.
- ✅ **Neue Pixler:** 20×30, Zipfelmütze mit Bommel, große Nase, Gürtel, Stiefel, Werkzeug je Beruf (`TOOL_OF`), 4-Phasen-Gehzyklus plus Standbild. Farben kommen aus `col` des Gebäudes.
- ✅ **Wege (1.8):** Wege werden als weiche Polylinien mit Rand, Füllung, Glanz und Kieseln gezeichnet, runde Gelenke an Knicken, Plätze an Flaggen. Wegsuche hat eine Kurvenstrafe (weniger Zacken) und ein Expansionslimit.
- ✅ **Flaggen (1.7):** kleinere Flaggen, Tür-Flagge sucht den besten freien Platz vor dem Gebäude und darf an vorhandene Wege andocken (`door_offsets`). Gebäude hängen zentriert am Mauszeiger, die Vorschau zeigt die Flagge.
- ✅ **Weiche Objekte (1.9):** Kräuter, Pilze, Leuchtblumen und Glühpilze blockieren nicht mehr (`Data.SOFT`) und werden beim Bauen von Gebäuden, Wegen und Feldern geräumt. Planierer-Gebäude damit für diese Pflanzen nicht nötig; für Bäume und Felsen weiter offen.
- ✅ **Performance-Basis:** Objekte und Baumstümpfe stehen in einem Chunk-Index (`chunk_obj`, `chunk_stump`), das Rendern ist objektbasiert statt zellbasiert.
- ✅ **Ballonfahrer (neu, 1.13 teilweise):** Gebäude mit Heißluftballon, der im Hinterhof aufgepumpt wird und dann einen Pixler quer über die Karte fährt (zwei zufällige Fernziele, dann Landung und neu aufpumpen). Rein kosmetisch, **kein Erkundungs-Effekt**. Logik in `Sim.Balloon` / `upd_balloons`.
- ✅ **Quick Wins vom 2026-10-04:** Lagerhaus nicht abreißbar (1.23), längere Tätigkeitsdauer mit Faktor 1,6 und Taverne zusätzlich 2,5 (1.22, `Data.WORK_MULT`/`TAVERN_MULT`), Fortschrittsbalken im Info-Panel und über dem gewählten Gebäude (1.24, `Sim.progress`), Pixler-Aufschlüsselung in der Kopfleiste mit Frühwarnung bei höchstens 2 freien Pixlern (1.4), Balance-Regler per Kommandozeile (1.5), Abriss-Bestätigung bei Inhalt oder Ausbaustufe und hervorgehobene Spielgeschwindigkeit (2.9).
- ✅ **Lagerarbeiter (1.19 teilweise):** Langhaus 3, Lagerhaus 1 fest angestellte Pixler tragen Waren Stück für Stück vor die Tür (`Sim.Keeper`, `upd_keepers`, Warteschlange `out_q`). Produktionsgebäude (Prozess-Typ) liefern ihre Waren jetzt ebenfalls selbst aus (`out`/`ret` in `upd_bld`); Sammler trugen sie schon vorher. Das Langhaus hat nur noch eine Tür-Flagge. Tutorial-Popups sind abgeschaltet (`tut := 2`). Lauftempo aller Pixler −25 % (`WALK_MULT`).
- ✅ **Tag/Nacht 6 + 4 Minuten (2.8 teilweise):** `_phase()`, `_night()`, `_day_t()` in `main.gd`, Tinte und Uhr angepasst. Wetter und Jahreszeiten offen.
- ✅ **Musik-Playlist (1.18 teilweise):** fünf Stücke in `audio.gd`: Spieluhr (C-Dur), Kora (D-Dur, perlende Arpeggien), Banjo (G-Dur, Vorwärts-Roll, nur am Tag), Klarinette (sehr ruhiges Nachtstück, nur nachts) und Handpan (d-Moll), gemischte Reihenfolge ohne direkte Wiederholung, jedes Stück als nahtlose Schleife 60–180 s mit 8 s Ein-/Ausblenden und 10 s Pause. Offen: Tageszeit- und Biom-Themen, Dynamik nach Spielzustand, Lautstärkeregler.
- ✅ **Waren-Icons neu (deutlicher):** alle 21 Waren mit kräftiger Kontur und klaren Silhouetten, **Wasser als Eimer**. Welt-Icons nativ 10×10 (kein Skalieren mehr).
- ✅ **Brunnen:** der Pixler kurbelt sichtbar neben dem Brunnen (Kurbel dreht sich, Arm, Wippen), danach trägt er den Eimer zur Flagge. Wasser bleibt ortlos baubar (1.6 offen).
- ✅ **Info-Panel mit Warenicons:** Icon mit Zahl dahinter (vorhanden bzw. vorhanden/benötigt, rot wenn zu wenig) für Lager, Produktion, Baustellen und Wohnhäuser, neu gebaut nur bei geänderter Warenliste. Das Panel überdeckt die Minimap nicht mehr.
- ✅ **Entwicklerwerkzeug:** `tools/sheet.gd` rendert alle Sprites in ein Bild.

**Offene Ränder der Umsetzung:** Wirtschaftsbalance mit 1 Ware/Träger ungetestet (Stellschrauben: `CARRY_N`, `BARROW_N`, `BARROW_AT`, `ROAD_SEG`, `FLAG_CAP`). Gebäudegrafik ist nur schärfer, nicht detaillierter (Schindeln und Holzmaserung fehlen). Selbsttest nutzt feste Koordinaten nur noch für die HQ-Mitte.

---

## 1. Feedback aus dem Spieltest (👤)

### 1.1 Andere Geräusche für eigentlich alles (M, ★★)
Aktuell: Kenney-Aufnahmen (`audio/`) plus prozedurale Töne in `audio.gd` (`_make_effects`, `_tone`). Das Ergebnis klingt zusammengewürfelt (Holz-Impact für vieles, Glas/Bell als "Pop").
- **Ton-Konzept festlegen**, bevor Sounds getauscht werden: eine Klangfamilie (z. B. weich, hölzern, Spieluhr/Marimba, passend zu Cozy-Pixel-Art) statt Foley-Realismus.
- **Pro Ereignis eine eigene Signatur** statt Wiederverwendung: Bauen fertig, Wohnhaus-Upgrade, Pixler zieht ein, Ware ablegen, Flagge setzen, Weg bauen, Abriss, Fehler/"geht nicht", Wahrzeichen fertig.
- **Gebäude-Loops** je Gebäudetyp unterscheidbar (Sägewerk, Mühle, Bäckerei, Taverne, Küche …), nur nah/gezoomt hörbar (so wie jetzt).
- Quellen prüfen: CC0-Packs (Kenney, freesound CC0) oder komplett selbst synthetisiert mit festem Instrument-Set (Pluck/Marimba/Blubb). Lizenzen in `audio/LICENSE.txt` mitpflegen.
- Technisch: `FILES`-Map in `audio.gd:305` ist schon der richtige Hook; neue Sounds erst als Austausch einpflegen, dann Mischung (`FILE_GAIN`) pro Klangfamilie neu abstimmen.

### 1.2 Redesign der Pixler (S–M, ★★)
Status: ✅ neues Design, Werkzeuge, Gehzyklus. Offen: Varianz und Uniformen (siehe 1.14).
Ursprünglich: Zipfelmütze + große Nase, prozedural gezeichnet (`art.gd`).
- Lesbarkeit auf kleinster Zoomstufe: Silhouette entscheidet. Pro Rolle unterscheidbar machen (Mützenfarbe/Werkzeug/Schürze: Holzfäller, Träger, Bauarbeiter, Fischer …).
- Träger vs. Träger-mit-Karre vs. Bauarbeiter klar trennen (Farbe der Mütze).
- Laufanimation mit 2–4 Frames (Wippen), Blickrichtung (`face` gibt es schon in `Bld`/`Builder`).
- Variation: Mützenfarbe/Nase pro Pixler leicht zufällig → wirkt lebendiger.
- Vorgehen: erst Referenzbild/Entwurf (3 Varianten), dann Austausch an einer Stelle.

### 1.3 Upgrades: Wohnhäuser machen Spaß → auch für andere Gebäude (M–L, ★★★)
Das Upgrade-System (`HOUSE_UP`, `start_upgrade`, `fed`) ist schon da, aber auf `haus` hartcodiert.
- **Verallgemeinern**: `UP` als Teil von `BD` je Gebäude (Kosten, Bedingung, Effekt, neues Aussehen), statt `if b.type == "haus"` an vielen Stellen.
- **Kandidaten mit echtem Effekt**:
  - Holzfäller/Steinbruch/Fischer: größere Reichweite `R` oder kürzere Arbeitszeit `t`.
  - Sägewerk/Steinmetz/Mühle/Bäckerei: `outn` +1 oder schneller; ab Stufe 3 braucht es kein Wasser mehr o. Ä.
  - Lagerhaus: mehr Bauarbeiter / höhere Flaggenkapazität im Umkreis.
  - Langhaus: zusätzliche Tür (Flagge) → entzerrt Stau am Lager.
  - Taverne: mehr Pixler pro Mahlzeit.
- **Bedingung nach Gebäudeart**: Wohnhaus = versorgt (wie jetzt); Produktion = X Einheiten produziert; Biom-Gebäude = Biomware als Upgrade-Material (löst auch Punkt 1.9 teilweise).
- **Sichtbar machen**: Stufe im Sprite (Fahne, Anbau, Schornstein), Upgrade-Button im Info-Panel, Fortschrittsanzeige "noch 2× versorgen".

### 1.4 Anfang ist zu knapp mit den Pixlern (S, ★★★)
Status: 🟡 Startwert 30/50 umgesetzt. Offen: Zähler-Aufschlüsselung im UI, Warnung vor Mangel.
Ursache im Code: `free_pixlers()` = `pop − Arbeiter − Träger − aktive Bauarbeiter` (`sim.gd:372`). Start 12 (`START_POP`), und **jeder Träger zählt als Pixler**. Zwei, drei Straßen fressen den Vorrat, bevor ein Haus arbeitet.
- Schnellste Lösung: `START_POP` anheben (z. B. 20–24) **oder** Träger/Bauarbeiter vom Pixler-Konto abkoppeln (eigener Pool "Träger", wächst mit Straßenlänge/Lager).
- Taverne früher erreichbar machen (günstiger bzw. im Tutorial vor Küche/Mühle), da sie den Nachschub liefert.
- UI: Pixler-Zähler aufschlüsseln (Arbeiter / Träger / Bauarbeiter / frei) und warnen, **bevor** die Meldung "Keine freien Pixler" blockiert.
- Zusätzlicher Hinweis, wenn Wohnraum voll ist und Taverne fehlt/leer läuft.

### 1.5 Zwei Ressourcen tragen vielleicht doch zu viel (S, ★★)
Status: ✅ 1 Ware pro Träger, Karre 3 (Balance noch zu testen).
Ursprünglich: Träger tragen 2 Waren, Karren 5 (`cap_of`, `sim.gd:935`). Gemeinsam mit langen Segmenten kaum Stau-Gefühl, Logistik wird zu leicht und Wege/Flaggen verlieren Bedeutung.
- Zurück auf **1 Ware pro Träger**, Karre 2–3 (Karre bleibt als echtes Upgrade).
- Dann `FLAG_CAP`, Träger-Geschwindigkeit und Segmentlänge (`k - last >= 6` in `add_road`) neu balancieren.
- Als Option in `Data`/Konstanten halten, damit man per Debug-Flag A/B testen kann.

### 1.6 Wasser: überall Brunnen gefällt nicht (M, ★★★)
Wasser ist Zutat von Weizenfarm, Bäckerei, Ranch, Gärtner, Küche, Taverne, Obsidian **und** Wohnhaus. Der Brunnen ist ortlos baubar (`need` fehlt) → jede Kette hat einen Brunnen daneben, Wasser ist die langweiligste Ressource.
Optionen (kombinierbar):
- **Wasser als Ortsressource**: Brunnen braucht Grundwasser/Quelle (neue Quell-Objekte, oder nur nahe Ufer/Sumpf/Oase). Dann entstehen Standorte statt Beliebigkeit.
- **Wasser aus der Kette entfernen** dort, wo es nur Füllstoff ist: Weizen braucht Regen/Feld, Küche/Taverne brauchen Wasser nicht → nur Bäckerei, Ranch, Wohnhaus behalten.
- Alternative: **Wasserträger/Wasserleitung** (Rinnen) statt Warenlogistik; oder Wasser als Gebäude-Reichweite (Brunnen versorgt Umkreis automatisch, kein Transport).
- Empfehlung: Wasser auf 2–3 Verbraucher reduzieren **und** Brunnen an Quellen binden.

### 1.7 Flaggen vor den Gebäuden zu klobig – gute Wege schwer baubar (M, ★★★)
Status: 🟡 kleinere Flaggen, automatische Türwahl, Andocken an Wege, zentrierte Bauvorschau umgesetzt. Offen: Tür-Seite drehen, Straßenbau-Hilfe.
Ursprünglich: Jedes Gebäude belegt eine Flaggenzelle direkt vor der Tür (Standard `[w-1, h]`, `can_place`). Diese Zelle blockiert für Nachbargebäude und Straßen, die Tür kann nur an einer Stelle sein (Langhaus: drei).
- **Flagge an Gebäudekante freier wählbar** (Tür-Seite beim Platzieren drehen: R/Mausrad), Vorschau zeigt Flagge.
- **Mehr Bauplatz-Toleranz**: Flagge darf eine bereits vorhandene Straße/Flagge sein (Gebäude "dockt" an) – `can_place` meldet heute "Straße im Weg".
- **Abstand**: Gebäude dürfen Rücken an Rücken stehen, Flaggen teilen sich eine Zelle.
- **Visuell kleiner** (die Flagge ist ein Marker, kein Objekt): kleineres Symbol, halbtransparent, wenn kein Weg anliegt.
- **Straßenbau-Hilfe**: Vorschau, welche Zellen blockiert werden; Auto-Routing um Gebäude herum (A* `find_path` gibt es schon).

### 1.8 Diagonale Straßen und "Kreuzungen" sehen nicht gut aus (M, ★★★)
Status: ✅ Wege als weiche Bänder mit Plätzen an Flaggen, Kurvenstrafe in der Wegsuche. Offen: Texturdetails (Spurrillen, Pflaster).
Ursprünglich: Diagonalen (8-Richtungen) mit `dlink`-Bits, X-Kreuzungen werden in `find_path` ausgeschlossen. Optisch bleibt es zackig/pixelig, Ecken und Abzweige wirken lückenhaft.
- **Rendering**: Auto-Tiling (Bitmask: N/E/S/W/Diagonalen) mit eigenen Kurven-, T-, Kreuzungs-Tiles statt Linien; Kanten zum Gras weich ausblenden.
- Oder **Diagonalen abschaffen** (nur 4 Richtungen) und stattdessen Kurven schöner zeichnen – einfacher, sauberer, Stadtbild wie bei Pixel-Aufbauspielen; Pathfinding wird billiger.
- **Kreuzungen nur an Flaggen** zulassen und dort einen Platz (Plaza-Tile) zeichnen → Flaggen werden zu Knoten statt Fremdkörpern, hängt mit 1.7 zusammen.
- Kompromiss: Diagonalen erlauben, aber **nur als 45°-Stücke mit eigenem Tile**, nie einzelne Diagonalzelle zwischen Geraden.

### 1.9 Kräuter/Pilze blockieren – Planierer einführen (M, ★★★)
Status: 🟡 weiche Objekte umgesetzt (Kräuter, Pilze, Leuchtblumen, Glühpilze). Offen: Planierer für Bäume, Felsen, Stümpfe.
Ursprünglich: `HERB`/`SHROOM` setzen `obj[i] != 0` (siehe `gen`) → `free_ground`/`can_place` verbieten Bauen; auch Bäume, Felsen wirken so. Wiesen sind schnell "vermint".
- **Planierer/Rodungs-Gebäude** (oder Rodungs-Werkzeug): räumt Kräuter, Pilze, kleine Büsche, Stumpf in Radius; liefert evtl. Ressource (Kräuter, Pilze) beim Abräumen.
- **Alternativ/Zusätzlich**: Kräuter und Pilze **nicht blockierend** (nur Deko-Overlay, kein `obj`) – dann braucht man keinen Planierer für sie, nur für Bäume/Felsen.
- **Bauherr entfernt Bewuchs automatisch**, wenn Bauplatz nur durch weiche Objekte (Kraut/Pilz) blockiert; Kosten: etwas Bauzeit.
- Bonus: Planierer ebnet Gelände für Straßen/Felder, räumt Baumstümpfe (`stump`).

### 1.10 Mehr aus den Biotop-Ressourcen herausholen (L, ★★★)
Aktuell: jedes Biom → **eine** Ware → **ein** Wahrzeichen (5 Stück), danach hat das Biom keinen Zweck. Das ist der größte Spieltiefen-Hebel.
- **Weiterverarbeitung** (wie Glas aus Sand): Feenstaub → Zaubertrank/Lichter, Obsidian → Werkzeug/Schmuck, Glühpilze → Laternen/Medizin, Eis → Kühlung (Fisch/Fleisch haltbar), Glas → Fenster/Gewächshaus.
- **Nutzen im Alltag**: Biomwaren als **Upgrade-Material** (1.3), als Zutat für Spezialgerichte (Taverne/Küche) oder als **Wohnhaus-Stufe 4** ("Villa").
- **Mehr Rohstoffe pro Biom** (2–3 statt 1): z. B. Wüste: Sand + Kaktus + Salz; Sumpf: Glühpilz + Torf + Schilf; Schnee: Eis + Pelze + Pinienholz.
- **Gebäude-Boni**: Eis-Kühlhaus verlängert Haltbarkeit; Feenstaub-Segen (+Wachstum Wald); Obsidian-Schmiede (Werkzeug → schneller arbeiten).
- **Handel**: Überschuss-Biomwaren → Händler/Schiff (siehe 1.13) tauscht gegen Seltenes.

### 1.11 Fog of War + Erkundung (L, ★★)
Es gibt keinen Nebel; die gesamte 192×192-Karte inkl. Minimap ist von Anfang an sichtbar, Biome fix an festen Koordinaten (`A` in `gen`).
- Nebel als zweite Ebene (Shader `terrain.gdshader` kann das; ein `explored`-Byte-Array parallel zu `ground`).
- Sicht: Gebäude/Flaggen/Pixler decken Radius auf, **Erkunder** (Pixler zu Fuß, Ballon, Schiff) mehr.
- Minimap zeigt nur erkundete Bereiche; Bauen nur in erkundetem Gebiet.
- Wirkt zusammen mit 1.12 (Gebietsgrenzen) und 1.13 (Fahrzeuge). Ohne Erkundungsziel (Biome verstecken, Funde, Ruinen) ist der Nebel nur Verzögerung → Biome sollten **gefunden** werden (zufällige Positionen pro Seed statt fixer Koordinaten).

### 1.12 Gebietsgrenzen erweitern (M, ★★)
Bauen ist überall erlaubt, es gibt kein Gebiet. Mit Nebel/Erkundung passt Grenzlogik gut dazu: Territorium um Langhaus/Lager, erweiterbar durch **Wachhaus/Banner/Außenposten** oder durch Wahrzeichen (+Radius).
- Grenzen auf der Karte zeichnen (Linie, Farbton).
- Außenposten kostet Material und Pixler, schaltet Biome nacheinander frei → natürliche Progression (zuerst Wald/Fels, später Biome).
- Konflikt vermeiden: Nicht zu früh erdrosseln – Startgebiet sollte Tutorial-Gebäude sicher fassen.

### 1.13 Fahrzeuge: Ballons, Schifffahrt, Boote, Kutschen (L, ★)
Status: 🟡 Ballonfahrer-Haus als rein kosmetischer Ballon vorhanden. Er deckt noch keinen Nebel auf; dafür Nebel (1.11) und Erkundungslogik ergänzen. Boote und Kutschen (1.21) offen.
Ursprünglich: Große Spielwelt mit Wasser (See, Oase) – bisher nur Kulisse.
- **Erkundungsballon** (billig, begrenzte Flugzeit): deckt Nebel auf (1.11), einfach zu bauen, kein Pathfinding nötig.
- **Boote/Fähren** über Wasser: Flaggen am Ufer, Wasserwege als Straßenersatz; Inseln als Biom-Reiseziele (Biome auf Inseln auslagern).
- **Kutschen** auf langen Straßen: entlasten Träger-Ketten (Fernlieferung zwischen Lagern) – gleiche Funktion wie Karre, aber höher skaliert.
- **Schiff-Handel** mit Händlern an Küste (verknüpft mit 1.10).
- Empfehlung: Ballon zuerst (kleiner Aufwand, großer Effekt), dann Boote, Kutschen zuletzt.

---

### 1.14 Pixler-Varianz und Berufs-Uniformen (M, ★★)
Status 🟡: Mützen- und Tunikafarbe pro Beruf und ein Werkzeug sind da, alle Pixler eines Berufs sehen aber gleich aus.
- **Variation pro Pixler:** Hautton, Nasengröße, Bart, Haarfarbe, Mützenform (Zipfel, Kappe, Hut), Körpergröße leicht zufällig; Seed pro Pixler stabil, damit Gesichter wiedererkennbar bleiben.
- **Echte Uniformen:** Schürzen (Bäcker, Metzger), Lederweste (Holzfäller), Kittel (Steinmetz), Helm (Steinbruch), Kapuze (Jäger), Hut (Fischer) statt nur Farbwechsel.
- **Technik:** `man_img` in Teile zerlegen (Basis, Kopf, Hut, Oberteil, Werkzeug), Kombinationen vorrendern oder per Shader einfärben, damit nicht hunderte Texturen entstehen.
- Hängt mit 1.17 (Biom-Pixler) zusammen.

### 1.15 Gebäude besser unterscheidbar (M, ★★)
Viele Häuser nutzen dieselbe Vorlage `house()` (Wand, Dach, Fenster, Tür); aus der Entfernung sind Holzfäller, Förster, Fischer, Jäger kaum zu trennen.
- **Eigene Silhouetten** je Gebäudeart: Türme (Mühle, Sägewerk mit Wasserrad), Anbauten, Schornsteintypen, Dachformen (Walm, Flach, Zelt, Strohdach), unterschiedliche Grundrisse.
- **Arbeitsstationen im Vorgarten** (Holzstapel, Fischernetze, Beete, Fässer) größer und eindeutig.
- **Farbcodes** pro Kategorie (Basis, Nahrung, Biome) als Dachfarbe oder Wimpel.
- **Test:** Kontaktbild mit `tools/sheet.gd` bei Zoom 0.5 prüfen: erkennt man jedes Gebäude?

### 1.16 Stil weniger pixelig und simpel, mehr Siedler 2 (L, ★★)
Aktuell: prozedural gezeichnete, flächige Pixel-Art mit dünnem Rand.
- **Zielstil klären:** handgemalte Sprites mit weichen Schattierungen, dunkle Konturen nur außen, Lichtkante oben links, kräftige Farbpalette, detaillierte Dächer und Mauern wie bei Siedler 2.
- **Zwischenschritt:** Texturdetails im Generator (Schindeln, Holzmaserung, Steinfugen, Moos), weiche Schatten unter Gebäuden, Ambient Occlusion an Wänden, Farbverläufe in Baumkronen.
- **Langfristig:** externe Assets (selbst gemalt oder lizenziert) statt Prozedural-Code; das Rendering-System (`Art.bld`, `Art.objs`) bleibt als Schnittstelle bestehen.
- **Terrain:** weichere Übergänge, Gras-Büschel, Uferlinien, Straßen mit Spurrillen.
- Voraussetzung: Entscheidung Prozedural vs. Assets, sonst viel verlorene Arbeit.

### 1.17 Große Welt, Erkunden, Biom-Pixler (L, ★★★)
Verbindet 1.10, 1.11, 1.12, 1.13 und 2.4 zu einem Spielkonzept.
- **Zufälliger Start:** Startpunkt und Biom-Positionen pro Seed würfeln (Mindestabstand, Reihenfolge nach Distanz). Der Start kann in jedem Biom liegen.
- **Größere Karte** mit Inseln oder Kontinenten; Erkundung per Ballon (Gebäude gibt es schon, Nutzen fehlt), Boot, Schiff, Kutsche. Nebel (1.11) deckt auf, Minimap zeigt nur Erkundetes.
- **Biome mit großem Einfluss:** Klima bestimmt Wachstum, Bautempo, Pixlerbedarf, Wasserquellen, Ressourcen, Wetter.
- **Biom-Pixler:** Eine Taverne in einem Biom lockt Pixler dieses Biomtyps an (Lava-, Eis-, Wüsten-, Feen-, Sumpf-Pixler mit eigenem Aussehen und Mütze). Alle können dasselbe, aber **nur Lava-Pixler bauen Obsidian ab**, nur Eis-Pixler hauen Eis usw. Gebäude brauchen dann Pixler des richtigen Typs (Filter in `free_pixlers`, getrennte Zähler pro Typ).
- **Material nach Herkunft:** Holz und Stein aus Biomen sehen anders aus (Kiefernholz, Obsidianstein, Feenholz) und erzeugen andere Warenvarianten. Gebäude können dadurch andere Optik bekommen (Dach aus Glas, Eisbau, Pilzhaus), mit Warenvarianten in `GOODS` und Baumaterial-Stufen aus 1.20.
- **Technik:** Pixler- und Warenart als Tag (`biome`) mitführen, Sprites per Palettentausch einfärben.

### 1.18 Mehr Musikvarianz (M, ★)
Aktuell eine generierte Spieluhr-Schleife (ca. 25 s, `_make_music` in `audio.gd`).
- Mehrere Stücke mit Tonart-/Tempowechsel, Tageszeit-Stimmung (Morgen, Abend, Nacht), eigenes Thema pro Biom.
- Dynamik nach Spielzustand: ruhig am Anfang, voller bei großer Stadt, besonderes Thema bei Wahrzeichen.
- Übergänge per Crossfade statt hartem Schnitt; Lautstärke der Musik regelbar.

### 1.19 Waren erscheinen nicht aus dem Nichts: Träger aus dem Haus (M, ★★)
Heute entstehen Waren per `emit` direkt an der Flagge.
- **Haus-Träger:** Jedes Produktionsgebäude hat einen Pixler als Hausträger, der jede Ware zur Tür-Flagge trägt (und Eingänge von der Flagge holt). Sichtbar mit Sprite, Wegzeit, Warteschlange im Haus.
- Der Ausgang wird dadurch zu einem eigenen Engpass (mehrere Waren kommen nacheinander, nicht gleichzeitig).
- Technik: kurze Laufbahn Tür→Flagge (`door_offsets` liefert Position), Zustand `out_queue` in `Bld`, `emit` nur noch aus der Warteschlange.
- Hängt mit 1.5 (Logistik) und 1.2/1.14 (Pixler-Darstellung) zusammen.

### 1.20 Mehrstufiges Baumaterial: Holz → Bretter → Möbel (L, ★★)
Aktuell: Bretter und Steinblöcke sind die einzigen Baustoffe.
- **Stufe 1:** Holz, Stein (Rohstoffe). **Stufe 2:** Bretter, Steinblöcke. **Stufe 3:** Möbel, Fenster (Glas), Ziegel, Dachziegel, Werkzeug.
- Einfache Gebäude brauchen nur Stufe 1, höhere Gebäude und Upgrades (1.3) Stufe 2 und 3. Das staffelt den Spielfortschritt und gibt Biomwaren (Glas, Obsidian, Eis) einen festen Platz.
- **Neue Gebäude:** Schreinerei (Möbel aus Bretter + Stoff/Leder), Ziegelei, Schmiede.
- Hängt mit 1.17 (Materialherkunft) und 1.10 (Biomwaren) zusammen.

### 1.21 Kutschen und Wagenbauer (M–L, ★)
- **Wagenbauer** (analog Schubkarrenbauer) baut Kutschen/Wagen für lange Strecken.
- **Kutschen** pendeln zwischen Lagern auf Fernrouten; Reihenfolge der Beförderung, Haltepunkte an Lagern.
- Ersatz für Schubkarren auf hoch ausgelasteten Wegen; benötigt Straßenqualität (Kopfsteinpflaster?) oder Pferde als Ressource.
- Einordnung nach Fahrzeugen in 1.13: Ballon (vorhanden) → Boot → Kutsche.

### 1.22 Dauer erhöhen für fast alle Tätigkeiten, vor allem die Taverne (S, ★★★)
Die `t`-Werte in `Data.BD_T` sind kurz (Taverne 8 s, Küche 10 s, Sägewerk 5 s …).
- **Globaler Faktor** `WORK_TIME_MULT` (z. B. 1.5–2.0) auf alle `t` plus separate Taverne-Verlängerung (z. B. 25–40 s pro Pixler), damit Einwanderung ein Ereignis ist.
- Gleichzeitig Produktionsmenge/Kosten und Lagerlimits prüfen, sonst läuft die Wirtschaft leer.
- Mit 1.19 (Hausträger) und dem Fortschrittsbalken (1.24) gut kombinierbar: längere Zeiten wirken dann weniger zäh.

### 1.23 Abriss auf dem Lagerhaus nicht anbieten (S, ★★★)
Im Info-Panel und per Abriss-Tool lassen sich Lagerhäuser derzeit abreißen (nur das Langhaus `hq` ist geschützt).
- Lagerhaus-Abriss entfernen oder sperren (Button unsichtbar, Abriss-Tool zeigt Hinweis). Falls erlaubt, nur wenn leer und mit Rückgabe der Waren an ein anderes Lager.
- Prüfung in `Sim.demolish` und im Info-Panel (`main.gd`, `idb`-Button): `b.type in ["hq", "lager"]`.

### 1.24 Fortschrittsbalken bei angeklickten Gebäuden (S, ★★★)
- Im Info-Panel eine ProgressBar für die laufende Tätigkeit: Produktion (`b.timer` / `d.t`), Gehen/Sammeln (`act`-Timer), Ausbau/Bau (`b.prog` gibt es schon als Text), Taverne (Mahlzeit), Ballon (Aufpumpen).
- Zusätzlich dünner Balken über dem Gebäude, wenn es ausgewählt ist.
- Technik: `Bld` merkt sich `work_total` beim Start; Panel zeigt `1 − timer/total`.

### 1.25 Schickeres, durchgängiges UI (M–L, ★★)
Aktuell: Godot-Standard-Controls mit Braun-Theme (`_make_theme` in `main.gd`), gemischte Größen, Textlabels.
- **Einheitlicher Stil** passend zum Zielstil (1.16): Rahmen, Papier-/Holztexturen, eigene Buttons, Icons statt Text, Tooltips im Layout.
- Gebäudemenü mit Kategorie-Tabs als Leiste, Icons in einheitlicher Größe, Kosten direkt sichtbar, ausgegraute Einträge.
- Info-Panel als Karte mit Titelleiste, Balken, Warenicons mit Zahlen (statt Textlisten).
- Oberleiste: Warengruppen mit Icons, Pixler-Aufschlüsselung (Arbeiter/Träger/Bau/frei), Uhr, Geschwindigkeit.
- Schrift: Pixel- oder Handschrift passend zum Stil statt Fallback-Font.

### 1.26 Straßen-Upgrades (M, ★★)
Status: ⬜ offen. Heute gibt es nur einen Wegtyp (Erdweg), gezeichnet in `_draw_roads` (`main.gd`), Tempo und Kapazität sind für alle Segmente gleich (`upd_seg`, `cap_of` in `sim.gd`).
- **Stufen:** Trampelpfad (Start, billig) → Schotterweg → Pflasterstraße, optional dritte Stufe "Prachtstraße" für große Städte.
- **Effekt pro Stufe:** höhere Trägergeschwindigkeit (z. B. +15 % / +30 %), größere Schubkarren-Last oder mehr Waren pro Trip, höhere Flaggenkapazität an Segmentenden. Das gibt Wegen einen Wert neben Flaggen und Zweitstraßen (1.5).
- **Kosten:** Steinblöcke bzw. Bretter pro Zelle (oder pro Segment), geliefert über das Wegenetz wie bei Baustellen; Bauarbeiter oder Straßenbauer-Haus (Pflasterer) führt das Upgrade aus. Auf Zellenebene möglich, praktischer pro Segment, weil Tempo am `Seg` hängt.
- **Bedienung:** Werkzeug "Straße ausbauen" (Taste U) oder Klick auf ein Segment im Info-Panel mit Kosten, Nutzen und Fortschrittsbalken (1.24). Vorschau, welche Segmente gemeinsam verbessert werden. Optional "Ausbau-Priorität" für Hauptstrecken.
- **Optik:** Stufe pro Segment im Rendering: Farbe, Rand und Kiesel für Schotter, Pflastermuster und Randsteine für Stein, Spurrillen beim Erdweg. Passt zu 1.16 und lässt sich in `_draw_roads` pro Segment-Stufe trennen (eigener Satz Farben/Texturen pro Ebene).
- **Anbindung an andere Punkte:** Kutschen (1.21) fahren nur auf Pflasterstraße; Fernrouten für Fahrzeuge ab Schotter; Mehrstufiges Material (1.20) liefert Kies und Ziegel/Pflastersteine als Baustoff; Wohnhaus-Upgrade (1.3) kann an Straßenanschluss gebunden werden.
- **Technik:** `Seg.level` (0–2) mit Speicherstand (2.1) berücksichtigen, `_mk_seg`/`create_flag` beim Teilen eines Segments Stufe vererben, `_sc`/Geschwindigkeit mit Stufenfaktor multiplizieren, Cache `s.pts` bleibt gültig (Zellen ändern sich nicht).

---

## 2. Weitere Beobachtungen aus der Code-Analyse (🔍)

### 2.1 Kein Speichern/Laden (M, ★★★)
In `main.gd`/`sim.gd` gibt es kein Save/Load (nur Screenshot-Debug). Bei Spielen dieser Dauer (Warenketten, Wahrzeichen) ist das der wichtigste fehlende Baustein. Zustand (`blds`, `flags`, `segs`, Arrays) ist gut serialisierbar; dazu Seed + Änderungen an `ground/obj/amt`.

### 2.2 Sim-Datei zu groß / Hot Paths (M, ★★)
`sim.gd` hat über 1800 Zeilen (Welt, Routing, Träger, Gebäude, Tiere). Aufteilung in `world.gd`, `net.gd` (Flaggen/Segmente/Routing), `economy.gd` hilft jeder späteren Erweiterung.
Performance:
- `dist_map` ist ein Dijkstra mit linearem Min-Suchen (`open`-Array) pro Quelle; `_hpush/_hpop` (Heap) existiert schon für A* → dort wiederverwenden.
- `scan()` läuft über ein Quadrat pro Aufruf und wird oft aufgerufen (`has_resource`, `pick_target`); bei vielen Gebäuden Cache/Chunk-Index nutzen.
- `dispatch()` iteriert alle Flaggen/Gebäude/Lager; bei großen Städten nur bei "Änderung" (net_ver, Bedarf) arbeiten.

### 2.3 Spielziel und Progression sind dünn (M, ★★)
Ziel: 5 Wahrzeichen. Danach nur Fenster `win_panel`.
- Zwischenziele/Quests ("Taverne bauen", "20 Pixler", "erstes Stadthaus"), Statistik (Waren/Minute, Produktionsübersicht).
- Endlos-Modus nach Sieg, Szenarien/Seeds mit Zielen.
- Warenübersicht-Panel (Lagerbestand je Ware, Engpässe) – `total_stock` existiert.

### 2.4 Welt immer gleich (S, ★★)
Status: ⬜ offen (jetzt Teil von 1.17). Die Weltgenerierung läuft seit dem Raster-Umbau in Kachel-Einheiten, Biom-Positionen stehen weiter fest in `gen` (`A`).
Ursprünglich: `gen` platziert Biome und Seen an **festen Koordinaten** (Dictionary `A`, Features `Vector2(80,100)` …). Seed variiert nur Rauschen. Zufällige Biom-Positionen (mit Mindestabstand, Reihenfolge nach Distanz zum Start) bringt Wiederspielwert und macht Erkundung (1.11) sinnvoll.

### 2.5 Pixler haben keine Eigenschaften (M, ★)
Pixler sind nur eine Zahl (`pop`). Namen, Rollen-Fähigkeiten, Zufriedenheit/Laune (Versorgung → mehr Geburten) würden dem Spiel Seele geben und passen zu "Cozy".

### 2.6 Wohnhäuser: Versorgungsketten sichtbarer machen (S, ★★)
`_upd_house` zeigt nur Text ("Braucht Wasser"). Besser: Icons über dem Haus, Wohnstufe als Pfeil im Panel, Hinweis welches Gericht fehlt, Haushaltsbilanz (+/- pro Minute).

### 2.7 Tiere/Natur als Spielelement (S–M, ★)
Wild (`deer`, `rabbit`) respawnt nicht aktiv (`spawn_animal` nur in `gen`). Jäger könnte die Population leerfangen. Einfaches Nachwachsen/Fortpflanzung. Ranch-Tiere (`sheep`/`pig`) sind Deko; Wolle/Eier wären naheliegende Zusatzprodukte (→ 1.10).

### 2.8 Tag/Nacht, Wetter, Jahreszeiten (M, ★)
Schon Ambient-Mix (`wind`, `harsh`) vorhanden. Tag/Nacht mit beleuchteten Fenstern, Jahreszeiten (Schnee, Ernte), Regen füllt Brunnen/Felder (verknüpft mit Wasser-Redesign 1.6).

### 2.9 Barrierefreiheit & Bedienung (S, ★)
- Tastaturbelegung im Spiel erklären (Hilfe-Overlay, "?").
- Farbige Warenicons mit Form-Unterscheidung (nicht nur Farbe).
- Pausen/Geschwindigkeit (nur Leertaste Pause): 1×/2×/4×.
- Undo für Abriss; Bestätigung bei Abriss von Gebäuden mit Inhalt.

### 2.10 Test/Debug (S, ★)
`--selftest` und `--demo` sind vorhanden – erweitern um Regressions-Szenarien: Pixler-Zähler, Routing-Stau, Upgrade-Flows. Besonders wichtig vor dem Umbau von Straßen/Flaggen (1.7/1.8).

---

## 3. Empfohlene Reihenfolge

1. ✅ **Quick Wins:** Pixler-Start, Träger-Kapazität, Felsen. Offen: UI-Zähler-Aufschlüsselung (1.4).
2. ✅/🟡 **Bauen fühlt sich besser an:** Flaggen, Straßen, weiche Objekte umgesetzt; Rest aus 1.7/1.9 offen.
3. **Nächste Quick Wins (S):** Lagerhaus nicht abreißbar (1.23), Fortschrittsbalken im Info-Panel (1.24), Dauer-Faktor und längere Taverne (1.22).
4. **Spielgefühl (M):** Hausträger statt Wareneffekt (1.19), Pixler-Varianz und Uniformen (1.14), unterscheidbare Gebäude (1.15).
5. **Wirtschaft vertiefen (M–L):** Wasser-Redesign (1.6), mehrstufiges Baumaterial (1.20), Upgrades für alle (1.3) und für Straßen (1.26), Biome nutzbar machen (1.10).
6. **Optik/Ton (M–L):** Stilentscheidung Siedler 2 (1.16), einheitliches UI (1.25), Sounds (1.1), Musikvarianz (1.18).
7. **Welt erweitern (L):** Zufallsstart/Zufallsbiome (2.4, 1.17), Fog of War (1.11), Gebietsgrenzen (1.12), Erkundung mit Ballon/Boot/Kutsche (1.13, 1.21), Biom-Pixler (1.17).
8. **Querschnitt:** Speichern/Laden (2.1) früh einplanen – je später, desto aufwendiger, vor allem vor Biom-Pixlern und Nebel.

## 4. Abhängigkeiten
- Flaggen (1.7) ↔ Straßen-Rendering (1.8) ↔ Planierer (1.9): zusammen entwerfen, sonst doppelte Arbeit am Bauplatz-Code (`can_place`, `free_ground`, `find_path`).
- Wasser (1.6) ↔ Biome/Obsidian (1.10) ↔ Wetter (2.8).
- Fog (1.11) ↔ Gebiet (1.12) ↔ Ballon/Boote (1.13) ↔ Zufallsbiome (2.4).
- Upgrades (1.3) ↔ Biomwaren (1.10): Biomwaren als Upgrade-Material gibt den Biomen sofort Sinn.
- Biom-Pixler (1.17) ↔ Pixler-Varianz (1.14) ↔ Materialherkunft und Baumaterial-Stufen (1.17, 1.20): gemeinsames Datenmodell für Pixler- und Warenvarianten (`biome`-Tag) entwerfen.
- Stil (1.16) ↔ UI (1.25) ↔ unterscheidbare Gebäude (1.15): zuerst Zielstil festlegen.
- Hausträger (1.19) ↔ Dauer erhöhen (1.22) ↔ Fortschrittsbalken (1.24): zusammen wirken sie als Rhythmus der Wirtschaft.
- Ballon (vorhanden) ↔ Nebel (1.11) ↔ Gebietsgrenzen (1.12): Ballon als erster Erkunder.
- Straßen-Upgrades (1.26) ↔ Kutschen (1.21) ↔ Mehrstufiges Material (1.20) ↔ Fortschrittsbalken (1.24): Pflasterstraße als Voraussetzung für Kutschen, Baustoffe aus Stufe 2/3.
