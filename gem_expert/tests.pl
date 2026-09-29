/*  tests.pl
    Gemstone Identification Assistant - AUTOMATED TESTS (plunit)
    Run:   ?- run_tests.
    Test names match the manual test case table (TC1, TC2, ...).
*/

:- encoding(utf8).
:- use_module(library(plunit)).

fired_all(Ids) :- fired_ids(F), subtract(Ids, F, []).
contains(String, Sub) :- once(sub_string(String, _, _, _, Sub)).

:- begin_tests(identify_forward_chaining).

test(tc01_natural_blue_sapphire) :-
    identify([ri(1.765), sg(4.00), optic(uniaxial), observed_colour(blue), inclusion(silk)]),
    fact(species(corundum)),
    fact(variety(blue_sapphire)),
    fact(origin(likely_natural)),
    fact(advice(get_certificate)),
    fired_all([r1, r24, r46, r61]).

test(tc02_spinel_not_garnet) :-
    identify([ri(1.718), sg(3.60), optic(isotropic), observed_colour(red)]),
    fact(species(spinel)),
    \+ fact(species(garnet)),
    fact(variety(red_spinel)),
    fired_all([r2, r37]).

test(tc03_garnet_not_corundum) :-
    identify([ri(1.79), sg(4.05), optic(isotropic)]),
    fact(species(garnet)),
    \+ fact(species(corundum)),
    fired_all([r3]).

test(tc04_glass_imitation) :-
    identify([ri(1.60), optic(isotropic), inclusion(gas_bubbles)]),
    fact(imitation(glass)),
    fact(origin(imitation)),
    fact(advice(imitation_value)),
    fired_all([r11, r45, r63]).

test(tc05_synthetic_ruby) :-
    identify([ri(1.765), sg(4.00), optic(uniaxial), observed_colour(red), inclusion(curved_lines)]),
    fact(variety(ruby)),
    fact(origin(synthetic)),
    fired_all([r1, r21, r41, r62]).

test(tc06_star_sapphire) :-
    identify([ri(1.765), sg(4.00), optic(uniaxial), observed_colour(blue), phenomenon(star)]),
    fact(variety(star_sapphire)),
    \+ fact(variety(blue_sapphire)),
    fired_all([r1, r23]).

test(tc07_missing_ri_gives_candidates) :-
    identify([optic(isotropic), observed_colour(red)]),
    \+ fact(species(_)),
    findall(G, fact(candidate(G)), Gs), msort(Gs, [garnet, spinel]),
    fact(advice(measure_more)),
    fired_all([r14, r70]).

test(tc08_no_match) :-
    identify([ri(1.40), sg(1.50), optic(uniaxial)]),
    \+ fact(species(_)),
    \+ fact(candidate(_)),
    fact(advice(no_match)),
    fired_ids([r72]).

test(tc11_alexandrite) :-
    identify([ri(1.748), sg(3.73), optic(biaxial), observed_colour(green), phenomenon(colour_change)]),
    fact(variety(alexandrite)),
    fact(advice(check_colour_change)),
    fired_all([r4, r29, r68]).

test(tc12_moonstone) :-
    identify([ri(1.52), sg(2.57), optic(biaxial), observed_colour(colourless), phenomenon(adularescence)]),
    fact(variety(moonstone)),
    fired_all([r9, r31]).

test(tc13_cubic_zirconia) :-
    identify([sg(5.80), optic(isotropic), observed_colour(colourless)]),
    fact(imitation(cubic_zirconia)),
    \+ fact(candidate(_)),
    fired_all([r13, r45]).

test(tc14_heated_sapphire) :-
    identify([ri(1.764), sg(4.00), optic(uniaxial), observed_colour(blue), inclusion(discoid_fractures)]),
    fact(treatment(likely_heated)),
    fact(origin(likely_natural)),
    fired_all([r49, r50, r67]).

