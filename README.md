# Pixlers – Das Tal der Waren

Cozy Pixel-Art-Aufbauspiel mit Warenkreisläufen, inspiriert von *Die Siedler 1*.
Godot 4.x (GDScript), alle Grafiken werden zur Laufzeit prozedural erzeugt – keine externen Assets.

**Starten:** Ordner in Godot 4.7 öffnen (`project.godot`) und F5 drücken.

## Spielprinzip
Dieser Zweig (`feature/no-flags-no-carriers`) ist die **flaggen- und wegträgerlose Testvariante**.
- Häuser stehen fest auf einem Raster. Es gibt keine Flaggen und keine Träger auf Wegstücken mehr.
- Waren werden in den Gebäuden gesammelt wie bisher (Eingang). Produzenten legen fertige Ware in ihren **Ausgang** (höchstens 8) und warten auf einen Träger.
- **Träger** sitzen im **Langhaus** (4 am Start, Umkreis 20 Kacheln) und in **Trägerlagern** (2x2, Umkreis 12 Kacheln, doppelt so viel wie bei den meisten Betrieben). Innerhalb ihres Umkreises holen sie Waren aus Betrieben und Lagern und bringen sie dorthin, wo sie gebraucht werden (Baustellen zuerst), sonst ins nächste Lager. Beide Gebäude müssen im Umkreis liegen: Für weitere Strecken baut man ein Lagerhaus als Zwischenstation und ein zweites Trägerlager.
- **Trägerlager** gibt es in drei zufälligen Designs (Steinkreis, Baumstämme ums Lagerfeuer, Pilze), die Träger sitzen darauf. Im Info-Panel stellt man 0 bis 10 Träger und die Schubkarren ein (höchstens so viele wie Träger, mit Karre trägt ein Träger 3 Waren statt 1).
- Pixler laufen **frei** zwischen den Gebäuden, ohne Weg nur mit 60 % Tempo.
- Der **Wegebauer** schaltet Wege (R) und **Trägerstationen** (T) frei. Neue Wege sind zuerst nur geplant (gestrichelt): Der Pixler eines Wegebauers schaufelt sie Zelle für Zelle (`Sim.DIG_T`), pro Wegebauer ein Weg zur Zeit, für mehr Tempo beim Wegebau baut man mehrere. Wege sind schneller als Wiese (`Sim.ROAD_SPEED`, später pflasterbar für mehr Tempo). Die Trägerstation ist ein Fliegenpilz in der Mitte eines Weges, auf dem ein Pixler sitzt: Auf diesem Weg gehen alle 1,5-mal so schnell (`Sim.STATION_SPEED`).
- **Abriss:** Alles außer dem Langhaus lässt sich abreißen, Baustellen immer. Der Inhalt und die vollen Baukosten (roh: Bretter → Holz, Steinblöcke → Stein) bleiben als **Abrisshaufen** an der Stelle liegen, Träger im Umkreis sammeln sie ein.
- Neue Häuser sind Baustellen und bekommen ihr Material von den Trägern geliefert; die Bauarbeiter laufen frei vom Lager hin.
- Jedes Produktionshaus, jeder Träger und jede besetzte Station braucht einen **Pixler**. Neue Pixler ziehen ein, wenn die **Taverne** Mahlzeiten (Brot + Fisch/Fleisch + Wasser) serviert.
- Ziel: Baue alle **5 Wahrzeichen**. Sie brauchen jeweils eine Spezialware aus einem Biom.

## Neu in dieser Version
*Hinweis: Die folgenden Abschnitte stammen aus der Hauptvariante. Aussagen zu Flaggen, Wegträgern, Schubkarren an Flaggen und Lagerarbeitern gelten in diesem Zweig nicht mehr, siehe Spielprinzip oben.*

