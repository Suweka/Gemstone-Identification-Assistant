/*  diagrams.pl
    Gemstone Identification Assistant - REASONING DIAGRAMS (SVG)

    Draws the reasoning of the current session as an SVG diagram:

      forward_diagram(-SVG, -Captions)
          Data-driven flow. Input facts at the top; each fired rule is a
          node fed by the facts that satisfied it, producing a new fact
          one level lower. Nodes are numbered in firing order (cycles).

      backward_diagram(+VerifyResult, -SVG, -Captions)
          Goal tree. The goal at the top; below it the rules that could
          conclude it; below each rule its conditions (sub-goals) with
          status: proved, failed, or never checked (search stops at the
          first failed condition).

    Every node carries data-step="N" so the page can replay the reasoning
    step by step. Captions is a list with one explanation per step.
*/

:- encoding(utf8).

node_w(146).
node_h(58).
rule_w(60).
rule_h(28).
gap(16).
row_h(80).
margin(24).

/* ==================================================================
   Short labels for nodes
   ================================================================== */
short_label(ri(V), S)              :- !, format(string(S), "RI = ~w", [V]).
short_label(sg(V), S)              :- !, format(string(S), "SG = ~w", [V]).
short_label(optic(T), S)           :- !, label(T, L), format(string(S), "Optic: ~w", [L]).
short_label(observed_colour(C), S) :- !, label(C, L), format(string(S), "Colour: ~w", [L]).
short_label(phenomenon(P), S)      :- !, label(P, L), format(string(S), "Effect: ~w", [L]).
short_label(inclusion(I), S)       :- !, label(I, L), format(string(S), "Inclusion: ~w", [L]).
short_label(species(G), S)         :- !, ( var(G) -> S = "Any species" ; label(G, L), format(string(S), "Species: ~w", [L]) ).
short_label(variety(V), S)         :- !, label(V, L), format(string(S), "Variety: ~w", [L]).
short_label(imitation(M), S)       :- !, ( var(M) -> S = "Any imitation" ; label(M, L), format(string(S), "Imitation: ~w", [L]) ).
short_label(candidate(G), S)       :- !, ( var(G) -> S = "Any candidate" ; label(G, L), format(string(S), "Possible: ~w", [L]) ).
short_label(origin(O), S)          :- !, origin_text(O, T), format(string(S), "Origin: ~w", [T]).
short_label(treatment(_), "Heat-treated") :- !.
short_label(advice(K), S)          :- !, advice_title(K, T), format(string(S), "Advice: ~w", [T]).
short_label(ri_in(G), S)           :- !, label(G, L), format(string(S), "RI in ~w range", [L]).
short_label(sg_in(G), S)           :- !, label(G, L), format(string(S), "SG in ~w range", [L]).
short_label(ri_ok(G), S)           :- !, label(G, L), format(string(S), "RI fits ~w", [L]).
short_label(sg_ok(G), S)           :- !, label(G, L), format(string(S), "SG fits ~w", [L]).
short_label(optic_ok(G), S)        :- !, label(G, L), format(string(S), "Optic fits ~w", [L]).
short_label(colour_ok(G), S)       :- !, label(G, L), format(string(S), "Colour fits ~w", [L]).
short_label(phenomenon_ok(G), S)   :- !, label(G, L), format(string(S), "Effect fits ~w", [L]).
short_label(gem_type(G), S)        :- !, label(G, L), format(string(S), "~w is a gem", [L]).
short_label(missing(K), S)         :- !, key_label(K, L), format(string(S), "~w not given", [L]).
short_label(partial_data, "Data incomplete") :- !.
short_label(ambiguous_species, "Several species fit") :- !.
short_label(not(C), S)             :- !, short_label(C, S0), string_concat("NOT ", S0, S).
short_label(T, S)                  :- term_text(T, S).

goal_question(species(G), "Which species is it?") :- var(G), !.
goal_question(species(G), S)   :- nonvar(G), !, label(G, L), format(string(S), "Is it ~w?", [L]).
goal_question(variety(V), S)   :- nonvar(V), !, label(V, L), format(string(S), "Is it ~w?", [L]).
goal_question(imitation(M), S) :- nonvar(M), !, label(M, L), format(string(S), "Is it ~w?", [L]).
goal_question(G, S)            :- short_label(G, S0), format(string(S), "~w?", [S0]).

