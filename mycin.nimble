version       = "0.1.0"
author        = "Phil Wang"
description   = "An expert system based on MYCIN"
license       = "MIT"
srcDir        = "src"

requires "nim >= 1.0.0"
requires "karax"
requires "static_server"
requires "db_connector"
requires "debby"
requires "mummy"

bin = @["mycin"]

task test, "Run tests":
  exec "nim compile --run tests/test_mycin.nim"

task buildweb, "Build web version":
  exec "nim js src/mycin_web.nim"
  exec "cp src/mycin_web.js static/"

task server, "Start API server":
  exec "nimble buildweb"
  exec "nim compile --run src/api_server.nim"
