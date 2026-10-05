// Shared styles and helpers for the CodeShare write-up (iPad page).
// Two themes: dark (default) and light, picked with `--input theme=light` (see build.sh).

#let theme = sys.inputs.at("theme", default: "dark")
#assert(theme in ("dark", "light"), message: "theme must be dark or light, got " + theme)
#let dark = theme == "dark"

#let c-dark = (
  bg: rgb("#0E1513"),
  panel: rgb("#16201E"),
  panel2: rgb("#1B2825"),
  text: rgb("#E4EDEA"),
  muted: rgb("#95A6A0"),
  accent: rgb("#5EEAD4"),
  teal: rgb("#0F766E"),
  deep: rgb("#134E48"),
  hair: rgb("#24322E"),
  amber: rgb("#F2C46D"),
  amberbg: rgb("#1E1C14"),
  red: rgb("#FF8A80"),
  redbg: rgb("#211616"),
  blue: rgb("#86D4F5"),
  violet: rgb("#C9B3F5"),
  paper: rgb("#DAD8D0"),
  ink: rgb("#1C1C1A"),
  strong: rgb("#F4FAF8"),
  emph: rgb("#D6E4E0"),
  code: rgb("#BDEFE5"),
)

// Day mode. Fills that carry text in `c.bg` (byte bars, step badges) need these accents
// dark enough for white text.
#let c-light = (
  bg: rgb("#FAFCFB"),
  panel: rgb("#EDF3F1"),
  panel2: rgb("#E3EDEA"),
  text: rgb("#16211E"),
  muted: rgb("#5E6F69"),
  accent: rgb("#0D766B"),
  teal: rgb("#9DD6CD"),
  deep: rgb("#CDEBE5"),
  hair: rgb("#D3DEDA"),
  amber: rgb("#A2600F"),
  amberbg: rgb("#FBF2E1"),
  red: rgb("#B42318"),
  redbg: rgb("#FDECEA"),
  blue: rgb("#1D6FA5"),
  violet: rgb("#6B46C1"),
  paper: rgb("#ECEAE2"),
  ink: rgb("#1C1C1A"),
  strong: rgb("#0B1311"),
  emph: rgb("#2C3A36"),
  code: rgb("#0B5E55"),
)

#let c = if dark { c-dark } else { c-light }

#let body-font = ("IBM Plex Sans", "PingFang TC")
#let mono-font = ("IBM Plex Mono", "PingFang TC")

// ---------------------------------------------------------------- callouts

#let callout(title, body, color: c.accent, fill: c.panel, icon: none) = block(
  width: 100%,
  fill: fill,
  stroke: (left: 2.5pt + color),
  radius: (right: 4pt),
  inset: (left: 10pt, right: 10pt, top: 8pt, bottom: 9pt),
  breakable: true,
  above: 1.1em,
  below: 1.1em,
)[
  #text(fill: color, weight: "semibold", size: 9.5pt, tracking: 0.02em)[#upper(title)]
  #v(-0.35em)
  #set text(size: 10pt)
  #body
]

#let lesson(body, title: "Lesson learned") = callout(title, body, color: c.amber, fill: c.amberbg)
#let note(body, title: "Note") = callout(title, body, color: c.accent, fill: c.panel)
#let warn(body, title: "Limit") = callout(title, body, color: c.red, fill: c.redbg)

// ---------------------------------------------------------------- tables

#let dtable(columns: auto, header: (), ..cells) = {
  set text(size: 9pt)
  set par(justify: false, leading: 0.55em)
  table(
    columns: columns,
    stroke: (x, y) => (
      bottom: if y == 0 { 0.8pt + c.accent } else { 0.5pt + c.hair },
    ),
    fill: (x, y) => if y == 0 { c.panel } else { none },
    inset: (x: 5pt, y: 5pt),
    align: left + top,
    table.header(..header.map(h => text(fill: c.accent, weight: "semibold", size: 8.6pt, h))),
    ..cells,
  )
}

// ---------------------------------------------------------------- figures

#let fig(body, caption) = figure(body, caption: caption, kind: image, supplement: [Figure])

// ---------------------------------------------------------------- diagrams
// Coordinates are lengths from the canvas' top-left corner.

#let canvas(height, body) = block(
  width: 100%,
  height: height,
  breakable: false,
  above: 0.8em,
  below: 0.8em,
  body,
)

