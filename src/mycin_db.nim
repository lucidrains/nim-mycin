import debby/sqlite
import json

type
  Context* = ref object
    id*: int
    name*: string
    goal*: string
    
  Parameter* = ref object
    id*: int
    name*: string
    context*: string
    param_type*: string
    choices*: string  # JSON array
    
  Rule* = ref object
    id*: int
    num*: int
    premises*: string  # JSON array
    conclusions*: string  # JSON array
    cf*: float

proc setup_db*(db_path: string = "mycin.db"): auto =
  result = openDatabase(db_path)
  result.createTable(Context)
  result.createTable(Parameter)
  result.createTable(Rule)

proc teardown_db*(db: auto) =
  db.dropTable(Rule)
  db.dropTable(Parameter)
  db.dropTable(Context)
  db.close()

when isMainModule:
  let db = setup_db()
  
  # Test context
  var ctx = Context(name: "patient", goal: "identity")
  db.insert(ctx)
  
  # Test parameter
  var param = Parameter(
    name: "burn",
    context: "patient",
    param_type: "Boolean",
    choices: $ %*["yes", "no"]
  )
  db.insert(param)
  
  # Test rule
  var rule = Rule(
    num: 1,
    premises: $ %*[["burn", "patient", "==", "yes"]],
    conclusions: $ %*[["identity", "organism", "==", "pseudomonas"]],
    cf: 0.7
  )
  db.insert(rule)
  
  echo "Created tables and inserted test data"
  echo "Contexts: ", db.filter(Context).len
  echo "Parameters: ", db.filter(Parameter).len
  echo "Rules: ", db.filter(Rule).len
  
  teardown_db(db)
  echo "Database torn down"