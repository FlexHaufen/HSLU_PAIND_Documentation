#import "@preview/dashy-todo:0.1.3": todo

= Testszenarien


Ein einzelner Test kann den folgenden status erhalten

#figure(
    caption: "Testzustände",
    
    table(
        columns: (0.5fr, 1fr),
        align: left,
        table.header(
            [*Status*], [*Beschreibung*]
        ),
        [`PASSED`],
        [Der Test wurde erfolgreich bestanden],

        [`SKIPPED`],
        [Der Test wurde übersprungen],

        [`FAILED`],
        [Der Test wurde nicht bestanden],

        [`ERROR`],
        [Der Test selber ist fehlgeschlagen],
    )
)

Zusätzlich kann ein Test als "critical" (kritisch) eingestuft werden.
Wird ein Test welche als kritisch eingestuft unterbricht den Testdurchlauf sobald der kritische Test fehlschlägt.


#pagebreak()

== Testen der Kommunikation
Damit die einzelnen Funktionen des IO-Bricks getestet werden können, muss zuerst die Kommunikation über CANopen überprüft werden.

=== Konzept

Von jedem Brick wird über @SDO ein Objekt gelesen. Antwortet der Brick, ist er am CAN-Bus erreichbar und die Kommunikation funktioniert.
Der Test ist als kritisch eingestuft. Ohne funktionierende Kommunikation können alle nachfolgenden Tests nicht durchgeführt werden.

#figure(
    caption: "Ergebnisse des Kommunikationstests",
    table(
        columns: (auto, 1fr),
        align: left,
        table.header([*Ergebnis*], [*Bedeutung*]),
        [`PASSED`], [Brick antwortet],
        [`FAILED`], [Keine @SDO\-Antwort (Timeout oder Abbruch)],
    )
)

#todo()[
    Evtl. Zusätzliche überprüfung der SlotID dokumentieren
]


=== Umsetzung

Der Test ist in der Klasse ```py CommunicationTest``` umgesetzt. Für jeden Brick wird das Objekt `Device Type` gelesen. Der Wert selbst wird nicht ausgewertet, es zählt nur, ob eine Antwort kommt. Bleibt sie aus oder wird der Zugriff abgebrochen, wirft die CANopen-Bibliothek eine Exception und der Brick wird als fehlerhaft gemeldet.

#figure(
    kind: "Codeausschnitt",
    supplement: [Codeausschnitt],
    caption: "Prüfen der Kommunikation",
    [
```python
try:
    _ = brick.get_device_type()     
except (SdoCommunicationError, SdoAbortedError) as e:
    result.add_fail(f"No SDO response: {e}", bricks=(brick,))
    continue
...
result.add_pass(...)
```
    ]
)


#pagebreak()


== Testen der digitalen Ein-/Ausgänge


=== Konzept

Die IOs der beiden IO-Bricks sind über die Baseplate 1:1 miteinander verbunden. Damit kann jede Leitung von einem Brick getrieben und gleichzeitig von beiden Bricks gelesen werden. Der treibende Brick liest seinen eigenen Pin zurück (Readback), der andere Brick liest dieselbe Leitung über die Baseplate (Remote).

Jeder IO wird nacheinander von beiden Bricks getrieben. Dadurch entstehen pro IO vier Messungen S1 bis S4. Aus der Kombination dieser vier Messungen lässt sich bestimmen, ob der Ausgang, der Eingang oder die Leitung selbst fehlerhaft ist und welchem Brick der Fehler zuzuordnen ist.

Jede Messung besteht dabei aus zwei Pegeln: Die Leitung wird zuerst auf `HIGH` und danach auf `LOW` getrieben. Eine Messung gilt nur als korrekt, wenn beide Pegel richtig gelesen werden. Würde nur ein Pegel geprüft, bliebe eine Leitung, die zufällig auf genau diesem Pegel "festhängt", unentdeckt.

Während ein Brick treibt, ist der IO des anderen Bricks immer als Eingang konfiguriert. Es treiben also nie zwei Ausgänge gegeneinander.

#figure(
    caption: "Testen der digitalen Ein/-Ausgänge - Konzept",
    image("../assets/test_digital_inout.png")
)

