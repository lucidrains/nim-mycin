include karax/prelude

import std/options
import ./mycin

var expert = ExpertSystem()

expert.add_context(Context(name: "patient", initial_data: @["name", "sex", "age"]))
expert.add_context(Context(name: "culture", initial_data: @["site", "days-old"]))
expert.add_context(Context(name: "organism", goals: @["identity"]))

# patient paramas

expert.add_param(Parameter(
  name: "name",
  context_name: "patient",
  ask_first: true,
  kind: String
))

expert.add_param(Parameter(
  name: "sex",
  context_name: "patient",
  ask_first: true,
  kind: String,
  string_valid: some(@["M", "F"])
))

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

# add rules

proc str_cond(param: string, context: string, operation: CondMatchOp,
    value: string): Cond =
  Cond(
    param_name: param,
    context_name: context,
    operation: operation,
    value: ParameterValue(kind: String, string_value: value)
  )

proc bool_cond(param: string, context: string, operation: CondMatchOp,
    value: bool): Cond =
  Cond(
    param_name: param,
    context_name: context,
    operation: operation,
    value: ParameterValue(kind: Boolean, boolean_value: value)
  )

expert.add_rule(Rule(
  num: 52,
  premises: @[
    str_cond("site", "culture", `==`, "blood"),
    str_cond("gram", "organism", `==`, "neg"),
    str_cond("morphology", "organism", `==`, "rod"),
    str_cond("aerobicity", "organism", `==`, "anaerobic"),
  ],
  conclusions: @[
    str_cond("identity", "organism", `==`, "bacteroides")
  ],
  cf: 0.4
))

expert.add_rule(Rule(
  num: 71,
  premises: @[
    str_cond("gram", "organism", `==`, "pos"),
    str_cond("morphology", "organism", `==`, "coccus"),
    str_cond("growth-conformation", "organism", `==`, "clumps"),
  ],
  conclusions: @[
    str_cond("identity", "organism", `==`, "staphylococcus")
  ],
  cf: 0.7
))

expert.add_rule(Rule(
  num: 73,
  premises: @[
    str_cond("site", "culture", `==`, "blood"),
    str_cond("gram", "organism", `==`, "neg"),
    str_cond("morphology", "organism", `==`, "rod"),
    str_cond("aerobicity", "organism", `==`, "anaerobic")
  ],
  conclusions: @[
    str_cond("identity", "organism", `==`, "bacteroides")
  ],
  cf: 0.9
))

expert.add_rule(Rule(
  num: 73,
  premises: @[
    str_cond("gram", "organism", `==`, "neg"),
    str_cond("morphology", "organism", `==`, "rod"),
    bool_cond("compromised-host", "patient", `==`, true)
  ],
  conclusions: @[
    str_cond("identity", "organism", `==`, "pseudomonas")
  ],
  cf: 0.6
))

expert.add_rule(Rule(
  num: 107,
  premises: @[
    str_cond("gram", "organism", `==`, "neg"),
    str_cond("morphology", "organism", `==`, "rod"),
    str_cond("aerobicity", "organism", `==`, "aerobic")
  ],
  conclusions: @[
    str_cond("identity", "organism", `==`, "enterobacteriaceae")
  ],
  cf: 0.8
))

expert.add_rule(Rule(
  num: 165,
  premises: @[
    str_cond("gram", "organism", `==`, "pos"),
    str_cond("morphology", "organism", `==`, "coccus"),
    str_cond("growth-conformation", "organism", `==`, "chain")
  ],
  conclusions: @[
    str_cond("identity", "organism", `==`, "streptococcus")
  ],
  cf: 0.7
))


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
