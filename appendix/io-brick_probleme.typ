#import "@local/stddoc:1.0.0": *

#show:stddoc.with(
    title: "IO-Brick Probleme",
    show-title-page: false
)

*Messmethode* <messmethode>

Alle Messungen wurden mit denselben zwei IO-Bricks (Label 5 und Label 16) auf derselben Grundplatte durchgeführt,
auf der die IOs beider Bricks 1:1 verbunden sind.

Die Bricks werden in diesem Dokument über ihr Label angesprochen, weil die Grundplatte die CANopen-Node-ID je nach
Steckplatz vergibt.

#figure(
    caption: "Zuordnung der IO-Bricks",
    table(
        columns: (auto, 1fr),
        align: left + top,
        table.header([*Label*], [*Seriennummer (`0x1018` Subindex 4)*]),
        [Label 5], [`0x68506461`],
        [Label 16], [`0x684F647F`],
    )
)

#pagebreak()

= Messen der Spannung am Ausgang deaktiviert Ausgangstreiber <issue-1>

== Zusammenfassung

Wird die analoge Spannung (`Voltage Read`, `0x6403`) eines IOs gelesen, der als *Ausgang* konfiguriert ist, schaltet das den Ausgangstreiber dieses IOs ab. Die Leitung fällt dann auf 0V ab, obwohl der Ausgang weiterhin auf HIGH gesetzt ist. Einen neuen Ausgangspegel zu schreiben, stellt ihn nicht wieder her. Nur ein Richtungswechsel EINGANG → AUSGANG (`Io Direction 1 Bit`) aktiviert den Treiber wieder.

Ausserdem ist der gelesene Wert falsch (gemessen 1.92-2.87 V statt 3.3 V). Die Spannung eines Ausgangs lässt
sich also auf dem Brick, der ihn treibt, nicht zurücklesen.


== Beobachtetes Verhalten

Messungen von A0 über die Zeit. Label 16 wird nur gelesen (treibt die Leitung nicht). Der Schritt
"Rücklesen auf Label 5" ist ein *einzelner* SDO-Lesezugriff auf `Voltage Read` A0 auf Label 5.

#figure(
    caption: "Spannung an A0, gemessen von Label 16",
    table(
        columns: (2fr, 1.8fr),
        align: left + top,
        table.header([*Schritt (Label 5, A0)*], [*Label 16 misst A0 nach \ 10ms / 50ms / 100ms / 300ms / 1s / 2s*]),
        [Richtung EINGANG → AUSGANG, Ausgang HIGH], [3.30 / 3.30 / 3.30 / 3.30 / 3.30 / 3.30 V],
        [Ausgang LOW], [0.00 / 0.00 / 0.00 / 0.00 / 0.00 / 0.00 V],
        [Ausgang wieder HIGH], [3.30 / 3.30 / 3.30 / 3.30 / 3.30 / 3.30 V],
        [*Einmal `Voltage Read` A0 auf Label 5 lesen* \ liefert 2.87V], [],
        [(keine weiteren Schreibzugriffe)], [*2.44 / 2.03 / 1.67 / 1.17 / 0.44 / 0.11 V*],
        [Ausgang LOW → HIGH], [0.09 / 0.08 / 0.06 / 0.06 / 0.05 / 0.05 V \ (Ausgang bleibt tot)],
        [Richtung AUSGANG → EINGANG → AUSGANG], [3.30 / 3.30 / 3.30 / 3.30 / 3.30 / 3.30 V (wiederhergestellt)],
    )
)

Weitere Beobachtungen:

- Solange `Voltage Read` des treibenden Bricks nicht gelesen wird, bleibt der Ausgang beliebig lange auf
  voller Spannung (getestet: 2s). Der Abfall beginnt mit dem ersten Lesezugriff, nicht mit dem Pegelwechsel.
- Während der Ausgang "tot" ist, zeigt das Objektverzeichnis weiterhin den gewünschten Zustand an
  (`Io Direction 1 Bit` = 1, `Write Output 1 Bit` = 1, `Supply Voltage Enable` = 1, Sollwert 3.3 V),
  und `Read Input 1 Bit` liefert 0.