/* ==================================================================
   FORWARD CHAINING DIAGRAM
   ================================================================== */
forward_diagram(SVG, Captions) :-
    session_inputs(Inputs),
    findall(f(F, 0, 0), member(F, Inputs), InNodes),
    findall(fired(Id, Cs, Cc), fired(Id, Cs, Cc), Fired),
    fc_build(Fired, 1, InNodes, FactNodes, RuleNodes, Edges),
    fc_layout(FactNodes, RuleNodes, Pos, W, H),
    fc_svg(FactNodes, RuleNodes, Edges, Pos, W, H, SVG),
    fc_captions(Inputs, RuleNodes, Captions).

% fc_build(+Fired, +N, +FactsSoFar, -Facts, -Rules, -Edges)
%   f(Fact, Level, Step)     r(N, Id, Level, Conds, Concl)
%   e(FromKey, ToKey, Step)  keys are fact terms or rule(N)
fc_build([], _, FN, FN, [], []).
fc_build([fired(Id, Conds, Concl)|T], N, FN0, FN, [r(N, Id, Lc, Conds, Concl)|Rs], Es) :-
    findall(K, ( member(C, Conds), cond_sources(C, Ks), member(K, Ks),
                 memberchk(f(K, _, _), FN0) ), Ks0),
    sort(Ks0, Keys),
    findall(L, ( member(K, Keys), memberchk(f(K, L, _), FN0) ), Ls),
    max_list([0|Ls], M), Lc is M + 1,
    append(FN0, [f(Concl, Lc, N)], FN1),
    findall(e(K, rule(N), N), member(K, Keys), E1),
    N1 is N + 1,
    fc_build(T, N1, FN1, FN, Rs, Es0),
    append(E1, [e(rule(N), Concl, N) | Es0], Es).

% Which facts in working memory a condition depends on
cond_sources(ri_in(_), [ri(V)])  :- !, fact(ri(V)).
cond_sources(ri_ok(_), Ks)       :- !, findall(ri(V), fact(ri(V)), Ks).
cond_sources(sg_in(_), [sg(V)])  :- !, fact(sg(V)).
cond_sources(sg_ok(_), Ks)       :- !, findall(sg(V), fact(sg(V)), Ks).
cond_sources(optic(_), [optic(U)]) :- !, fact(optic(U)).
cond_sources(optic_ok(_), Ks)    :- !, findall(optic(U), fact(optic(U)), Ks).
cond_sources(colour_ok(_), Ks)   :- !, findall(observed_colour(C), fact(observed_colour(C)), Ks).
cond_sources(phenomenon_ok(_), Ks) :- !,
    findall(phenomenon(P), (fact(phenomenon(P)), P \== none), Ks).
cond_sources(ambiguous_species, Ks) :- !, findall(species(S), fact(species(S)), Ks).
cond_sources(not(_), [])         :- !.
cond_sources(missing(_), [])     :- !.
cond_sources(partial_data, [])   :- !.
cond_sources(gem_type(_), [])    :- !.
cond_sources(C, [C])             :- ground(C), !.
cond_sources(_, []).

% Layout: facts of level L on row 2L, rules concluding level L on row 2L-1
fc_layout(Facts, Rules, Pos, W, H) :-
    findall(L, member(f(_, L, _), Facts), Ls), max_list([0|Ls], MaxL),
    MaxRow is 2 * MaxL,
    node_w(NW), rule_w(RW), gap(G), margin(M), row_h(RH), node_h(NH),
    findall(row(R, Keys, Slot),
            ( between(0, MaxRow, R),
              (   R mod 2 =:= 0
              ->  L is R // 2, findall(K, member(f(K, L, _), Facts), Keys), Slot is NW + G
              ;   L is (R + 1) // 2, findall(rule(N), member(r(N, _, L, _, _), Rules), Keys),
                  Slot is RW + 2 * G
              ),
              Keys \== [] ),
            Rows),
    findall(RWd, ( member(row(_, Ks, Sl), Rows), length(Ks, Nk), RWd is Nk * Sl ), Ws),
    max_list([NW|Ws], Inner),
    W is Inner + 2 * M,
    H is 2 * M + MaxRow * RH + NH,
    findall(p(K, X, Y),
            ( member(row(R, Ks, Sl), Rows),
              length(Ks, Nk), RowW is Nk * Sl,
              nth0(I, Ks, K),
              X is round(M + (Inner - RowW) / 2 + I * Sl + Sl / 2),
              Y is round(M + R * RH + NH / 2) ),
            Pos).

