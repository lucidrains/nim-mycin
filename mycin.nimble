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

bin = @["mycin"]

task test, "Run tests":
  exec "nim compile --run tests/test_mycin.nim"

task buildweb, "Build web version":
  exec "nim js src/mycin_web.nim"

task start_webserver, "Start web server for Karax app":
  exec "static_server ."
