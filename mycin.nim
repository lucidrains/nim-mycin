import std/ [
  tables,
  strformat,
  options,
  sugar,
  sequtils,
  strutils,
  sets,
  json
]

# helper functions

proc find_by_cond[T](
  arr: seq[T],
  cond: proc(_: T): bool
): Option[T] =
  for el in arr:
    if cond(el):
      return el.some

# confidence factor related type and functions

const
  CF_TRUE_VALUE = 1.0
  CF_FALSE_VALUE = -1.0
  CF_UNKNOWN_VALUE = 0.0
  CF_CUTOFF = 0.2
  INPUT_UNKNOWN_STRING = "unknown"

type
  ConfidenceFactor = object
    value: float
    true_value: float = CF_TRUE_VALUE
    false_value: float = CF_FALSE_VALUE
    unknown: float = CF_UNKNOWN_VALUE
    cutoff: float = CF_CUTOFF

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
  cf.is_valid and (cf.value < (cf.cutoff - 1.0))

proc `$`(cf: Cf): string =
  $cf.value

# parameters

type
  ParameterType* = enum
    String, Float, Integer, Boolean

  ParameterValue* = object
    case kind*: ParameterType
    of String:
      string_value*: string
    of Float:
      float_value*: float
    of Integer:
      integer_value*: int
    of Boolean:
      boolean_value*: bool

  ParameterValueAndConfidence = tuple
    value: ParameterValue
    confidence: Cf

proc `==`*(a, b: ParameterValue): bool =
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

proc always_false*(a, b: ParameterValue): bool =
  false

proc `$`[T](option_value: Option[T]): string =
  if option_value.is_some:
    result = $option_value.get
  else:
    result = ""

proc `$`(value: ParameterValue): string = 
  case value.kind:
  of String:
    result = $value.string_value
  of Integer:
    result = $value.integer_value
  of Float:
    result = $value.float_value
  of Boolean:
    result = $value.boolean_value

# use object variants in nim

type
  ParameterName = string

  Parameter* = object
    name*: ParameterName
    context_name*: string
    ask_first*: bool
    case kind*: ParameterType
    of String:
      string_valid*: Option[seq[string]]
    of Float:
      float_valid*: Option[seq[float]]
    of Integer:
      integer_valid*: Option[seq[int]]
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

proc from_string(
  parameter: Parameter,
  input: string,
  unknown_input_value: string = INPUT_UNKNOWN_STRING
): Option[ParameterValue] =

  if input == unknown_input_value:
    return

  case parameter.kind:
  of String:

    let valid = parameter.string_valid

    if valid.is_none or valid.get.contains(input):
      result = some(ParameterValue(kind: String, string_value: input))

  of Integer:

    let valid = parameter.integer_valid
    var integer_value = parse_int_to_option(input)

    if (
      integer_value.is_some and
      (valid.is_none or valid.get.contains(integer_value.get))
    ):
      result = some(ParameterValue(kind: Integer, integer_value: integer_value.get))

  of Float:
    let valid = parameter.float_valid
    var float_value = parse_float_to_option(input)

    if (
      float_value.is_some and
      (valid.is_none or not valid.get.contains(float_value.get))
    ):
      result = ParameterValue(kind: Float, float_value: float_value.get).some

  of Boolean:
    let maybe_bool = parse_bool(input)
    if maybe_bool.is_some:
      result = ParameterValue(kind: Boolean, boolean_value: maybe_bool.get).some

proc ask(parameter: Parameter, question: Option[string]): Option[ParameterValue] =
  if question.is_some:
    echo question.get

  when not defined(js):
    parameter.from_string(read_line(stdin))

# context

type
  Instance = tuple
    id: int
    name: string

  ParameterForInstance = tuple
    param_name: ParameterName
    instance: Instance

  Context* = ref object
    name*: string
    count: int = 0
    initial_data*: seq[string] = @[]
    goals*: seq[string] = @[]
    current_instance: Option[Instance] = none(Instance)

proc init(c: Context): Instance =
  inc(c.count)
  let instance = (id: c.count, name: c.name)

  c.current_instance = some(instance)
  instance

# instance and findings

type

  Finding = tuple
    param_name: ParameterName
    values: seq[ParameterValueAndConfidence]

  Findings = TableRef[
    Instance,
    seq[Finding]
  ]

proc report_findings(findings_table: Findings) = 

  if findings_table.is_nil:
    return

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
  CondMatchOp* = (a: ParameterValue, b: ParameterValue) -> bool

  Condition* = object
    param_name*: string
    context_name*: string
    operation*: CondMatchOp
    value*: ParameterValue

  Cond* = Condition