#let node(x, y, w, h, body, fill: c.panel2, stroke: c.accent, fg: c.text, size: 8pt, dash: none, radius: 3pt) = place(
  top + left,
  dx: x,
  dy: y,
  rect(
    width: w,
    height: h,
    fill: fill,
    stroke: (paint: stroke, thickness: 0.8pt, dash: dash),
    radius: radius,
    inset: 3pt,
    align(center + horizon, text(size: size, fill: fg, hyphenate: false, body)),
  ),
)

#let label(x, y, body, size: 7.2pt, fg: c.muted, w: auto, al: left) = place(
  top + left,
  dx: x,
  dy: y,
  box(width: w, align(al, par(justify: false, leading: 0.5em, text(size: size, fill: fg, hyphenate: false, body)))),
)

#let arrow(a, b, color: c.muted, thickness: 0.8pt, head: true, dash: none, both: false) = {
  let (x1, y1) = a
  let (x2, y2) = b
  let ang = calc.atan2((x2 - x1) / 1pt, (y2 - y1) / 1pt)
  let s = (paint: color, thickness: thickness, dash: dash)
  place(top + left, line(start: a, end: b, stroke: s))
  let tip(px, py, ang) = {
    let L = 5pt
    let W = 2.4pt
    let bx = px - L * calc.cos(ang)
    let by = py - L * calc.sin(ang)
    place(top + left, polygon(
      fill: color,
      stroke: none,
      (px, py),
      (bx + W * calc.sin(ang), by - W * calc.cos(ang)),
      (bx - W * calc.sin(ang), by + W * calc.cos(ang)),
    ))
  }
  if head { tip(x2, y2, ang) }
  if both { tip(x1, y1, ang + 180deg) }
}

// A polyline with an arrowhead on the last segment.
#let path-arrow(color: c.muted, thickness: 0.8pt, dash: none, ..pts) = {
  let p = pts.pos()
  for i in range(p.len() - 2) {
    place(top + left, line(start: p.at(i), end: p.at(i + 1), stroke: (paint: color, thickness: thickness, dash: dash)))
  }
  arrow(p.at(p.len() - 2), p.at(p.len() - 1), color: color, thickness: thickness, dash: dash)
}

// ---------------------------------------------------------------- EAN-13 (drawn, like the app does)

#let ean-l = ("0001101", "0011001", "0010011", "0111101", "0100011", "0110001", "0101111", "0111011", "0110111", "0001011")
#let ean-g = ("0100111", "0110011", "0011011", "0100001", "0011101", "0111001", "0000101", "0010001", "0001001", "0010111")
#let ean-r = ("1110010", "1100110", "1101100", "1000010", "1011100", "1001110", "1010000", "1000100", "1001000", "1110100")
#let ean-parity = ("LLLLLL", "LLGLGG", "LLGGLG", "LLGGGL", "LGLLGG", "LGGLLG", "LGGGLL", "LGLGLG", "LGLGGL", "LGGLGL")

#let ean13-modules(code) = {
  let d = code.clusters().map(int)
  let par = ean-parity.at(d.at(0)).clusters()
  let s = "101"
  for i in range(6) {
    s += if par.at(i) == "G" { ean-g.at(d.at(i + 1)) } else { ean-l.at(d.at(i + 1)) }
  }
  s += "01010"
  for i in range(7, 13) { s += ean-r.at(d.at(i)) }
  s + "101"
}

#let ean13(code, module: 0.42mm, height: 16mm, ink: black, bg: white, digits: true) = {
  let m = ean13-modules(code)
  let quiet-l = 11
  let quiet-r = 7
  let total = quiet-l + 95 + quiet-r
  box(fill: bg, inset: (y: 2mm), {
    box(width: total * module, height: height, {
      for (i, ch) in m.clusters().enumerate() {
        if ch == "1" {
          place(top + left, dx: (quiet-l + i) * module, rect(width: module + 0.01mm, height: height, fill: ink, stroke: none))
        }
      }
    })
    if digits {
      linebreak()
      box(width: total * module, align(center, text(font: mono-font, size: 7pt, fill: ink, tracking: 0.12em,
        code.slice(0, 1) + "  " + code.slice(1, 7) + "  " + code.slice(7))))
    }
  })
}

// ---------------------------------------------------------------- Code 128, subset C (REWE Pfandbon)

