/*  console.pl
    Gemstone Identification Assistant - CONSOLE USER INTERFACE
    Backup interface if the web UI is unavailable.  Run:  ?- start.
*/

:- encoding(utf8).

start :-
    nl, writeln('==================================================='),
    writeln('   GEMSTONE IDENTIFICATION ASSISTANT (console)'),
    writeln('==================================================='),
    writeln('An expert system that identifies common Sri Lankan'),
    writeln('gemstones and tells you whether a stone is natural,'),
    writeln('synthetic or an imitation - and explains why.'),
    menu_loop.

menu_loop :-
    nl,
    writeln('What would you like to do?'),
    writeln('  1. Identify a stone  - "I don''t know what it is"      (forward chaining)'),
    writeln('  2. Check a claim     - "The seller says it''s a ruby"   (backward chaining)'),
    writeln('  3. Step by step      - asks only what it needs; type WHY at any question'),
    writeln('  4. Ask in English    - e.g. is it a ruby if the RI is 1.765 and it is red'),
    writeln('  5. Run the demo      - natural blue sapphire example'),
    writeln('  6. Quit'),
    ask_int('Choose 1-6', 1, 6, Choice),
    (   Choice == 6
    ->  writeln('Goodbye.')
    ;   menu_action(Choice), menu_loop
    ).

menu_action(1) :-
    ask_inputs(Inputs),
    identify(Inputs),
    print_identification.
menu_action(2) :-
    verify_targets(Ts),
    nl, writeln('Which gem do you want to check?'),
    ask_option(Ts, Target),
    (   Target == unknown
    ->  writeln('No gem chosen.')
    ;   ask_inputs(Inputs),
        verify(Inputs, Target, Result),
        print_verification(Result, Target)
    ).
menu_action(3) :-
    verify_targets(Ts),
    nl, writeln('What do you want to find out?  (0 = find the species by hypothesise-and-test)'),
    ask_option(Ts, T0),
    ( T0 == unknown -> Target = any_species ; Target = T0 ),
    console_consult(Target).
menu_action(4) :-
    format("~nYour question: "), flush_output,
    read_line_to_string(user_input, Q),
    (   Q == end_of_file -> true
    ;   parse_query(Q, Mode, Facts, Ignored),
        format("Understood: ~w  ~w~n", [Mode, Facts]),
        ( Ignored \== [] -> format("Words not used: ~w~n", [Ignored]) ; true ),
        (   Mode = verify(T)
        ->  verify(Facts, T, R), print_verification(R, T)
        ;   Facts == []
        ->  writeln('I could not find any gem properties in that question.')
        ;   identify(Facts), print_identification
        )
    ).
menu_action(5) :-
    demo.

/* ---- Step-by-step consultation (backward chaining that asks) ----- */
console_consult(Target) :-
    consult_loop(Target, [], []).

consult_loop(Target, Inputs, Unknowns) :-
    consult(Target, Inputs, Unknowns, Outcome),
    (   Outcome = ask(K, Stack)
    ->  ask_consult(K, Stack, Answer),
        (   Answer == unknown
        ->  consult_loop(Target, Inputs, [K|Unknowns])
        ;   consult_loop(Target, [Answer|Inputs], Unknowns)
        )
    ;   Outcome = done(Result),
        length(Inputs, NI), length(Unknowns, NU), NQ is NI + NU,
        format("~nBackward chaining asked ~w of the 6 possible questions.~n", [NQ]),
        (   Result = proved(species(S), _), Target == any_species
        ->  print_verification(Result, S)
        ;   print_verification(Result, Target)
        )
    ).

% ask one question; the user may type WHY to see the reasoning
ask_consult(K, Stack, Answer) :-
    consult_question(K, Q, Options),
    format("~n~w~n", [Q]),
    (   Options == number
    ->  writeln('   (type a number, press Enter if you don''t know, or type WHY)')
    ;   writeln('    0. Don''t know'),
        forall(nth1(N, Options, O), ( label(O, L), format("    ~w. ~w~n", [N, L]) )),
        writeln('   (type a number, or WHY)')
    ),
    format("> "), flush_output,
    read_line_to_string(user_input, S0),
    (   S0 == end_of_file -> Answer = unknown
    ;   normalize_space(string(S1), S0), string_lower(S1, S),
        (   S == "why"
        ->  why_asking(K, Stack, Lines),
            writeln('WHY I AM ASKING:'),
            forall(member(L, Lines), format("  - ~w~n", [L])),
            ask_consult(K, Stack, Answer)
        ;   S == "" -> Answer = unknown
        ;   consult_answer(K, Options, S, Answer) -> true
        ;   writeln('  Sorry, I did not understand that.'),
            ask_consult(K, Stack, Answer)
        )
    ).

