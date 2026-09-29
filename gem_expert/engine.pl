/*  engine.pl
    Gemstone Identification Assistant - INFERENCE ENGINE + EXPLANATION

    Two inference strategies run over the SAME rule base (rule/3):

      Mode A  identify(Inputs)            FORWARD chaining (data-driven)
              Fires every rule whose conditions hold, adds its conclusion
              as a new fact and repeats until nothing new can be derived.
              Conflict resolution: the first applicable rule in knowledge
              base order fires (rules are ordered in layers), and the same
              rule never fires twice for the same conclusion (refractoriness).

      Mode B  verify(Inputs, Target, R)   BACKWARD chaining (goal-driven)
              Starts from a goal such as variety(ruby) and works backwards
              through the rules that conclude it, building a proof tree.
              If the goal fails, it explains WHICH condition failed.

      Mode C  consult(Target, Inputs, Unknowns, Outcome)
              Interactive backward chaining. The engine asks the user only
              for the facts it needs, when it needs them, and can answer
              "Why are you asking?" from its stack of active rules.

    Certainty factors (MYCIN style)
      Each rule has a certainty rule_cf(Id, CF) in the knowledge base.
      CF(conclusion) = CF(rule) x min(CF(conditions)).
      When a second rule supports a fact that is already known, the two
      certainties are combined:  CF = CF1 + CF2 x (1 - CF1).
      A reading inside a gem's published range has CF 1.0; a reading that
      only fits thanks to the measurement tolerance has CF 0.7.

    Session state is thread_local, so each web request (own thread) has
    its own working memory and several users cannot interfere.
*/

:- encoding(utf8).

:- thread_local fact/1.        % working memory: observed + derived facts
:- thread_local fired/3.       % fired(RuleId, InstantiatedConds, Conclusion)
:- thread_local cf/2.          % cf(Fact, Certainty) for derived facts
:- thread_local fired_cf/6.    % fired_cf(Id, Concl, RuleCF, MinCondCF, Contribution, CombinedAfter)
:- thread_local unknown_key/1. % consult mode: properties the user said they don't know

tolerance(ri, 0.005).
tolerance(sg, 0.03).

% highest RI a standard gem refractometer can read
refractometer_limit(1.81).

% how an RI value is shown to users
ri_value_text(over_limit, "over the refractometer limit") :- !.
ri_value_text(V, V).

/* Facts that come from the user (never concluded by rules) */
input_key(ri,         ri(_)).
input_key(sg,         sg(_)).
input_key(optic,      optic(_)).
input_key(colour,     observed_colour(_)).
input_key(phenomenon, phenomenon(_)).
input_key(inclusion,  inclusion(_)).

input_fact(F) :- input_key(_, F).

/* Conclusions that rules can derive */
derived_condition(species(_)).
derived_condition(variety(_)).
derived_condition(imitation(_)).
derived_condition(candidate(_)).
derived_condition(origin(_)).
derived_condition(treatment(_)).
derived_condition(advice(_)).

/* Conditions evaluated by computation rather than looked up */
test_condition(not(_)).
test_condition(optic(_)).
test_condition(ri_in(_)).
test_condition(sg_in(_)).
test_condition(missing(_)).
test_condition(partial_data).
test_condition(gem_type(_)).
test_condition(optic_ok(_)).
test_condition(ri_ok(_)).
test_condition(sg_ok(_)).
test_condition(colour_ok(_)).
test_condition(phenomenon_ok(_)).
test_condition(ambiguous_species).
test_condition(typical_colour_ok(_)).

/* ==================================================================
   Working memory
   ================================================================== */
reset_session :-
    retractall(fact(_)),
    retractall(fired(_, _, _)),
    retractall(cf(_, _)),
    retractall(fired_cf(_, _, _, _, _, _)),
    retractall(unknown_key(_)).

load_inputs(Inputs) :-
    reset_session,
    forall(member(F, Inputs), assertz(fact(F))).

session_inputs(Inputs) :-
    findall(F, (fact(F), input_fact(F)), Inputs).

/* ==================================================================
   Condition evaluation (forward mode)
   ================================================================== */
holds(C) :- test_condition(C), !, test(C).
holds(C) :- fact(C).

all_true([]).
all_true([C|Cs]) :- holds(C), all_true(Cs).

test(not(C)) :- \+ holds(C).
test(optic(T)) :-
    fact(optic(U)), optic_compatible(U, T).
% RI "over the limit": the refractometer shows no reading, so the stone's RI
% is above the instrument's limit; it fits any gem whose range goes above it
test(ri_in(G)) :-
    fact(ri(over_limit)), !,
    ri_range(G, _, Max), refractometer_limit(L), Max > L.
test(ri_in(G)) :-
    fact(ri(V)), number(V), ri_range(G, Min, Max), tolerance(ri, T),
    V >= Min - T, V =< Max + T.
test(sg_in(G)) :-
    fact(sg(V)), sg_range(G, Min, Max), tolerance(sg, T),
    V >= Min - T, V =< Max + T.
test(missing(K)) :-
    input_key(K, F), \+ fact(F).
test(partial_data) :-
    once(( member(K, [ri, sg, optic]), test(missing(K)) )),
    once(discriminating_input).
test(gem_type(G)) :- gem(G).
test(optic_ok(G)) :-
    (   fact(optic(_)) -> optic(G, T), test(optic(T)) ; true ).
test(ri_ok(G)) :-
    (   fact(ri(_)) -> test(ri_in(G)) ; true ).
test(sg_ok(G)) :-
    (   fact(sg(_)) -> test(sg_in(G)) ; true ).
test(colour_ok(G)) :-
    (   fact(observed_colour(C)) -> colour(G, C) ; true ).
test(phenomenon_ok(G)) :-
    (   fact(phenomenon(P)), P \== none -> phenomenon(G, P) ; true ).
test(ambiguous_species) :-
    fact(species(A)), fact(species(B)), A @< B, !.
test(typical_colour_ok(G)) :-
    fact(observed_colour(C)), typical_colour(G, C).

% "doubly refractive" (polariscope only, axis unknown) fits uniaxial or biaxial
optic_compatible(T, T).
optic_compatible(doubly_refractive, uniaxial).
optic_compatible(doubly_refractive, biaxial).

discriminating_input :- fact(ri(_)).
discriminating_input :- fact(sg(_)).
discriminating_input :- fact(optic(_)).
discriminating_input :- fact(observed_colour(_)).
discriminating_input :- fact(phenomenon(P)), P \== none.

/* ==================================================================
   MODE A - FORWARD CHAINING
   ================================================================== */
identify(Inputs) :-
    load_inputs(Inputs),
    forward_chain.

forward_chain :-
    (   select_rule(Id, Conds, Concl)
    ->  fire(Id, Conds, Concl),
        forward_chain
    ;   true                        % no rule can fire: fixed point reached
    ).