/*
#figure(
    kind: "Codeausschnitt",
    supplement: [Codeausschnitt],
    caption: "Pseudocode testablauf für ein IO",
    [
```
Step 0 - Safe state
    IO-Brick 1: A1 → INPUT
    IO-Brick 2: A1 → INPUT

Step 1 - IO-Brick 1 drives, IO-Brick 2 receives
    IO-Brick 1: A1 → OUTPUT
    for level in (HIGH, LOW):
        IO-Brick 1: set_io_level(A1, level)
        wait (settle time)
        S1 = IO-Brick 1.get_io_level(A1)   # readback
        S2 = IO-Brick 2.get_io_level(A1)   # remote read
    IO-Brick 1: A1 → INPUT

Step 2 - IO-Brick 2 drives, IO-Brick 1 receives
    IO-Brick 2: A1 → OUTPUT
    for level in (HIGH, LOW):
        IO-Brick 2: set_io_level(A1, level)
        wait (settle time)
        S3 = IO-Brick 2.get_io_level(A1)   # readback
        S4 = IO-Brick 1.get_io_level(A1)   # remote read
    IO-Brick 2: A1 → INPUT
```
    ]
)
*/

#pagebreak()


Die Tabelle unten zeigt die Klassifizierung der einzelnen Zustände auf.

