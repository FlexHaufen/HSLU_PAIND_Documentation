#import "@preview/dio:0.2.0": drawio
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
    drawio(path("../assets/drawIO/tests.drawio"), page: "digital_io_loopback")
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

=== Konzept

Jeder IO des IO-Bricks kann neben dem digitalen Pegel auch die Spannung der Leitung über einen @ADC messen. Der Test der analogen Eingänge basiert auf dem digitalen Loopback-Test: Der Aufbau, der Ablauf und die Fehlerinterpretation sind gleich. Anstelle des digitalen Pegels wird jedoch die Spannung der Leitung gemessen und mit einem Sollwert verglichen.

Wie beim digitalen Test wird jeder IO nacheinander von beiden Bricks getrieben. Der treibende Brick misst die Spannung an seinem eigenen Pin (Readback), der andere Brick misst dieselbe Leitung über die Baseplate (Remote). Pro IO entstehen so wieder die vier Messungen S1 bis S4.

Eine Messung besteht aus zwei Pegeln: Wird die Leitung auf `HIGH` getrieben, muss die Spannung der Bankspannung $U_"bank"$ entsprechen, bei `LOW` muss sie $0"V"$ betragen. Eine Messung gilt als korrekt, wenn beide Spannungen höchstens $plus.minus 0.1"V"$ vom Sollwert abweichen.

Damit der @ADC nicht nur an einem einzelnen Punkt geprüft wird, wird der Test bei den drei Bankspannungen $1.0"V"$, $2.0"V"$ und $3.3"V"$ durchgeführt. Da beide Bricks dieselbe Leitung teilen, wird die Bankspannung jeweils auf beiden Bricks gleich gesetzt. Zusammen mit dem Pegel `LOW` wird der Eingang damit an vier Punkten über den ganzen Messbereich geprüft.

#pagebreak()

==== Fehlerinterpretation

Die Klassifizierung entspricht derjenigen des digitalen Tests. Da der digitale Loopback-Test zuvor bestanden wurde, sind Unterbrüche, Kurzschlüsse und defekte Ausgangstreiber bereits ausgeschlossen. Eine falsche Spannung auf der Leitung deutet deshalb nicht auf einen defekten Ausgang hin, sondern auf eine falsche Ausgangsspannung.