// Symbol values 0–105, 11 modules each (bar first); 105 is Start C. Stop is 13 modules.
#let code128-patterns = (
  "11011001100", "11001101100", "11001100110", "10010011000", "10010001100", "10001001100",
  "10011001000", "10011000100", "10001100100", "11001001000", "11001000100", "11000100100",
  "10110011100", "10011011100", "10011001110", "10111001100", "10011101100", "10011100110",
  "11001110010", "11001011100", "11001001110", "11011100100", "11001110100", "11101101110",
  "11101001100", "11100101100", "11100100110", "11101100100", "11100110100", "11100110010",
  "11011011000", "11011000110", "11000110110", "10100011000", "10001011000", "10001000110",
  "10110001000", "10001101000", "10001100010", "11010001000", "11000101000", "11000100010",
  "10110111000", "10110001110", "10001101110", "10111011000", "10111000110", "10001110110",
  "11101110110", "11010001110", "11000101110", "11011101000", "11011100010", "11011101110",
  "11101011000", "11101000110", "11100010110", "11101101000", "11101100010", "11100011010",
  "11101111010", "11001000010", "11110001010", "10100110000", "10100001100", "10010110000",
  "10010000110", "10000101100", "10000100110", "10110010000", "10110000100", "10011010000",
  "10011000010", "10000110100", "10000110010", "11000010010", "11001010000", "11110111010",
  "11000010100", "10001111010", "10100111100", "10010111100", "10010011110", "10111100100",
  "10011110100", "10011110010", "11110100100", "11110010100", "11110010010", "11011011110",
  "11011110110", "11110110110", "10101111000", "10100011110", "10001011110", "10111101000",
  "10111100010", "11110101000", "11110100010", "10111011110", "10111101110", "11101011110",
  "11110101110", "11010000100", "11010010000", "11010011100",
)
#let code128-stop = "1100011101011"

// Subset C packs two digits per symbol, so this takes an even number of digits only (all a
// Pfandbon needs). Check symbol: (105 + Σ position × value) mod 103.
#let code128c-modules(code) = {
  assert(calc.even(code.len()) and code.clusters().all(d => "0123456789".contains(d)))
  let values = range(0, code.len(), step: 2).map(i => int(code.slice(i, i + 2)))
  let check = calc.rem(values.enumerate().fold(105, (s, p) => s + (p.at(0) + 1) * p.at(1)), 103)
  (105, ..values, check).map(v => code128-patterns.at(v)).join() + code128-stop
}

#let code128c(code, module: 0.3mm, height: 12mm, ink: black, bg: white, digits: true) = {
  let m = code128c-modules(code)
  let quiet = 10
  let total = 2 * quiet + m.len()
  box(fill: bg, inset: (y: 2mm), {
    box(width: total * module, height: height, {
      for (i, ch) in m.clusters().enumerate() {
        if ch == "1" {
          place(top + left, dx: (quiet + i) * module, rect(width: module + 0.01mm, height: height, fill: ink, stroke: none))
        }
      }
    })
    if digits {
      linebreak()
      box(width: total * module, align(center, text(font: mono-font, size: 7pt, fill: ink, tracking: 0.08em, code)))
    }
  })
}

// ---------------------------------------------------------------- QR (from a precomputed matrix)

// Typst has no QR encoder of its own here; the caller passes the module matrix (rows of "0"/"1",
// produced by a QR encoder and verified by decoding the rendered page). Quiet zone: 4 modules.
#let qr-matrix(rows, module: 0.6mm, ink: black, bg: white) = {
  let n = rows.len()
  let quiet = 4
  box(fill: bg, width: (n + 2 * quiet) * module, height: (n + 2 * quiet) * module, {
    for (y, row) in rows.enumerate() {
      for (x, ch) in row.clusters().enumerate() {
        if ch == "1" {
          place(top + left, dx: (quiet + x) * module, dy: (quiet + y) * module,
            rect(width: module + 0.01mm, height: module + 0.01mm, fill: ink, stroke: none))
        }
      }
    }
  })
}

// ---------------------------------------------------------------- byte layout bars