% conflict resolution: first rule in KB order whose conditions hold and
% which has not yet fired for this conclusion
select_rule(Id, Conds, Concl) :-
    rule(Id, Conds, Concl),
    all_true(Conds),
    ground(Concl),
    \+ fired(Id, _, Concl).

% fire a rule: add the conclusion (or strengthen it) with its certainty
fire(Id, Conds, Concl) :-
    rule_certainty(Id, RCF),
    % an evidence rule's own conclusion is not evidence for itself
    exclude(==(Concl), Conds, EvidenceConds),
    conds_cf(EvidenceConds, MinCF),
    Contribution is RCF * MinCF,
    (   cf(Concl, Old)
    ->  New is Old + Contribution * (1 - Old),       % MYCIN combination
        retract(cf(Concl, Old)), assertz(cf(Concl, New))
    ;   New = Contribution,
        assertz(fact(Concl)), assertz(cf(Concl, New))
    ),
    assertz(fired(Id, Conds, Concl)),
    assertz(fired_cf(Id, Concl, RCF, MinCF, Contribution, New)).

fired_ids(Ids) :- findall(Id, fired(Id, _, _), Ids).

/* ---- Certainty factors ------------------------------------------- */
rule_certainty(Id, CF) :- ( rule_cf(Id, CF0) -> CF = CF0 ; CF = 1.0 ).

% certainty of a fact in working memory (user inputs are certain)
fact_cf(F, CF) :- ( cf(F, CF0) -> CF = CF0 ; CF = 1.0 ).

conds_cf(Conds, Min) :-
    maplist(cond_cf, Conds, CFs),
    min_list([1.0|CFs], Min).

cond_cf(ri_in(G), CF) :- !, range_cf(ri, G, CF).
cond_cf(sg_in(G), CF) :- !, range_cf(sg, G, CF).
cond_cf(ri_ok(G), CF) :- !, ( fact(ri(_)) -> range_cf(ri, G, CF) ; CF = 1.0 ).
cond_cf(sg_ok(G), CF) :- !, ( fact(sg(_)) -> range_cf(sg, G, CF) ; CF = 1.0 ).
cond_cf(C, CF) :- derived_condition(C), ground(C), cf(C, CF), !.
cond_cf(_, 1.0).

% 1.0 when the reading lies inside the published range, 0.7 when it
% only fits thanks to the measurement tolerance
range_cf(ri, _, 0.85) :-                 % only known to be above the limit
    fact(ri(over_limit)), !.
range_cf(ri, G, CF) :-
    fact(ri(V)), ri_range(G, Mi, Ma),
    ( V >= Mi, V =< Ma -> CF = 1.0 ; CF = 0.7 ).
range_cf(sg, G, CF) :-
    fact(sg(V)), sg_range(G, Mi, Ma),
    ( V >= Mi, V =< Ma -> CF = 1.0 ; CF = 0.7 ).

% certainty of a backward-chaining proof tree
proof_cf(by(Id, _, Ps), CF) :- !,
    rule_certainty(Id, R),
    maplist(proof_cf, Ps, CFs), min_list([1.0|CFs], Min),
    CF is R * Min.
proof_cf(test(C), CF) :- !, cond_cf_test(C, CF).
proof_cf(_, 1.0).

cond_cf_test(ri_in(G), CF) :- !, range_cf(ri, G, CF).
cond_cf_test(sg_in(G), CF) :- !, range_cf(sg, G, CF).
cond_cf_test(_, 1.0).

percent(CF, P) :- P is round(CF * 100).

% cf_word(+Percent, -Words): what a certainty percentage means in plain words
cf_word(P, "very likely")        :- P >= 80, !.
cf_word(P, "likely")             :- P >= 60, !.
cf_word(P, "possible")           :- P >= 40, !.
cf_word(P, "weak evidence")      :- P >= 20, !.
cf_word(_, "very weak evidence").

% the scale shown to users
cf_scale([ "80-100%"-"Very likely: the evidence strongly supports it.",
           "60-79%"-"Likely: good evidence, with some doubt.",
           "40-59%"-"Possible: some evidence; take more measurements.",
           "20-39%"-"Weak evidence: treat it as a first guess only.",
           "below 20%"-"Very weak: not enough evidence to go on." ]).

/* ==================================================================
   MODE C - CONSULTATION (interactive backward chaining)
   The engine asks for an input only when a rule it is testing needs it.
   When it needs something it does not know it throws ask(Key, Stack),
   where Stack is the chain of rules being tried (innermost first).
   The interface asks the question and runs the consultation again with
   the new answer; answers already given are never asked again.
   ================================================================== */
consult(Target, Inputs, Unknowns, Outcome) :-
    load_inputs(Inputs),
    forall(member(K, Unknowns), assertz(unknown_key(K))),
    consult_goal(Target, Goal),
    catch(( prove_c(Goal, [], Proof)
          ->  Outcome = done(proved(Goal, Proof))
          ;   why_not(Goal, 3, Reasons),
              Outcome = done(failed(Goal, Reasons)) ),
          ask(K, Stack),
          Outcome = ask(K, Stack)).

consult_goal(any_species, species(_)) :- !.
consult_goal(T, G) :- goal_for(T, G).

prove_c(not(C), S, negated(C)) :- !, \+ prove_c(C, S, _).
prove_c(C, S, test(C)) :- test_condition(C), !,
    askable_keys(C, Ks), maplist(ensure_known(S), Ks),
    test(C).
prove_c(C, S, given(C)) :- input_fact(C), !,
    askable_keys(C, Ks), maplist(ensure_known(S), Ks),
    fact(C).
prove_c(C, S, by(Id, C, Ps)) :-
    rule(Id, Conds, C),
    prove_all_c(Conds, [frame(Id, C)|S], Ps).

prove_all_c([], _, []).
prove_all_c([C|Cs], S, [P|Ps]) :- prove_c(C, S, P), prove_all_c(Cs, S, Ps).

% ask for property K unless it is known or the user said "don't know"
ensure_known(S, K) :-
    input_key(K, F),
    (   fact(F) -> true
    ;   unknown_key(K) -> true
    ;   throw(ask(K, S))
    ).

% which user properties a condition needs
askable_keys(optic(_), [optic]).
askable_keys(optic_ok(_), [optic]).
askable_keys(ri_in(_), [ri]).
askable_keys(ri_ok(_), [ri]).
askable_keys(sg_in(_), [sg]).
askable_keys(sg_ok(_), [sg]).
askable_keys(observed_colour(_), [colour]).
askable_keys(colour_ok(_), [colour]).
askable_keys(typical_colour_ok(_), [colour]).
askable_keys(phenomenon(_), [phenomenon]).
askable_keys(phenomenon_ok(_), [phenomenon]).
askable_keys(inclusion(_), [inclusion]).
askable_keys(missing(K), [K]).
askable_keys(partial_data, [ri, sg, optic]).
askable_keys(C, []) :-
    \+ member(C, [optic(_), optic_ok(_), ri_in(_), ri_ok(_), sg_in(_), sg_ok(_),
                  observed_colour(_), colour_ok(_), typical_colour_ok(_),
                  phenomenon(_), phenomenon_ok(_), inclusion(_), missing(_), partial_data]).

