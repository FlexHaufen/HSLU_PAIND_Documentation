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

Die folgende Tabelle listet mögliche Fehler auf, die bei der Produktion eines IO-Bricks auftreten können, und ordnet jedem Fehler eine Testmethode zu.

Status: #ok (Test implementiert), #plan (Work In Progress), #open (Test nicht implementiert).

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
        [Kommunikationstest (Seriennummer und Produktcode prüfen, noch nicht umgesetzt)],
        [#open],

        // ---------------------------------------------------------------
        group[C: Bankspannung (2x)],

        [C1], [V#sub[Bank]],
        [Kurzschluss / Überlast],
        [Ganze Bank ohne Funktion],
        [Analoger Loopback-Test: Gruppenauswertung, alle 16 IOs einer Bank mit falscher Spannung (Readback und Remote) → Fehler der Bankversorgung],
        [#ok],

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
        [Digitaler Loopback: nicht zuverlässig, die floatende Leitung behält ihren letzten Pegel (*entgegengesetzter Pull beim Empfänger* noch nicht umgesetzt). Analoger Loopback: Unterbruch wird erkannt (Remote-Spannung falsch), aber als defekter analoger Eingang beider Bricks gemeldet],
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


        // ---------------------------------------------------------------
        group[E: Pull-Widerstand pro IO (10k + IO-Expander)],

        [E1], [10k-Widerstand],
        [Fehlt / Unterbruch],
        [Kein Pull],
        [Pull-Widerstandstest: Pull des Prüflings gegen entgegengesetzten Pull des Testers, fehlender Widerstand → Leitung auf Schiene statt V#sub[Bank]/2],
        [#ok],

        [E2], [10k-Widerstand],
        [Falscher Wert (z. B. 1k oder 100k)],
        [Spannungsteiler stimmt nicht],
        [Pull-Widerstandstest: Prüfling PU / Tester PD und umgekehrt → erwartet V#sub[Bank]/2 ± Toleranz (nur bei 3.3 V)],
        [#ok],

        [E3], [Expander-Pin],
        [Hängt fest auf HIGH/LOW],
        [Pull immer aktiv],
        [Pull-Widerstandstest, Referenzkonfigurationen: Prüfling NONE / Tester PU → erwartet ≈ V#sub[Bank], Prüfling NONE / Tester PD → erwartet ≈ 0 V (nicht V#sub[Bank]/2)],
        [#ok],

        // ---------------------------------------------------------------
        group[F: ADC pro IO],

        [F1], [Leiterbahn ADC → MCU],
        [Unterbruch],
        [Messwert 0 V / zufällig],
        [Analoger Loopback-Test: Tester treibt HIGH/LOW, der ADC des Prüflings muss folgen (Remote-Messung)],
        [#ok],

        [F2], [Referenz / Spannungsteiler],
        [Verstärkungs- oder Offsetfehler],
        [Messwerte um einen Faktor falsch],
        [Analoger Loopback-Test: Messpunkte 0 V und V#sub[Bank] bei 1.0 V, 2.0 V und 3.3 V, absoluter Vergleich (±0.1 V) und Vergleich mit dem ADC des Testers],
        [#ok]
    )
)
]