#let C = sym.checkmark.heavy
#let X = sym.crossmark
#figure(
    caption: "Fehlerinterpretation Digitale Ein-/Ausgänge",
    table(
        columns: (auto, 1fr, 1fr, 1fr, 1fr),
        table.header(
            [*Klassifizierung*], [*S1*\ IO-Brick 1 readback], [*S2*\ IO-Brick 2 remote], [*S3*\ IO-Brick 2 readback], [*S4*\ IO-Brick 1 remote]
        ),
        [Kein Fehler gefunden],
        [#C],[#C],[#C],[#C],
        [IO-Brick 1 defekter Ausgang],
        [#X],[#X],[#C],[#C],
        [IO-Brick 1 defekter Eingang],
        [#X],[#C],[#C],[#X],
        [IO-Brick 2 defekter Ausgang],
        [#C],[#C],[#X],[#X],
        [IO-Brick 2 defekter Eingang],
        [#C],[#X],[#X],[#C],
        [Unterbruch],
        [#C],[#X],[#C],[#X],
        [Kurzschluss],
        [#X],[#X],[#X],[#X],
        [Unklassifizierbarer Fehler],
        table.cell(colspan: 4)[_Restliche Zustände_],
    )
)

*Ausgang defekt*: Der Ausgangstreiber kann den Pegel nicht auf die Leitung legen, daher lesen beide Bricks einen falschen Wert. In der Gegenrichtung funktioniert alles, weil die Eingangsstufe dieses Bricks intakt ist.

*Eingang defekt*: Der Brick liest seinen eigenen Pin falsch, egal ob er selbst treibt (Readback) oder empfängt. Der andere Brick erkennt dagegen den korrekten Pegel, was belegt, dass der Ausgang funktioniert.

*Unterbrochen*: Jeder Treiber liest seinen eigenen Pegel korrekt zurück, aber das Signal kommt in keiner Richtung auf der Gegenseite an.

*Kurzschluss*: Die Leitung bleibt unabhängig davon, wer treibt, fest auf einem Pegel. Mit diesem Test allein lässt sich der Fehler keinem Brick eindeutig zuordnen. Ursache kann jeder der beiden Bricks oder die Grundplatine (Baseplate) sein. Ein Test des Bricks auf einer zweiten Grundplatine oder gegen einen bekannt funktionierenden Partner grenzt den Fehler weiter ein.

*Restliche Zustände*: Für Zustände welche nicht in der Tabelle aufgeführt sind, gibt es keine eindeutige Fehlerzuweisung. Dies kann beispielsweise vorkommen, falls mehrere Fehler gleichzeitig vorhanden sind. Eine weitere Diagnose ist demnach nötig.


#pagebreak()


==== Testdauer

Die Dauer des Tests wird durch die Anzahl der @SDO\-Zugriffe und durch die Wartezeiten nach jedem Pegelwechsel bestimmt. Jeder @SDO\-Zugriff ist ein Roundtrip über den CAN-Bus (Anfrage und Antwort) mit der Dauer $t_"SDO"$.

#figure(
    caption: "Variablen zur Berechnung der Testdauer",
    table(
        columns: (auto, 1fr, auto),
        align: left,
        table.header([*Symbol*], [*Bedeutung*], [*Wert*]),
        [$N$], [IOs pro Brick], [$32$],
        [$B$], [Anzahl Bricks], [$2$],
        [$K$], [Bänke pro Brick], [$2$],
        [$D$], [Richtungen (IO-Brick 1 → IO-Brick 2 und umgekehrt)], [$2$],
        [$L$], [Getriebene Pegel (`HIGH`, `LOW`)], [$2$],
        [$t_"SDO"$], [Dauer eines @SDO\-Roundtrips], [$approx 1.12"ms"$ #h(5pt) #footnote[Die Bestimmung von $t_"SDO"$ ist in #text(red)[TODO: Verweis auf Kapitel] beschrieben.]],
        [$t_"settle"$], [Wartezeit nach einem Pegelwechsel (`IO_SETTLE_TIME`)], [$5"ms"$],
    )
)

*Vorbereitung:* Auf beiden Bricks wird die Bankspannung gesetzt (Sollwert und Freigabe pro Bank, also $2K$ Zugriffe) und alle IOs werden als Eingang konfiguriert ($N$ Zugriffe).

*Durchführung:* Pro IO und Richtung wird der Ausgang vorbereitet (Pegel `LOW` vorgeben und auf Ausgang schalten, 2 Zugriffe). Pro Pegel folgen das Setzen des Pegels, das Readback und das Remote-Lesen (3 Zugriffe). Zum Schluss wird der IO wieder als Eingang konfiguriert (1 Zugriff).

*Abschluss:* Alle IOs beider Bricks werden wieder als Eingang konfiguriert ($N$ Zugriffe pro Brick).

$
  "SDO"_"total" &= underbrace(B (2K + N), "Vorbereitung") + underbrace(N D (3 + 3L), "Durchführung") + underbrace(B N, "Abschluss") \
  &= 72 + 576 + 64 = 712
$


Die gesamte Testdauer ergibt sich damit zu

$
  t_"total" &approx "SDO"_"total" dot t_"SDO" + N D L dot t_"settle" \
  &approx 712 dot t_"SDO" + 640"ms" \
  &approx 1.44"s"
$

Die gemessene Testdauer von $1.449 "s"$ stimmt gut mit dieser Abschätzung überein.



#pagebreak()


=== Umsetzung

Der Test ist in der Klasse ```py DigitalIoLoopbackTest``` umgesetzt. In der Software wird IO-Brick 1 als Tester (Referenz-Brick, Knoten 10) und IO-Brick 2 als Prüfling (Testee, Knoten 11) bezeichnet. Der Test ist als kritisch eingestuft: Schlägt er fehl, werden die nachfolgenden Tests übersprungen, da diese auf funktionierende digitale Ein- und Ausgänge angewiesen sind.

==== Vorbereitung und Abschluss

In der Vorbereitung (```py setup()```) wird auf beiden Bricks die Bankspannung auf den Standardwert von 3.3 V gesetzt und alle IOs als Eingang konfiguriert. Damit startet der Test aus einem sicheren Zustand, in dem kein IO treibt. Im Abschluss (```py teardown()```) werden alle IOs wieder als Eingang konfiguriert. Der Abschluss wird vom Testrunner auch dann ausgeführt, wenn der Test mit einer Exception abbricht.

==== Treiben eines IOs

Ein einzelner Durchlauf (ein IO, eine Richtung) ist in der Methode ```py __drive()``` umgesetzt.

#figure(
    kind: "Codeausschnitt",
    supplement: [Codeausschnitt],
    caption: "Treiben eines IOs und Lesen von Readback und Remote",
    [
```python
def __drive(self, driver, receiver, bank, io):
    readback, remote = [], []
    # preset the output latch so enabling the output doesn't glitch the line
    driver.set_io_level(bank, io, L.LOW)
    driver.set_io_dir(bank, io, D.OUTPUT)
    try:
        for level in LEVELS:                    # (HIGH, LOW)
            driver.set_io_level(bank, io, level)
            time.sleep(IoBrick.IO_SETTLE_TIME)
            readback.append(driver.get_io(bank, io))
            remote.append(receiver.get_io(bank, io))
    finally:
        driver.set_io_dir(bank, io, D.INPUT)
    return readback, remote
```
    ]
)

Bevor der IO auf Ausgang geschaltet wird, wird der Ausgangspegel auf `LOW` vorgegeben. Ohne diese Vorgabe würde der Ausgang beim Umschalten kurz den zuletzt gespeicherten Pegel treiben.

Der IO wird in einem `finally`-Block wieder auf Eingang geschaltet. Tritt während der Messung ein Fehler auf (z.B. ein Timeout der @SDO\-Kommunikation), bleibt der IO dadurch nicht als Ausgang aktiv. Andernfalls würde der zweite Brick bei der Messung in der Gegenrichtung gegen diesen Ausgang treiben.

#pagebreak()

==== Klassifizierung

Für jeden IO wird ```py __drive()``` zweimal aufgerufen, zuerst mit dem Tester als treibendem Brick (S1, S2), danach mit dem Prüfling (S3, S4). Jede der vier Messungen wird mit der erwarteten Pegelfolge `HIGH/LOW` verglichen. Das Ergebnis ist ein Tupel aus vier Wahrheitswerten, mit dem der Fehler direkt in der Fehlertabelle nachgeschlagen wird.

#figure(
    kind: "Codeausschnitt",
    supplement: [Codeausschnitt],
    caption: "Fehlertabelle und Klassifizierung",
    [
```python
# (S1, S2, S3, S4) -> fault
FAULT_TABLE = {
    (True,  True,  True,  True):  Fault.NONE,
    (False, False, True,  True):  Fault.TESTER_OUTPUT,
    (False, True,  True,  False): Fault.TESTER_INPUT,
    (True,  True,  False, False): Fault.TESTEE_OUTPUT,
    (True,  False, False, True):  Fault.TESTEE_INPUT,
    (True,  False, True,  False): Fault.OPEN,
    (False, False, False, False): Fault.SHORT,
}

s1, s2 = self.__drive(tester, testee, bank, io)
s3, s4 = self.__drive(testee, tester, bank, io)
states = tuple(list(s) == list(LEVELS) for s in (s1, s2, s3, s4))
fault = FAULT_TABLE.get(states, Fault.UNCLASSIFIABLE)
```
    ]
)

Alle Zustände, die nicht in der Tabelle enthalten sind, werden als `UNCLASSIFIABLE` (unklassifizierbar) eingestuft.



#pagebreak()

==== Einschränkungen

Der empfangende IO ist während der Messung ein Eingang ohne Pull-Widerstand und damit hochohmig. Ist die Leitung unterbrochen, floatet der Eingang und kann seinen letzten Pegel über die Leitungskapazität behalten. Ein Unterbruch wird deshalb nicht in jedem Fall zuverlässig erkannt (siehe @anhang-fehleranalyse, D4). Abhilfe schafft ein Pull-Widerstand beim Empfänger, der entgegengesetzt zum getriebenen Pegel geschaltet wird. Dieser kann erst eingesetzt werden, wenn die Pull-Widerstände selbst getestet sind.

Kurzschlüsse zwischen zwei IOs werden mit diesem Test nicht erkannt, da die übrigen Leitungen während der Messung nicht getrieben werden. Dafür ist der Walking-One-Test vorgesehen.


#pagebreak()

== Testen der analogen Eingänge

Die analogen ein


#pagebreak()

== Testen von Kurzschlüssen zwischen IOs (Walking One)

=== Konzept

Der Loopback-Test aus dem vorherigen Kapitel prüft jede Leitung einzeln. Ein Kurzschluss zwischen zwei IOs, z.B. eine Lötbrücke zwischen zwei benachbarten Pins, wird dabei nicht erkannt: Die übrigen Leitungen werden während der Messung nicht getrieben und deshalb auch nicht ausgewertet.

Beim Walking-One-Test wird deshalb jeweils genau ein IO auf `HIGH` getrieben, während alle 32 IOs gelesen werden. Der getriebene Pegel "wandert" so nacheinander über alle IOs. Damit die nicht getriebenen Leitungen nicht floaten, wird bei allen IOs der Pull-Down-Widerstand eingeschaltet. Ohne Fehler liest nur der getriebene IO selbst `HIGH`, alle anderen IOs lesen `LOW`. Liest ein weiterer IO ebenfalls `HIGH`, ist er mit dem getriebenen IO kurzgeschlossen.

#figure(caption: " Testen von Kurzschlüssen - Konzepts")[
    #image("/assets/test_walking_one.png")
]



Es ist immer nur ein Ausgang aktiv. Bei einem Kurzschluss zieht der Ausgang nur einen Eingang mit Pull-Down auf `HIGH`, es treiben also nie zwei Ausgänge gegeneinander. Geprüft werden alle 32 IOs gegeneinander, also auch Kurzschlüsse zwischen Bank A und Bank B.

#figure(
    kind: "Codeausschnitt",
    supplement: [Codeausschnitt],
    caption: "Pseudocode Walking-One-Test",
    [
```
Step 0 - Safe state
    IO-Brick 1, IO-Brick 2: all IOs → INPUT, PULL_DOWN

Step 1 - Walk over all IOs of the device under test (IO-Brick 2)
    for X in (A0 ... A15, B0 ... B15):
        IO-Brick 2: X → OUTPUT, HIGH
        wait (settle time)
        levels = IO-Brick 2.get_inputs()      # all 32 IOs
        IO-Brick 2: X → LOW, INPUT
        for Y in all IOs except X:
            if levels[Y] == HIGH:
                short between X and Y
```
    ]
)

Da die IOs der beiden Bricks über die Baseplate 1:1 verbunden sind, sieht ein Kurzschluss elektrisch gleich aus, egal ob er sich auf dem Tester, dem Prüfling oder der Baseplate befindet. Der Tester ist ein bekannt funktionierender Brick und die Baseplate wird als fehlerfrei angenommen. Ein gefundener Kurzschluss wird deshalb dem Prüfling zugeordnet. Der Tester wird nur als Eingang mit Pull-Down konfiguriert und treibt während des ganzen Tests nie. Da der Test ausschliesslich mit dem Prüfling arbeitet, könnte er auch ohne eingesteckten Tester durchgeführt werden.

Pro getriebenem IO werden $N - 1$ andere IOs geprüft. Insgesamt werden damit

$
  N (N - 1) = 32 dot 31 = 992
$

IO-Kombinationen geprüft. Jeder Kurzschluss wird dabei zweimal gesehen, einmal aus jeder Richtung (X treibt Y und Y treibt X).


#pagebreak()


==== Testdauer

Würde jeder IO einzeln über `Read Input 1 Bit` gelesen, wären pro getriebenem IO $N = 32$ Lesezugriffe nötig. Das Objekt `Read Input 8 Bit` liefert dagegen die Pegel von 8 IOs mit einem einzigen @SDO\-Zugriff. Damit lassen sich alle 32 IOs eines Bricks mit $G = N / 8 = 4$ Zugriffen lesen.

Es gelten dieselben Variablen wie beim digitalen Loopback-Test. Zusätzlich ist $G = 4$ die Anzahl Zugriffe, um alle IOs eines Bricks zu lesen.

*Vorbereitung:* Auf beiden Bricks wird die Bankspannung gesetzt ($2K$ Zugriffe), alle IOs als Eingang konfiguriert ($N$ Zugriffe) und der Pull-Down-Widerstand eingeschaltet ($N$ Zugriffe).

*Durchführung:* Pro IO wird der Ausgang vorbereitet (Pegel `LOW` vorgeben und auf Ausgang schalten, 2 Zugriffe), auf `HIGH` gesetzt (1 Zugriff) und alle Eingänge gelesen ($G$ Zugriffe). Danach wird der IO wieder auf `LOW` gesetzt und als Eingang konfiguriert (2 Zugriffe). Es wird nur in eine Richtung getrieben und nur ein Pegel geprüft.

*Abschluss:* Auf beiden Bricks werden alle IOs als Eingang konfiguriert und die Pull-Widerstände ausgeschaltet ($2N$ Zugriffe pro Brick).

$
  "SDO"_"total" &= underbrace(B (2K + 2N), "Vorbereitung") + underbrace(N (5 + G), "Durchführung") + underbrace(2 B N, "Abschluss") \
  &= 136 + 288 + 128 = 552
$

$
  t_"total" &approx "SDO"_"total" dot t_"SDO" + N dot t_"settle" \
  &= 552 dot 1.12"ms" + 32 dot 5"ms" approx 0.78"s"
$

Mit Einzelzugriffen über `Read Input 1 Bit` wären es in der Durchführung $N (5 + N) = 1184$ statt $288$ Zugriffe. Die Testdauer würde damit auf rund $1.78"s"$ steigen.

Die gemessene Testdauer von $0.854"s"$ stimmt gut mit dieser Abschätzung überein.

#pagebreak()


=== Umsetzung

Der Test ist in der Klasse ```py WalkingOneTest``` umgesetzt. Er ist nicht als kritisch eingestuft: Ein gefundener Kurzschluss wird im Bericht aufgeführt, die nachfolgenden Tests werden aber trotzdem ausgeführt. Der Test setzt voraus, dass der digitale Loopback-Test bestanden wurde. Leitungen, die fest auf einem Pegel hängen, sind damit bereits ausgeschlossen.

==== Vorbereitung und Abschluss

In der Vorbereitung (```py setup()```) wird auf beiden Bricks die Bankspannung auf 3.3 V gesetzt, alle IOs als Eingang konfiguriert und bei allen IOs der Pull-Down-Widerstand eingeschaltet. Im Abschluss (```py teardown()```) werden alle IOs wieder als Eingang konfiguriert und die Pull-Widerstände ausgeschaltet. Damit beeinflussen die Pull-Down-Widerstände die nachfolgenden Tests nicht, insbesondere nicht die Spannungsmessung des analogen Tests.


==== Treiben eines IOs

Das Treiben eines IOs ist wie beim digitalen Loopback-Test in der Methode ```py __drive()``` umgesetzt. Auch hier wird der Ausgangspegel vor dem Umschalten auf `LOW` vorgegeben, und der IO wird in einem `finally`-Block wieder als Eingang konfiguriert. Im Unterschied zum Loopback-Test treibt nur der Prüfling, und anstelle eines einzelnen IOs werden alle Eingänge des Prüflings gelesen.

#figure(
    kind: "Codeausschnitt",
    supplement: [Codeausschnitt],
    caption: "Treiben eines IOs und Lesen aller Eingänge",
    [
```python
def __drive(brick, bank, io):
    brick.set_io_level(bank, io, L.LOW)
    brick.set_io_dir(bank, io, D.OUTPUT)
    try:
        brick.set_io_level(bank, io, L.HIGH)
        time.sleep(IoBrick.IO_SETTLE_TIME)
        return brick.get_inputs()
    finally:
        brick.set_io_level(bank, io, L.LOW)
        brick.set_io_dir(bank, io, D.INPUT)
```
    ]
)

==== Auswertung

Zuerst werden alle 32 IOs nacheinander getrieben. Für jeden getriebenen IO werden die anderen IOs gespeichert, die dabei ebenfalls `HIGH` gelesen haben. Erst danach werden die Ergebnisse ausgewertet, da für die Auswertung eines Kurzschlusses beide Richtungen bekannt sein müssen.

#figure(
    kind: "Codeausschnitt",
    supplement: [Codeausschnitt],
    caption: "Messung und Auswertung der Kurzschlüsse",
    [
```python
followers = {}
for bank, io in IoBrick.all_ios():
    levels = self.__drive(testee, bank, io)
    followers[(bank, io)] = [key for key, level in levels.items()
                             if key != (bank, io) and level == L.HIGH]

reported = set()
for driven, shorted in followers.items():
    for other in shorted:
        pair = frozenset((driven, other))
        if pair in reported:
            continue
        reported.add(pair)
        both_ways = driven in followers[other]
        result.add_fail(...)
```
    ]
)