#figure(
    caption: "Fehlerinterpretation Analoge Eingänge",
    table(
        columns: (auto, 1fr, 1fr, 1fr, 1fr),
        table.header(
            [*Klassifizierung*], [*S1*\ IO-Brick 1 readback], [*S2*\ IO-Brick 2 remote], [*S3*\ IO-Brick 2 readback], [*S4*\ IO-Brick 1 remote]
        ),
        [Kein Fehler gefunden],
        [#C],[#C],[#C],[#C],
        [IO-Brick 1 defekter analoger Eingang],
        [#X],[#C],[#C],[#X],
        [IO-Brick 2 defekter analoger Eingang],
        [#C],[#X],[#X],[#C],
        [IO-Brick 1 Ausgangsspannung falsch],
        [#X],[#X],[#C],[#C],
        [IO-Brick 2 Ausgangsspannung falsch],
        [#C],[#C],[#X],[#X],
        [Falsche Leitungsspannung],
        [#X],[#X],[#X],[#X],
        [Mehrere Fehler],
        table.cell(colspan: 4)[_Restliche Zustände_],
    )
)

*Defekter analoger Eingang*: Der @ADC eines Bricks misst eine falsche Spannung, egal ob der Brick selbst treibt (Readback) oder empfängt (Remote). Der andere Brick misst in beiden Richtungen die korrekte Spannung, womit belegt ist, dass die Spannung auf der Leitung stimmt.

*Ausgangsspannung falsch*: Treibt ein Brick, messen beide Bricks dieselbe falsche Spannung. In der Gegenrichtung stimmen beide Messungen, die analogen Eingänge beider Bricks sind also intakt. Ist die Spannung bei allen 16 IOs einer Bank falsch, liegt der Fehler nicht beim einzelnen Ausgang, sondern bei der Bankversorgung des treibenden Bricks. Diese Unterscheidung ist nur möglich, wenn zuerst alle IOs gemessen und danach gemeinsam ausgewertet werden.

*Falsche Leitungsspannung*: Die Spannung ist falsch, unabhängig davon, welcher Brick treibt. Eine mögliche Ursache ist eine Last auf der Leitung, z.B. ein niederohmiger Pfad gegen GND, wie er bei einem IO-Brick an Pin B0 festgestellt wurde. Der Fehler lässt sich keinem Brick eindeutig zuordnen, eine weitere Diagnose ist nötig.

*Restliche Zustände*: Im Unterschied zum digitalen Test werden die beiden Richtungen einzeln ausgewertet. Ein Zustand, der nicht in der Tabelle aufgeführt ist, ergibt deshalb nicht einen unklassifizierbaren Fehler, sondern es werden mehrere Fehler gemeldet, z.B. ein defekter analoger Eingang auf beiden Bricks.


/*
#pagebreak()

==== Testdauer

Es gelten dieselben Variablen wie beim digitalen Loopback-Test. Zusätzlich gelten die folgenden Variablen:

#figure(
    caption: "Zusätzliche Variablen zur Berechnung der Testdauer des analogen Tests",
    table(
        columns: (auto, 1fr, auto),
        align: left,
        table.header([*Symbol*], [*Bedeutung*], [*Wert*]),
        [$V$], [Anzahl geprüfter Bankspannungen], [$3$],
        [$t_"bank"$], [Wartezeit nach dem Setzen der Bankspannung (`BANK_VOLTAGE_SETTLE_TIME`)], [$200"ms"$],
    )
)

*Vorbereitung:* Auf beiden Bricks werden alle IOs als Eingang konfiguriert ($N$ Zugriffe pro Brick).

*Durchführung:* Pro Bankspannung wird auf beiden Bricks die Bankspannung gesetzt ($2K$ Zugriffe pro Brick). Danach folgt für jede Bankspannung derselbe Ablauf wie beim digitalen Test: Pro IO und Richtung wird der Ausgang vorbereitet (2 Zugriffe), pro Pegel folgen das Setzen des Pegels, das Readback und das Remote-Messen (3 Zugriffe) und zum Schluss wird der IO wieder als Eingang konfiguriert (1 Zugriff).

*Abschluss:* Auf beiden Bricks werden alle IOs als Eingang konfiguriert und die Bankspannung wieder auf den Standardwert gesetzt ($N + 2K$ Zugriffe pro Brick).

$
  "SDO"_"total" &= underbrace(B N, "Vorbereitung") + underbrace(V (2 B K + N D (3 + 3L)), "Durchführung") + underbrace(B (N + 2K), "Abschluss") \
  &= 64 + 1752 + 72 = 1888
$

Die gesamte Testdauer ergibt sich damit zu

$
  t_"total" &approx "SDO"_"total" dot t_"SDO" + V N D L dot t_"settle" + V dot t_"bank" \
  &approx 1888 dot 1.12"ms" + 1920"ms" + 600"ms" \
  &approx 4.63"s"
$

Der Test dauert damit rund dreimal so lange wie der digitale Loopback-Test, da derselbe Ablauf für jede der drei Bankspannungen wiederholt wird.

#todo()[Gemessene Testdauer ergänzen]
*/

#pagebreak()


=== Umsetzung

Der Test ist in der Klasse ```py AnalogIoLoopbackTest``` umgesetzt. Er ist nicht als kritisch eingestuft: Ein fehlerhafter analoger Eingang wird im Bericht aufgeführt, die nachfolgenden Tests werden aber trotzdem ausgeführt. Der Test setzt voraus, dass der digitale Loopback-Test bestanden wurde. Leitungen, Ausgangstreiber und Verbindungen über die Baseplate sind damit bereits geprüft.

Der Test benötigt die IO-Brick-Firmware ab Version V0.005. Bei älteren Versionen schaltet das Lesen von `Voltage Read` an einem Ausgang den Ausgangstreiber ab. Ein Readback wäre damit nicht möglich.

==== Vorbereitung und Abschluss

In der Vorbereitung (```py setup()```) werden auf beiden Bricks alle IOs als Eingang konfiguriert. Die Bankspannung wird erst in der Durchführung gesetzt, da sie für jeden Durchlauf ändert. Im Abschluss (```py teardown()```) werden alle IOs wieder als Eingang konfiguriert und die Bankspannung auf den Standardwert von 3.3 V zurückgesetzt. Damit laufen die nachfolgenden Tests wieder mit der Standard-Bankspannung.

==== Treiben eines IOs

Das Treiben eines IOs ist in der Methode ```py __drive()``` gleich umgesetzt wie beim digitalen Loopback-Test. Der Ausgangspegel wird vor dem Umschalten auf `LOW` vorgegeben, und der IO wird in einem `finally`-Block wieder als Eingang konfiguriert. Der einzige Unterschied ist, dass anstelle des digitalen Pegels (```py get_io()```) die Spannung gemessen wird (```py get_io_voltage()```).

#figure(
    kind: "Codeausschnitt",
    supplement: [Codeausschnitt],
    caption: "Treiben eines IOs und Messen der Spannung",
    [
```python
for level in LEVELS:                    # (HIGH, LOW)
    driver.set_io_level(bank, io, level)
    time.sleep(IoBrick.IO_SETTLE_TIME)
    readback.append(driver.get_io_voltage(bank, io))
    remote.append(receiver.get_io_voltage(bank, io))
```
    ]
)

==== Messung

Für jede Bankspannung wird diese zuerst auf beiden Bricks gesetzt. Anschliessend wird gewartet, bis sich die Bankspannung eingeschwungen hat (`BANK_VOLTAGE_SETTLE_TIME`). Ein Wechsel von $3.3"V"$ auf $1.0"V"$ dauert rund $100"ms"$.

Danach werden zuerst alle 32 IOs in beiden Richtungen gemessen und jede Messung mit den Sollspannungen verglichen. Erst anschliessend wird ausgewertet, da ein Fehler der Bankversorgung nur erkannt werden kann, wenn die Ergebnisse aller IOs einer Bank bekannt sind.

#figure(
    kind: "Codeausschnitt",
    supplement: [Codeausschnitt],
    caption: "Messung aller IOs und Erkennung eines Fehlers der Bankversorgung",
    [
```python
for brick in ctx.bricks:
    brick.set_voltage(bank_voltage)
time.sleep(IoBrick.BANK_VOLTAGE_SETTLE_TIME)
expected = [bank_voltage if l == L.HIGH else 0.0 for l in LEVELS]

samples = {(bank, io): [self.__drive(drv, rcv, bank, io) for drv, rcv in directions]
           for bank, io in IoBrick.all_ios()}
ok = {key: [tuple(self.__within_tolerance(s, expected) for s in pair)
            for pair in per_dir]
      for key, per_dir in samples.items()}

# line voltage wrong (readback and remote) on all IOs of a bank
bank_failed = {(bank, d): all(ok[(bank, io)][d] == (False, False)
                              for io in range(IoBrick.NUMBER_OF_IOS_PER_BANK))
               for bank in IoBrick.Bank for d in range(len(directions))}
```
    ]
)

#pagebreak()

==== Klassifizierung

Pro IO liegt für jede Richtung ein Paar aus Readback und Remote vor. Sind in beiden Richtungen alle Messungen korrekt, ist der IO fehlerfrei. Sind in beiden Richtungen alle Messungen falsch, wird eine falsche Leitungsspannung gemeldet. In allen anderen Fällen wird jede Richtung einzeln ausgewertet.

#figure(
    kind: "Codeausschnitt",
    supplement: [Codeausschnitt],
    caption: "Klassifizierung pro Richtung",
    [
```python
faults = {}
for d, ((driver, receiver), (readback_ok, remote_ok)) in enumerate(zip(directions, states)):
    match (readback_ok, remote_ok):
        case (True, True):
            continue
        case (True, False):
            faults["Defective analog input on receiver"] = (receiver,)
        case (False, True):
            faults["Defective analog input on driver"] = (driver,)
        case _ if bank_failed[(bank, d)]:
            faults["Bank supply voltage of driver out of tolerance"] = (driver,)
        case _:
            faults["Output voltage of driver out of tolerance"] = (driver,)
```
    ]
)

Ein defekter analoger Eingang zeigt sich in beiden Richtungen, einmal als Empfänger (Remote falsch) und einmal als Treiber (Readback falsch). Da beide Richtungen dieselbe Meldung erzeugen, werden die Fehler in einem Dictionary gesammelt. Dadurch wird derselbe Fehler nur einmal im Bericht aufgeführt.

Im Bericht werden für jede Messung neben dem Ergebnis auch die Sollspannungen und die in beiden Richtungen gemessenen Spannungen ausgegeben.

#figure(
    caption: "Ergebnisse des analogen Loopback-Tests",
    table(
        columns: (auto, 1fr, auto),
        align: left,
        table.header([*Ergebnis*], [*Bedeutung*], [*Betroffener Brick*]),
        [`PASSED`], [Alle Spannungen liegen in der Toleranz], [-],
        [`FAILED`], [Defekter analoger Eingang], [Messender Brick],
        [`FAILED`], [Ausgangsspannung ausserhalb der Toleranz], [Treibender Brick],
        [`FAILED`], [Bankversorgung ausserhalb der Toleranz], [Treibender Brick],
        [`FAILED`], [Falsche Leitungsspannung in beiden Richtungen, weitere Diagnose nötig], [Beide],
    )
)


==== Einschränkungen

Der @ADC wird nur an den Punkten $0"V"$ und $U_"bank"$ geprüft. Spannungen zwischen $0"V"$ und $U_"bank"$ können mit einem getriebenen Ausgang nicht erzeugt werden. Ein Fehler, der nur in diesem Bereich auftritt (z.B. eine Nichtlinearität des @ADC), wird deshalb nur über die drei verschiedenen Bankspannungen teilweise erkannt.

Ein Unterbruch zeigt sich im Muster S1 #C, S2 #X, S3 #C, S4 #X. Da die beiden Richtungen einzeln ausgewertet werden, wird dieser Fehler als defekter analoger Eingang auf beiden Bricks gemeldet (siehe @anhang-fehleranalyse). Ein Unterbruch sollte allerdings bereits durch den vorangehenden digitalen Loopback-Test erkannt werden.

Ist ein @ADC\-Kanal einem falschen IO zugeordnet (vertauschter Kanal), misst der Brick bei diesem IO eine falsche Spannung. Der Fehler wird als defekter analoger Eingang gemeldet, aber nicht als Vertauschung erkannt.


#pagebreak()

== Testen von Kurzschlüssen zwischen IOs (Walking One)

=== Konzept

Der Loopback-Test aus dem vorherigen Kapitel prüft jede Leitung einzeln. Ein Kurzschluss zwischen zwei IOs, z.B. eine Lötbrücke zwischen zwei benachbarten Pins, wird dabei nicht erkannt: Die übrigen Leitungen werden während der Messung nicht getrieben und deshalb auch nicht ausgewertet.

Beim Walking-One-Test wird deshalb jeweils genau ein IO auf `HIGH` getrieben, während alle 32 IOs gelesen werden. Der getriebene Pegel "wandert" so nacheinander über alle IOs. Damit die nicht getriebenen Leitungen nicht floaten, wird bei allen IOs der Pull-Down-Widerstand eingeschaltet. Ohne Fehler liest nur der getriebene IO selbst `HIGH`, alle anderen IOs lesen `LOW`. Liest ein weiterer IO ebenfalls `HIGH`, ist er mit dem getriebenen IO kurzgeschlossen.

#figure(
    caption: "Testen von Kurzschlüssen - Konzept",
    drawio(path("../assets/drawIO/tests.drawio"), page: "walking_one")
)



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