/* WHY explanation: why is the system asking for property K? */
why_asking(K, Stack, Lines) :-
    reverse(Stack, Frames),
    findall(L, why_line(Frames, L), Body),
    key_phrase(K, KP0), string_lower(KP0, KP),
    (   last(Frames, frame(LastId, _))
    ->  format(string(Last), "To test rule ~w I need to know: ~w.", [LastId, KP])
    ;   format(string(Last), "I need to know: ~w.", [KP])
    ),
    append(Body, [Last], Lines).

why_line(Frames, L) :-
    nth1(I, Frames, frame(Id, Goal)),
    rule(Id, Conds, _),
    goal_text(Goal, GT),
    maplist(short_label_safe, Conds, CLs),
    atomic_list_concat(CLs, ' AND ', CA),
    short_label_safe(Goal, GL),
    (   I =:= 1
    ->  format(string(L), "I am trying to find out: ~w  Rule ~w says: IF ~w THEN ~w.", [GT, Id, CA, GL])
    ;   format(string(L), "To use that rule I first need to establish: ~w  Rule ~w says: IF ~w THEN ~w.", [GT, Id, CA, GL])
    ).

goal_text(species(G), T) :- !, ( var(G) -> T = "which species it is" ; label(G, L), format(string(T), "is it ~w?", [L]) ).
goal_text(variety(V), T) :- !, label(V, L), format(string(T), "is it ~w?", [L]).
goal_text(imitation(M), T) :- !, ( var(M) -> T = "is it an imitation?" ; label(M, L), format(string(T), "is it ~w?", [L]) ).
goal_text(G, T) :- term_text(G, T).

% short_label/2 lives in diagrams.pl; fall back to the raw term if absent
short_label_safe(C, S) :- catch(short_label(C, S), _, term_text(C, S)).

/* ==================================================================
   MODE B - BACKWARD CHAINING
   Proof tree terms:
     given(C)           C is a fact supplied by the user
     test(C)            C was checked by computation (ranges, optic ...)
     negated(C)         not(C): C could not be proved
     by(Id, C, Proofs)  C was proved by rule Id from sub-proofs
   ================================================================== */
verify(Inputs, Target, Result) :-
    load_inputs(Inputs),
    goal_for(Target, Goal),
    (   prove(Goal, Proof)
    ->  Result = proved(Goal, Proof)
    ;   why_not(Goal, 3, Reasons),
        Result = failed(Goal, Reasons)
    ).

goal_for(T, species(T))   :- gem(T), !.
goal_for(T, imitation(T)) :- imitation_material(T), !.
goal_for(T, variety(T)).

prove(not(C), negated(C)) :- !, \+ prove(C, _).
prove(C, test(C))  :- test_condition(C), !, test(C).
prove(C, given(C)) :- input_fact(C), !, fact(C).
prove(C, by(Id, C, Proofs)) :-
    rule(Id, Conds, C),
    prove_all(Conds, Proofs).

prove_all([], []).
prove_all([C|Cs], [P|Ps]) :- prove(C, P), prove_all(Cs, Ps).

/* Why not?  For every rule that could conclude Goal, find the first
   condition that fails. If that condition is itself a derived fact,
   explain recursively (to a depth limit).
   Reason = rule_failed(Id, FailedCondition, Detail)
   Detail = text(String) | sub(String, Reasons)                        */
why_not(Goal, Depth, Reasons) :-
    findall(rule_failed(Id, F, Detail),
            ( rule(Id, Conds, Goal),
              fail_point(Conds, F),
              fail_detail(F, Depth, Detail) ),
            Reasons).

fail_point([], none).
fail_point([C|Cs], F) :-
    (   prove(C, _) -> fail_point(Cs, F) ; F = C ).

fail_detail(none, _, text("all conditions hold")) :- !.
fail_detail(F, Depth, sub(Text, Sub)) :-
    derived_condition(F), Depth > 0, !,
    D1 is Depth - 1,
    why_not(F, D1, Sub),
    term_text(F, FT),
    format(string(Text), "needs ~w, which could not be established", [FT]).
fail_detail(F, _, text(Text)) :-
    describe_fail(F, Text).

/* ==================================================================
   Conclusion summary (after forward chaining)
   summary(Title, Confidence, OriginText, AdviceTexts)
   ================================================================== */
summary(Title, Confidence, Origin, Advice) :-
    summary_title(Title, Confidence),
    origin_summary(Origin),
    findall(T, (fired(_, _, advice(K)), advice_text(K, T)), Advice).

summary_title(Title, "Strong match - imitation identified") :-
    findall(M, fact(imitation(M)), Ms), Ms \== [], !,
    maplist(label, Ms, Ls), atomic_list_concat(Ls, ' / ', L),
    format(string(Title), "Imitation: ~w", [L]).
summary_title(Title, "Strong match - optic character, RI and SG all agree") :-
    findall(S, fact(species(S)), [S]), !,
    species_title(S, Title).
summary_title(Title, "Possible match - measurements fit more than one species") :-
    findall(S, fact(species(S)), Ss), Ss = [_,_|_], !,
    maplist(label, Ss, Ls), atomic_list_concat(Ls, ' or ', L),
    format(string(Title), "Ambiguous: ~w", [L]).
summary_title(Title, "Possible match - some data missing") :-
    findall(G, fact(candidate(G)), Gs), Gs \== [], !,
    maplist(label, Gs, Ls), atomic_list_concat(Ls, ', ', L),
    format(string(Title), "Possible: ~w", [L]).
summary_title("Unknown - no gem in the knowledge base matches",
              "No match - laboratory test advised").

species_title(S, Title) :-
    findall(V, fact(variety(V)), Vs),
    label(S, SL),
    (   Vs == []
    ->  format(string(Title), "~w", [SL])
    ;   maplist(label, Vs, VLs), atomic_list_concat(VLs, ' / ', VL),
        format(string(Title), "~w (~w)", [VL, SL])
    ).

origin_priority([imitation, synthetic, glass_or_synthetic,
                 needs_lab_test, likely_natural, undetermined]).

origin_summary(Text) :-
    origin_priority(Ps),
    member(O, Ps), fact(origin(O)), !,
    origin_text(O, T0),
    (   fact(treatment(likely_heated)), O == likely_natural
    ->  string_concat(T0, " (probably heat-treated)", T1)
    ;   T1 = T0
    ),
    (   member(O2, Ps), O2 \== O, fact(origin(O2)),
        O2 \== undetermined, O \== imitation
    ->  origin_text(O2, T2),
        format(string(Text), "~w - note: conflicting evidence also suggested '~w'", [T1, T2])
    ;   Text = T1
    ).
origin_summary("Not determined").