Ein Kurzschluss zwischen X und Y wird normalerweise zweimal gefunden: Wenn X getrieben wird, liest Y `HIGH`, und umgekehrt. Damit derselbe Kurzschluss nicht zweimal im Bericht erscheint, wird jedes IO-Paar als ungeordnete Menge (```py frozenset```) gespeichert und nur einmal gemeldet.

Zusätzlich wird festgehalten, ob der Kurzschluss in beiden Richtungen oder nur in einer Richtung aufgetreten ist. Ein satter Kurzschluss (z.B. eine Lötbrücke) zeigt sich immer in beiden Richtungen. Tritt er nur in einer Richtung auf, deutet das auf einen anderen Fehler hin, z.B. auf einen hochohmigen Kurzschluss in der Nähe der Schaltschwelle oder einen fehlerhaften Eingang. Eine weitere Diagnose ist in diesem Fall nötig.

#figure(
    caption: "Ergebnisse des Walking-One-Tests",
    table(
        columns: (auto, 1fr, auto),
        align: left,
        table.header([*Ergebnis*], [*Bedeutung*], [*Betroffener Brick*]),
        [`PASSED`], [Beim Treiben dieses IOs liest kein anderer IO `HIGH`], [Prüfling],
        [`FAILED`], [Kurzschluss zwischen IO X und IO Y (in beiden Richtungen)], [Prüfling],
        [`FAILED`], [Kurzschluss zwischen IO X und IO Y (nur wenn X getrieben wird)], [Prüfling],
    )
)


