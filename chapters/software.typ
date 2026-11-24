
#import "@preview/mannot:0.4.0": *
#import "@preview/dashy-todo:0.1.3": todo


= Software

Die Software, mit dem Namen *pinpoint*, ist komplett in Python @ref_python, als eine Kommandozeilenanwendung, geschrieben.
Die Software führt alle Tests aus dem Kapitel Testszenarien automatisch nacheinander aus und gibt am Ende ein Testergebnis pro Brick aus.
Die Software läuft dabei unter Linux und Windows.


== Aufbau

#todo()[Finales SysMl Diagramm einfügen]


=== Hardware Abstraktion

Der IO-Brick wird in der Software als einzelne Klasse ```py class IoBrick``` dargestellt. Diese verfügt über Methoden um die Funktionen des IO-Bricks zu verwenden.

Beispielsweise kann so wie folgt ein IO angesteuert werden.
```python
brick = IoBrick(...)
brick.set_io_dir(IoBrick.Bank.A, 0, IoBrick.Direction.OUTPUT)   # Set IO A0 to OUTPUT
brick.set_io_level(IoBrick.Bank.A, 0, IoBrick.Level.HIGH)       # Set IO A0 to HIGH
```

Der IO-Brick #todo()[UML Diagramm IO-Brick klasse] verfügt über Konfigurationsdaten und Metadaten welche beim erstellen

==== Schnittstelle

Der IO-Brick wird direkt über CAN angesteuert dazu steht ein @EDS\-File zur Verfügung



#pagebreak()


== Ablauf

Das unten dargestellte Sequenzdiagramm stellt den Ablauf der Software dar.

#figure(caption: "Sequenzdiagramm Software")[
    #import "../assets/diagrams/software_sequence_diagram.typ": diagram
    #diagram
]


#pagebreak()



== Testergebnis

Die Testergebnisse können auf der Konsole ausgegeben werden oder in Dateien abgespeichert werden.


=== Datei

Toradex verwendet bereits einen fest definierten Dateinamen für Log-Dateien.
Der Dateiname besteht dabei aus folgenden Komponenten:
- Seriennummer (z.B. `09100480`)
- Produkt-ID und Version (z.B. `02371100`) 
- Testdatum und Zeit im format `YYYYMMDDhhmmss` (z.B `20260924075825`)
- Kriterium PASS: `P` oder FAIL: `F`


Zusammengesetzes Beispiel:
$
    markul("09100480", #red, stroke: #1pt, #<mannot_serial>)"-"markul("02371100", #blue, stroke: #1pt, #<mannot_product_id>)"-"markul("20260924075825", #green, stroke: #1pt, #<mannot_date>)"-"markul("F", #purple, stroke: #1pt, #<mannot_pass_fail>)".log"

    #annot(<mannot_serial>)[Seriennummer]
    #annot(<mannot_product_id>)[Produkt-ID]
    #annot(<mannot_date>)[Datum & Zeit]
    #annot(<mannot_pass_fail>)[Kriterium]
$