=== Konzept

Jeder IO des IO-Bricks besitzt einen zuschaltbaren Pull-Up- oder Pull-Down-Widerstand von #box[$10"k"Omega plus.minus 5%$] #todo[Toleranz überprüfen]. Geprüft wird, ob beide Widerstände vorhanden sind und die Werte in der Toleranz liegen.

Während des ganzen Tests treibt kein Brick. Alle IOs beider Bricks sind als Eingang konfiguriert, und die Leitung wird nur über die Pull-Widerstände auf einen Pegel gezogen. Die Spannung der Leitung wird mit dem analogen Eingang gemessen. Gemessen wird mit dem Tester #todo[mit beiden bricks messen] , da dieser ein bekannt funktionierender Brick ist.

Die Abbildung unten zeigt die Messung an einem IO. Dabei werden immer zwei Pull-Widerstände entgegengesetzt geschaltet. Die beiden Widerstände bilden so einen Spannungsteiler, und die Leitung liegt bei etwa der halben Bankspannung. Fehlt einer der beiden Widerstände, zieht der andere die Leitung auf seine Schiene ($"GND"$ oder $V_"bank"$).

#figure(
    caption: "Testen der konfigurierbaren Pull-Up/Pull-Down-Widerstände - Konzept",
    drawio(path("../assets/drawIO/tests.drawio"), page: "pull_up_down")
)

