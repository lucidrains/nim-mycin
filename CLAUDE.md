# CLAUDE.md - Nim MYCIN Expert System

## Project Overview
This is an implementation of the MYCIN expert system in Nim, recreating the famous 1970s Stanford medical expert system for diagnosing bacterial infections. The system uses rule-based reasoning with confidence factors to identify bacterial organisms based on patient, culture, and organism characteristics.

## Project Structure
- `mycin.nim` - Core expert system implementation with confidence factors, rules engine, and backward chaining
- `mycin.json` - Knowledge base with diagnostic rules, parameters, and contexts
- `mycin_web.nim` - Web interface using Karax framework
- `mycin.html` - HTML wrapper for web version
- `mycin.js`, `mycin_web.js` - Compiled JavaScript outputs

## Key Commands
```bash
# Compile and run CLI version
nim compile --run mycin.nim

# Compile with custom rules file
nim compile --run mycin.nim mycin-from-llm

# Compile web version to JavaScript
nim js mycin_web.nim

# Run with specific JSON rules file
./mycin mycin-from-llm
```

## Development Guidelines
- The system uses backward chaining reasoning starting from goals
- Confidence factors range from -1.0 (definitely false) to 1.0 (definitely true)
- Rules have premises (conditions) and conclusions with confidence factors
- Three main contexts: patient, culture, organism
- Parameters are strongly typed (String, Integer, Float, Boolean)
- User can type "?" during questions to see valid choices
- Type "unknown" to skip questions

## Testing
- Test by running the CLI and answering diagnostic questions
- Verify rule firing by checking confidence factor calculations
- Test web interface by opening mycin.html in browser

## Knowledge Base Structure
The JSON file contains:
- `contexts` - Define problem domains and goals
- `parameters` - Typed variables with validation rules
- `rules` - IF-THEN rules with confidence factors

## Adding New Rules
Rules follow the format:
```json
{
  "num": 999,
  "premises": [["param", "context", "==", "value"]],
  "conclusions": [["param", "context", "==", "value"]],
  "cf": 0.8
}
```

## Style
Prioritize simple, concise, pure functions. Think ultrahard about whether the solution is too complicated before getting back to me
