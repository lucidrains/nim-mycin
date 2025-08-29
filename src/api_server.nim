import mummy, mummy/routers
import json, os, strutils, mimetypes

proc list_data_files(request: Request) =
  var response = %* {"files": []}
  
  for kind, path in walk_dir("data"):
    if kind == pcFile:
      let filename = path.split_path().tail
      response["files"].add(%* {"filename": filename})
  
  var headers: HttpHeaders
  headers["Content-Type"] = "application/json"
  headers["Access-Control-Allow-Origin"] = "*"
  headers["Access-Control-Allow-Methods"] = "GET, OPTIONS"
  headers["Access-Control-Allow-Headers"] = "Content-Type"
  request.respond(200, headers, $response)

proc get_data_file(request: Request) =
  let filename = request.pathParams["filename"]
  let file_path = "data" / filename
  
  var headers: HttpHeaders
  headers["Content-Type"] = "application/json"
  headers["Access-Control-Allow-Origin"] = "*"
  headers["Access-Control-Allow-Methods"] = "GET, OPTIONS"
  headers["Access-Control-Allow-Headers"] = "Content-Type"
  
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

proc handle_options(request: Request) =
  var headers: HttpHeaders
  headers["Access-Control-Allow-Origin"] = "*"
  headers["Access-Control-Allow-Methods"] = "GET, OPTIONS"
  headers["Access-Control-Allow-Headers"] = "Content-Type"
  request.respond(200, headers, "")

proc serve_static(request: Request) =
  var file_path = request.uri
  if file_path == "/" or file_path == "":
    file_path = "/index.html"
  
  let static_path = "static" & file_path
  
  if not file_exists(static_path):
    request.respond(404, @[], "File not found")
    return
  
  let m = new_mime_types()
  let ext = split_file(static_path).ext
  let content_type = m.get_mime_type(ext)
  
  var headers: HttpHeaders
  headers["Content-Type"] = content_type
  headers["Access-Control-Allow-Origin"] = "*"
  
  try:
    let content = read_file(static_path)
    request.respond(200, headers, content)
  except IOError:
    request.respond(500, @[], "Failed to read file")

var router: Router
router.get("/api/data-files", list_data_files)
router.get("/api/data-files/@filename", get_data_file)
router.options("/api/data-files", handle_options)
router.options("/api/data-files/@filename", handle_options)
router.get("/**", serve_static)

let server = new_server(router)
echo "Starting server on http://localhost:8080"
server.serve(Port(8080))