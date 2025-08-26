import std / [
  unittest,
  os,
  strutils,
  osproc
]

suite "MYCIN Expert System Tests":
  setup:
    putEnv("CI", "true")
    
  test "Test mycin.json compilation and execution":
    let (output, exitCode) = execCmdEx("nim compile src/mycin.nim")
    check exitCode == 0
    check output.contains("SuccessX")
    
  test "Test mycin-from-claude.json knowledge base":
    writeFile("test_input_claude.txt", "John Doe\n37\nyes\nno\nyes\nblood\nyes\n380\nyes\nno\nyes\nunknown\nunknown\n")
    let (output, exitCode) = execCmdEx("./src/mycin mycin-from-claude < test_input_claude.txt")
    check exitCode == 0
    check output.contains("patient-1")
    removeFile("test_input_claude.txt")
    
  test "Test mycin-from-gemini.json knowledge base":
    writeFile("test_input_gemini.txt", "Jane Doe\n42\nno\nyes\nno\nunknown\nunknown\nunknown\n")
    let (output, exitCode) = execCmdEx("./src/mycin mycin-from-gemini < test_input_gemini.txt")
    check exitCode == 0
    check output.contains("patient-1")
    removeFile("test_input_gemini.txt")
    
  test "Test default mycin.json knowledge base":
    writeFile("test_input_default.txt", "Test Patient\n65\nyes\nyes\nno\ncsf\nno\nunknown\nunknown\n")
    let (output, exitCode) = execCmdEx("./src/mycin < test_input_default.txt")
    check exitCode == 0
    check output.contains("patient-1")
    removeFile("test_input_default.txt")