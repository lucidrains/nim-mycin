include karax/prelude

import std/[json, options]
import ./mycin

var expert = ExpertSystem()

# patient paramas

expert.add_param(Parameter(
  name: "age",
  context_name: "patient",
  ask_first: true,
  kind: Integer
))

expert.add_param(Parameter(
  name: "burn",
  context_name: "patient",
  ask_first: true,
  kind: String,
  string_valid: @["no", "mild", "serious"].some
))

expert.add_param(Parameter(
  name: "compromised-host",
  context_name: "patient",
  kind: Boolean
))

# culture params

expert.add_param(Parameter(
  name: "site",
  context_name: "culture",
  ask_first: true,
  kind: String,
  string_valid: @["blood"].some
))

expert.add_param(Parameter(
  name: "days-old",
  context_name: "culture",
  ask_first: true,
  kind: Integer
))

# organism

expert.add_param(Parameter(
  name: "identity",
  context_name: "organism",
  ask_first: true,
  kind: String,
  string_valid: @[
    "pseudomonas",
    "klebsiella",
    "enterobacteriaceae",
    "staphylococcus",
    "bacteroides",
    "streptococcus"
  ].some
))

expert.add_param(Parameter(
  name: "gram",
  context_name: "organism",
  ask_first: true,
  kind: String,
  string_valid: @["acid-fast", "pos", "neg"].some
))

expert.add_param(Parameter(
  name: "morphology",
  context_name: "organism",
  kind: String,
  string_valid: @["rod", "coccus"].some
))

expert.add_param(Parameter(
  name: "aerobicity",
  context_name: "organism",
  kind: String,
  string_valid: @["aerobic", "anaerobic"].some
))

expert.add_param(Parameter(
  name: "growth-conformation",
  context_name: "organism",
  kind: String,
  string_valid: @["chains", "pairs", "clumps"].some
))

const expert_json_string = static_read("./mycin.json")

let expert_json = parse_json(expert_json_string)
let rules_json = expert_json.to(RulesJson)

expert.populate_from_json(rules_json)

# add rules

proc create_dom(): VNode =
  result = buildHtml(tdiv):
    tdiv:
      text "Contexts"
      ul:
        for context in expert.contexts:
          li:
            text context.name
    tdiv:
      text "Parameters"
      ul:
        for param in expert.parameters:
          li:
            text param.name
    tdiv:
      text "Rules"
      ul:
        for rule in expert.rules:
          li:
            text $rule.num

set_renderer createDom