- Den Bankspannungs-Sollwert neu zu schreiben oder zu ändern (3.3 → 1.0 → 3.3 → 2.0 V), stellt den
  Ausgang nicht wieder her.
- Den Ausgangspegel umzuschalten, stellt den Ausgang nicht wieder her.
- Die Leserate spielt keine Rolle (getestet: 0ms bis 1s zwischen den Lesezugriffen).

#pagebreak()

== Verifikation mit Multimeter

Label 5 treibt A0, das Multimeter misst A0 gegen GND. Im Schritt "nach einmaligem Rücklesen" wurde 3s gewartet
und zuerst nur das Multimeter abgelesen, ohne weiteren Zugriff auf einen der Bricks.

#figure(
    caption: "Multimetermessung an A0",
    table(
        columns: (1.6fr, auto, auto, auto),
        align: left + top,
        table.header([*Schritt (Label 5, A0)*], [*Erwartet*], [*Label 16 `Voltage Read`*], [*DMM*]),
        [Ausgang HIGH], [3.3V], [3.30V], [3.278V],
        [Ausgang LOW], [0V], [0.00V], [0V],
        [Ausgang wieder HIGH], [3.3V], [3.30V], [3.277V],
        [3 s nach einmaligem `Voltage Read` A0 auf Label 5 (liefert *1.92V*)], [3.3V], [-], [*0.076V*],
        [gleicher Zustand, danach von Label 16 gelesen], [3.3V], [0.18V], [*0.075V*],
        [Ausgang LOW → HIGH], [3.3V], [0.00V], [*0.072V*],
        [Richtung AUSGANG → EINGANG → AUSGANG], [3.3V], [3.30V], [3.278V],
    )
)

Das Multimeter bestätigt, dass die Leitung tatsächlich auf \~0V abfällt und somit der Ausgangstreiber abgeschaltet ist.

== Minimale Reproduktion

```python
import time, canopen

net = canopen.Network(); net.connect(interface="socketcan", channel="can0")
drv = net.add_node(10, "res/io-brick.eds").sdo   # Label 5
rem = net.add_node(11, "res/io-brick.eds").sdo   # Label 16

def remote(tag):
    time.sleep(0.1)
    print(f"{tag:35} remote A0 = {rem['Voltage Read']['A0'].raw:.2f} V")

drv['Io Direction 1 Bit']['A0'].raw = 0
drv['Io Direction 1 Bit']['A0'].raw = 1
drv['Write Output 1 Bit']['A0'].raw = 1
remote("output HIGH")                                   # 3.30V

print("driver readback:", drv['Voltage Read']['A0'].raw)  # ~2.87V statt 3.30V
remote("after one driver readback")                     # fällt ab, ~0V nach ~2 s
time.sleep(2)
remote("2 s later")

drv['Write Output 1 Bit']['A0'].raw = 0
drv['Write Output 1 Bit']['A0'].raw = 1
remote("after level toggle")                            # weiterhin ~0V

drv['Io Direction 1 Bit']['A0'].raw = 0
drv['Io Direction 1 Bit']['A0'].raw = 1
remote("after direction toggle")                        # wieder 3.30V

drv['Io Direction 1 Bit']['A0'].raw = 0
drv['Write Output 1 Bit']['A0'].raw = 0
net.disconnect()
```

== Fragen

+ Ist das Lesen von `Voltage Read` an einem Ausgang überhaupt vorgesehen? \    
    Falls nicht: Sollte der SDO-Zugriff dann nicht abgelehnt werden (Abort-Code), statt den Ausgang still abzuschalten?
+ Kann die Firmware die Ausgangsfunktion nach der ADC-Messung wiederherstellen?
+ Gibt es einen unterstützten Weg, die tatsächliche Spannung eines getriebenen Ausgangs zurückzulesen?

#pagebreak()

= Festgestellter Hardwaredefekt bei IO-Brick Label 16 <issue-2>

== Zusammenfassung

