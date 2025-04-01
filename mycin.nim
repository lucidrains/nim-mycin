import std/[
  tables,
  hashes,
  strformat,
  options,
  sugar,
  sequtils,
  strutils,
]

# confidence factor related type and functions

type
  ConfidenceFactor = object
    value: float
    true_value: float = 1.0
    false_value: float = -1.0
    unknown: float = 0.0
    cutoff: float = 0.2

  Cf = ConfidenceFactor

proc `and`(cf1: Cf, cf2: Cf): Cf =
  let value = min(cf1.value, cf2.value)
  Cf(value: value)

proc `or`(cf1: Cf, cf2: Cf): Cf =
  let a = cf1.value
  let b = cf2.value

  var value: float

  if (a > 0 and b > 0):
    value = a + b - a * b
  elif (a < 0 and b < 0):
    value = a + b + a * b
  else:
    value = (a + b) / (1 - min(abs(a), abs(b)))

  Cf(value: value)

proc is_valid(cf: Cf): bool =
  (cf.value <= cf.true_value) and (cf.value >= cf.false_value)

proc is_true(cf: Cf): bool =
  cf.is_valid and (cf.value > cf.cutoff)

proc is_false(cf: Cf): bool =
  cf.is_valid and (cf.value < (1.0 - cf.cutoff))

proc `$`(cf: Cf): string =
  $cf.value

# parameters

type
  ParameterType = enum
    String, Float, Integer, Boolean

  ParameterValue = object
    case kind: ParameterType
    of String:
      string_value: Option[string]
    of Float:
      float_value: Option[float]
    of Integer:
      integer_value: Option[int]
    of Boolean:
      boolean_value: Option[bool]

proc eq(a, b: ParameterValue): bool =
  if a.kind != b.kind:
    return false

  case a.kind:
  of String:
    result = a.string_value == b.string_value
  of Integer:
    result = a.integer_value == b.integer_value
  of Float:
    result = a.float_value == b.float_value
  of Boolean:
    result = a.boolean_value == b.boolean_value

proc to_str[T](value: Option[T]): string =
  if value.is_some:
    result = $value.get
  else:
    result = ""

proc `$`(value: ParameterValue): string = 
  case value.kind:
  of String:
    result = to_str(value.string_value)
  of Integer:
    result = to_str(value.integer_value)
  of Float:
    result = to_str(value.float_value)
  of Boolean:
    result = to_str(value.boolean_value)

# use object variants in nim

type
  Parameter = object
    name: string
    context_name: string
    ask_first: bool
    case kind: ParameterType
    of String:
      string_valid: Option[seq[string]]
    of Float:
      float_valid: Option[seq[float]]
    of Integer:
      integer_valid: Option[seq[int]]
    of Boolean:
      discard

proc parse_bool(input: string): Option[bool] =
  if input == "true":
    result = some(true)
  elif input == "false":
    result = some(false)
  else:
    result = none(bool)

proc parse_int_to_option(input: string): Option[int] =
  try:
    result = some(parse_int(input))
  except ValueError:
    result = none(int)

proc parse_float_to_option(input: string): Option[float] =
  try:
    result = some(parse_float(input))
  except ValueError:
    result = none(float)

proc from_string(parameter: Parameter, input: string): ParameterValue =
  case parameter.kind:
  of String:

    let valid = parameter.string_valid
    var string_value: Option[string]

    if valid.is_some and valid.get.contains(input):
      string_value = some(input)
    else:
      string_value = none(string)

    result = ParameterValue(kind: String, string_value: string_value)

  of Integer:

    let valid = parameter.integer_valid
    var integer_value = parse_int_to_option(input)

    if valid.is_some and integer_value.is_some and
        not valid.get.contains(integer_value.get):
      integer_value = none(int)

    result = ParameterValue(kind: Integer, integer_value: integer_value)

  of Float:
    let valid = parameter.float_valid
    var float_value = parse_float_to_option(input)

    if valid.is_some and float_value.is_some and
        not valid.get.contains(float_value.get):
      float_value = none(float)

    result = ParameterValue(kind: Float, float_value: float_value)

  of Boolean:
    result = ParameterValue(kind: Boolean, boolean_value: parse_bool(input))

proc ask(parameter: Parameter): ParameterValue =
  parameter.from_string(read_line(stdin))

# context

type
  Instance = tuple
    id: int
    name: string

  Context = ref object
    name: string
    count: int = 0
    initial_data: seq[string] = @[]
    goals: seq[string] = @[]
    current_instance: Option[Instance] = none(Instance)

proc init(c: Context): Instance =
  inc(c.count)
  let instance = (id: c.count, name: c.name)

  c.current_instance = some(instance)
  instance

# instance and findings

type

  ParameterValueAndConfidence = tuple
    value: ParameterValue
    confidence: Cf

  Finding = tuple
    finding_name: string
    values: seq[ParameterValueAndConfidence]

  Findings = Table[
    Instance,
    seq[Finding]
  ]

  FindingsRef = ref Findings

proc report_findings(findings_table: ref Findings) = 

  for inst, findings in findings_table.pairs:
    echo &"Findings for {inst.id}-{inst.name}:"

    for param, finding in findings:

      let possibilities = finding.values.map(value_and_cf => (
        let (value, cf) = value_and_cf
        &"{$value}-{cf}"
      )).join

      echo &"{param} - {possibilities}"

# condition

type
  CondMatchOp = (a: ParameterValue, b: ParameterValue) -> bool

  Condition = object
    param_name: string
    context_name: string
    operation: CondMatchOp
    value: ParameterValue

  Cond = Condition

