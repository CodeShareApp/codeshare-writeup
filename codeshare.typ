// CodeShare — a study write-up. Build with `mise run build` (see README.md).

#import "lib.typ": *
#show: template

// ---------------------------------------------------------------- title page
#page(header: none, footer: none, margin: (x: 14mm, top: 26mm, bottom: 16mm))[
  #align(center)[
    #box(radius: 22pt, clip: true, image("/images/app-icon.png", width: 46mm))
    #v(12mm)
    #text(size: 34pt, weight: "bold", fill: c.text)[CodeShare]
    #v(2mm)
    #text(size: 13pt, fill: c.accent)[A study write-up]
    #v(8mm)
    #block(width: 104mm)[
      #set par(justify: false)
      #set text(size: 10.5pt, fill: c.muted)
      A private iPhone app for a household to keep and share Albert Heijn deposit vouchers and a
      Bonuskaart, with a Go backend that stores only sealed blobs. What was built, why it was built
      that way, how the cryptography works, and what review caught along the way.
    ]
  ]
  #v(1fr)
  #line(length: 100%, stroke: 0.5pt + c.hair)
  #grid(
    columns: (1fr, 1fr),
    row-gutter: 0.7em,
    text(size: 8.5pt, fill: c.muted)[State described],
    align(right, text(size: 8.5pt, fill: c.text)[3 October 2026]),
    text(size: 8.5pt, fill: c.muted)[Repositories],
    align(right, text(size: 8.5pt, fill: c.text)[codeshare-ios, codeshare-api, codeshare-web (jj)]),
    text(size: 8.5pt, fill: c.muted)[Stack],
    align(right, text(size: 8.5pt, fill: c.text)[SwiftUI · GRDB · CryptoKit · Go · Echo v5 · PostgreSQL 18]),
  )
]

// ---------------------------------------------------------------- contents
#page(header: none)[
  #text(size: 22pt, weight: "semibold")[Contents]
  #v(2mm)
  #line(length: 22mm, stroke: 2pt + c.accent)
  #v(4mm)
  #set text(size: 8pt)
  #set par(leading: 0.45em, justify: false)
  #set text(hyphenate: false)
  #columns(2, gutter: 6mm, outline(title: none, depth: 2, indent: 1.2em))
]

#include "chapters/01-problem.typ"
#include "chapters/02-constraints.typ"
#include "chapters/03-architecture.typ"
#include "chapters/04-ios.typ"
#include "chapters/05-backend.typ"
#include "chapters/06-crypto.typ"
#include "chapters/07-sync.typ"
#include "chapters/08-infra.typ"
#include "chapters/09-review.typ"
#include "chapters/10-incidents.typ"
#include "chapters/11-next.typ"
#include "chapters/12-rewe.typ"
#include "chapters/13-parking.typ"
#include "chapters/appendix.typ"
