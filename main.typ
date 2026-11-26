#import "@preview/abbr:0.3.1"
#import "@local/stddoc:1.0.1":*


#show:stddoc-thesis.with(
    title: "Produktionstest für IO Brick",
    subtitle: "Industriearbeit",
    author: "Janin Indergand",
    location: "Hochschule Luzern Technik & Architektur"
)


// abbreviations
#show: abbr.show-rule
#abbr.load("abbreviations.csv")
#abbr.config(style: it => text(it), space-char: sym.space)  // custom style

// figure alignment
//#show figure: set align(left)
//#show figure.caption: set align(left)

// table formatting / coloring
#set table(fill: (x, y) => if y == 0 { gray.lighten(50%) } else { none })


//#include "chapters/abstract.typ"
//#pagebreak()


#outline()
#pagebreak()



#include "chapters/einleitung.typ"
#pagebreak()

#include "chapters/hardware.typ"
#pagebreak()

#include "chapters/software.typ"
#pagebreak()

#include "chapters/testszenarien.typ"
#pagebreak()


// TODO:    verifikation & validierung
//          - überprüfen des usecase
// TODO:    herausvorderung während der arbeit
//          - fehler welche gefunden worden sind in der firmware          



#include "chapters/fazit.typ"
#pagebreak()



= Abbildungsverzeichnis
#outline(title: none, target: figure.where(kind: image))

= Tabellenverzeichnis
#outline(title: none, target: figure.where(kind: table))

#abbr.list(title: "Abkürzungsverzeichnis")

= Literaturverzeichnis
#bibliography(title: none, "references.yml")


// APPENDIX

#set heading(numbering: "A.1.", supplement: [Appendix])
#counter(heading).update(0)

//#pagebreak()
//#include "chapters/ki-nachweis.typ"
// 

#include "chapters/anhang-fehleranalyse.typ"