- **Langhaus** mit einer Tür-Flagge unten in der Mitte. Seine drei Lagerarbeiter legen Waren gleichzeitig dort ab.
- **Tutorial-Popups sind aus** (`var tut := 2` in `main.gd`, mit 0 läuft das Tutorial wieder).
- **Produktionshäuser** liefern fertige Waren selbst aus: Der Pixler trägt sie aus dem Haus zur Tür-Flagge und legt sie dort ab.
- **Träger kommen aus dem Langhaus** und laufen zu neuen Wegen. Ein Träger trägt **1 Ware**.
- **Schubkarren:** Man startet mit 10. Liegen an einer Flagge mehr als 4 Waren (Limit 20), holt sich ein Träger eine Karre und trägt **3 Waren**. Der **Schubkarrenbauer** baut neue. Ist eine Flagge voll, kann ein Träger trotzdem ablegen, wenn er dafür gleich Ware mitnimmt.
- **Größere Welt** (192x192) mit weiter auseinanderliegenden Biomen.
- **8 Richtungen:** Wege dürfen auch diagonal verlaufen (wie bei Siedler 2).
- **Bauarbeiter:** Baustellen werden nur gebaut, wenn ein Bauarbeiter vom Lager hinläuft (am Anfang 3, jedes Lagerhaus +2). Baustelle anklicken: **anhalten** oder **Priorität** setzen. **Abriss gibt Waren zurück** (Inhalt komplett, fertige Gebäude die Hälfte der Baukosten).
- **Wohnraum:** Start mit 30 Pixlern, das Langhaus bietet 50 Plätze. **Wohnhäuser** (+4) schaffen Platz und lassen sich zu Haus (+8) und Stadthaus (+14) **ausbauen**, wenn die Bewohner mehrfach mit **Gerichten und Wasser** versorgt wurden. Die **Taverne** lockt neue Pixler an, solange Platz ist.
- **Nahrung:** Viehzucht liefert Schweine, die **Metzgerei** macht Fleisch (der Jäger holt Fleisch weiter vom Wild). **Kräuterkundler**, **Pilzsammler** und **Gärtner** (Gemüse) beliefern die **Küche**, die Gerichte kocht.
- **Pixler** haben große Zipfelmützen und große Nasen.
- **Tutorial** mit Popups: Erst Holz und Stein, dann Essen und Taverne. Danach schalten sich die restlichen Blaupausen frei.
- Wege setzen nur noch selten Zwischenflaggen (eigene mit **F**). **Z** nimmt den letzten Weg zurück.
- **Sound:** Effekte (Axt, Hammer, Steinbruch, Taverne, Küche ...) sind echte CC0-Aufnahmen von Kenney (Ordner `audio/`, Lizenz dort). Gebäudegeräusche hört man nur nah dran und hineingezoomt, sonst sehr leise. Musik (Spieluhr) und Ambiente (Vögel, Grillen, Wasser, Wind) sind weiter generiert. **M** schaltet den Ton aus/ein.

## Warenkreisläufe
| Kette | |
|---|---|
| Holz | Holzfäller → Sägewerk → Bretter (Förster pflanzt nach) |
| Stein | Steinbruch → Steinmetz → Steinblöcke |
| Wasser | Brunnen |
| Fisch | Fischer am Ufer |
| Brot | Weizenfarm (+Wasser) → Mühle → Bäckerei (+Wasser) |
| Fleisch | Jäger, oder Viehzucht (Weizen + Wasser → Schweine) → Metzgerei |
| Gerichte | Küche: 2 verschiedene Zutaten aus Fleisch, Fisch, Pilzen, Kräutern, Gemüse + Wasser |
| Pilze / Kräuter / Gemüse | Pilzsammler / Kräuterkundler / Gärtner (+Wasser) |
| Feenwald | Feenhain-Hütte → **Feenstaub** |
| Vulkan | Obsidianbrecher (+Wasser) → **Obsidian** |
| Sumpf | Glühpilz-Sammler → **Glühpilze** |
| Wüste | Sandgrube → Sand; Glashütte (Sand + Holz) → **Glas** |
| Schneeland | Eishauer am gefrorenen See → **Eis** |

## Steuerung
- Linksklick: bauen / auswählen. Mausrad oder +/-: Zoom.
- **R** Weg (Start anklicken, dann Ziel; Kettenbau, Rechtsklick/Esc beendet; braucht den Wegebauer)
- **T** Trägerstation: Klick auf einen Weg, der Pilz kommt in dessen Mitte (braucht den Wegebauer)
- **Z** letzten Weg zurücknehmen, **M** Ton an/aus
- **X** Abriss, **Esc** Auswahl, **Leertaste** Pause, **F5** neue Welt
- WASD/Pfeile oder Mittelmaustaste/Rechtsklick ziehen: Kamera. Minimap anklicken zum Springen.

## Tipps
- Liegt viel Ware im Ausgang, setze mehr Träger ins Trägerlager, gib ihnen Schubkarren, baue ein zweites Trägerlager oder ein **Lagerhaus** näher an der Produktion.
- Ein rotes/oranges Ausrufezeichen über einem Haus zeigt: wartet auf Waren, Ausgang voll oder kein Trägerlager in Reichweite. Wählt man ein Trägerlager aus, erscheint sein Umkreis.

