/*  main.pl
    Gemstone Identification Assistant - loads the whole system.

    Run from this folder:   swipl main.pl
    Then:   ?- server(8080).    web interface at http://localhost:8080
            ?- start.           console interface
            ?- demo.            worked example (natural blue sapphire)
            ?- run_tests.       automated test suite (tests.pl)
*/

:- encoding(utf8).

:- ensure_loaded(knowledge_base).
:- ensure_loaded(engine).
:- ensure_loaded(console).
:- ensure_loaded(examples).
:- ensure_loaded(diagrams).
:- ensure_loaded(query_parser).
:- ensure_loaded(ui).
:- ensure_loaded(tests).

:- initialization(banner).

banner :-
    format("~n==============================================================~n"),
    format("   GEMSTONE IDENTIFICATION ASSISTANT~n"),
    format("==============================================================~n"),
    format("An expert system that identifies common Sri Lankan gemstones~n"),
    format("from their readings (RI, SG, optic character) and what you can~n"),
    format("see (colour, optical effect, inclusions). It tells you whether~n"),
    format("a stone is natural, synthetic or an imitation - and explains why.~n~n"),
    format("HOW TO START~n"),
    format("  1. At the ?- prompt below, type   server(8080).~n"),
    format("     (include the full stop) and press Enter.~n"),
    format("  2. Open your web browser and go to   http://localhost:8080~n"),
    format("  3. Keep this window open while you use the system.~n~n"),
    format("ON THE HOME PAGE~n"),
    format("  - Fill in what you know under \"Describe your stone\".~n"),
    format("  - IDENTIFY A GEM:  press \"Identify stone\"~n"),
    format("      (forward chaining - works from your inputs to an answer).~n"),
    format("  - VERIFY A CLAIM:  choose a gem under \"Check a claim\" and~n"),
    format("      press \"Verify\"  (backward chaining - e.g. \"is it a ruby?\").~n"),
    format("  - STEP BY STEP:    press \"Start\" under \"Ask me step by step\"~n"),
    format("      (the system asks one question at a time).~n"),
    format("  - New to gems? Try an \"Example stone\" further down the page.~n~n"),
    format("OTHER COMMANDS (type at the ?- prompt)~n"),
    format("  start.               use the system here, without a browser~n"),
    format("  demo.                show a worked example (blue sapphire)~n"),
    format("  run_tests.           run the automated tests~n"),
    format("  stop_server(8080).   stop the web server~n"),
    format("  halt.                exit~n~n").