consult_question(ri, 'What is the refractive index (RI)?', number).
consult_question(sg, 'What is the specific gravity (SG)?', number).
consult_question(optic, 'What is the optic character?', [isotropic, uniaxial, biaxial, doubly_refractive]).
consult_question(colour, 'What colour is the stone?', Cs) :- findall(C, colour(_, C), Cs0), sort(Cs0, Cs).
consult_question(phenomenon, 'Does it show an optical effect?', [none|Ps]) :- findall(P, phenomenon(_, P), Ps0), sort(Ps0, Ps).
consult_question(inclusion, 'What inclusions can you see with a loupe?', Is) :- findall(I, inclusion_type(I, _), Is).

consult_answer(K, number, S, F) :- !,
    number_string(N, S), input_key(K, F), arg(1, F, N).
consult_answer(K, Options, S, Answer) :-
    number_string(N, S), integer(N),
    (   N =:= 0 -> Answer = unknown
    ;   nth1(N, Options, V), input_key(K, F), arg(1, F, V), Answer = F ).

% Worked example used in the report
demo :-
    Inputs = [ri(1.765), sg(4.00), optic(uniaxial),
              observed_colour(blue), inclusion(silk)],
    identify(Inputs),
    print_identification.

/* ---- Friendly result printing ----------------------------------- */
print_identification :-
    result_kind(Kind),
    headline(Kind, Kicker, Title, Sub, Level, _),
    level_text(Level, LT),
    main_cf(Kind, CF), percent(CF, P),
    primary_origin(_, _, OText),
    rule_line,
    format("  ~w: ~w~n", [Kicker, Title]),
    format("  ~w~n", [Sub]),
    cf_word(P, PW),
    format("  Confidence: ~w (certainty ~w% - ~w)    Origin: ~w~n", [LT, P, PW, OText]),
    rule_line,
    (   ( Kind = candidates(Gs) ; Kind = ambiguous(Gs) )
    ->  writeln('RANKED POSSIBILITIES'),
        forall(nth1(N, Gs, G),
               ( ( Kind = candidates(_) -> T = candidate(G) ; T = species(G) ),
                 fact_cf(T, GC), percent(GC, GP), label(G, GL), cf_word(GP, GW),
                 format("  ~w. ~w  ~w% (~w)~n", [N, GL, GP, GW]),
                 evidence_for(Kind, G, Ev),
                 forall(member(E, Ev), format("       + ~w~n", [E])) ))
    ;   true ),
    findall(A, (fired(_, _, advice(K)), advice_text(K, A)), Advice),
    (   Advice \== []
    ->  writeln('WHAT YOU SHOULD DO'),
        forall(member(A, Advice), format("  * ~w~n", [A]))
    ;   true ),
    friendly_steps(Steps),
    print_steps('HOW THE SYSTEM REACHED THIS', Steps),
    ask_yes('Show the technical trace (facts and rule ids)?', Yes),
    (   Yes == true
    ->  identify_explanation(Sections), print_sections(Sections)
    ;   true ).

print_verification(Result, Target) :-
    label(Target, TL),
    rule_line,
    (   Result = proved(_, Proof)
    ->  proof_cf(Proof, CF), percent(CF, P), cf_word(P, PW),
        format("  YES - your stone is consistent with ~w (certainty ~w% - ~w).~n", [TL, P, PW]),
        writeln('  Every condition the expert rules require is met.'),
        rule_line,
        proof_steps(Proof, Steps),
        print_steps('HOW IT WAS CHECKED', Steps)
    ;   Result = failed(_, Reasons),
        friendly_why_not(Reasons, Items),
        format("  NO - your stone does not match ~w.~n", [TL]),
        (   main_reason(Items, MR) -> format("  Main reason: ~w~n", [MR]) ; true ),
        rule_line,
        writeln('WHY NOT?'),
        print_items(Items, 1)
    ),
    ask_yes('Show the technical trace?', Yes),
    (   Yes == true
    ->  verify_explanation(Result, _, Sections), print_sections(Sections)
    ;   true ).

