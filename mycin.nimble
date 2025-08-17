version       = "0.1.0"
author        = "Phil Wang"
description   = "An expert system based on MYCIN"
license       = "MIT"
srcDir        = "."

requires "nim >= 1.0.0"
requires "karax"

bin = "mycin", "mycin_web"