==== Einschränkungen

Der Test ist auf funktionierende Pull-Down-Widerstände angewiesen. Fehlt der Pull-Down eines IOs, floatet dieser Eingang und kann zufällig `HIGH` lesen. Das würde fälschlicherweise als Kurzschluss gemeldet. Die Pull-Widerstände werden erst im nachfolgenden Kapitel getestet.

Erkannt werden nur Kurzschlüsse, die den Eingang über die Schaltschwelle ziehen. Ein hochohmiger Kurzschluss bildet zusammen mit den parallel geschalteten Pull-Down-Widerständen von Tester und Prüfling einen Spannungsteiler. Liegt die Spannung am betroffenen IO unter der Schaltschwelle, wird der Kurzschluss nicht erkannt.

Kurzschlüsse gegen GND oder gegen die Bankspannung werden mit diesem Test nicht gesucht. Diese werden bereits vom digitalen Loopback-Test als Kurzschluss (Leitung festhängend) erkannt.


#pagebreak()


== Testen der konfigurierbaren Pull-Up/Pull-Down-Widerstände

//Ein Pull-Widerstand ist eine schwache, passive Quelle. Man testet ihn daher, indem man zwei Dinge prüft: Er zieht eine Leitung, die sonst von nichts getrieben wird, auf seinen Pegel, und er verliert gegen einen echten Treiber.