# rules

type
  Rule = object
    num: int
    premises: seq[Cond]
    conclusions: seq[Cond]
    cf: float = 1.0

# expert system

type
  ExpertSystem = ref object
    contexts: seq[Context] = @[]
    parameters: seq[Parameter] = @[]
    rules: seq[Rule] = @[]
    current_rule: Option[string] = none(string)
    current_instance: Instance

proc clear(expert: ExpertSystem) =
  expert.contexts.set_len(0)
  expert.parameters.set_len(0)
  expert.rules.set_len(0)
  expert.current_rule = none(string)

proc set_current_rule(expert: ExpertSystem, rule: string) =
  expert.current_rule = rule.some 

proc add_context(expert: ExpertSystem, c: Context) =
  expert.contexts.add(c)

proc add_param(expert: ExpertSystem, p: Parameter) =
  expert.parameters.add(p)

proc add_rule(expert: ExpertSystem, r: Rule) =
  expert.rules.add(r)

proc find_param_by_name(expert: ExpertSystem, param_name: string): Option[Parameter] =
  for parameter in expert.parameters:
    if parameter.name == param_name:
      result = some(parameter)

proc find_context_by_name(expert: ExpertSystem, context_name: string): Option[Context] =
  for context in expert.contexts:
    if context.name == context_name:
      result = some(context)

proc init_context(expert: ExpertSystem, context_name: string): Context =
  let maybe_context = expert.find_context_by_name(context_name)

  if not maybe_context.is_some:
    echo &"context with name {context_name} not found, aborting"
    return

  result = maybe_context.get
  let instance = result.init()

  expert.current_instance = instance

proc find_out(expert: ExpertSystem, param: Parameter, instance: Instance) =
  discard

proc find_out(expert: ExpertSystem, param: Parameter) =
  let instance = expert.current_instance
  expert.find_out(param, instance)

proc execute(expert: ExpertSystem, context_names: seq[string]): FindingsRef =
  echo "Beginning execution. For help answering questions, type \"help\"."

  # backwards chaining

  for context_name in context_names:

    let context = expert.init_context(context_name)

    expert.set_current_rule("initial")

    for param_name in context.initial_data:
      let param = expert.find_param_by_name(param_name)

      if param.is_none:
        continue

      expert.find_out(param.get)

    expert.set_current_rule("goal")

    for param_name in context.goals:
      let param = expert.find_param_by_name(param_name)

      if param.is_none:
        continue

      expert.find_out(param.get)

  # writing to findings table

  for context_name in context_names:
    discard

# main

proc main() =
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
    string_valid: @["rod", "coccus"].some
  ))

  expert.add_param(Parameter(
    name: "morphology",
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
      value: ParameterValue(kind: String, string_value: value.some)
    )

  proc bool_cond(param: string, context: string, operation: CondMatchOp,
      value: bool): Cond =
    Cond(
      param_name: param,
      context_name: context,
      operation: operation,
      value: ParameterValue(kind: Boolean, boolean_value: value.some)
    )

  expert.add_rule(Rule(
    num: 52,
    premises: @[
      str_cond("site", "culture", eq, "blood"),
      str_cond("gram", "organism", eq, "neg"),
      str_cond("morphology", "organism", eq, "rod"),
      str_cond("aerobicity", "organism", eq, "anaerobic"),
    ],
    conclusions: @[
      str_cond("identity", "organism", eq, "bacteroides")
    ],
    cf: 0.4
  ))

  expert.add_rule(Rule(
    num: 71,
    premises: @[
      str_cond("gram", "organism", eq, "pos"),
      str_cond("morphology", "organism", eq, "coccus"),
      str_cond("growth-conformation", "organism", eq, "clumps"),
    ],
    conclusions: @[
      str_cond("identity", "organism", eq, "staphylococcus")
    ],
    cf: 0.7
  ))

  expert.add_rule(Rule(
    num: 73,
    premises: @[
      str_cond("site", "culture", eq, "blood"),
      str_cond("gram", "organism", eq, "neg"),
      str_cond("morphology", "organism", eq, "rod"),
      str_cond("aerobicity", "organism", eq, "anaerobic")
    ],
    conclusions: @[
      str_cond("identity", "organism", eq, "bacteroides")
    ],
    cf: 0.9
  ))

  expert.add_rule(Rule(
    num: 73,
    premises: @[
      str_cond("gram", "organism", eq, "neg"),
      str_cond("morphology", "organism", eq, "rod"),
      bool_cond("compromised-host", "patient", eq, true)
    ],
    conclusions: @[
      str_cond("identity", "organism", eq, "pseudomonas")
    ],
    cf: 0.6
  ))

  expert.add_rule(Rule(
    num: 107,
    premises: @[
      str_cond("gram", "organism", eq, "neg"),
      str_cond("morphology", "organism", eq, "rod"),
      str_cond("aerobicity", "organism", eq, "aerobic")
    ],
    conclusions: @[
      str_cond("identity", "organism", eq, "enterobacteriaceae")
    ],
    cf: 0.8
  ))

  expert.add_rule(Rule(
    num: 165,
    premises: @[
      str_cond("gram", "organism", eq, "pos"),
      str_cond("morphology", "organism", eq, "coccus"),
      str_cond("growth-conformation", "organism", eq, "chain")
    ],
    conclusions: @[
      str_cond("identity", "organism", eq, "streptococcus")
    ],
    cf: 0.7
  ))

  discard expert.execute(@["patient", "culture", "organism"])

# execute main

when is_main_module:
  main()