proc cond[T](param: string, context: string, operation: CondMatchOp,
      value: T): Cond =

    let param_value = when (T is string):
      ParameterValue(kind: String, string_value: value)
    elif (T is bool):
      ParameterValue(kind: Boolean, boolean_value: value)
    elif (T is float):
      ParameterValue(kind: Float, float_value: value)
    elif (T is int):
      ParameterValue(kind: Integer, int_value: value)
    else:
      return

    Cond(
      param_name: param,
      context_name: context,
      operation: operation,
      value: param_value
    )

proc evaluate(
  condition: Condition,
  values: seq[ParameterValueAndConfidence]
): Cf =

  var total_cf_value = 0.0

  for (value, cf) in values:

    if not condition.operation(value, condition.value):
      continue

    total_cf_value += cf.value

  return Cf(value: total_cf_value)

# rules

type
  Rule* = object
    num*: int
    premises*: seq[Cond]
    conclusions*: seq[Cond]
    cf*: float = 1.0

# expert system

type
  State = enum
    Uninitialized, Initial, Goal

  ExpertSystem* = ref object
    contexts*: seq[Context] = @[]
    parameters*: seq[Parameter] = @[]
    rules*: seq[Rule] = @[]
    current_rule*: Option[Rule] = none(Rule)
    current_state*: State = Uninitialized
    current_instance*: Instance
    knowns*: HashSet[ParameterForInstance]
    asked*: HashSet[ParameterForInstance]
    known_values*: Table[ParameterForInstance, seq[ParameterValueAndConfidence]]

proc clear(expert: ExpertSystem) =
  expert.contexts.set_len(0)
  expert.parameters.set_len(0)
  expert.rules.set_len(0)
  expert.asked.clear()
  expert.knowns.clear()
  expert.known_values.clear()

proc add_context*(expert: ExpertSystem, c: Context) =
  expert.contexts.add(c)

proc add_param*(expert: ExpertSystem, p: Parameter) =
  expert.parameters.add(p)

proc add_rule*(expert: ExpertSystem, r: Rule) =
  expert.rules.add(r)

proc find_param_by_name(expert: ExpertSystem, param_name: string): Option[Parameter] =
  for parameter in expert.parameters:
    if parameter.name == param_name:
      result = some(parameter)

proc find_context_by_name(expert: ExpertSystem, context_name: string): Option[Context] =
  for context in expert.contexts:
    if context.name == context_name:
      result = some(context)

proc fetch_knowledge_from_condition(
  expert: ExpertSystem,
  cond: Cond
): seq[ParameterValueAndConfidence] =

  let param = expert.find_param_by_name(cond.param_name)

  let context = expert.find_context_by_name(cond.context_name)

  if param.is_none or context.is_none:
    return

  let param_instance: ParameterForInstance = (param.get.name, context.get.current_instance.get)

  if not (param_instance in expert.known_values):
    return

  expert.known_values[param_instance]

proc init_context(expert: ExpertSystem, context_name: string): Context =
  let maybe_context = expert.find_context_by_name(context_name)

  if not maybe_context.is_some:
    echo &"context with name {context_name} not found, aborting"
    return

  result = maybe_context.get
  let instance = result.init()

  expert.current_instance = instance

proc ask_value(
  expert: ExpertSystem,
  param: Parameter,
  instance: Instance
): bool =

  let param_for_instance: ParameterForInstance = (param.name, instance)

  if param_for_instance in expert.asked:
    return

  expert.asked.incl(param_for_instance)

  let maybe_parameter_value = param.ask(some(&"what is the {param.name} for {instance.name}-{instance.id}?"))

  if maybe_parameter_value.is_none:
    return false

  discard expert.known_values.has_key_or_put(param_for_instance, @[])

  let param_value_and_cf: ParameterValueAndConfidence = (
    value: maybe_parameter_value.get,
    confidence: Cf(value: CF_TRUE_VALUE)
  )

  expert.known_values[param_for_instance].add(param_value_and_cf)

  true

# applying rules, which recursively calls finding out

proc find_out(expert: ExpertSystem, param: Parameter, instance: Instance)

