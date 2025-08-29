import mummy, mummy/routers
import json, os, strutils

proc list_data_files(request: Request) =
  var response = %* {"files": []}
  
  for kind, path in walk_dir("data"):
    if kind == pcFile:
      let filename = path.split_path().tail
      response["files"].add(%* {"filename": filename})
  
  var headers: HttpHeaders
  headers["Content-Type"] = "application/json"
  request.respond(200, headers, $response)

proc get_data_file(request: Request) =
  let filename = request.pathParams["filename"]
  let file_path = "data" / filename
  
  var headers: HttpHeaders
  headers["Content-Type"] = "application/json"
  
  if not file_exists(file_path):
    let error_response = %* {"error": "File not found: " & filename}
    request.respond(404, headers, $error_response)
    return
  
  if not filename.ends_with(".json"):
    let error_response = %* {"error": "Only JSON files are allowed"}
    request.respond(400, headers, $error_response)
    return
  
  try:
    let content = read_file(file_path)
    request.respond(200, headers, content)
  except IOError:
    let error_response = %* {"error": "Failed to read file: " & filename}
    request.respond(500, headers, $error_response)

var router: Router
router.get("/api/data-files", list_data_files)
router.get("/api/data-files/@filename", get_data_file)

let server = new_server(router)
echo "Starting server on http://localhost:8080"
server.serve(Port(8080))