#figure(
    caption: "Konfigurationen der Pull-Widerstände",
    table(
        columns: (auto, auto, auto, 1fr),
        align: left,
        table.header([*Testee*], [*Tester*], [*Erwartet*], [*Zweck*]),
        [`NONE`], [`PULL_UP`], [`HIGH`], [Referenz: Pull-Widerstände des Prüflings lassen sich abschalten],
        [`NONE`], [`PULL_DOWN`], [`LOW`], [Referenz: Pull-Widerstände des Prüflings lassen sich abschalten],
        [`PULL_UP`], [`PULL_DOWN`], [`MID`], [Pull-Up des Prüflings vorhanden und in der Toleranz],
        [`PULL_DOWN`], [`PULL_UP`], [`MID`], [Pull-Down des Prüflings vorhanden und in der Toleranz],
    )
)

In den ersten beiden Konfigurationen ist der Pull-Widerstand des Prüflings ausgeschaltet. Die Leitung muss deshalb auf dem Pegel des Testers liegen. Bleibt ein Pull-Widerstand des Prüflings trotzdem eingeschaltet, entsteht ein Spannungsteiler und die Leitung liegt im Bereich `MID`.

#pagebreak()

==== Spannungsbereiche

Die gemessene Spannung $U$ wird bei einer Bankspannung von $U_"bank" = 3.3"V"$ einem der folgenden Bereiche zugeordnet:

#figure(
    caption: "Spannungsbereiche des Pull-Widerstandstests",
    table(
        columns: (auto, 1fr, auto),
        align: left,
        table.header([*Bereich*], [*Bedeutung*], [*Grenzen bei 3.3 V*]),
        [`LOW`], [Leitung auf GND gezogen], [$0"V" ... 0.2"V"$],
        [`MID`], [Spannungsteiler aus Pull-Up und Pull-Down], [$1.47"V" ... 1.83"V"$],
        [`HIGH`], [Leitung auf die Bankspannung gezogen], [$3.1"V" ... 3.5"V"$],
        [`OTHER`], [Keiner der obigen Bereiche], [_restliche Werte_],
    )
)

Für die Schienen `LOW` und `HIGH` wird eine Abweichung von $plus.minus 0.2"V"$ zugelassen. Ein einzelner Pull-Up misst bei $3.3"V"$ nur rund $3.17"V"$ bis $3.24"V"$, da der @ADC den $10"k"Omega$-Widerstand belastet.

Für den Bereich `MID` wird die Toleranz der Widerstände berücksichtigt. Im ungünstigsten Fall liegt ein Widerstand an der unteren und der andere an der oberen Toleranzgrenze:

$
  U_"MID" = U_"bank" dot R_"down" / (R_"up" + R_"down"), quad
  (1 - 0.05) / 2 dot U_"bank" <= U_"MID" <= (1 + 0.05) / 2 dot U_"bank"
$

Zusätzlich wird eine Messtoleranz des @ADC von $plus.minus 0.1"V"$ zugelassen. Daraus ergibt sich der Bereich von $1.47"V"$ bis $1.83"V"$.

==== Fehlerinterpretation

Aus der Konfiguration und dem gemessenen Bereich lässt sich der Fehler bestimmen und einem Brick zuordnen.