Auf dem IO-Brick Label 16 hat der Pin B0 einen niederohmigen Pfad von *\~100Ω gegen GND*.
Es handelt sich wahrscheinlich um einen Hardwaredefekt dieses einen Bricks.

Folgen des Defekts:
- Die Leitung B0 erreicht HIGH nicht mehr: 0.30 / 1.16 / 2.03V statt 1.0 / 2.0 / 3.3V, egal welcher Brick treibt.
- `Voltage Read` B0 auf Label 16 liefert immer 0.00V. Label 5 misst den (zu tiefen) Pegel korrekt.
- Der momentan implementierte analoge Loopback-Test erkennt den Defekt.

Alle anderen IOs (A0-A15, B1-B15) erreichen bei Bankspannungen von 1.0, 2.0 und 3.3V die korrekte Spannung (±0.1V).

== Beobachtetes Verhalten

Zuerst fiel auf, dass `Voltage Read` von B0 auf dem empfangenden Brick nicht stimmt. Der treibende Brick liest
dabei seinen eigenen Ausgang nie (siehe @issue-1).

#figure(
    caption: "Spannung an B0, gemessen mit Voltage Read und Multimeter (beide Bricks eingesteckt)",
    table(
        columns: (auto, auto, auto, auto, auto),
        align: left + top,
        table.header([*Treiber → Empfänger*], [*Bankspannung*], [*Erwartet*], [*Empfänger `Voltage Read`*], [*DMM*]),
        [Label 5 → Label 16], [1.0V], [1.0V], [0.00V], [*0.317V*],
        [], [2.0V], [2.0V], [0.00V], [*1.161V*],
        [], [3.3V], [3.3V], [0.00V], [*2.026V*],
        [], [LOW], [0V], [0.00V], [0V],
        [Label 16 → Label 5], [1.0V], [1.0V], [0.31V], [*0.295V*],
        [], [2.0V], [2.0V], [1.19V], [*1.155V*],
        [], [3.3V], [3.3V], [2.08V], [*2.024V*],
        [], [LOW], [0V], [0.00V], [0V],
    )
)

Der HIGH-Pegel ist in beide Richtungen gleich tief. Zum Vergleich: A0 erreicht in @issue-1 mit 3.278V die volle
Bankspannung. Label 5 misst B0 korrekt (Abweichung ≤ 0.06V), Label 16 liest immer 0.00V.

#pagebreak()

== Eingrenzung mit Multimeter

Um Brick, Grundplatte und Firmware als Ursache zu unterscheiden, wurden die Bricks einzeln eingesteckt und die
Steckplätze getauscht. Die Bricks wurden dabei über ihre Seriennummer (`0x1018` Subindex 4) identifiziert:
Label 5 = `0x68506461`, Label 16 = `0x684F647F`. Das Multimeter misst immer B0 gegen GND auf der Grundplatte.
Widerstand und Diodentest wurden ohne Speisung gemessen.

#figure(
    caption: "Eingrenzung des Defekts an B0",
    table(
        columns: (1.3fr, 1.2fr, auto, 1fr),
        align: left + top,
        table.header(
            [*Aufbau*],
            [*B0 HIGH bei 1.0 / 2.0 / 3.3V (DMM)*],
            [*B0 → GND ohne Speisung*],
            [*Diodentest \ (rot auf B0 / rot auf GND)*],
        ),
        [Beide Bricks, ursprüngliche Steckplätze], [0.30 / 1.16 / 2.03V], [-], [-],
        [*Nur Label 5*], [*1.0 / 2.0 / 3.2V* (korrekt)], [5-7MΩ], [1.8V / 0.53V (normal)],
        [*Nur Label 16*], [*0.29 / 1.15 / 2.02V* (zu tief)], [*101Ω* (beide Polaritäten)], [*0.055V / 0.055V*],
        [Keine Bricks (nur Grundplatte)], [-], [offen], [offen],
        [Beide Bricks, Steckplätze getauscht], [0.30 / 1.16 / 2.02V], [-], [-],
    )
)