#let bytes-bar(parts, total-width: 100%, height: 9mm) = {
  // parts: array of (label, bytes, color)
  let sum = parts.fold(0, (a, p) => a + p.at(1))
  grid(
    columns: parts.map(p => 1fr * p.at(1) / sum),
    column-gutter: 1.5pt,
    ..parts.map(p => rect(
      width: 100%,
      height: height,
      fill: p.at(2),
      stroke: none,
      radius: 2pt,
      inset: 2pt,
      align(center + horizon, text(size: 7pt, fill: c.bg, weight: "semibold", hyphenate: false)[#p.at(0) \ #str(p.at(1))]),
    ))
  )
}

#let kv(k, v) = [#text(fill: c.muted)[#k] #h(0.3em) #v]

// ---------------------------------------------------------------- document template

#let template(body) = {
  set document(title: "CodeShare: a study write-up", author: "CodeShare project")
  set page(
    width: 164mm,
    height: 236mm,
    margin: (top: 18mm, bottom: 15mm, x: 14mm),
    fill: c.bg,
    header: context {
      let p = here().page()
      if p <= 2 { return }
      let starts = query(heading.where(level: 1)).filter(h => h.location().page() == p)
      if starts.len() > 0 { return }
      let before = query(heading.where(level: 1).before(here()))
      let title = if before.len() > 0 {
        let hd = before.last()
        if hd.numbering != none {
          numbering(hd.numbering, ..counter(heading).at(hd.location())) + h(0.6em) + hd.body
        } else { hd.body }
      } else { [] }
      set text(size: 7.8pt, fill: c.muted)
      grid(
        columns: (1fr, auto),
        text(fill: c.accent, weight: "medium", tracking: 0.04em)[CODESHARE],
        title,
      )
      v(-0.55em)
      line(length: 100%, stroke: 0.5pt + c.hair)
    },
    footer: context {
      let p = here().page()
      if p <= 1 { return }
      set text(size: 7.8pt, fill: c.muted)
      align(center, str(p))
    },
  )
  set text(font: body-font, size: 10pt, fill: c.text, lang: "en", region: "gb", hyphenate: true)
  set par(justify: true, leading: 0.68em, spacing: 1em)
  set heading(numbering: "1.1")
  set list(indent: 0.6em, marker: text(fill: c.accent)[•])
  show list: set par(justify: false)
  show enum: set par(justify: false)
  set enum(indent: 0.6em, numbering: n => text(fill: c.accent, weight: "semibold")[#n.])
  set terms(indent: 0pt, hanging-indent: 1.2em, separator: [ — ])
  show link: set text(fill: c.accent)
  show strong: set text(weight: "semibold", fill: c.strong)
  show emph: set text(fill: c.emph)

  set raw(theme: if dark { "dark.tmTheme" } else { auto })
  show raw: set text(font: mono-font)
  show raw.where(block: false): it => box(
    fill: c.panel,
    inset: (x: 2.5pt, y: 0pt),
    outset: (y: 2.5pt),
    radius: 2pt,
    text(size: 0.88em, fill: c.code, it),
  )
  show raw.where(block: true): it => block(
    width: 100%,
    fill: c.panel,
    stroke: 0.5pt + c.hair,
    radius: 4pt,
    inset: (x: 8pt, y: 7pt),
    above: 0.9em,
    below: 1em,
    {
      set par(justify: false, leading: 0.5em)
      set text(size: 7.9pt)
      it
    },
  )

  show figure.caption: it => {
    set text(size: 8.5pt, fill: c.muted)
    set par(justify: false)
    [#text(fill: c.accent, weight: "medium")[#it.supplement #context it.counter.display(it.numbering)] #h(0.3em) #it.body]
  }
  set figure(gap: 0.7em)
  show figure: set block(above: 1.2em, below: 1.2em)

  show heading.where(level: 1): it => {
    pagebreak(weak: true)
    v(1mm)
    if it.numbering != none {
      block(below: 2mm, text(size: 32pt, weight: "bold", fill: c.teal, numbering(it.numbering, ..counter(heading).at(it.location()))))
    }
    block(below: 0.9em, text(size: 21pt, weight: "semibold", fill: c.text, it.body))
    line(length: 22mm, stroke: 2pt + c.accent)
    v(1.5mm)
  }
  show heading.where(level: 2): it => block(above: 1.5em, below: 0.75em, sticky: true, {
    set text(size: 13pt, weight: "semibold", fill: c.accent)
    if it.numbering != none {
      text(fill: c.muted, weight: "regular", numbering(it.numbering, ..counter(heading).at(it.location())))
      h(0.6em)
    }
    it.body
  })
  show heading.where(level: 3): it => block(above: 1.2em, below: 0.6em, sticky: true,
    text(size: 10.8pt, weight: "semibold", fill: c.text, it.body))

  show outline.entry.where(level: 1): it => {
    v(0.35em)
    text(weight: "semibold", fill: c.text, it)
  }
  set outline.entry(fill: text(fill: c.hair, repeat(gap: 0.25em)[.]))

  body
}
