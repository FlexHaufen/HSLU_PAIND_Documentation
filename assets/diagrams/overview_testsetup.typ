#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
#import "@local/stddoc:1.0.1"


#let blk(pos, title, sub, fill: stddoc.white, h: 2.2cm, ..args) = node(
  pos, [#title \ #text(size: 7pt, sub)],
  fill: fill, stroke: 0.5pt, corner-radius: 8pt,
  width: 3cm, height: h, ..args,
)

#let diagram =[
    #diagram(
        spacing: (2cm, 1cm),
        blk((0,0), "Host", "PC / Laptop"),
        blk((2,0), "Powersupply", []),
        blk((0,1), "IO-Brick 1", "PCB", fill: stddoc.denim),
        blk((1,1), "IO Selftest BP", "PCB", h: 5cm, name: <bp>),
        blk((2,1), "IO-Brick 2", "PCB", fill: stddoc.denim),

        edge((0,0), (0.9,0), (0.9,1), "<->", [CANopen], label-anchor: "east"),
        edge((2,0), (1.1,0), (1.1,1), "->", [+12VDC], label-anchor: "west"),
        edge((0,1), (1,1), "<->", [PCIEx4]),
        edge((1,1), (2,1), "<->", [PCIEx4]),
    )
]