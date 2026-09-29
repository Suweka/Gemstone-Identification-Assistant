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
    format("~n=== Gemstone Identification Assistant loaded ===~n"),
    format("  server(8080).   start web interface, then open http://localhost:8080~n"),
    format("  start.          console interface~n"),
    format("  demo.           worked example~n"),
    format("  run_tests.      run automated tests~n~n").