#table(
  columns: 3,
  table.header(
    [*Wer treibt die Leitung*],
    [*Was passieren sollte*],
    [*Was es beweist*],
  ),
  [Nur der Pull-Widerstand eines Bricks (alles andere hochohmig)],
  [Leitung geht auf den Pull-Pegel],
  [Der Widerstand ist vorhanden und zugeschaltet],

  [Pull-Up auf einem Brick, Pull-Down auf dem anderen],
  [Leitung liegt auf einer mittleren Spannung (≈ V/2 bei gleichen Widerstandswerten)],
  [Beide Widerstände sind vorhanden; ihr Verhältnis liegt in der Toleranz],

  [Ausgangstreiber gegen den entgegengesetzten Pull],
  [Leitung bleibt auf dem getriebenen Pegel],
  [Der Pull ist schwach, nicht kurzgeschlossen oder niederohmig],
)

=== Testkonzept, pro IO

*Schritt 0: Voraussetzungen.* Zuerst den bestehenden `DigitalIoLoopbackTest` ausführen. Der Pull-Test nutzt die Eingangspuffer als Messwerkzeug, daher müssen diese bereits als funktionsfähig bekannt sein.

*Schritt 1: Jeder Pull einzeln (digital).*
Ein fehlender Pull lässt die Leitung floaten, und eine floatende Leitung behält oft einfach ihre letzte Ladung. Ein naiver Test könnte daher zufällig den richtigen Pegel lesen. Um das zu vermeiden, wird die Leitung zuerst auf den _entgegengesetzten_ Pegel geladen:

+ Brick 2 treibt die Leitung LOW und schaltet dann zurück auf INPUT. Die Leitung ist jetzt LOW, aber floatend.
+ Brick 1 aktiviert `PULL_UP`. Warten, bis sich die Leitung eingeschwungen hat, dann auf beiden Bricks lesen. Beide sollten HIGH lesen.
+ Gespiegelt: auf HIGH laden, dann `PULL_DOWN`; beide sollten LOW lesen.
+ Mit vertauschten Rollen wiederholen (Pull von Brick 2, geladen durch Brick 1).

Das ergibt vier Ergebnisse pro Brick, die sich mit einer Fehlertabelle wie bei deinem Loopback-Test klassifizieren lassen:
- *Beide Leser falsch, nur wenn der Pull dieses Bricks aktiv ist:* Der Pull dieses Bricks ist defekt.
- *Nur `PULL_UP` falsch oder nur `PULL_DOWN` falsch:* Eine Hälfte der Pull-Schaltung ist defekt.
- *`PULL_UP` ergibt LOW und `PULL_DOWN` ergibt HIGH:* Das Enum-Mapping ist vertauscht. Das beantwortet auch das TODO in `io_brick.py:117` (`src/pinpoint/hardware/io_brick.py`).
- *`NONE` funktioniert:* Das lässt sich nur indirekt prüfen. Wenn Schritt 2 des Spannungstests unten die erwarteten Werte liefert, ist die „unbenutzte“ Seite tatsächlich hochohmig.