fc_svg(Facts, Rules, Edges, Pos, W, H, SVG) :-
    node_h(NH), rule_h(RH2),
    findall(E,
            ( member(e(A, B, S), Edges),
              memberchk(p(A, X1, Y1), Pos), memberchk(p(B, X2, Y2), Pos),
              ( A = rule(_) -> Y1b is Y1 + RH2 / 2 ; Y1b is Y1 + NH / 2 ),
              ( B = rule(_) -> Y2b is Y2 - RH2 / 2 ; Y2b is Y2 - NH / 2 ),
              edge_svg(X1, Y1b, X2, Y2b, S, normal, 'arrF', E) ),
            EdgeSvgs),
    findall(NS,
            ( member(f(F, _, S), Facts), memberchk(p(F, X, Y), Pos),
              fact_style(F, S, Fill, Stroke),
              short_label(F, Lb), fact_tooltip(F, S, Tip),
              box_svg(X, Y, Lb, Fill, Stroke, solid, none, S, Tip, NS) ),
            FactSvgs),
    findall(RS,
            ( member(r(N, Id, _, Conds, Concl), Rules), memberchk(p(rule(N), X, Y), Pos),
              rule_tooltip(Id, Conds, Concl, Tip),
              rule_svg(X, Y, Id, N, '#312e81', N, Tip, RS) ),
            RuleSvgs),
    svg_doc(W, H, 'arrF', EdgeSvgs, FactSvgs, RuleSvgs, SVG).

fact_style(F, 0, '#e0e7ff', '#6366f1') :- input_fact(F), !.
fact_style(species(_),   _, '#ede9fe', '#7c3aed') :- !.
fact_style(variety(_),   _, '#fae8ff', '#c026d3') :- !.
fact_style(imitation(_), _, '#fee2e2', '#dc2626') :- !.
fact_style(candidate(_), _, '#f1f5f9', '#64748b') :- !.
fact_style(treatment(_), _, '#fef3c7', '#d97706') :- !.
fact_style(advice(_),    _, '#fff7e6', '#f59e0b') :- !.
fact_style(origin(O),    _, Fill, Stroke) :- !,
    origin_tone(O, T), tone_colours(T, Fill, Stroke).
fact_style(_, _, '#f1f5f9', '#64748b').

tone_colours(good,    '#dcfce7', '#16a34a').
tone_colours(warn,    '#fef3c7', '#d97706').
tone_colours(bad,     '#fee2e2', '#dc2626').
tone_colours(neutral, '#f1f5f9', '#64748b').

fact_tooltip(F, 0, T) :- !, term_text(F, FT), format(string(T), "Input fact: ~w", [FT]).
fact_tooltip(F, S, T) :- term_text(F, FT), format(string(T), "Derived fact (cycle ~w): ~w", [S, FT]).

rule_tooltip(Id, Conds, Concl, T) :-
    maplist(short_label, Conds, CLs), atomic_list_concat(CLs, ' AND ', CA),
    short_label(Concl, CL),
    format(string(T), "Rule ~w: IF ~w THEN ~w", [Id, CA, CL]).

fc_captions(Inputs, Rules, Caps) :-
    length(Inputs, NI),
    (   NI =:= 0
    ->  C0 = "Start: no inputs were given, so working memory is empty."
    ;   format(string(C0), "Start: your ~w input(s) are loaded into working memory as facts (blue boxes).", [NI])
    ),
    findall(C,
            ( member(r(N, Id, _, _, Concl), Rules), short_label(Concl, L),
              format(string(C), "Cycle ~w: every condition of rule ~w is true, so the rule fires and adds \"~w\" to working memory.", [N, Id, L]) ),
            Cs),
    length(Rules, NR),
    (   NR =:= 0
    ->  End = "No rule has all its conditions satisfied, so nothing new can be concluded."
    ;   format(string(End), "Finished: after ~w cycle(s) no rule can add a new fact, so forward chaining stops. The facts at the bottom are the conclusions.", [NR])
    ),
    append([[C0], Cs, [End]], Caps).