test(tc15_doubly_refractive_unknown_axis) :-
    identify([ri(1.765), sg(4.00), optic(doubly_refractive), observed_colour(blue)]),
    fact(species(corundum)).

test(tc16_ambiguous_spinel_garnet) :-
    identify([ri(1.733), sg(3.62), optic(isotropic)]),
    fact(species(spinel)),
    fact(species(garnet)),
    fact(advice(re_measure)).

test(tc17_clean_corundum_needs_lab) :-
    identify([ri(1.765), sg(4.00), optic(uniaxial), observed_colour(pink), inclusion(none)]),
    fact(variety(pink_sapphire)),
    fact(origin(needs_lab_test)),
    fired_all([r51, r65]).

test(tc18_synthetic_spinel_bubbles) :-
    identify([ri(1.720), sg(3.60), optic(isotropic), inclusion(gas_bubbles)]),
    fact(origin(synthetic)),
    \+ fact(imitation(glass)),
    fired_all([r2, r43]).

test(tc19_no_rule_fires_twice_for_same_conclusion) :-
    % refractoriness: each (rule, conclusion) pair fires at most once
    identify([optic(isotropic), observed_colour(red)]),
    findall(Id-C, fired(Id, _, C), Ps),
    sort(Ps, Unique), length(Ps, N), length(Unique, N).

test(tc20_explanation_is_generated) :-
    identify([ri(1.765), sg(4.00), optic(uniaxial), observed_colour(blue), inclusion(silk)]),
    identify_explanation(Sections),
    length(Sections, 4),
    summary(Title, _, Origin, _),
    contains(Title, "Blue sapphire"),
    contains(Origin, "Likely natural").

:- end_tests(identify_forward_chaining).

:- begin_tests(verify_backward_chaining).

test(tc09_verify_ruby_true) :-
    verify([ri(1.765), sg(4.00), optic(uniaxial), observed_colour(red)], ruby, R),
    R = proved(variety(ruby), by(r21, _, [by(r1, species(corundum), _)|_])).

test(tc10_verify_spinel_false_names_failed_condition) :-
    verify([ri(1.765), sg(4.00), optic(uniaxial), observed_colour(blue)], spinel, R),
    R = failed(species(spinel), [rule_failed(r2, optic(isotropic), text(T))]),
    contains(T, "isotropic").

test(tc21_verify_ruby_false_nested_reason) :-
    % red spinel data: ruby fails because corundum fails because optic is wrong
    verify([ri(1.718), sg(3.60), optic(isotropic), observed_colour(red)], ruby, R),
    R = failed(variety(ruby), Reasons),
    member(rule_failed(r21, species(corundum), sub(_, Sub)), Reasons),
    memberchk(rule_failed(r1, optic(uniaxial), _), Sub).

test(tc22_verify_glass) :-
    verify([ri(1.55), optic(isotropic), inclusion(gas_bubbles)], glass, R),
    R = proved(imitation(glass), _).

test(tc23_verify_explanation_text) :-
    verify([ri(1.765), sg(4.00), optic(uniaxial), observed_colour(blue)], spinel, R),
    verify_explanation(R, Headline, Sections),
    contains(Headline, "NO"),
    length(Sections, 3).

test(tc24_friendly_steps_plain_language) :-
    identify([ri(1.765), sg(4.00), optic(uniaxial), observed_colour(blue), inclusion(silk)]),
    friendly_steps([step("Species", r1, Head, Reasons, _, _, _)|_]),
    contains(Head, "Corundum"),
    Reasons = [R1|_], contains(R1, "uniaxial").

test(tc25_friendly_why_not_main_reason) :-
    verify([ri(1.718), sg(3.60), optic(isotropic), observed_colour(red)], ruby, failed(_, Rs)),
    friendly_why_not(Rs, Items),
    main_reason(Items, MR),
    contains(MR, "you entered singly refractive").

:- end_tests(verify_backward_chaining).

:- begin_tests(certainty_factors).

cf_of(F, P) :- fact_cf(F, CF), percent(CF, P).