Folgerungen: *Hardwaredefekt bei IO-Brick Label 16 B0*

== Fragen
- Wäre es möglich einen alternativen IO-Brick zu erhalten, welcher nicht defekt ist?


/*
== Übersprechen auf die A-Bank

Treibt ein Brick B0 auf HIGH (3.3V), zeigen die Kanäle A0-A14 auf *beiden* Bricks praktisch dieselben Werte
von 0.3-1.6V. Normal floatende Eingänge liegen bei \~0.2-0.3V. A15 zeigt 0.00V. Wird stattdessen A15 oder B1
getrieben, erscheint die Spannung nur auf dem richtigen Kanal (3.30V).

Da beide Bricks dieselben Werte lesen und die A-Leitungen über die Grundplatte verbunden sind, liegt die Spannung
tatsächlich auf den A-Leitungen und ist kein Messfehler eines einzelnen ADCs. Mit getauschten Steckplätzen sind
die Werte tiefer (0.7-1.1V statt 1.0-1.6V). Ob das Übersprechen mit dem Defekt auf Label 16 zusammenhängt oder nur
eine Kopplung auf floatende Eingänge ist, wurde nicht geklärt. Dazu müsste B0 mit nur Label 5 getrieben und die
A-Kanäle von Label 5 gelesen werden.
*/

#pagebreak()

= `Pull Resistor 1 Bit` setzt den Pull-Widerstand am falschen Pin <issue-3>

Unabhängig von den obigen Problemen. 
- Gleicher Aufbau wie oben (Label 5 und Label 16, Bankspannung 3.3V, alle IOs als Eingang).
- Werte von `Pull Resistor 1 Bit` (`0x2200`): 0 = keiner, 1 = Pull-Down, 2 = Pull-Up \ 
    (Wert 3 wird mit Abort-Code `0x06060000` abgelehnt).
- Das Zurücklesen des Objekts liefert immer den geschriebenen Wert, der Fehler ist also nur am Pin sichtbar.

== Vertauschte Bänke

Messmethode (nur digital, ohne ADC): Auf einem Brick werden alle Subindizes auf Pull-Down gesetzt, dann
wird jeweils *ein* Subindex auf Pull-Up gesetzt und mit `Read Input 8 Bit` des anderen Bricks geprüft,
welcher Pin HIGH wird. Das Ergebnis ist auf beiden Bricks identisch:

#figure(
    caption: "Zuordnung Subindex → Pin von Pull Resistor 1 Bit",
    table(
        columns: (auto, 1fr),
        align: left + top,
        table.header([*Geschriebener Subindex*], [*Pin, der den Pull-Widerstand erhält*]),
        [A0], [*keiner*],
        [A1 - A14], [B1 - B14],
        [A15], [A15],
        [B0 - B15], [A0 - A15],
    )
)

Folgen:

- Die Bänke A und B sind vertauscht (Ausnahmen: A0, A15).
- Die Pins *B0 und B15 haben über keinen Subindex einen Pull-Widerstand*. Sie bleiben floatend
  (\~0.2-0.5 V), egal welcher Subindex geschrieben wird.
- A15 wird von zwei Subindizes (A15 und B15) gesteuert.
- Werden alle 32 Subindizes auf denselben Wert gesetzt, fällt der Fehler nicht auf (ausser bei B0 und B15).

Mit korrekter Zuordnung funktionieren die Widerstände: Pull-Up gegen Pull-Down des anderen Bricks ergibt
1.58-1.62 V (erwartet \~1.65V bei 2 x 10kΩ), ein einzelner Pull-Up 3.17-3.24 V, ein einzelner Pull-Down 0.00V
(gemessen auf A0-A14 und B1-B14).

== `Voltage Read` schaltet einen Pull-Widerstand ab

Wird `Voltage Read` eines IOs gelesen, wird der Pull-Widerstand des Pins abgeschaltet, auf den der
*gleichnamige* Subindex von `Pull Resistor 1 Bit` gemäss Tabelle oben zeigt. Der gelesene Spannungswert
selbst ist korrekt (sofern nicht der eigene Pull betroffen ist).