## Feineres Raster, höhere Auflösung
- Die Welt liegt auf einem **doppelt so feinen Raster** (384x384 Zellen). Gebäude sind 4x4 statt 2x2 Zellen groß, Wege, Flaggen und Pixler leben auf den kleinen Zellen: mehr Freiheit beim Straßenbau.
- Grafik in doppelter Auflösung (Gebäude, Bäume, Felsen), neue Pixler mit Berufswerkzeugen und 4-Phasen-Gehzyklus. Standard-Zoom ist weiter draußen, dazu eine zusätzliche Stufe (0.5, 1, 1.5, 2, 3, 4).
- **Wege** werden als weiche Bänder gezeichnet (Diagonalen und Abzweige verschmelzen an Flaggen), die Wegsuche bevorzugt gerade Linien.
- **Flaggen** sind kleiner. Die Tür-Flagge sucht sich einen freien Platz vor dem Gebäude und dockt an vorhandene Wege an. Gebäude hängen beim Platzieren zentriert am Mauszeiger.
- **Kräuter, Pilze, Leuchtblumen und Glühpilze blockieren nicht mehr**: Beim Bauen von Gebäuden, Wegen und Feldern werden sie weggeräumt.
- Weniger Felsen, dafür deutlich mehr Stein pro Fels.
- Start: 30 Pixler (Platz für 50), 10 Schubkarren. Ein Träger trägt 1 Ware, mit Karre 3.
- **Längere Arbeitszeiten:** alle Tätigkeiten dauern 1,6-mal so lange (`Data.WORK_MULT`), die Taverne zusätzlich 2,5-mal (`Data.TAVERN_MULT`).
- **Lagerhaus und Langhaus lassen sich nicht abreißen.** Gebäude mit Inhalt oder Ausbaustufe fragen vorher nach (nochmal klicken).
- **Info-Panel:** Fortschrittsbalken für die laufende Tätigkeit (auch als Balken über dem ausgewählten Gebäude). Die Kopfleiste zeigt Häuser, Träger, Bau und freie Pixler getrennt, die aktive Geschwindigkeit ist hervorgehoben.
- **Lagerarbeiter:** Waren erscheinen nicht mehr aus dem Nichts an der Flagge. Fest angestellte Pixler (Langhaus 3, jedes Lagerhaus 1) tragen sie nach und nach aus dem Lager vor die Tür; die Auslieferung steht im Info-Panel. Sie zählen als beschäftigte Pixler, ein neues Lagerhaus braucht daher einen freien.
- **Lauftempo** aller Pixler ist um 25 % gesenkt (`Sim.WALK_MULT`).
- **Tag und Nacht:** Ein Tag dauert 10 Minuten, davon 6 Minuten Tag und 4 Minuten Nacht (Dämmerung je rund 50 Sekunden inklusive). Die Uhr zeigt 06:00-20:00 für den Tag und 20:00-06:00 für die Nacht. Werte: `DAY_LEN`/`NIGHT_LEN` in `main.gd`.
- **Musik:** fünf Stücke laufen abwechselnd: Spieluhr, Kora, Banjo (nur am Tag), ein sehr ruhiges Klarinetten-Nachtstück (nur nachts, dort bevorzugt) und Handpan in d-Moll. Ein unpassendes Stück wird bei Wechsel der Tageszeit sanft ausgeblendet. Jedes Stück läuft als nahtlose Schleife 1 bis 3 Minuten, wird 8 Sekunden ein- und ausgeblendet, danach 10 Sekunden Pause. Die Reihenfolge wird durchgewechselt (gemischter Stapel), nie dasselbe Stück zweimal hintereinander. Regler in `audio.gd`: `MUSIC_MIN/MAX/FADE/GAP`. Ablauftest: `tools/musictest.gd`.
- **Waren-Icons** sind deutlicher gezeichnet, Wasser ist ein Eimer. Im Info-Panel stehen Waren als Icon mit der Anzahl dahinter. Der Brunnenpixler kurbelt sichtbar das Wasser hoch.
- Balance-Regler per Kommandozeile: `--carry=N --barrow=N`, außerdem `--select=<Gebäudetyp>` für Screenshots.
- Entwicklerwerkzeug: `tools/sheet.gd` rendert alle Sprites in ein Bild (`godot --headless --path . --script tools/sheet.gd -- out.png 2 all`).

## Debug-Optionen
`godot --path . -- --seed=7 --demo --ff=300 --zoom=3 --cam=1000,1000 --shot=out.png` (Demo-Aufbau, Zeitraffer, Screenshot).
`--selftest` prüft die Bedienlogik.
