import mummy, mummy/routers
import json, os

proc list_data_files(request: Request) =
  var response = %* {"files": []}
  
  for kind, path in walk_dir("data"):
    if kind == pcFile:
      let filename = path.split_path().tail
      response["files"].add(%* {"filename": filename})
  
  var headers: HttpHeaders
  headers["Content-Type"] = "application/json"
  request.respond(200, headers, $response)

var router: Router
router.get("/api/data-files", list_data_files)

let server = new_server(router)
echo "Starting server on http://localhost:8080"
server.serve(Port(8080))