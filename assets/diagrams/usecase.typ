#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
#import "@local/stddoc:1.0.1"

#let diagram = [
  #diagram(
    node-stroke: 0.6pt,
    node-corner-radius: 5pt,
    node-inset: 10pt,
    edge-stroke: 0.6pt,
    spacing: (2.5em, 2em),

    node((0, 0), [start software]),
    node((1, 0), [scan barcode]),
    node((2, 0), [run tests], width: 7em, height: 5em, corner-radius: 12pt),
    node((3, 0), [log test results]),

    edge((0, 0), (1, 0), "-|>"),
    edge((1, 0), (2, 0), "-|>"),
    edge((2, 0), (3, 0), "-|>"),

    // loop back: down, left two columns, up into "scan barcode"
    edge((3, 0), "d,ll,u", "-|>"),
  )
]