origin_text(imitation,          "Imitation (not a natural gemstone)").
origin_text(synthetic,          "Synthetic (laboratory-grown)").
origin_text(glass_or_synthetic, "Glass or synthetic").
origin_text(needs_lab_test,     "Undetermined - laboratory test recommended").
origin_text(likely_natural,     "Likely natural").
origin_text(undetermined,       "Not determined (no inclusion evidence)").

/* ==================================================================
   EXPLANATION FACILITY
   Explanations are built as a list of section(Title, Lines) where
   Lines = [line(Indent, String), ...], so the console and the web
   interface can render the same explanation.
   ================================================================== */

% HOW explanation for forward chaining
identify_explanation(Sections) :-
    session_inputs(Inputs),
    input_lines(Inputs, InLines),
    fact_lines(Inputs, FactLines),
    findall(Ls, (fired(Id, Conds, Concl), fired_rule_lines(Id, Conds, Concl, Ls)), Nested),
    append(Nested, RuleLines0),
    ( RuleLines0 == [] -> RuleLines = [line(0, "No rule could fire with the data supplied.")]
    ; RuleLines = RuleLines0 ),
    summary(Title, Conf, Origin, Advice),
    findall(line(1, A), member(A, Advice), AdvLines),
    findall(line(1, S),
            ( cf(F, CF), \+ F = advice(_), term_text(F, FT), percent(CF, P),
              format(string(S), "~w: ~w%", [FT, P]) ),
            CFLines),
    append([ [line(0, Title), line(0, "Confidence: " + Conf), line(0, "Origin: " + Origin)],
             [line(0, "Certainty of derived facts:")], CFLines,
             [line(0, "Recommendation(s):")], AdvLines ], ConcLines0),
    maplist(flatten_line, ConcLines0, ConcLines),
    Sections = [ section("User input", InLines),
                 section("Facts (working memory at start)", FactLines),
                 section("Rules fired (in order)", RuleLines),
                 section("Conclusion", ConcLines) ].

flatten_line(line(I, A + B), line(I, S)) :- !, format(string(S), "~w~w", [A, B]).
flatten_line(L, L).

fired_rule_lines(Id, Conds, Concl, [line(0, Head) | Rest]) :-
    term_text(Concl, CT),
    format(string(Head), "~w -> ~w", [Id, CT]),
    findall(line(2, D), (member(C, Conds), describe(C, D)), Because),
    (   rule_info(Id, Why, Src)
    ->  format(string(W), "why: ~w [source: ~w]", [Why, Src]),
        WhyLines = [line(1, W)]
    ;   WhyLines = []
    ),
    (   fired_cf(Id, Concl, RCF, Min, Contr, After)
    ->  format(string(CFL), "certainty: rule CF ~2f x weakest condition ~2f = ~2f; ~w now has CF ~2f",
               [RCF, Min, Contr, CT, After]),
        CFLines = [line(1, CFL)]
    ;   CFLines = []
    ),
    append([[line(1, "because:")], Because, WhyLines, CFLines], Rest).

input_lines(Inputs, Lines) :-
    findall(line(0, S),
            ( member(K, [ri, sg, optic, colour, phenomenon, inclusion]),
              input_key(K, F),
              (   member(F, Inputs)
              ->  arg(1, F, V0), ri_value_text(V0, V),
                  key_label(K, KL), format(string(S), "~w = ~w", [KL, V])
              ;   key_label(K, KL), format(string(S), "~w = (not supplied)", [KL])
              ) ),
            Lines).

fact_lines(Inputs, [line(0, S)]) :-
    maplist(term_text, Inputs, Ts),
    (   Ts == [] -> S = "(none)" ; atomic_list_concat(Ts, ', ', A), atom_string(A, S) ).

key_label(ri, 'RI').
key_label(sg, 'SG').
key_label(optic, 'Optic character').
key_label(colour, 'Colour').
key_label(phenomenon, 'Phenomenon').
key_label(inclusion, 'Inclusion').

% Proof-tree explanation for backward chaining
verify_explanation(proved(Goal, Proof), Headline, Sections) :-
    goal_label(Goal, GL),
    format(string(Headline), "YES - the evidence supports: ~w", [GL]),
    session_inputs(Inputs), input_lines(Inputs, InLines),
    proof_lines(Proof, 0, PLines),
    Sections = [ section("User input", InLines),
                 section("Goal", [line(0, GL)]),
                 section("Proof tree (backward chaining)", PLines) ].
verify_explanation(failed(Goal, Reasons), Headline, Sections) :-
    goal_label(Goal, GL),
    format(string(Headline), "NO - the evidence does not support: ~w", [GL]),
    session_inputs(Inputs), input_lines(Inputs, InLines),
    term_text(Goal, GT),
    (   Reasons == []
    ->  format(string(S), "No rule in the knowledge base concludes ~w.", [GT]),
        WLines = [line(0, S)]
    ;   reason_lines(Reasons, 0, WLines)
    ),
    format(string(WT), "Why not ~w?", [GL]),
    Sections = [ section("User input", InLines),
                 section("Goal", [line(0, GL)]),
                 section(WT, WLines) ].

goal_label(G, L) :- arg(1, G, X), label(X, L).

proof_lines(by(Id, C, Ps), I, [line(I, S) | Sub]) :- !,
    term_text(C, CT),
    format(string(S), "~w   [proved by rule ~w]", [CT, Id]),
    I1 is I + 1,
    findall(L, (member(P, Ps), proof_lines(P, I1, L)), Nested),
    append(Nested, Sub).
proof_lines(given(C), I, [line(I, S)]) :- !,
    term_text(C, CT), format(string(S), "~w   [your input]", [CT]).
proof_lines(test(C), I, [line(I, S)]) :- !,
    describe(C, D), format(string(S), "~w   [checked]", [D]).
proof_lines(negated(C), I, [line(I, S)]) :-
    term_text(C, CT), format(string(S), "not ~w   [cannot be proved]", [CT]).

reason_lines(Reasons, I, Lines) :-
    findall(L, (member(R, Reasons), reason_line(R, I, L)), Nested),
    append(Nested, Lines).

reason_line(rule_failed(Id, _F, text(T)), I, [line(I, S)]) :-
    format(string(S), "Rule ~w failed: ~w", [Id, T]).
reason_line(rule_failed(Id, _F, sub(T, Sub)), I, [line(I, S) | SubLines]) :-
    format(string(S), "Rule ~w failed: ~w", [Id, T]),
    I1 is I + 1,
    (   Sub == []
    ->  SubLines = [line(I1, "(no rule concludes it)")]
    ;   reason_lines(Sub, I1, SubLines)
    ).

/* ---- Describing a satisfied condition ---------------------------- */
describe(optic(T), S) :- !,
    (   fact(optic(T))
    ->  format(string(S), "optic character is ~w", [T])
    ;   fact(optic(U)),
        format(string(S), "optic character is ~w (compatible with ~w)", [U, T])
    ).
describe(ri_in(G), S) :- fact(ri(over_limit)), !,
    ri_range(G, Mi, Ma), refractometer_limit(L),
    format(string(S), "RI is over the refractometer limit (~w); the ~w range ~3f-~3f goes above it", [L, G, Mi, Ma]).