/* ==================================================================
   BACKWARD CHAINING DIAGRAM
   Tree nodes:  goal(Goal, Status, RuleNodes)
                rule(Id, Status, CondNodes)
                leaf(Condition, Status, Kind)
   Status: ok | fail | skip      Kind: input | test | derived | norule
   ================================================================== */
backward_diagram(Result, SVG, Captions) :-
    bc_tree(Result, Tree),
    margin(M),
    bc_place(Tree, M, 0, 0, _, Items, true),
    tree_width(Tree, TW),
    W is TW + 2 * M,
    findall(D, member(n(_, _, _, _, D, _), Items), Ds), max_list([0|Ds], MaxD),
    row_h(RH), node_h(NH),
    H is 2 * M + MaxD * RH + NH,
    bc_svg(Items, W, H, SVG),
    findall(S-Cap, member(n(_, _, _, S, _, Cap), Items), SCs0),
    keysort(SCs0, SCs), pairs_values(SCs, Caps0),
    bc_final(Result, Final),
    append(Caps0, [Final], Captions).

bc_tree(proved(_, Proof), T) :- proof_to_tree(Proof, T).
bc_tree(failed(Goal, _), T)  :- fail_goal(Goal, 3, T).

proof_to_tree(by(Id, C, Ps), goal(C, ok, [rule(Id, ok, Kids)])) :- !,
    maplist(proof_to_tree, Ps, Kids).
proof_to_tree(given(C), leaf(C, ok, input)).
proof_to_tree(test(C), leaf(C, ok, test)).
proof_to_tree(negated(C), leaf(not(C), ok, test)).

fail_goal(G, D, goal(G, fail, Rules)) :-
    findall(rule(Id, fail, Kids),
            ( rule(Id, Conds, G), walk_conds(Conds, D, Kids) ),
            Rules).

walk_conds([], _, []).
walk_conds([C|Cs], D, [N|Ns]) :-
    (   prove(C, P)
    ->  proven_node(C, P, N), walk_conds(Cs, D, Ns)
    ;   failed_node(C, D, N), maplist(skip_node, Cs, Ns)
    ).

proven_node(C, by(_, _, _), leaf(C, ok, derived)) :- !.
proven_node(C, given(_), leaf(C, ok, input)) :- !.
proven_node(C, _, leaf(C, ok, test)).

failed_node(C, D, N) :-
    (   derived_condition(C), D > 0
    ->  D1 is D - 1, fail_goal(C, D1, goal(C, fail, Rs)),
        ( Rs == [] -> N = leaf(C, fail, norule) ; N = goal(C, fail, Rs) )
    ;   input_fact(C) -> N = leaf(C, fail, input)
    ;   N = leaf(C, fail, test)
    ).

skip_node(C, leaf(C, skip, test)).

children(goal(_, _, Ks), Ks).
children(rule(_, _, Ks), Ks).
children(leaf(_, _, _), []).

self_w(rule(_, _, _), W) :- !, rule_w(W0), gap(G), W is W0 + G.
self_w(_, W) :- node_w(W).

tree_width(N, W) :-
    children(N, Ks), self_w(N, SW),
    (   Ks == [] -> W = SW
    ;   maplist(tree_width, Ks, Ws), sum_list(Ws, Sum), length(Ks, K), gap(G),
        W0 is Sum + (K - 1) * G, W is max(W0, SW)
    ).

% bc_place(+Node, +X0, +Depth, +Step0, -Step, -Items, +IsRoot)
%   Items: n(Node, X, Y, Step, Depth, Caption) and edge(X1,Y1,X2,Y2,Step,Style)
bc_place(N, X0, Depth, S0, S, [n(N, X, Y, S0, Depth, Cap) | Items], IsRoot) :-
    tree_width(N, W),
    X is round(X0 + W / 2),
    margin(M), row_h(RH), node_h(NH),
    Y is round(M + Depth * RH + NH / 2),
    node_caption(N, IsRoot, Cap),
    S1 is S0 + 1,
    children(N, Ks),
    (   Ks == []
    ->  S = S1, Items = []
    ;   maplist(tree_width, Ks, Ws), sum_list(Ws, Sum), length(Ks, K), gap(G),
        CW is Sum + (K - 1) * G,
        CX0 is X0 + (W - CW) / 2,
        D1 is Depth + 1,
        place_kids(Ks, CX0, D1, X, Y, N, S1, S, Items)
    ).