#figure(
    caption: "Einfluss von Voltage Read auf die Pull-Widerstände",
    table(
        columns: (1.4fr, auto, 1fr),
        align: left + top,
        table.header(
            [*Schritt (nur Label 5 hat Pull-Up auf allen Subindizes)*],
            [*`Voltage Read`*],
            [*Digitale Pegel danach (Label 5 und 16)*],
        ),
        [Pull-Up auf allen Subindizes], [-], [alle HIGH ausser B0, B15],
        [`Voltage Read` A3 auf Label 5], [3.19V], [zusätzlich *B3* LOW],
        [`Voltage Read` A5 auf Label 16 (ohne Pull)], [3.19V], [unverändert],
        [`Voltage Read` B4 auf Label 5], [3.23V], [zusätzlich *A4* LOW],
        [Pull-Up erneut auf allen Subindizes schreiben], [-], [wiederhergestellt],
    )
)

Bei A15 zeigt der Subindex auf den Pin selbst: `Voltage Read` A15 schaltet den eigenen Pull-Widerstand ab
und liefert 0.00 V, obwohl der Pin vorher HIGH war. Ein Pull-Widerstand an A15 lässt sich deshalb nicht mit
dem ADC des eigenen Bricks messen.

Nur der Brick, auf dem `Voltage Read` gelesen wird, ist betroffen. Das Objektverzeichnis zeigt den
abgeschalteten Pull-Widerstand weiterhin als gesetzt an (`Pull Resistor 1 Bit` = 2 für A3, B3, B4, A4 und A15
nach den Lesezugriffen). Der Fehler ist also auch hier nur am Pin sichtbar.

== Verifikation mit Multimeter

Nur IO-Brick Label 5 setzt Pull-Widerstände, IO-Brick Label 16 hat keine und liest die Leitung nur. Das Multimeter misst den
jeweiligen Pin gegen GND.

#figure(
    caption: "Multimetermessung der Pull-Widerstand-Zuordnung (übrige Subindizes auf Pull-Down)",
    table(
        columns: (auto, auto, 1fr, auto, auto),
        align: left + top,
        table.header([*Subindex Pull-Up*], [*Pin*], [*Erwartet (mit Fehler)*], [*IO-Brick Label 16 `Voltage Read`*], [*DMM*]),
        [A3], [A3], [0V (korrekt wäre 3.2V)], [0.00V], [0V],
        [], [B3], [3.2V (korrekt wäre 0V)], [3.18V], [3.273V],
        [B3], [B3], [0V (korrekt wäre 3.2V)], [0.00V], [0V],
        [], [A3], [3.2V (korrekt wäre 0V)], [3.20V], [3.278V],
        [A0], [A0], [0V (korrekt wäre 3.2V)], [0.00V], [0V],
        [], [B0], [kein Pull], [0.00V#super[1]], [0V],
        [B0], [B0], [kein Pull (korrekt wäre 3.2V)], [0.00V#super[1]], [0V],
        [], [A0], [3.2V (korrekt wäre 0V)], [3.19V], [3.278V],
        [A15], [A15], [3.2V], [3.20V], [3.278V],
        [B15], [B15], [kein Pull (korrekt wäre 3.2V)], [0.30V], [0.047V],
        [], [A15], [3.2V (korrekt wäre 0V)], [3.20V], [3.277V],
    )
)

#super[1] `Voltage Read` B0 auf Label 16 liefert wegen @issue-2 immer 0 V.

#figure(
    caption: "Multimetermessung: Voltage Read schaltet einen Pull-Widerstand ab (Pull-Up auf allen Subindizes)",
    table(
        columns: (1.6fr, auto, auto, auto, auto),
        align: left + top,
        table.header([*Schritt (Label 5)*], [*Pin*], [*Erwartet (mit Fehler)*], [*Label 16 `Voltage Read`*], [*DMM*]),
        [vor `Voltage Read` A3], [B3], [3.2V], [3.17V], [3.272V],
        [nach einmaligem `Voltage Read` A3 (liefert 3.19V)], [B3], [\~0V], [0.00V], [0.049V],
        [], [A3], [3.2V], [3.19V], [3.277V],
        [vor `Voltage Read` A15], [A15], [3.2V], [3.21V], [3.276V],
        [nach einmaligem `Voltage Read` A15 (liefert 0.01V)], [A15], [\~0V], [0.00V], [0V],
        [Pull-Up erneut auf allen Subindizes geschrieben], [B3], [3.2V], [3.17V], [3.272V],
    )
)