print_steps(Title, Steps) :-
    nl, writeln(Title),
    (   Steps == []
    ->  writeln('  No rule could be applied to the data given.')
    ;   forall(nth1(N, Steps, step(Stage, Id, Head, Reasons, Why, _, CFText)),
               ( format("  ~w. [~w] ~w   (rule ~w; ~w)~n", [N, Stage, Head, Id, CFText]),
                 forall(member(R, Reasons), format("       - ~w~n", [R])),
                 ( Why \== "" -> format("       Expert knowledge: ~w~n", [Why]) ; true ) ))
    ).

print_items(Items, Depth) :-
    forall(member(item(Id, Text, Sub), Items),
           ( Pad is Depth * 3,
             ( Sub == [] -> Mark = 'x' ; Mark = '>' ),
             ( Id == '-' -> format("~t~*|~w ~w~n", [Pad, Mark, Text])
             ; format("~t~*|~w ~w  (rule ~w)~n", [Pad, Mark, Text, Id]) ),
             D1 is Depth + 1,
             print_items(Sub, D1) )).

rule_line :- writeln('---------------------------------------------------').

ask_yes(Prompt, Yes) :-
    format("~n~w (y/n): ", [Prompt]), flush_output,
    read_line_to_string(user_input, S),
    (   S \== end_of_file, sub_string(S, 0, 1, _, F), memberchk(F, ["y", "Y"])
    ->  Yes = true ; Yes = false ).

/* ---- Asking questions ------------------------------------------- */
ask_inputs(Inputs) :-
    nl, writeln('Enter what you know. Press Enter to skip (unknown).'),
    ask_number('Refractive index (RI), e.g. 1.765', 1.3, 3.0, RI),
    ask_number('Specific gravity (SG), e.g. 4.00', 1.0, 8.0, SG),
    writeln('Optic character (from a polariscope/refractometer):'),
    ask_option([isotropic, uniaxial, biaxial, doubly_refractive], Optic),
    writeln('Colour:'),
    findall(C, colour(_, C), Cs0), sort(Cs0, Cs),
    ask_option(Cs, Colour),
    writeln('Optical phenomenon:'),
    findall(P, phenomenon(_, P), Ps0), sort(Ps0, Ps),
    ask_option([none|Ps], Phen),
    writeln('Inclusions seen with a 10x loupe:'),
    findall(I, inclusion_type(I, _), Is),
    ask_option(Is, Incl),
    convlist(opt_fact,
             [ opt(ri, RI), opt(sg, SG), opt(optic, Optic),
               opt(observed_colour, Colour), opt(phenomenon, Phen),
               opt(inclusion, Incl) ],
             Inputs).

opt_fact(opt(_, unknown), _) :- !, fail.
opt_fact(opt(Name, V), F) :- F =.. [Name, V].

ask_number(Prompt, Min, Max, Value) :-
    format("~w: ", [Prompt]), flush_output,
    read_line_to_string(user_input, S0),
    (   S0 == end_of_file -> Value = unknown
    ;   normalize_space(string(S), S0),
        (   S == "" -> Value = unknown
        ;   catch(number_string(N, S), _, fail), N >= Min, N =< Max
        ->  Value = N
        ;   format("  Please enter a number between ~w and ~w, or press Enter.~n", [Min, Max]),
            ask_number(Prompt, Min, Max, Value)
        )
    ).

ask_option(Options, Value) :-
    writeln('    0. Unknown'),
    forall(nth1(N, Options, O),
           ( label(O, L), format("    ~w. ~w~n", [N, L]) )),
    length(Options, Len),
    ask_int('  Choice', 0, Len, K),
    (   K =:= 0 -> Value = unknown ; nth1(K, Options, Value) ).

ask_int(Prompt, Min, Max, N) :-
    format("~w: ", [Prompt]), flush_output,
    read_line_to_string(user_input, S0),
    (   S0 == end_of_file              % input closed: "unknown" for options, quit for the menu
    ->  ( Min =:= 0 -> N = 0 ; N = Max )
    ;   normalize_space(string(S), S0),
        (   S == "", Min =:= 0 -> N = 0
        ;   catch(number_string(N0, S), _, fail), integer(N0), N0 >= Min, N0 =< Max
        ->  N = N0
        ;   format("  Please enter a whole number ~w-~w.~n", [Min, Max]),
            ask_int(Prompt, Min, Max, N)
        )
    ).

/* ---- Printing an explanation ------------------------------------ */
print_sections(Sections) :-
    forall(member(section(Title, Lines), Sections),
           ( nl, string_upper(Title, T), format("~w~n", [T]),
             forall(member(line(I, Text), Lines),
                    ( Pad is 3 + I * 4, format("~t~*|~w~n", [Pad, Text]) )) )).