describe(ri_in(G), S) :- !,
    fact(ri(V)), ri_range(G, Mi, Ma), tolerance(ri, T),
    format(string(S), "RI ~w lies in the ~w range ~3f-~3f (+/-~w)", [V, G, Mi, Ma, T]).
describe(sg_in(G), S) :- !,
    fact(sg(V)), sg_range(G, Mi, Ma), tolerance(sg, T),
    format(string(S), "SG ~w lies in the ~w range ~2f-~2f (+/-~w)", [V, G, Mi, Ma, T]).
describe(missing(K), S) :- !,
    key_label(K, KL), format(string(S), "~w was not supplied", [KL]).
describe(partial_data, "some core measurements (RI, SG or optic character) are missing") :- !.
describe(gem_type(G), S) :- !,
    format(string(S), "~w is a gem species in the knowledge base", [G]).
describe(optic_ok(G), S) :- !,
    (   fact(optic(U)) -> optic(G, T), format(string(S), "optic ~w is consistent with ~w (~w)", [U, G, T])
    ;   S = "optic character not supplied - no constraint" ).
describe(ri_ok(G), S) :- !,
    (   fact(ri(_)) -> describe(ri_in(G), S) ; S = "RI not supplied - no constraint" ).
describe(sg_ok(G), S) :- !,
    (   fact(sg(_)) -> describe(sg_in(G), S) ; S = "SG not supplied - no constraint" ).
describe(colour_ok(G), S) :- !,
    (   fact(observed_colour(C)) -> format(string(S), "~w occurs in ~w colour", [G, C])
    ;   S = "colour not supplied - no constraint" ).
describe(phenomenon_ok(G), S) :- !,
    (   fact(phenomenon(P)), P \== none -> format(string(S), "~w can show ~w", [G, P])
    ;   S = "no phenomenon reported - no constraint" ).
describe(ambiguous_species, "more than one species matched the measurements") :- !.
describe(not(C), S) :- !,
    term_text(C, CT), format(string(S), "~w is not established", [CT]).
describe(observed_colour(C), S) :- !, format(string(S), "colour is ~w (your input)", [C]).
describe(phenomenon(P), S) :- !, format(string(S), "phenomenon ~w observed (your input)", [P]).
describe(inclusion(I), S) :- !, format(string(S), "inclusion seen: ~w (your input)", [I]).
describe(C, S) :-
    term_text(C, CT), format(string(S), "~w (established earlier)", [CT]).

/* ---- Describing a FAILED condition (Why not?) -------------------- */
describe_fail(optic(T), S) :- !,
    (   fact(optic(U))
    ->  format(string(S), "needs optic character ~w, but you entered ~w", [T, U])
    ;   format(string(S), "needs optic character ~w, which was not supplied", [T])
    ).
describe_fail(ri_in(G), S) :- !,
    ri_range(G, Mi, Ma),
    (   fact(ri(V0))
    ->  ri_value_text(V0, V),
        format(string(S), "needs RI in the ~w range ~3f-~3f, but RI is ~w", [G, Mi, Ma, V])
    ;   format(string(S), "needs RI in the ~w range ~3f-~3f, but RI was not supplied", [G, Mi, Ma])
    ).
describe_fail(sg_in(G), S) :- !,
    sg_range(G, Mi, Ma),
    (   fact(sg(V))
    ->  format(string(S), "needs SG in the ~w range ~2f-~2f, but SG is ~w", [G, Mi, Ma, V])
    ;   format(string(S), "needs SG in the ~w range ~2f-~2f, but SG was not supplied", [G, Mi, Ma])
    ).
describe_fail(observed_colour(C), S) :- !,
    (   fact(observed_colour(U))
    ->  format(string(S), "needs colour ~w, but you entered ~w", [C, U])
    ;   format(string(S), "needs colour ~w, which was not supplied", [C])
    ).
describe_fail(phenomenon(P), S) :- !,
    (   fact(phenomenon(U))
    ->  format(string(S), "needs phenomenon ~w, but you entered ~w", [P, U])
    ;   format(string(S), "needs phenomenon ~w, which was not reported", [P])
    ).
describe_fail(inclusion(I), S) :- !,
    (   fact(inclusion(U))
    ->  format(string(S), "needs inclusion ~w, but you entered ~w", [I, U])
    ;   format(string(S), "needs inclusion ~w, which was not reported", [I])
    ).
describe_fail(missing(K), S) :- !,
    key_label(K, KL), format(string(S), "applies only when ~w is missing, but it was supplied", [KL]).
describe_fail(not(C), S) :- !,
    term_text(C, CT), format(string(S), "is blocked because ~w holds", [CT]).
describe_fail(C, S) :-
    term_text(C, CT), format(string(S), "condition ~w is not satisfied", [CT]).

/* ==================================================================
   USER-FRIENDLY EXPLANATIONS
   The same reasoning as above, phrased in plain language for users
   who do not read Prolog. Used by the web and console interfaces.
   ================================================================== */

/* ---- Result classification (after forward chaining) -------------- */
result_kind(imitation(Ms))  :- ranked(imitation, Ms), Ms \== [], !.
result_kind(strong(S))      :- findall(S0, fact(species(S0)), [S]), !.
result_kind(ambiguous(Ss))  :- ranked(species, Ss), Ss = [_,_|_], !.
result_kind(candidates(Gs)) :- ranked(candidate, Gs), Gs \== [], !.
result_kind(none).

% ranked(+Functor, -Xs): derived facts Functor(X), most certain first
ranked(F, Xs) :-
    findall(NegCF-X, ( T =.. [F, X], fact(T), fact_cf(T, CF), NegCF is -CF ), Ps),
    keysort(Ps, Sorted), pairs_values(Sorted, Xs).

% certainty of the main conclusion
main_cf(imitation([M|_]), CF) :- !, fact_cf(imitation(M), CF).
main_cf(strong(S), CF) :- !,
    (   findall(C, (fact(variety(V)), fact_cf(variety(V), C)), [C1|Cs])
    ->  max_list([C1|Cs], CF)
    ;   fact_cf(species(S), CF) ).
main_cf(ambiguous([S|_]), CF) :- !, fact_cf(species(S), CF).
main_cf(candidates([G|_]), CF) :- !, fact_cf(candidate(G), CF).
main_cf(none, 0.0).

% plain-language evidence behind a candidate or ambiguous species
evidence_for(Kind, G, Items) :-
    ( Kind = candidates(_) -> T = candidate(G) ; T = species(G) ),
    findall(Text,
            ( fired(Id, Conds, T),
              fired_cf(Id, T, _, _, Contr, _), percent(Contr, P),
              evidence_text(Id, Conds, T, E),
              format(string(Text), "~w (+~w%, rule ~w)", [E, P, Id]) ),
            Items).