place_kids([], _, _, _, _, _, S, S, []).
place_kids([K|Ks], X0, D, PX, PY, Parent, S0, S, Items) :-
    tree_width(K, W),
    bc_place(K, X0, D, S0, S1, KItems, false),
    KItems = [n(_, KX, KY, KS, _, _) | _],
    node_bottom(Parent, PY, Y1), node_top(K, KY, Y2),
    edge_style(K, Style),
    X1 = PX,
    append([edge(X1, Y1, KX, Y2, KS, Style)], KItems, Here),
    gap(G), X1n is X0 + W + G,
    place_kids(Ks, X1n, D, PX, PY, Parent, S1, S, Rest),
    append(Here, Rest, Items).

node_bottom(rule(_, _, _), Y, B) :- !, rule_h(H), B is Y + H / 2.
node_bottom(_, Y, B) :- node_h(H), B is Y + H / 2.
node_top(rule(_, _, _), Y, T) :- !, rule_h(H), T is Y - H / 2.
node_top(_, Y, T) :- node_h(H), T is Y - H / 2.

node_status(goal(_, S, _), S).
node_status(rule(_, S, _), S).
node_status(leaf(_, S, _), S).

edge_style(N, Style) :- node_status(N, S), ( S == fail -> Style = fail ; S == skip -> Style = skip ; Style = normal ).

node_caption(goal(G, _, Rs), IsRoot, Cap) :-
    goal_question(G, Q), length(Rs, NR),
    (   IsRoot == true
    ->  format(string(Cap), "Goal: \"~w\" Backward chaining looks for rules whose THEN part concludes this (~w found).", [Q, NR])
    ;   format(string(Cap), "Sub-goal: \"~w\" To use the rule above, this must be proved first, so the system looks for rules that conclude it (~w found).", [Q, NR])
    ).
node_caption(rule(Id, _, Ks), _, Cap) :-
    length(Ks, NK),
    format(string(Cap), "Try rule ~w: check its ~w condition(s) one by one, from left to right.", [Id, NK]).
node_caption(leaf(C, ok, input), _, Cap) :- !,
    short_label(C, L), format(string(Cap), "Check \"~w\": it matches your input. Proved.", [L]).
node_caption(leaf(C, ok, derived), _, Cap) :- !,
    short_label(C, L), format(string(Cap), "Check \"~w\": proved by another rule. Proved.", [L]).
node_caption(leaf(C, ok, test), _, Cap) :- !,
    short_label(C, L),
    (   friendly_reason(C, R) -> format(string(Cap), "Check \"~w\": ~w. Proved.", [L, R])
    ;   format(string(Cap), "Check \"~w\": true. Proved.", [L]) ).
node_caption(leaf(C, fail, norule), _, Cap) :- !,
    short_label(C, L), format(string(Cap), "Check \"~w\": no rule can conclude it, so it FAILS.", [L]).
node_caption(leaf(C, fail, _), _, Cap) :- !,
    short_label(C, L),
    (   friendly_fail(C, R) -> format(string(Cap), "Check \"~w\": FAILS. ~w. The rule cannot fire.", [L, R])
    ;   format(string(Cap), "Check \"~w\": FAILS. The rule cannot fire.", [L]) ).
node_caption(leaf(C, skip, _), _, Cap) :-
    short_label(C, L),
    format(string(Cap), "\"~w\" is never checked: its rule already failed, and backward chaining stops at the first failed condition.", [L]).

bc_final(proved(G, _), S) :-
    goal_question(G, Q),
    format(string(S), "Result: every condition on the path was proved, so the answer to \"~w\" is YES.", [Q]).
bc_final(failed(G, _), S) :-
    goal_question(G, Q),
    format(string(S), "Result: every rule that could prove it failed, so the answer to \"~w\" is NO.", [Q]).

