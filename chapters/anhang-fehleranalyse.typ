// Anhang: Fehleranalyse IO-Brick (mögliche Produktionsfehler und deren Erkennung)

#let ok   = text(fill: rgb("#2e7d32"), weight: "bold")[#sym.checkmark]
#let plan = text(fill: rgb("#e69100"), weight: "bold")[WIP]
#let open = text(fill: rgb("#c62828"), weight: "bold")[#sym.crossmark]

#let group(body) = table.cell(
    colspan: 6,
    fill: gray.lighten(80%),
)[*#body*]

#page(flipped: true)[

= Fehleranalyse IO-Brick <anhang-fehleranalyse>

Die folgende Tabelle mögliche Fehler auf, die bei der Produktion eines IO-Bricks auftreten können, und ordnet jedem Fehler eine Testmethode zu.

Status: #ok (Test implementiert), #plan (Work In Progress), #open = (Test nicht implementiert).

#show figure.where(kind: table): set block(breakable: true)
#figure(
    caption: "Fehleranalyse IO-Brick",
    table(
        columns: (auto, 1fr, 1fr, 1fr, 1.8fr, auto),
        align: left + top,
        table.header(
            [*#sym.hash*],
            [*Ort*],
            [*Produktionsfehler*],
            [*Auswirkung*],
            [*Erkennung / Testmethode*],
            [*Status*],
        ),

        // ---------------------------------------------------------------
        group[A: Versorgung / Aufstarten],

        [A1], [12V-Eingang (L1, D1, Regler)],
        [Bauteil fehlt / vertauscht, kalte Lötstelle],
        [Brick startet nicht],
        [Kommunikationstest (Keine SDO-Antwort)],
        [#ok],


        // ---------------------------------------------------------------
        group[B: CAN / Identität],

        [B1], [CAN-Transceiver],
        [Defekt, kalte Lötstelle],
        [Keine Antwort],
        [Kommunikationstest],
        [#ok],


        [B2], [Identität],
        [Seriennummer nicht programmiert],
        [Dateiname des Logs ungültig],
        [Kommunikationstest],
        [#plan],

        // ---------------------------------------------------------------
        group[C: Bankspannung (2x)],

        [C1], [V#sub[Bank]],
        [Kurzschluss / Überlast],
        [Ganze Bank ohne Funktion],
        [Gruppenauswertung: alle 16 IOs einer Bank fehlerhaft → Fehler der Bank],
        [#open],

        // ---------------------------------------------------------------
        group[D: Signalpfad pro IO (32x)],

        [D1], [Pegelwandler MCU → Pin],
        [Kanal defekt / Unterbruch],
        [IO kann nicht treiben],
        [Loopback Test],
        [#ok],

        [D2], [Pegelwandler Pin → MCU],
        [Kanal defekt],
        [IO kann nicht lesen],
        [Loopback Test],
        [#ok],

        [D3], [DIR-Leitung],
        [Unterbruch / festhängend],
        [IO bleibt in einer Richtung],
        [Loopback Test],
        [#ok],

        [D4], [Lötstelle Pegelwandler - Steckerkontakt],
        [Unterbruch],
        [Leitung unterbrochen],
        [Loopback; zuverlässig nur mit *entgegengesetztem Pull beim Empfänger*, sonst behält die floatende Leitung ihren letzten Pegel (*analog readback implementieren*)],
        [#plan],

        [D5], [Pin-Knoten],
        [Kurzschluss nach V#sub[Bank] / GND],
        [Leitung bleibt HIGH],
        [Loopback-Test],
        [#ok],

        [D6], [Benachbarte Pins],
        [Lötbrücke zwischen zwei IOs],
        [Zweiter IO folgt dem ersten],
        [Walking One (alle 32 IOs lesen)],
        [#ok],

        [D7], [Layout, Bestückung, Firmware-Mapping],
        [IOs vertauscht],
        [Falscher IO reagiert],
        [Walking One: IO n wird getrieben, beim Gegenüber reagiert IO m → "vertauscht"],
        [#plan],


        // ---------------------------------------------------------------
        group[E: Pull-Widerstand pro IO (10k + IO-Expander)],

        [E1], [10k-Widerstand],
        [Fehlt / Unterbruch],
        [Kein Pull],
        [Pull-Test Schritt 1 (Leitung vorher auf den entgegengesetzten Pegel laden)],
        [#plan],

        [E2], [10k-Widerstand],
        [Falscher Wert (z. B. 1k oder 100k)],
        [Spannungsteiler stimmt nicht],
        [Spannungsteiler-Test: Prüfling PU, Referenz PD → erwartet V#sub[Bank]/2 ± Toleranz],
        [#plan],

        [E3], [Expander-Pin],
        [Hängt fest auf HIGH/LOW],
        [Pull immer aktiv],
        [*Zustand NONE testen:* Referenz PU, Prüfling NONE → erwartet ≈ V#sub[Bank] (nicht V#sub[Bank]/2)],
        [#open],

        // ---------------------------------------------------------------
        group[F: ADC pro IO],

        [F1], [Leiterbahn ADC → MCU],
        [Unterbruch],
        [Messwert 0 V / zufällig],
        [Referenz-Brick treibt LOW/HIGH, der ADC des Prüflings muss folgen],
        [#open],

        [F2], [Referenz / Spannungsteiler],
        [Verstärkungs- oder Offsetfehler],
        [Messwerte um einen Faktor falsch],
        [3 Messpunkte: 0 V, V#sub[Bank]/2 (Pull-Teiler), V#sub[Bank]; Vergleich mit dem ADC des Referenz-Bricks],
        [#open],

        [F3], [ADC-Mapping],
        [Kanäle vertauscht],
        [Falscher Kanal reagiert],
        [Analoge Messung parallel zu D8 auswerten],
        [#open]
    )
)
]
