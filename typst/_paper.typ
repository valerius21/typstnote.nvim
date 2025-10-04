#let conf(id: none, title: none, authors: (), abstract:[], doc) = {
  set page(
    paper: "a4",
    header: align(
      right + horizon,
      id
    ),
  )
  set par(justify: true)
  set text(
    size: 11pt,
  )

  set align(center)
  text(17pt, title)

  par(justify: true)[
    *Abstract* \
    #abstract
  ]

  set columns(2)
  set align(left)
  set heading(numbering: "A.")
  doc
}