#figure(
    caption: "Fehlerinterpretation Pull-Widerstände",
    table(
        columns: (auto, auto, auto, 1fr, auto),
        align: left,
        table.header([*Prüfling*], [*Tester*], [*Gemessen*], [*Fehler*], [*Brick*]),
        [`NONE`], [`PULL_UP`], [`MID`], [Pull-Down des Prüflings bleibt eingeschaltet], [Prüfling],
        [`NONE`], [`PULL_UP`], [`LOW`], [Pull-Up des Testers defekt], [Tester],
        [`NONE`], [`PULL_DOWN`], [`MID`], [Pull-Up des Prüflings bleibt eingeschaltet], [Prüfling],
        [`PULL_UP`], [`PULL_DOWN`], [`LOW`], [Pull-Up des Prüflings fehlt], [Prüfling],
        [`PULL_UP`], [`PULL_DOWN`], [`HIGH`], [Pull-Down des Testers fehlt], [Tester],
        [`PULL_UP`], [`PULL_DOWN`], [`OTHER`], [Widerstandswert ausserhalb der Toleranz], [Beide],
        [`PULL_DOWN`], [`PULL_UP`], [`HIGH`], [Pull-Down des Prüflings fehlt], [Prüfling],
        [`PULL_DOWN`], [`PULL_UP`], [`LOW`], [Pull-Up des Testers fehlt], [Tester],
        [`PULL_DOWN`], [`PULL_UP`], [`OTHER`], [Widerstandswert ausserhalb der Toleranz], [Beide],
        table.cell(colspan: 3)[_Restliche Kombinationen_], [Unklassifizierbarer Fehler], [Beide],
    )
)

*Widerstandswert ausserhalb der Toleranz*: Gemessen wird nur das Verhältnis der beiden Widerstände. Ein falscher Wert lässt sich daher nicht eindeutig einem der beiden Bricks zuordnen.

*Fehler des Testers*: Der Tester gilt zwar als bekannt funktionierend, seine Pull-Widerstände werden aber trotzdem mitgeprüft. Fehlt ein Pull-Widerstand des Testers, würde sonst der Prüfling fälschlicherweise als fehlerhaft gemeldet.


#pagebreak()


=== Umsetzung

Der Test ist in der Klasse ```py PullResistorTest``` umgesetzt. Er ist nicht als kritisch eingestuft. Ein fehlerhafter Pull-Widerstand wird im Bericht aufgeführt, die nachfolgenden Tests werden aber trotzdem ausgeführt. Der Test setzt voraus, dass der digitale Loopback-Test bestanden wurde. Leitungen, die unterbrochen sind oder fest auf einem Pegel hängen, sind damit bereits ausgeschlossen.

==== Vorbereitung und Abschluss

In der Vorbereitung (```py setup()```) wird auf beiden Bricks die Bankspannung auf 3.3 V gesetzt und alle IOs als Eingang konfiguriert. Anschliessend wird gewartet, bis sich die Bankspannung eingeschwungen hat (`BANK_VOLTAGE_SETTLE_TIME`). Im Abschluss (```py teardown()```) werden die Pull-Widerstände aller IOs beider Bricks wieder ausgeschaltet.

==== Konfigurationen und Fehlertabelle

Die Konfigurationen und die Fehlertabelle sind direkt als Tabellen im Code abgebildet. Jede Konfiguration ordnet dem Paar aus Pull-Widerstand des Prüflings und des Testers den erwarteten Bereich zu. Die Fehlertabelle ordnet jeder abweichenden Messung einen Fehler und den betroffenen Brick zu.

#figure(
    kind: "Codeausschnitt",
    supplement: [Codeausschnitt],
    caption: "Konfigurationen und Fehlertabelle (gekürzt)",
    [
```python
# (testee pull, tester pull) -> expected zone
CONFIGS = {
    (P.NONE, P.PULL_UP):        Zone.HIGH,
    (P.NONE, P.PULL_DOWN):      Zone.LOW,
    (P.PULL_UP, P.PULL_DOWN):   Zone.MID,
    (P.PULL_DOWN, P.PULL_UP):   Zone.MID,
}

# (testee pull, tester pull, measured zone) -> (fault, faulty brick)
FAULT_TABLE = {
    (P.NONE, P.PULL_UP, Zone.MID):      ("Pull-down of testee stuck enabled", TESTEE),
    (P.PULL_UP, P.PULL_DOWN, Zone.LOW): ("Pull-up of testee missing", TESTEE),
    ...
}
```
    ]
)

==== Zuordnung der Spannung

