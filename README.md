# Gemstone Identification Assistant

A rule-based expert system, written in SWI-Prolog, that identifies common Sri Lankan gemstones, detects synthetics and imitations, and explains its reasoning.

Coursework for **CM3321 – Logic Programming and Artificial Cognitive Systems**, Faculty of Information Technology, University of Moratuwa.

## Features

- **Knowledge base:** 297 facts and 62 production rules in four chained layers (species → variety → origin → advice), each rule with a certainty factor and a literature source.
- **Three reasoning modes over one rule base:**
  - *Identify*: forward chaining (data-driven).
  - *Verify*: backward chaining, using a meta-interpreter that builds proof trees.
  - *Step by step*: an interactive consultation that asks only for the facts it needs.
- **Certainty factors (MYCIN-style):** incomplete data gives a ranked list of candidates.
- **Explanation facility:** How, Why and Why-not explanations, plus animated reasoning diagrams.
- **Plain-English questions:** parsed by a Definite Clause Grammar, e.g. *"Is my stone a sapphire if the RI is 1.765 and it is blue?"*
- **Interfaces:** a web interface (SWI-Prolog HTTP server), a console interface, and 41 automated tests (plunit).

## Quick start

Requires [SWI-Prolog](https://www.swi-prolog.org/download/stable) 9 or later (tested with 10.1.16).

```
cd gem_expert
swipl main.pl
?- server(8080).
```

Then open http://localhost:8080 in a browser.

Other commands at the `?-` prompt:

| Command | Effect |
|---|---|
| `start.` | Console interface |
| `demo.` | Worked example (natural blue sapphire) |
| `run_tests.` | Run the 41 automated tests |
| `stop_server(8080).` | Stop the web server |

## Project structure

| Path | Contents |
|---|---|
| `gem_expert/knowledge_base.pl` | Facts, production rules, certainty factors, sources |
| `gem_expert/engine.pl` | Forward and backward chaining, consultation, certainty factors, explanations |
| `gem_expert/diagrams.pl` | SVG reasoning diagrams |
| `gem_expert/query_parser.pl` | DCG for plain-English questions |
| `gem_expert/ui.pl`, `examples.pl` | Web interface and example stones |
| `gem_expert/console.pl` | Console interface |
| `gem_expert/tests.pl` | Automated tests |
| `gem_expert/docs/` | Project report and user manual (Word and PDF) |

See the user manual in `gem_expert/docs/` for full instructions.

## Disclaimer

This system gives a first opinion only. It does not replace a certificate from the National Gem and Jewellery Authority (NGJA) or another accredited gem laboratory.

## Author

Sansiluni J.A.S