evidence_text(r14, _, _, "Consistent with everything you entered") :- !.
evidence_text(_, Conds, candidate(_), E) :- last(Conds, C), friendly_reason(C, E), !.
evidence_text(_, Conds, _, E) :-
    convlist(friendly_reason_once, Conds, Rs), atomic_list_concat(Rs, '; ', A), atom_string(A, E).

% headline(+Kind, -Kicker, -Title, -Subtitle, -Level(1-3), -PictureKey)
headline(imitation(Ms), "Imitation detected", Title, "This is not a natural gemstone", 3, M) :-
    Ms = [M|_], join_labels(Ms, " / ", Title).
headline(strong(S), "Most likely", Title, Sub, 3, Key) :-
    label(S, SL),
    findall(V, fact(variety(V)), Vs),
    (   Vs = [V|_]
    ->  join_labels(Vs, " / ", Title), Key = V,
        format(string(Sub), "Gem species: ~w", [SL])
    ;   format(string(Title), "~w", [SL]), Key = S,
        Sub = "Gem species (the colour given does not name a specific variety)"
    ).
headline(ambiguous(Ss), "Close call", Title, "Your readings fall where these species overlap", 2, S) :-
    Ss = [S|_], join_labels(Ss, " or ", Title).
headline(candidates(Gs), "Possible matches", Title, "Not enough measurements for a firm answer", 2, Key) :-
    length(Gs, N),
    (   N =< 4 -> join_labels(Gs, " or ", Title)
    ;   format(string(Title), "~w possible gems", [N]) ),
    (   Gs = [Key] -> true ; Key = unknown ).
headline(none, "No match", "We could not identify this stone",
         "None of the gems in the knowledge base fit your data", 1, unknown).

level_text(3, "Strong match").
level_text(2, "Possible match").
level_text(1, "No match").

join_labels(Xs, Sep, Text) :-
    maplist(label, Xs, Ls), atomic_list_concat(Ls, Sep, A), atom_string(A, Text).

% primary_origin(-Origin, -Tone, -Text)   Tone: good | warn | bad | neutral
primary_origin(O, Tone, Text) :-
    origin_priority(Ps), member(O, Ps), fact(origin(O)), !,
    origin_tone(O, Tone), origin_text(O, Text).
primary_origin(none, neutral, "Origin not assessed").

origin_tone(likely_natural,     good).
origin_tone(synthetic,          warn).
origin_tone(needs_lab_test,     warn).
origin_tone(glass_or_synthetic, bad).
origin_tone(imitation,          bad).
origin_tone(undetermined,       neutral).

/* ---- Plain-language phrases -------------------------------------- */
optic_phrase(isotropic,         "singly refractive (isotropic)").
optic_phrase(uniaxial,          "doubly refractive with one optic axis (uniaxial)").
optic_phrase(biaxial,           "doubly refractive with two optic axes (biaxial)").
optic_phrase(doubly_refractive, "doubly refractive").

phenomenon_phrase(star,          "a star (asterism)").
phenomenon_phrase(cats_eye,      "a cat's-eye band (chatoyancy)").
phenomenon_phrase(colour_change, "a colour change between daylight and lamp light").
phenomenon_phrase(adularescence, "a floating bluish glow (adularescence)").
phenomenon_phrase(none,          "no special optical effect").

inclusion_phrase(I, P) :- inclusion_type(I, T), downcase_atom(T, P).

key_phrase(ri,         "The refractive index").
key_phrase(sg,         "The specific gravity").
key_phrase(optic,      "The optic character").
key_phrase(colour,     "The colour").
key_phrase(phenomenon, "An optical effect").
key_phrase(inclusion,  "Inclusion information").

stage(species(_),   "Species").
stage(imitation(_), "Imitation check").
stage(candidate(_), "Possible match").
stage(variety(_),   "Variety").
stage(origin(_),    "Natural or not?").
stage(treatment(_), "Treatment").
stage(advice(_),    "Recommendation").

friendly_conclusion(species(G), S)   :- label(G, L), format(string(S), "Identified as ~w", [L]).
friendly_conclusion(imitation(M), S) :- label(M, L), format(string(S), "Identified as an imitation: ~w", [L]).
friendly_conclusion(candidate(G), S) :- label(G, L), format(string(S), "~w is still possible", [L]).
friendly_conclusion(variety(V), S)   :- label(V, L), format(string(S), "Variety named: ~w", [L]).
friendly_conclusion(origin(O), S)    :- origin_text(O, T), format(string(S), "Origin: ~w", [T]).
friendly_conclusion(treatment(likely_heated), "Probably heat-treated").
friendly_conclusion(advice(K), S)    :- advice_title(K, T), format(string(S), "Advice: ~w", [T]).

advice_title(get_certificate,     "get it certified before buying").
advice_title(synthetic_price,     "price it as a synthetic").
advice_title(imitation_value,     "not a real gemstone").
advice_title(lab_test_bubbles,    "a laboratory test is needed").
advice_title(lab_test_clean,      "a laboratory test is needed").
advice_title(check_inclusions,    "look for inclusions with a loupe").
advice_title(disclose_heat,       "heat treatment must be disclosed").
advice_title(check_colour_change, "confirm the colour change").
advice_title(padparadscha_cert,   "certify the padparadscha name").
advice_title(measure_more,        "take more measurements").
advice_title(re_measure,          "re-measure to separate the species").
advice_title(no_match,            "re-check the data or get a lab test").

/* friendly_reason(+Condition, -Text): why a satisfied condition holds.
   Fails for purely technical conditions, which are then left out. */
friendly_reason(optic(T), S) :-
    fact(optic(U)), optic_phrase(U, UP),
    (   U == T -> format(string(S), "Your stone is ~w", [UP])
    ;   optic_phrase(T, TP), format(string(S), "Your stone is ~w, which fits ~w", [UP, TP]) ).
friendly_reason(ri_in(G), S) :-
    fact(ri(over_limit)), !, ri_range(G, Mi, Ma), label(G, L), refractometer_limit(Lim),
    format(string(S), "Its refractive index is over the refractometer limit (above about ~w), which fits the ~w range of ~3f-~3f", [Lim, L, Mi, Ma]).
friendly_reason(ri_in(G), S) :-
    fact(ri(V)), ri_range(G, Mi, Ma), label(G, L),
    format(string(S), "Its refractive index (~w) is within the ~w range of ~3f-~3f", [V, L, Mi, Ma]).
friendly_reason(sg_in(G), S) :-
    fact(sg(V)), sg_range(G, Mi, Ma), label(G, L),
    format(string(S), "Its specific gravity (~w) is within the ~w range of ~2f-~2f", [V, L, Mi, Ma]).
friendly_reason(observed_colour(C), S) :- format(string(S), "Its colour is ~w", [C]).
friendly_reason(phenomenon(P), S) :-
    phenomenon_phrase(P, PP), format(string(S), "It shows ~w", [PP]).
friendly_reason(inclusion(I), S) :-
    inclusion_phrase(I, IP), format(string(S), "Under the loupe you saw: ~w", [IP]).
