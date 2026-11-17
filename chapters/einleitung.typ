
= Einleitung



== Ausgangslage
Die Firma Toradex produziert mehrere hundert IO-Bricks als internes Betriebsmittel. 
Jeder IO-Brick verfügt über 32 IOs, aufgeteilt auf zwei Bänke mit jeweils 16 IOs. 
Die IOs können als digitale Ein- und Ausgänge sowie als analoge Eingänge verwendet werden.
Zusätzlich verfügt jeder IO über einen zuschaltbaren Pull-Up/Pull-Down-Widerstand.


Die Ausgangspannung der beiden IO-Bänke kann variabel zwischen $0"V"$ und $3,3"V"$  betragen. 

Zur Produktion und Prüfung der IO-Bricks steht eine Basisplatte zur Verfügung. 
Über diese können die IOs zweier IO-Bricks jeweils 1:1 miteinander verbunden werden,
beispielsweise IO 1 von Brick 1 mit IO 1 von Brick 2.

Die Kommunikation mit den IO-Bricks erfolgt über CANopen. 
Hierfür steht ein @EDS zur Verfügung. Zusätzlich besitzen die IO-Bricks eine UART-Schnittstelle mit Zephyr Shell, welche hauptsächlich zu Debug- und Diagnosezwecken verwendet wird.

Die Prüfung der IO-Bricks soll durch eine unter Linux laufende Python-Anwendung automatisiert werden. Die Kommunikation zwischen Testsoftware und IO-Bricks erfolgt über einen CAN-zu-USB-Adapter.

#figure(
    caption: "Übersicht Testaufbau ",
    image("/assets/overview.png", width: 80%)
)

Die Software wird dabei primär von Produktionsmitarbeiter verwendet. Die Benutzer verfügen über Erfahrung im Testen von Elektronik-PCBs, besitzen jedoch keine vertiefte Ausbildung in Elektronik oder Linux.

Das Aufsetzen und die Wartung der Testumgebung sowie die Diagnose komplexerer Probleme werden durch Entwickler übernommen. Der reguläre Testablauf soll jedoch ohne Unterstützung eines Entwicklers durchgeführt werden können.


#pagebreak()



== Zielsetzung und Abgrenzung


Ziel des Projekts ist die Entwicklung einer unter Linux ausführbaren Python-Testsoftware, welche die automatisierte und reproduzierbare Funktionsprüfung der IO-Bricks ermöglicht. Die Software soll einen einfachen Testablauf für Produktionsmitarbeitende bereitstellen, Fehler zuverlässig erkennen und die Testergebnisse nachvollziehbar dokumentieren.

Die nachfolgenden Punkte gehören nicht zum Umfang dieses Projekts:
- Entwicklung oder Änderung der IO-Brick-Firmware
- Entwicklung der IO-Brick-Hardware
- Entwicklung zusätzlicher Hardware zur Durchführung der Tests


// TODO
#text(fill: red)[

Ziel ist es die Folgenden potentiellen Fehler festzustellen:

- Leitung / Verbindung:
  - Unterbrüche (Stecker, Lötstellen)
  - Kurzschlüsse zu GND / VCC
  - Kurzschlüsse zwischen IOs

- Eingänge
- Ausgänge
- Pull-Widerstände

- Kommunikation
  - Keine Antwort, Falsche NodeID oder Slot
  - Falsche Identität

]

#pagebreak()

#page(flipped: true)[


== Anforderungen

Unten aufgelistet sind die Anforderungen für das Projekt.
Die Prioritäten sind dabei von 1 bis 3 verteilt. Wobei Anforderungen mit Priorität 1 zwingend Pflichtanforderungen und Anforderungen mit Prioritäten 2 und 3 Wunschanforderungen sind.