Die gemessene Spannung wird in der Methode ```py __zone()``` einem Bereich zugeordnet. Die Grenzen werden aus den Konstanten `RAIL_TOLERANCE`, `VOLTAGE_TOLERANCE` und `PULL_RESISTANCE_TOLERANCE` berechnet.

#figure(
    kind: "Codeausschnitt",
    supplement: [Codeausschnitt],
    caption: "Zuordnung der gemessenen Spannung zu einem Bereich",
    [
```python
DIVIDER_RATIO_MIN = (1 - PULL_RESISTANCE_TOLERANCE) / 2
DIVIDER_RATIO_MAX = (1 + PULL_RESISTANCE_TOLERANCE) / 2

def __zone(voltage, bank_voltage):
    if abs(voltage) <= RAIL_TOLERANCE:
        return Zone.LOW
    if abs(voltage - bank_voltage) <= RAIL_TOLERANCE:
        return Zone.HIGH
    if (DIVIDER_RATIO_MIN * bank_voltage - VOLTAGE_TOLERANCE
            <= voltage <=
            DIVIDER_RATIO_MAX * bank_voltage + VOLTAGE_TOLERANCE):
        return Zone.MID
    return Zone.OTHER
```
    ]
)

==== Messung und Auswertung

Für jede Konfiguration werden die Pull-Widerstände auf allen IOs beider Bricks gleichzeitig gesetzt. Nach der Wartezeit `IO_SETTLE_TIME` misst der Tester die Spannung jedes IOs. Weicht der gemessene Bereich vom erwarteten ab, wird der Fehler in der Fehlertabelle nachgeschlagen. Kombinationen, die nicht in der Tabelle enthalten sind, werden als unklassifizierbar gemeldet und beiden Bricks zugeordnet.

#figure(
    kind: "Codeausschnitt",
    supplement: [Codeausschnitt],
    caption: "Messung und Auswertung der Pull-Widerstände",
    [
```python
for (testee_pull, tester_pull), expected_zone in CONFIGS.items():
    testee.set_pull_resistor(testee_pull)
    tester.set_pull_resistor(tester_pull)
    time.sleep(IoBrick.IO_SETTLE_TIME)

    for bank, io in IoBrick.all_ios():
        voltage = tester.get_io_voltage(bank, io)
        zone = self.__zone(voltage, bank_voltage)
        if zone == expected_zone:
            result.add_pass(...)
            continue
        fault, faulty = FAULT_TABLE.get(
            (testee_pull, tester_pull, zone),
            ("Unclassifiable fault, further diagnosis required", BOTH),
        )
        result.add_fail(...)
```
    ]
)

Pro IO werden vier Konfigurationen geprüft, insgesamt also $4 dot 32 = 128$ Messungen. Im Bericht wird für jede Messung neben dem Ergebnis auch der erwartete Spannungsbereich und die gemessene Spannung ausgegeben.

#figure(
    caption: "Ergebnisse des Pull-Widerstandstests",
    table(
        columns: (auto, 1fr, auto),
        align: left,
        table.header([*Ergebnis*], [*Bedeutung*], [*Betroffener Brick*]),
        [`PASSED`], [Gemessene Spannung liegt im erwarteten Bereich], [-],
        [`FAILED`], [Fehler gemäss Fehlertabelle], [Prüfling, Tester oder beide],
        [`FAILED`], [Unklassifizierbarer Fehler, weitere Diagnose nötig], [Beide],
    )
)


==== Einschränkungen

Der Wert der Widerstände wird nicht absolut gemessen, sondern nur das Verhältnis von Pull-Up zu Pull-Down. Weichen beide Widerstände in die gleiche Richtung ab, bleibt das Verhältnis gleich und der Fehler wird nicht erkannt.

Geprüft wird nur bei einer Bankspannung von $3.3"V"$. Ob die Pull-Widerstände auch bei anderen Bankspannungen korrekt arbeiten, wird nicht geprüft.

Der vorangehende Walking-One-Test ist auf funktionierende Pull-Down-Widerstände angewiesen. Meldet der Walking-One-Test einen Kurzschluss und dieser Test gleichzeitig einen fehlenden Pull-Down am selben IO, ist der gemeldete Kurzschluss vermutlich eine Folge des fehlenden Pull-Downs.