friendly_reason(species(G), S) :-
    nonvar(G), label(G, L), format(string(S), "It has been identified as ~w", [L]).
friendly_reason(variety(V), S) :-
    nonvar(V), label(V, L), format(string(S), "It is the variety ~w", [L]).
friendly_reason(imitation(M), S) :-
    (   nonvar(M) -> label(M, L), format(string(S), "It was identified as ~w, an imitation", [L])
    ;   S = "It was identified as an imitation" ).
friendly_reason(candidate(G), S) :-
    (   nonvar(G) -> label(G, L), format(string(S), "~w is a possible match", [L])
    ;   S = "There are possible matches" ).
friendly_reason(origin(O), S) :-
    origin_text(O, T), format(string(S), "Its origin was assessed as: ~w", [T]).
friendly_reason(treatment(likely_heated), "It shows signs of heat treatment").
friendly_reason(not(C), S) :- friendly_negation(C, S).
friendly_reason(missing(K), S) :-
    key_phrase(K, KP), format(string(S), "~w was not given", [KP]).
friendly_reason(partial_data, "Some key measurements are missing, so only a partial match is possible").
friendly_reason(optic_ok(G), S) :-
    fact(optic(_)), optic(G, T), optic_phrase(T, TP), label(G, L),
    format(string(S), "~w is ~w, which fits your stone", [L, TP]).
friendly_reason(ri_ok(G), S)  :- fact(ri(_)), friendly_reason(ri_in(G), S).
friendly_reason(sg_ok(G), S)  :- fact(sg(_)), friendly_reason(sg_in(G), S).
friendly_reason(colour_ok(G), S) :-
    fact(observed_colour(C)), label(G, L), format(string(S), "~w can be ~w", [L, C]).
friendly_reason(phenomenon_ok(G), S) :-
    fact(phenomenon(P)), P \== none, phenomenon_phrase(P, PP), label(G, L),
    format(string(S), "~w can show ~w", [L, PP]).
friendly_reason(ambiguous_species, "The readings fit more than one species").
friendly_reason(typical_colour_ok(G), S) :-
    fact(observed_colour(C)), label(G, L),
    format(string(S), "~w is a typical colour for ~w", [C, L]).

friendly_negation(missing(K), S) :- !,
    key_phrase(K, KP), format(string(S), "~w was given", [KP]).
friendly_negation(phenomenon(P), S) :-
    phenomenon_phrase(P, PP), format(string(S), "It does not show ~w", [PP]).
friendly_negation(observed_colour(C), S) :- format(string(S), "It is not ~w", [C]).
friendly_negation(species(G), S) :-
    (   var(G) -> S = "No gem species matched all the measurements"
    ;   label(G, L), format(string(S), "It is not ~w", [L]) ).
friendly_negation(imitation(_), "It was not identified as an imitation").
friendly_negation(candidate(_), "No partial matches were found either").
friendly_negation(C, S) :- term_text(C, T), format(string(S), "~w does not hold", [T]).

/* friendly_steps(-Steps): the forward-chaining trace in plain language
   step(Stage, RuleId, Headline, Reasons, ExpertKnowledge, Source, Certainty) */
friendly_steps(Steps) :-
    findall(step(Stage, Id, Head, Reasons, Why, Cite, CFText),
            ( fired(Id, Conds, Concl),
              stage(Concl, Stage),
              step_head(Conds, Concl, Head),
              convlist(friendly_reason_once, Conds, Reasons0),
              exclude(==(""), Reasons0, Reasons),
              rule_why(Id, Why, Cite),
              step_cf_text(Id, Conds, Concl, CFText) ),
            Steps).

% an evidence rule re-concludes a fact that is already one of its conditions
step_head(Conds, candidate(G), Head) :- memberchk(candidate(G), Conds), !,
    label(G, L), format(string(Head), "More evidence for ~w", [L]).
step_head(_, Concl, Head) :- friendly_conclusion(Concl, Head).

step_cf_text(Id, Conds, Concl, Text) :-
    (   fired_cf(Id, Concl, _, _, Contr, After)
    ->  percent(Contr, P1), percent(After, P2),
        (   Concl = candidate(_), memberchk(Concl, Conds)
        ->  format(string(Text), "adds ~w% - combined certainty now ~w%", [P1, P2])
        ;   P1 =:= P2
        ->  format(string(Text), "certainty ~w%", [P1])
        ;   format(string(Text), "adds ~w% - combined certainty now ~w%", [P1, P2])
        )
    ;   Text = ""
    ).

friendly_reason_once(C, S) :- friendly_reason(C, S), !.

rule_why(Id, Why, Cite) :-
    (   rule_info(Id, Why, Src)
    ->  ( source(Src, Cite) -> true ; Cite = Src )
    ;   Why = "", Cite = ""
    ).

/* proof_steps(+ProofTree, -Steps): a backward-chaining proof as the
   same kind of plain-language steps, innermost (first proved) first */
proof_steps(by(Id, C, Ps), Steps) :- !,
    findall(S, (member(P, Ps), proof_steps(P, S)), Nested),
    append(Nested, Sub),
    stage(C, Stage),
    friendly_conclusion(C, Head),
    convlist(proof_reason, Ps, Reasons),
    rule_why(Id, Why, Cite),
    proof_cf(by(Id, C, Ps), CF), percent(CF, P),
    format(string(CFText), "certainty ~w%", [P]),
    append(Sub, [step(Stage, Id, Head, Reasons, Why, Cite, CFText)], Steps).
proof_steps(_, []).

proof_reason(given(C), S)    :- friendly_reason(C, S), !.
proof_reason(test(C), S)     :- friendly_reason(C, S), !.
proof_reason(negated(C), S)  :- friendly_negation(C, S), !.
proof_reason(by(_, C, _), S) :- friendly_reason(C, S), !.

/* friendly_why_not(+Reasons, -Items): a failed backward-chaining goal
   as a plain-language tree   item(RuleId, Text, SubItems) */
friendly_why_not(Rs, Items) :- maplist(friendly_item, Rs, Items).

friendly_item(rule_failed(Id, F, sub(_, Sub)), item(Id, S, Items)) :- !,
    friendly_fail(F, S0),
    string_concat(S0, ", which fails because:", S),
    friendly_why_not(Sub, Items0),
    (   Items0 == []
    ->  Items = [item('-', "No rule in the knowledge base can conclude it", [])]
    ;   Items = Items0 ).
friendly_item(rule_failed(Id, F, text(_)), item(Id, S, [])) :-
    friendly_fail(F, S0),
    (   derived_condition(F) -> string_concat(S0, ", which could not be established", S)
    ;   S = S0 ).

main_reason([item(_, T, [])|_], T) :- !.
main_reason([item(_, _, Sub)|_], T) :- main_reason(Sub, T).

friendly_fail(optic(T), S) :- !,
    optic_phrase(T, TP),
    (   fact(optic(U)), optic_phrase(U, UP)
    ->  format(string(S), "It must be ~w, but you entered ~w", [TP, UP])
    ;   format(string(S), "It must be ~w, but the optic character was not given", [TP]) ).
