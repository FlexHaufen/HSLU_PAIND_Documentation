#import "@preview/chronos:0.2.1"
#import "@local/stddoc:1.0.1"

#let par-name(title, subtitle) = align(center)[
  *#title* \
  #text(size: 0.8em, subtitle)
]



#let diagram = scale(80%,reflow: true)[
    #chronos.diagram({
        import chronos: *

        _par("U", display-name: "User", shape: "actor", show-bottom: false)
        _par("P",  display-name: par-name("Pinpoint", "app"), color: stddoc.white, show-bottom: false)
        _par("TR", display-name: par-name("TestRunner", "core"), color: stddoc.teal, show-bottom: false)
        _par("T",  display-name: par-name("Tests", "Communication, Digital, Analog"), color: stddoc.teal, show-bottom: false)
        _par("IB", display-name: par-name("IoBrick", "hardware driver"), color: stddoc.cyan, show-bottom: false)
        _par("IO", display-name: par-name("IO-Bricks", "tester + testee via CAN"), color: stddoc.denim, show-bottom: false)

        _seq("U", "P", comment: "start", enable-dst: true)

        _grp("loop", {
            _seq("U", "P", comment: "scan QR code")
            _seq("P", "TR", comment: "run all tests", enable-dst: true)

            _grp("loop", desc: "for each test", {
            _seq("TR", "T", comment: "run test", enable-dst: true)
            _seq("T", "IB", comment: "drive / read IOs", enable-dst: true)
            _seq("IB", "IO", comment: "CANopen SDO", enable-dst: true)
            _seq("IO", "IB", comment: "SDO response", dashed: true, disable-src: true)
            _seq("IB", "T", comment: "levels / voltages / IDs", dashed: true, disable-src: true)
            _seq("T", "TR", comment: "pass / fail per brick", dashed: true, disable-src: true)
            })

            _seq("TR", "P", comment: "test report", dashed: true, disable-src: true)
            _seq("P", "U", comment: "report per brick", dashed: true)
        })
        _evt("P", "disable")
    })
]