proc apply_rules(
  expert: ExpertSystem,
  param: Parameter,
): bool =

  let instance = expert.current_instance
  let param_for_instance = (param.name, instance)

  discard expert.known_values.has_key_or_put(param_for_instance, @[])

  let rules = expert.rules.filter(rule => rule.conclusions.filter(cond => cond.param_name == param.name).len > 0)

  # reject first

  for rule in rules:
    var curr_cf: Cf = Cf(value: 0.0)

    for condition in rule.premises:
      let knowledge = expert.fetch_knowledge_from_condition(condition)

      let cf_from_condition = condition.evaluate(knowledge)

      if cf_from_condition.is_false:
        curr_cf = Cf(value: CF_FALSE_VALUE)
        break

    if not curr_cf.is_false:
      curr_cf = Cf(value: CF_TRUE_VALUE)

      for condition in rule.premises:
        let param = expert.find_param_by_name(condition.param_name)

        let context = expert.find_context_by_name(condition.context_name)

        var knowledge = expert.fetch_knowledge_from_condition(condition)

        if param.is_none or context.is_none:
          continue

        expert.find_out(param.get, context.get.current_instance.get)

        knowledge = expert.fetch_knowledge_from_condition(condition)

        let cf_from_condition = condition.evaluate(knowledge)

        curr_cf = curr_cf and cf_from_condition

        if not curr_cf.is_true:
          curr_cf = Cf(value: CF_FALSE_VALUE)
          break

    let update_cf = Cf(value: curr_cf.value * rule.cf)

    if not update_cf.is_true:
      continue

    for conclusion in rule.conclusions:

      let knowledge = expert.fetch_knowledge_from_condition(conclusion)

      # insert entry if not exists

      var
        cf: ConfidenceFactor

      var maybe_entry: Option[ParameterValueAndConfidence]

      for value_and_cf in knowledge:
        if value_and_cf.value == conclusion.value:
          maybe_entry = value_and_cf.some
          break

      let entry: ParameterValueAndConfidence = if maybe_entry.is_none:
        let new_entry: ParameterValueAndConfidence = (conclusion.value, update_cf)
        expert.known_values[param_for_instance].add(new_entry)
        new_entry
      else:
        maybe_entry.get

      cf = entry.confidence

      cf.value = (cf or update_cf).value

    result = true

proc find_out(
  expert: ExpertSystem,
  param: Parameter,
  instance: Instance
) =

  let param_instance: ParameterForInstance = (param.name, instance)

  # skip if already known

  if param_instance in expert.knowns:
    return

  # ask or apply rules

  var success: bool

  if param.ask_first:
    success = expert.ask_value(param, instance) or expert.apply_rules(param)
  else:
    success = expert.apply_rules(param) or expert.ask_value(param, instance)

  # store knowledge from asking the user or applying the rule

  if not success:
    return

  expert.knowns.incl(param_instance)

proc execute(
  expert: ExpertSystem,
  context_names: seq[string]
): Findings =
  echo "Beginning execution. For help answering questions, type \"help\"."

  result = new_table[Instance, seq[Finding]]()

  # backwards chaining

  for context_name in context_names:

    let context = expert.init_context(context_name)

    expert.current_state = INITIAL

    for param_name in context.initial_data:
      let param = expert.find_param_by_name(param_name)

      if param.is_none:
        continue

      expert.find_out(param.get, context.current_instance.get)

    expert.current_state = GOAL

    for param_name in context.goals:
      let param = expert.find_param_by_name(param_name)

      if param.is_none:
        continue

      expert.find_out(param.get, context.current_instance.get)

    if context.goals.len == 0 or context.current_instance.is_none:
      continue

    let instance = context.current_instance.get

    # writing to findings table

    var seq_findings: seq[Finding] = @[]

    for param_name in context.goals:
      let param = expert.find_param_by_name(param_name)

      if param.is_none:
        continue

      let param_instance: ParameterForInstance = (param.get.name, instance)

      let one_finding: Finding = (
        param_name: param_name,
        values: expert.known_values.get_or_default(param_instance, @[])
      )

      seq_findings.add(one_finding)

    result[instance] = seq_findings

# json related

type
  RuleJson* = object
    num: int
    premises: seq[array[4, string]]
    conclusions: seq[array[4, string]]
    cf: float

  RulesJson* = object
    rules*: seq[RuleJson]

proc json_to_rule*(json: RuleJson): Rule =

  var
    premises: seq[Cond] = @[]
    conclusions: seq[Cond] = @[]

  for cond_json in json.premises:
    let operation: CondMatchOp = if cond_json[2] == "==":
      `==`
    else:
      always_false

    premises.add(cond(
      cond_json[0],
      cond_json[1],
      operation,
      cond_json[3]
    ))

  for cond_json in json.conclusions:
    let operation: CondMatchOp = if cond_json[2] == "==":
      `==`
    else:
      always_false

    conclusions.add(cond(
      cond_json[0],
      cond_json[1],
      operation,
      cond_json[3]
    ))

  Rule(
    num: json.num,
    cf: json.cf,
    premises: premises,
    conclusions: conclusions
  )

# main

proc populate(expert: ExpertSystem) =

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
    kind: String,
    string_valid: @["true", "false"].some
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

# execute main

when is_main_module:

  let expert = ExpertSystem()

  expert.populate()

  let expert_json_string = read_file("./mycin.json")
  let expert_json = parse_json(expert_json_string)
  let rules_json = expert_json.to(RulesJson)

  for json in rules_json.rules:
    let rule = json_to_rule(json)
    expert.add_rule(rule)

  let findings = expert.execute(@["patient", "culture", "organism"])
  report_findings(findings)