friendly_fail(ri_in(G), S) :- !,
    ri_range(G, Mi, Ma), label(G, L),
    (   fact(ri(V0))
    ->  ri_value_text(V0, V),
        format(string(S), "Its refractive index must be ~3f-~3f (~w), but yours is ~w", [Mi, Ma, L, V])
    ;   format(string(S), "Its refractive index must be ~3f-~3f (~w), but no RI was given", [Mi, Ma, L]) ).
friendly_fail(sg_in(G), S) :- !,
    sg_range(G, Mi, Ma), label(G, L),
    (   fact(sg(V))
    ->  format(string(S), "Its specific gravity must be ~2f-~2f (~w), but yours is ~w", [Mi, Ma, L, V])
    ;   format(string(S), "Its specific gravity must be ~2f-~2f (~w), but no SG was given", [Mi, Ma, L]) ).
friendly_fail(observed_colour(C), S) :- !,
    (   fact(observed_colour(U))
    ->  format(string(S), "It must be ~w, but you entered ~w", [C, U])
    ;   format(string(S), "It must be ~w, but no colour was given", [C]) ).
friendly_fail(phenomenon(P), S) :- !,
    phenomenon_phrase(P, PP),
    (   fact(phenomenon(U)), phenomenon_phrase(U, UP)
    ->  format(string(S), "It must show ~w, but you reported ~w", [PP, UP])
    ;   format(string(S), "It must show ~w, but no optical effect was reported", [PP]) ).
friendly_fail(inclusion(I), S) :- !,
    inclusion_phrase(I, IP),
    (   fact(inclusion(U)), inclusion_phrase(U, UP)
    ->  format(string(S), "It needs this inclusion: ~w - but you reported: ~w", [IP, UP])
    ;   format(string(S), "It needs this inclusion: ~w - but no inclusions were reported", [IP]) ).
friendly_fail(species(G), S) :- nonvar(G), !,
    label(G, L), format(string(S), "It must first be identified as ~w", [L]).
friendly_fail(variety(V), S) :- nonvar(V), !,
    label(V, L), format(string(S), "It must first be the variety ~w", [L]).
friendly_fail(missing(K), S) :- !,
    key_phrase(K, KP), format(string(S), "This route only applies when ~w is unknown, but you gave it", [KP]).
friendly_fail(not(C), S) :- !, friendly_blocker(C, S).
friendly_fail(C, S) :-
    term_text(C, T), format(string(S), "The condition ~w is not met", [T]).

friendly_blocker(phenomenon(P), S) :- !,
    phenomenon_phrase(P, PP), format(string(S), "It must NOT show ~w, but you reported it", [PP]).
friendly_blocker(observed_colour(C), S) :- !,
    format(string(S), "It must NOT be ~w, but it is", [C]).
friendly_blocker(species(G), S) :- !,
    (   var(G) -> S = "This route only applies when no gem species matches, but one does"
    ;   label(G, L), format(string(S), "It must NOT be ~w, but it is", [L]) ).
friendly_blocker(imitation(_), "This route only applies when no imitation was identified, but one was") :- !.
friendly_blocker(C, S) :-
    term_text(C, T), format(string(S), "It is ruled out because ~w holds", [T]).

/* gem_profile(+Material, -Pairs): reference facts about a gem */
gem_profile(G, Pairs) :-
    findall(K-V,
            ( ( ri_range(G, Mi, Ma), K = "Refractive index", format(string(V), "~3f - ~3f", [Mi, Ma])
              ; sg_range(G, Mi, Ma), K = "Specific gravity", format(string(V), "~2f - ~2f", [Mi, Ma])
              ; optic(G, O), K = "Optic character", optic_phrase(O, V)
              ; birefringence(G, B), B > 0, K = "Birefringence", format(string(V), "~3f", [B])
              ; hardness(G, H), K = "Hardness (Mohs)", format(string(V), "~w", [H])
              ; findall(C, colour(G, C), Cs), Cs \== [], K = "Colours",
                atomic_list_concat(Cs, ', ', A), atom_string(A, V)
              ; findall(P, phenomenon(G, P), Ps), Ps \== [], K = "Possible effects",
                maplist(label, Ps, PLs), atomic_list_concat(PLs, ', ', A2), atom_string(A2, V)
              ) ),
            Pairs).

/* ==================================================================
   Utilities
   ================================================================== */

% term_text(+Term, -String): print a term, unbound variables shown as _
term_text(T, S) :-
    copy_term(T, T2),
    term_variables(T2, Vs),
    maplist(=('_'), Vs),
    format(string(S), "~w", [T2]).

% label(+Atom, -Text): human-readable name
label(cats_eye_chrysoberyl, 'Cat''s-eye chrysoberyl') :- !.
label(pyrope_almandine, 'Pyrope-almandine garnet') :- !.
label(cats_eye, 'Cat''s-eye') :- !.
label(any_species, 'any gem species') :- !.
label(X, 'any gem species') :- var(X), !.
label(A, L) :-
    atom(A), !,
    atomic_list_concat(Parts, '_', A),
    atomic_list_concat(Parts, ' ', Spaced),
    sub_atom(Spaced, 0, 1, _, First),
    sub_atom(Spaced, 1, _, 0, Rest),
    upcase_atom(First, Up),
    atom_concat(Up, Rest, L).
label(X, L) :- format(atom(L), "~w", [X]).

% All verifiable targets (for menus): species, varieties, imitations
verify_targets(Targets) :-
    findall(G, gem(G), Gems),
    findall(V, rule(_, _, variety(V)), Vs0), sort(Vs0, Vs),
    findall(M, imitation_material(M), Ms),
    append([Vs, Gems, Ms], Targets).

/* Export the rule base as CSV (for the knowledge acquisition table) */
export_rules_csv(File) :-
    setup_call_cleanup(
        open(File, write, Out),
        ( format(Out, "Id,Conditions,Conclusion,CF,Justification,Source~n", []),
          forall(rule(Id, Conds, Concl),
                 ( term_text(Conds, CS), term_text(Concl, CoS),
                   rule_certainty(Id, CF),
                   ( rule_info(Id, W, Src) -> true ; W = '', Src = '' ),
                   ( source(Src, Cite) -> true ; Cite = Src ),
                   csv_quote(CS, Q1), csv_quote(CoS, Q2),
                   csv_quote(W, Q3), csv_quote(Cite, Q4),
                   format(Out, "~w,~w,~w,~2f,~w,~w~n", [Id, Q1, Q2, CF, Q3, Q4]) )) ),
        close(Out)),
    format("Rules written to ~w~n", [File]).

csv_quote(X, Q) :-
    format(string(S), "~w", [X]),
    split_string(S, "\"", "", Parts),
    atomic_list_concat(Parts, '""', Esc),
    format(string(Q), "\"~w\"", [Esc]).