test(tc26_species_cf_from_rule) :-
    identify([ri(1.765), sg(4.00), optic(uniaxial), observed_colour(blue)]),
    cf_of(species(corundum), 95),          % rule r1 CF 0.95, all readings in range
    cf_of(variety(blue_sapphire), 90).     % 0.95 x 0.95

test(tc27_edge_reading_lowers_cf) :-
    % RI 1.783 is outside 1.757-1.780 but inside the +/-0.005 tolerance
    identify([ri(1.783), sg(4.00), optic(uniaxial)]),
    cf_of(species(corundum), P),           % 0.95 x 0.7 = 0.665
    memberchk(P, [66, 67]).

test(tc28_evidence_combines_mycin_style) :-
    identify([optic(isotropic), observed_colour(red)]),
    % r14 0.20, then r15 +0.30 -> 0.44, then r19 +0.15 -> 0.524
    cf_of(candidate(spinel), 52),
    fired_all([r14, r15, r19]).

test(tc29_ranked_candidates_most_certain_first) :-
    identify([optic(uniaxial), observed_colour(blue)]),
    result_kind(candidates(Gs)),
    last(Gs, tourmaline),                  % blue is not a typical tourmaline colour
    Gs = [G1|_], cf_of(candidate(G1), P1), cf_of(candidate(tourmaline), P2),
    P1 > P2.

test(tc30_proof_certainty) :-
    verify([ri(1.765), sg(4.00), optic(uniaxial), observed_colour(red)], ruby, proved(_, Proof)),
    proof_cf(Proof, CF), percent(CF, 90).

:- end_tests(certainty_factors).

:- begin_tests(consultation_why).

test(tc31_asks_optic_first_for_ruby) :-
    consult(ruby, [], [], ask(optic, [frame(r1, species(corundum)), frame(r21, variety(ruby))])).

test(tc32_stops_early_when_hypothesis_fails) :-
    % isotropic rules out corundum, so ruby fails without asking RI, SG or colour
    consult(ruby, [optic(isotropic)], [], done(failed(variety(ruby), _))).

test(tc33_asks_next_needed_fact) :-
    consult(ruby, [optic(uniaxial)], [], ask(ri, _)).

test(tc34_hypothesise_and_test_species) :-
    consult(any_species, [optic(isotropic), ri(1.718), sg(3.60)], [],
            done(proved(species(spinel), _))).

test(tc35_dont_know_is_respected) :-
    consult(ruby, [optic(uniaxial)], [ri], done(failed(_, _))).

test(tc36_why_explanation_names_rules) :-
    consult(ruby, [], [], ask(K, Stack)),
    why_asking(K, Stack, Lines),
    atomic_list_concat(Lines, ' ', All),
    contains(All, "r21"), contains(All, "r1"), contains(All, "optic character").

:- end_tests(consultation_why).

:- begin_tests(natural_language_dcg).

test(tc37_verify_question) :-
    parse_query("Is my stone a sapphire if the RI is 1.765 and it is blue?", M, F, _),
    M == verify(blue_sapphire),
    F == [ri(1.765), observed_colour(blue)].

test(tc38_identify_description) :-
    parse_query("What is a singly refractive red stone with SG 3.60?", identify, F, _),
    msort(F, S), S == [observed_colour(red), optic(isotropic), sg(3.6)].

test(tc39_longest_gem_name_wins) :-
    parse_query("is this a star sapphire? ri 1.765", verify(star_sapphire), _, _).

test(tc40_multiword_phrases) :-
    parse_query("Cat's eye stone with curved growth lines and gas bubbles", identify, F, _),
    memberchk(phenomenon(cats_eye), F),
    memberchk(inclusion(gas_bubbles), F).    % last inclusion mentioned wins

test(tc41_unknown_words_reported) :-
    parse_query("RI 1.52 sparkly glass-like thing", _, [ri(1.52)], Ignored),
    memberchk(sparkly, Ignored).

:- end_tests(natural_language_dcg).