*Schritt 2: Spannungsteiler-Test (analog, optional, aber aussagekräftig).*
Pull-Up von Brick 1 und Pull-Down von Brick 2 einschalten, dann `get_io_voltage` auf beiden Bricks lesen.
- Erwartet: $V = V_"bank" dot R_"down" / (R_"up" + R_"down")$, innerhalb einer Toleranz.
- Etwa 0 V bedeutet, dass der Pull-Up fehlt. Etwa $V_"bank"$ bedeutet, dass der Pull-Down fehlt. Ein Wert dazwischen, aber außerhalb der Toleranz, bedeutet einen falschen Widerstandswert.
- Danach umgekehrt durchführen (Brick 1 Pull-Down, Brick 2 Pull-Up).
- Bonus: Bei zwei Bankspannungen wiederholen (z. B. 1,8 V und 3,3 V). Der Pull-Up hängt an der Bankversorgung, damit wird also auch geprüft, ob der Sollwert der Versorgung eingehalten wird.

*Schritt 3: Treiber gegen den entgegengesetzten Pull.*
Brick 1 treibt LOW, während bei Brick 2 `PULL_UP` aktiv ist. Die Leitung muss LOW bleiben, sowohl digital als auch bei etwa 0 V. Danach HIGH gegen `PULL_DOWN`. Das erkennt einen gegen die Versorgungsschiene kurzgeschlossenen Pull und ist zugleich eine einfache Prüfung, wie stark der Ausgangstreiber ist.

=== Nebeneffekt: ein besserer Loopback-Test
Mit verfügbaren Pulls wird dein bestehender Test zuverlässiger:
- *Offene Leitung:* Derzeit floatet der empfangende Eingang, sodass `Fault.OPEN` zufällig übersehen werden kann. Wenn der Empfänger den zum getriebenen Pegel entgegengesetzten Pull nutzt (HIGH treiben → Empfänger `PULL_DOWN`), liest eine offene Leitung zuverlässig den falschen Wert.
- *Kurzschlüsse zwischen IOs (Bridging):* Alle IOs nach unten ziehen, einen HIGH treiben und prüfen, ob seine Nachbarn LOW bleiben. Ohne Pulls lässt sich das gar nicht erkennen, weil die Nachbarn floaten.

=== Pendenzen Implementierung
+ *Nennwert und Toleranz der Pull-Widerstände.* Wird für die Grenzwerte des Spannungsteilers benötigt (z. B. 10 kΩ ±5 %).
+ *Wo `Voltage Read` misst.* Sitzt der ADC direkt am Pin oder hinter einem Pegelwandler oder Serienwiderstand? Im zweiten Fall ändert sich die Teilerrechnung.
+ *Ist der Pull noch aktiv, wenn der IO auf OUTPUT steht?* Das betrifft Schritt 3 und die Frage, ob der Pull abgeschaltet werden muss, bevor der Brick treibt.
+ *`Impedance Read` liefert NaN.* Falls sich das zum Laufen bringen lässt (evtl. braucht es einen Modus oder einen Messstrom), könnte man damit den Pull-Widerstand direkt messen.