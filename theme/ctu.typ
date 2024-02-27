#import "@preview/polylux:0.3.1": *

#let theme = (
  accent: rgb("#F74C00"),
  text: rgb("#000000"),
)

#let ctu-theme(
  aspect-ratio: "4-3",
  footer: [],
  background: white,
  foreground: black,
  body
) = {
  set page(
    paper: "presentation-" + aspect-ratio,
    margin: 1em,
    header: none,
    footer: none,
    fill: background,
  )
  set text(
    fill: foreground,
    size: 24pt,
    font: "Fira Sans",
    weight: 400,
  )
  show footnote.entry: set text(size: .6em)
  show heading.where(level: 2): set block(below: 2em)
  show heading.where(level: 1): set block(below: 1em)
  show heading: set text(fill: theme.accent)
  set outline(target: heading.where(level: 1), title: none, fill: none)
  show outline.entry: it => it.body
  show outline: it => block(inset: (x: 1em), it)

  set page(footer: 
  utils.polylux-progress( p => {
    box(fill: gradient.linear(rgb("#F58600"), theme.accent), width: p * 100%, height: 1em, outset: (left: 24pt, right: 24pt), align(left, move(dy: -2em, dx: -.7em, image("../media/ferris.svg", height: 2.5em, width: 4em)))
)
  }))

  body
}

#let master-slide(body) = {
  polylux-slide({
    body
  })
}

#let centered-slide(body) = {
  master-slide(align(center + horizon, body))
}

#let title-slide(body) = {
  set heading(outlined: false)
  show heading: set block(above: 3em)
  set text(fill: theme.accent)
  centered-slide(body)
}

#let slide(body) = {
  master-slide({
    block(inset: (top: 2em, x: 2em), width: 100%, height: 80%, body)
  })
}

#let notes(body) = { pdfpc.speaker-note(body) }

   #let code(lines, block) = {
   show raw: it => stack(..it.lines.map(line =>
    box(
    width: 100%,
    height: 1.25em,
    inset: 0.25em,
    align(horizon, stack(if lines.contains(line.number) { line.body } else { strike(stroke: rgb(255, 255, 255, 70%) + 1.25em, line.body) }
    )))))

    block
  }