#show figure.where(kind: table): set block(breakable: true)
#figure(
    caption: "Anforderungskatalog",

    table(
  columns: (auto, auto, 1fr, 1fr),
  align: left,
  table.header(
    [*#sym.hash*],
    [*Prio.*],
    [*Anforderung*],
    [*Kriterium*],
  ),

  [1],
  table.cell(colspan: 3)[*Bedienung*],

  [1.1],
  [1],
  [*Automatisierter Test:* Nach dem Start des Tests werden alle definierten Prüfungen ohne manuelle Eingriffe bis zum Abschluss durchgeführt.],
  [Der Test läuft nach dem Start selbstständig bis zum Abschluss durch.],

  [1.2],
  [1],
  [*Eindeutiges Testergebnis:* Nach Abschluss des Tests wird eindeutig angezeigt, ob der IO-Brick den Test bestanden hat oder nicht.],
  [Das Testergebnis ist eindeutig als *Bestanden* oder *Nicht bestanden* erkennbar.],

  [2],
  table.cell(colspan: 3)[*Kommunikation*],

  [2.1],
  [1],
  [*CANopen / USB:* Die Software kommuniziert über den vorhandenen CAN-USB-Adapter mit dem IO-Brick über die CANopen-Schnittstelle.],
  [CANopen-Nachrichten können über den CAN-USB-Adapter erfolgreich gesendet und empfangen werden.],

  [2.2],
  [1],
  [*Konfiguration:* Die Software kann die für die definierten Tests erforderlichen CANopen-Objekte konfigurieren und auslesen.],
  [Die benötigten CANopen-Objekte können korrekt geschrieben und ausgelesen werden. Die zurückgelesenen Werte entsprechen den erwarteten Werten.],

  [3],
  table.cell(colspan: 3)[*Funktionale Tests*],

  [3.1],
  [1],
  [*Digitale IO:* Die digitalen Ein- und Ausgangsfunktionen des IO-Bricks können automatisiert geprüft werden.],
  [Fehlerhafte digitale Zustände werden erkannt und als Fehler ausgewiesen.],

  [3.2],
  [1],
  [*Testen der relevanten IOs:* Die definierten Tests können auf alle 32 IOs des IO-Bricks angewendet werden.],
  [Jeder der 32 IOs kann entsprechend seiner vorgesehenen Funktion getestet und eindeutig einem Testergebnis zugeordnet werden.],

  [3.3],
  [2],
  [*Detaillierte Fehlerdiagnose:* Fehler sollen möglichst präzise lokalisiert und relevante Informationen zum Fehler bereitgestellt werden.],
  [Bei einem Fehler werden, sofern verfügbar, mindestens der betroffene IO und relevante Soll-/Istwerte angezeigt.],

  [3.4],
  [2],
  [*Testen der analogen Eingänge:* Die analogen Eingänge können automatisiert getestet werden.],
  [Definierte Eingangswerte werden gemessen und mit den entsprechenden Sollwerten verglichen. Abweichungen ausserhalb der definierten Toleranz werden erkannt.],

  [3.5],
  [2],
  [*Testen der Pull-Widerstände:* Die Funktion der zuschaltbaren Pull-Up- und Pull-Down-Widerstände kann automatisiert überprüft werden.],
  [Die Pull-Up- und Pull-Down-Funktionen können aktiviert und deren erwartetes Verhalten überprüft werden. Fehlerhafte Funktionen werden erkannt.],

  [3.6],
  [2],
  [*Testen der Versorgungsspannung:* Verschiedene konfigurierte Versorgungsspannungen der IO-Bänke können überprüft werden.],
  [Die definierten Versorgungsspannungen können eingestellt bzw. geprüft werden. Abweichungen ausserhalb der definierten Toleranz werden erkannt.],

  [4],
  table.cell(colspan: 3)[*Fehlerbehandlung*],

  [4.1],
  [1],
  [*Fehlererkennung:* Abweichungen von den definierten Testkriterien werden erkannt und der entsprechende Test als fehlgeschlagen markiert.],
  [Ein Test mit einem absichtlich erzeugten Fehler wird zuverlässig als *Nicht bestanden* erkannt.],

  [4.2],
  [3],
  [*Robustheit:* Kommunikationsfehler oder unerwartete Zustände des IO-Bricks führen nicht zu einem unkontrollierten Absturz der Testsoftware.],
  [Bei Kommunikationsfehlern und unerwarteten Zuständen bleibt die Software kontrolliert aktiv und gibt eine verständliche Fehlermeldung aus.],

  [5],
  table.cell(colspan: 3)[*Dokumentation*],

  [5.1],
  [3],
  [*Nachvollziehbarkeit:* Die Testergebnisse können gespeichert werden, sodass sie später nachvollzogen werden können.],
  [Testergebnisse können mit dem von Toradex definieren Dateinamen gespeichert und eindeutig dem getesteten IO-Brick zugeordnet werden. Die gespeicherten Daten sind später von einem Menschen lesbar.],

  [5.2],
  [3],
  [*Bedienungsanleitung:* Die Bedienung und der vorgesehene Testablauf der Testsoftware sind dokumentiert.],
  [Die Dokumentation beschreibt die Inbetriebnahme, den Testablauf, die Interpretation der Testergebnisse und das Vorgehen bei einem fehlgeschlagenen Test.],
)
)


]