bc_svg(Items, W, H, SVG) :-
    findall(E,
            ( member(edge(X1, Y1, X2, Y2, S, Style), Items),
              edge_svg(X1, Y1, X2, Y2, S, Style, 'arrB', E) ),
            EdgeSvgs),
    findall(NS,
            ( member(n(N, X, Y, S, _, Cap), Items), N \= rule(_, _, _),
              bc_node_svg(N, X, Y, S, Cap, NS) ),
            NodeSvgs),
    findall(RS,
            ( member(n(rule(Id, St, _), X, Y, S, _, Cap), Items),
              ( St == ok -> Fill = '#15803d' ; Fill = '#b91c1c' ),
              rule_svg(X, Y, Id, none, Fill, S, Cap, RS) ),
            RuleSvgs),
    svg_doc(W, H, 'arrB', EdgeSvgs, NodeSvgs, RuleSvgs, SVG).

bc_node_svg(goal(G, St, _), X, Y, S, Cap, SVG) :-
    goal_question(G, Q), status_colours(St, Fill, Stroke),
    box_svg(X, Y, Q, Fill, Stroke, bold, St, S, Cap, SVG).
bc_node_svg(leaf(C, St, _), X, Y, S, Cap, SVG) :-
    short_label(C, L), status_colours(St, Fill, Stroke),
    ( St == skip -> Dash = dashed ; Dash = solid ),
    box_svg(X, Y, L, Fill, Stroke, Dash, St, S, Cap, SVG).

status_colours(ok,   '#dcfce7', '#16a34a').
status_colours(fail, '#fee2e2', '#dc2626').
status_colours(skip, '#f8fafc', '#b6bdcc').

/* ==================================================================
   SVG primitives
   ================================================================== */
svg_doc(W, H, Arrow, Edges, Nodes, Rules, SVG) :-
    atomic_list_concat(Edges, EA),
    atomic_list_concat(Nodes, NA),
    atomic_list_concat(Rules, RA),
    format(atom(SVG),
      '<svg class="rsvg" style="max-width:~wpx;aspect-ratio:~w/~w" viewBox="0 0 ~w ~w" xmlns="http://www.w3.org/2000/svg" font-family="Inter,Segoe UI,Arial,sans-serif"><defs><marker id="~w" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="#8b93b8"/></marker></defs><g class="edges">~w</g><g class="nodes">~w~w</g></svg>',
      [W, W, H, W, H, Arrow, EA, NA, RA]).

edge_svg(X1, Y1, X2, Y2, Step, Style, Arrow, SVG) :-
    Dy is (Y2 - Y1) / 2,
    C1 is Y1 + Dy, C2 is Y2 - Dy,
    edge_paint(Style, Stroke, Dash),
    format(atom(SVG),
      '<path data-step="~w" class="dstep" d="M~w,~w C~w,~w ~w,~w ~w,~w" fill="none" stroke="~w" stroke-width="1.6"~w marker-end="url(#~w)"/>',
      [Step, X1, Y1, X1, C1, X2, C2, X2, Y2, Stroke, Dash, Arrow]).

edge_paint(normal, '#9aa1c2', '').
edge_paint(fail,   '#dc2626', '').
edge_paint(skip,   '#c3c8d6', ' stroke-dasharray="4 4"').

% box_svg(X, Y, Label, Fill, Stroke, Border(solid|bold|dashed), Status, Step, Tooltip, SVG)
box_svg(X, Y, Label, Fill, Stroke, Border, Status, Step, Tip, SVG) :-
    node_w(W), node_h(H),
    X0 is X - W / 2, Y0 is Y - H / 2,
    border_attrs(Border, BA),
    wrap_text(Label, 20, Lines0),
    (   length(Lines0, NL), NL > 3
    ->  Lines0 = [A, B, C|_], string_concat(C, "...", C1), Lines = [A, B, C1]
    ;   Lines = Lines0 ),
    text_svg(X, Y, Lines, Status, TA),
    status_icon(Status, X0, Y0, W, IA),
    xml_escape(Tip, TipE),
    format(atom(SVG),
      '<g data-step="~w" class="dstep"><title>~w</title><rect x="~w" y="~w" width="~w" height="~w" rx="10" fill="~w" stroke="~w"~w/>~w~w</g>',
      [Step, TipE, X0, Y0, W, H, Fill, Stroke, BA, TA, IA]).