Das Multimeter bestätigt die vertauschte Zuordnung und das Abschalten durch `Voltage Read` in allen Fällen.
Ein Pull-Up ergibt 3.27-3.28V, der ADC des anderen Bricks liest 0.1V weniger (3.17-3.21V). An B0 und B15
misst das Multimeter 0-0.05V statt der 0.2-0.5V des ADCs. Bei einem Pin ohne Pull zieht der Innenwiderstand
des Multimeters die Leitung gegen 0V, deshalb lässt sich mit dem Multimeter nicht unterscheiden, ob der Pin
floatet oder schwach nach GND belastet ist. Sicher ist, dass über keinen Subindex ein Pull-Up an B0 oder B15 wirkt.

== Minimale Reproduktion

```python
import time, canopen

net = canopen.Network(); net.connect(interface="socketcan", channel="can0")
a = net.add_node(10, "res/io-brick.eds").sdo     # Label 5
b = net.add_node(11, "res/io-brick.eds").sdo     # Label 16
IOS = [f"{bank}{i}" for bank in "AB" for i in range(16)]

def high_pins():
    time.sleep(0.05)
    pins = []
    for bank in "AB":
        for off in (0, 8):
            raw = b["Read Input 8 Bit"][f"{bank}{off}-{bank}{off + 7}"].raw
            pins += [f"{bank}{off + n}" for n in range(8) if raw >> n & 1]
    return pins

for sdo in (a, b):
    for io in IOS:
        sdo["Io Direction 1 Bit"][io].raw = 0
        sdo["Pull Resistor 1 Bit"][io].raw = 0
for io in IOS:
    a["Pull Resistor 1 Bit"][io].raw = 1                  # Pull-Down auf allen Subindizes

# 3.1: einzelne Subindizes auf Pull-Up
for io in ("A0", "A3", "A15", "B3", "B15"):
    a["Pull Resistor 1 Bit"][io].raw = 2
    print(f"Subindex {io:3} Pull-Up -> HIGH: {high_pins()}")    # A0 -> [], A3 -> [B3], A15 -> [A15], B3 -> [A3], B15 -> [A15]
    a["Pull Resistor 1 Bit"][io].raw = 1

# 3.2: Voltage Read schaltet einen Pull ab
for io in IOS:
    a["Pull Resistor 1 Bit"][io].raw = 2                  # Pull-Up auf allen Subindizes
print("vorher:", high_pins())                               # alle ausser B0, B15
print("Voltage Read A3:", a["Voltage Read"]["A3"].raw)     # ~3.19 V
print("nachher:", high_pins())                              # B3 fehlt

for io in IOS:
    a["Pull Resistor 1 Bit"][io].raw = 0
net.disconnect()
```
#pagebreak()

== Fragen

+ Ist die Zuordnung Subindex → Pin von `Pull Resistor 1 Bit` in der Firmware vertauscht, oder ist die
  Beschriftung im EDS falsch? Die anderen IO-Objekte (`Io Direction 1 Bit`, `Write Output 1 Bit`,
  `Read Input 1 Bit`) verwenden die erwartete Zuordnung.
+ Haben B0 und B15 einen Pull-Widerstand in der Hardware? Falls ja, über welchen Subindex ist er erreichbar?
+ Warum verändert das Lesen von `Voltage Read` die Pull-Konfiguration? Vermutlich wird beim Umschalten auf
  den Analogmodus die Pull-Konfiguration mit dem falschen Index zurückgesetzt (gleiche Vertauschung wie oben).