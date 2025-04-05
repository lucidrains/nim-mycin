include karax/prelude

proc create_dom(): VNode =

  result = buildHtml(tdiv):
    text "Expert System"

set_renderer createDom