border_attrs(solid,  ' stroke-width="1.5"').
border_attrs(bold,   ' stroke-width="3"').
border_attrs(dashed, ' stroke-width="1.5" stroke-dasharray="5 4"').

text_svg(X, Y, Lines, Status, SVG) :-
    length(Lines, N),
    ( Status == skip -> Colour = '#94a3b8' ; Colour = '#1b1f3a' ),
    Y1 is Y - (N - 1) * 7 + 4,
    findall(T,
            ( nth0(I, Lines, L), LY is Y1 + I * 14, xml_escape(L, LE),
              format(atom(T), '<text x="~w" y="~w" text-anchor="middle" font-size="12.5" font-weight="600" fill="~w">~w</text>', [X, LY, Colour, LE]) ),
            Ts),
    atomic_list_concat(Ts, SVG).

status_icon(none, _, _, _, '') :- !.
status_icon(Status, X0, Y0, W, SVG) :-
    CX is X0 + W - 2, CY is Y0 + 2, TY is CY + 4,
    icon_paint(Status, Fill, Glyph),
    format(atom(SVG),
      '<circle cx="~w" cy="~w" r="9" fill="~w" stroke="#fff" stroke-width="2"/><text x="~w" y="~w" text-anchor="middle" font-size="11" font-weight="700" fill="#fff">~w</text>',
      [CX, CY, Fill, CX, TY, Glyph]).

icon_paint(ok,   '#16a34a', '&#10003;').
icon_paint(fail, '#dc2626', '&#10007;').
icon_paint(skip, '#b6bdcc', '&#8211;').

% rule_svg(X, Y, Id, OrderBadge(N|none), Fill, Step, Tooltip, SVG)
rule_svg(X, Y, Id, Order, Fill, Step, Tip, SVG) :-
    rule_w(W), rule_h(H),
    X0 is X - W / 2, Y0 is Y - H / 2, TY is Y + 4,
    xml_escape(Tip, TipE),
    (   Order == none -> Badge = ''
    ;   BX is X0, BY is Y0, BTY is BY + 3.5,
        format(atom(Badge),
          '<circle cx="~w" cy="~w" r="9" fill="#f5b83d" stroke="#fff" stroke-width="2"/><text x="~w" y="~w" text-anchor="middle" font-size="10" font-weight="700" fill="#2a1a00">~w</text>',
          [BX, BY, BX, BTY, Order])
    ),
    format(atom(SVG),
      '<g data-step="~w" class="dstep"><title>~w</title><rect x="~w" y="~w" width="~w" height="~w" rx="14" fill="~w"/><text x="~w" y="~w" text-anchor="middle" font-size="12" font-weight="700" fill="#fff" font-family="Consolas,monospace">~w</text>~w</g>',
      [Step, TipE, X0, Y0, W, H, Fill, X, TY, Id, Badge]).

% wrap_text(+Text, +MaxChars, -Lines)
wrap_text(Text, Max, Lines) :-
    split_string(Text, " ", "", Words0),
    exclude(==(""), Words0, Words),
    wrap_words(Words, Max, "", Lines).

wrap_words([], _, "", []) :- !.
wrap_words([], _, Cur, [Cur]).
wrap_words([W|Ws], Max, "", Lines) :- !, wrap_words(Ws, Max, W, Lines).
wrap_words([W|Ws], Max, Cur, Lines) :-
    string_length(Cur, LC), string_length(W, LW),
    (   LC + 1 + LW =< Max
    ->  atomic_list_concat([Cur, ' ', W], A), atom_string(A, Cur1),
        wrap_words(Ws, Max, Cur1, Lines)
    ;   Lines = [Cur | Rest], wrap_words(Ws, Max, W, Rest)
    ).

xml_escape(In, Out) :-
    format(string(S), "~w", [In]),
    string_codes(S, Cs),
    phrase(xml_esc(Cs), Os),
    atom_codes(Out, Os).

xml_esc([]) --> [].
xml_esc([0'&|T]) --> !, "&amp;", xml_esc(T).
xml_esc([0'<|T]) --> !, "&lt;", xml_esc(T).
xml_esc([0'>|T]) --> !, "&gt;", xml_esc(T).
xml_esc([0'"|T]) --> !, "&quot;", xml_esc(T).
xml_esc([C|T]) --> [C], xml_esc(T).
