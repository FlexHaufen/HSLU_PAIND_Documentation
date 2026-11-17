
#import "@preview/oasis-align:0.4.1": oasis-align


= Übersicht der Hardware



== IO-Brick

#oasis-align(
    figure(
        caption: "IO-Brick",
        image("../assets/io-brick-3d-top.png")
    ),
    figure(
        caption: "IO-Brick Blockschaltbild",
        image("../assets/io-brick-blockschaltbild.png")
    )
)

\

Der IO-Brick verfügt über 32 identische GPIOs, welche je über einen digital Ein-/Ausgang, einen analogen eingang und einen zuschaltbaren Pull-Up-/Down Widerstand verfügen.


Das Blockschaltbild eines einzelnen IOs sieht dabei wie folgt aus:

#figure(
    caption: "IO-Brick Blockschaltbild IO",
    image("/assets/io-brick-blockschaltbild_io.png", width: 80%)
)


#pagebreak()


== IO Selftest BP
Um die IO-Bricks gegenseitig zu testen steht eine Basisplatte zur Verfügung.
Auf dieser können zwei IO-Bricks auf die PCIEx4 Stecker aufgesteckt werden und deren IOs über Jumper verbunden werden.



#oasis-align(
    figure(
        caption: "IO Selftest BP",
        image("../assets/io-selftest-bp-3d-top.png") 
    ),
    figure(
        caption: "IO Selftest BP Blockschaltbild",
        image("../assets/io-selftest-bp.png")
    )
)

Die Platine verfügt zusätzlich über zwei Stecker für den CAN-Bus, sowie ein Stecker für die 12V-Speisung.