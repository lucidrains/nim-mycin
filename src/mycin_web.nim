include karax/prelude

import std/[json, options]
import ./mycin

var expert = ExpertSystem()

const expert_json_string = static_read("../data/mycin.json")

let expert_json = parse_json(expert_json_string)
let rules_json = expert_json.to(RulesJson)

expert.populate_from_json(rules_json)

# add rules

proc create_dom(): VNode =
  result = buildHtml(tdiv(class="container")):
    tdiv(class="column"):
      h2:
        text "Context"
      ul:
        for context in expert.contexts:
          li:
            text context.name
    tdiv(class="column"):
      h2:
        text "Parameters"
      ul:
        for param in expert.parameters:
          li:
            text param.name
    tdiv(class="column"):
      h2:
        text "Rules"
      ul:
        for rule in expert.rules:
          li:
            text $rule.num

set_renderer createDom
