/*  ui.pl
    Gemstone Identification Assistant - WEB USER INTERFACE
    Uses SWI-Prolog's built-in HTTP library (nothing extra to install).

        ?- server(8080).        then open http://localhost:8080
        ?- stop_server(8080).

    Pages
        /            introduction, how it works, input form, examples, glossary
        /identify    result of forward chaining (Identify mode)
        /verify      result of backward chaining (Verify mode)
        /rules       the knowledge base (facts and rules)
*/

:- encoding(utf8).

:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/html_write)).
:- use_module(library(http/http_parameters)).
:- use_module(library(http/http_files)).
:- use_module(library(uri)).

:- http_handler(root(.),        home_page,     []).
:- http_handler(root(identify), identify_page, []).
:- http_handler(root(verify),   verify_page,   []).
:- http_handler(root(rules),    rules_page,    []).
:- http_handler(root(ask),      ask_page,      []).
:- http_handler(root(consult),  consult_page,  []).
:- http_handler(root(images),   serve_files_in_directory(gem_images), [prefix]).

% images/ folder next to this file: optional real photos of the example stones
:- prolog_load_context(directory, Dir),
   atom_concat(Dir, '/images', ImgDir),
   asserta(user:file_search_path(gem_images, ImgDir)).

server(Port) :-
    http_server(http_dispatch, [port(Port)]),
    format("~nWeb interface running: open http://localhost:~w in your browser.~n", [Port]),
    format("Stop it with  stop_server(~w).~n~n", [Port]).

stop_server(Port) :-
    http_stop_server(Port, []).

/* ==================================================================
   HOME PAGE
   ================================================================== */
home_page(Request) :-
    form_values(Request, Vals),
    page('Gemstone Identification Assistant',
         [ \hero,
           \features,
           \how_it_works,
           \identify_form(Vals),
           \examples_section,
           \glossary,
           \good_to_know,
           div([id(toast), class(toast)], ''),
           \page_script
         ]).

hero -->
    { aggregate_all(count, gem(_), NG),
      aggregate_all(count, imitation_material(_), NI),
      aggregate_all(count, rule(_, _, _), NR),
      picture_or_blank(blue_sapphire, P1),
      picture_or_blank(padparadscha, P2),
      picture_or_blank(star_ruby, P3),
      picture_or_blank(alexandrite, P4)
    },
    html(section(class(hero),
      div(class(wrap),
        div(class('hero-grid'),
          [ div(class('hero-text'),
              [ span(class(eyebrow), 'Expert system for Sri Lankan gemstones'),
                h1(['Know your gem ', span(class(accent), 'before you buy it.')]),
                p(class(lead),
                  [ 'Cheap look-alikes, lab-grown stones and glass fakes are common in the gem trade. ',
                    'Tell the assistant what you can measure or see, and it tells you what the stone ',
                    'most likely is, whether it is natural, synthetic or an imitation, ',
                    b('and exactly why.') ]),
                div(class('hero-cta'),
                    [ a([href('#identify'), class('btn btn-light')], 'Start identifying'),
                      a([href('/consult?goal=any_species'), class('btn btn-outline')], 'Ask me step by step'),
                      a([href('#examples'), class('btn btn-outline')], 'Try an example') ]),
                form([class('ask-box'), action('/ask'), method(get)],
                     [ input([type(text), name(q), required(required), 'aria-label'('Your question'),
                              placeholder('Or ask in plain English: "Is my stone a sapphire if the RI is 1.765 and it is blue?"')]),
                       button([type(submit), class('btn btn-light')], 'Ask') ]),
                div(class('ask-examples'),
                    [ span('Try: '),
                      \ask_example('Is it a ruby? RI 1.764, SG 3.99, uniaxial, red, curved lines'),
                      \ask_example('Red singly refractive stone with SG 3.60'),
                      \ask_example('Could it be glass? isotropic, RI 1.52, gas bubbles') ]),
                ul(class(stats),
                   [ li([b(NG), span('gem species')]),
                     li([b(NI), span('imitations detected')]),
                     li([b(NR), span('expert rules')]),
                     li([b('3'), span('reasoning modes')]) ])
              ]),
            div(class('hero-art'),
              [ div(class('gem g1'), P1), div(class('gem g2'), P2),
                div(class('gem g3'), P3), div(class('gem g4'), P4) ])
          ])))).

ask_example(Q) -->
    { uri_encoded(query_value, Q, E), format(atom(Href), '/ask?q=~w', [E]) },
    html(a([class('ask-chip'), href(Href)], Q)).

features -->
    html(section(class('section features'),
      div(class(wrap),
        [ h2(class(center), 'What the assistant tells you'),
          div(class('feature-grid'),
            [ \feature('&#9670;', 'Gem species and variety',
                       'For example corundum, and within it blue sapphire, ruby or padparadscha.'),
              \feature('&#9888;', 'Natural, synthetic or fake',
                       'Inclusion clues reveal lab-grown stones and glass or cubic zirconia imitations.'),
              \feature('&#9679;', 'How confident it is',
                       'A strong match, a possible match or no match. It never makes a blind guess.'),
              \feature('&#10003;', 'What to do next',
                       'Practical advice, such as asking for an NGJA certificate before buying.'),
              \feature('&#8505;', 'The reasoning behind it',
                       'Every answer lists the expert rules used, in plain language, with sources.'),
              \feature('&#9998;', 'Works with missing data',
                       'No refractometer? It still narrows the stone down to a short list.')
            ])
        ]))).

feature(Icon, Title, Text) -->
    html(div(class(feature),
             [ span(class(icon), \[Icon]), h3(Title), p(Text) ])).

how_it_works -->
    html(section([class('section alt'), id(how)],
      div(class(wrap),
        [ h2(class(center), 'How it works'),
          p(class('center sub'), 'Three simple steps, powered by rules taken from gemmology references.'),
          div(class(steps3),
            [ \how_step('1', 'Describe the stone',
                  'Enter readings from a refractometer, hydrostatic balance or polariscope, and what you see by eye or with a 10x loupe. Anything you do not know can stay as Unknown.'),
              \how_step('2', 'Expert rules reason',
                  'The inference engine applies IF-THEN rules from the knowledge base (GIA, Webster, Read and others) to your data.'),
              \how_step('3', 'Read the explained answer',
                  'You get the result, a confidence level, a buying recommendation and every reasoning step behind it.')
            ]),
          h3(class('center modes-title'), 'Two ways to ask'),
          div(class(modes),
            [ div(class('mode-card identify'),
                  [ span(class(pill), 'Identify mode'),
                    h3('"I don''t know what this stone is."'),
                    p('The system starts from your observations and applies every rule that fits, building up conclusions step by step until nothing new can be found.'),
                    p(class(tech), 'Technique: forward chaining (data-driven)') ]),
              div(class('mode-card verify'),
                  [ span(class(pill), 'Verify mode'),
                    h3('"The seller says it''s a ruby. Is it?"'),
                    p('The system starts from the claimed gem and works backwards, checking each condition it needs. If the claim fails, it tells you exactly which condition failed.'),
                    p(class(tech), 'Technique: backward chaining (goal-driven)') ])
            ])
        ]))).

how_step(N, Title, Text) -->
    html(div(class(step3), [span(class(num), N), h3(Title), p(Text)])).

/* ---- Input form -------------------------------------------------- */
identify_form(Vals) -->
    { val(ri, Vals, RI), val(sg, Vals, SG), val(optic, Vals, Optic),
      val(colour, Vals, Col), val(phenomenon, Vals, Ph), val(inclusion, Vals, Inc),
      val(target, Vals, Tgt)
    },
    html(section([class(section), id(identify)],
      div(class(wrap),
        [ h2(class(center), 'Describe your stone'),
          p(class('center sub'),
            'Every field is optional. The more you fill in, the more confident the answer.'),
          form([class('gem-form'), action('/identify'), method(get)],
            [ fieldset(
                [ legend([span(class(num), '1'), 'Instrument readings']),
                  div(class('field-grid'),
                    [ \field(ri, RI), \field(sg, SG), \field(optic, Optic) ]) ]),
              fieldset(
                [ legend([span(class(num), '2'), 'What you can see']),
                  div(class('field-grid'),
                    [ \field(colour, Col), \field(phenomenon, Ph), \field(inclusion, Inc) ]) ]),
              div(class(actions),
                [ div(class('action-card'),
                      [ h3('Identify my stone'),
                        p('Find the best match using every rule in the knowledge base.'),
                        button([type(submit), class('btn btn-primary')], 'Identify stone') ]),
                  div(class('action-card'),
                      [ h3('Check a claim'),
                        p('Test whether the stone could be one particular gem.'),
                        div(class('verify-row'),
                          [ \target_select(target, Tgt, []),
                            button([type(submit), class('btn btn-secondary'), formaction('/verify')],
                                   'Verify') ]) ]),
                  div(class('action-card consult'),
                      [ h3('Ask me step by step'),
                        p('The system asks only the questions it needs, and you can ask it why.'),
                        div(class('verify-row'),
                          [ \target_select(goal, any_species,
                                [option([value(any_species), selected(selected)],
                                        'Find the species (hypothesise and test)')]),
                            button([type(submit), class('btn btn-secondary'), formaction('/consult')],
                                   'Start') ]) ])
                ]),
              p(class('form-foot'), a(href('/#identify'), 'Clear the form'))
            ])
        ]))).

optic_options([ isotropic-'Singly refractive (isotropic)',
                uniaxial-'Doubly refractive, one axis (uniaxial)',
                biaxial-'Doubly refractive, two axes (biaxial)',
                doubly_refractive-'Doubly refractive (axis not known)' ]).

phenomenon_options([ none-'No special effect',
                     star-'Star (asterism)',
                     cats_eye-'Cat''s-eye (chatoyancy)',
                     colour_change-'Colour change (daylight vs lamp)',
                     adularescence-'Moonstone glow (adularescence)' ]).

% field(+Key, +Value): the input control for one property, with help text.
% Shared by the form and the step-by-step consultation questions.
field(ri, V) -->
    { (   V == over_limit
      ->  Num = '', Box = [type(checkbox), id(ri_otl), name(ri_otl), value(1), checked(checked)]
      ;   Num = V,  Box = [type(checkbox), id(ri_otl), name(ri_otl), value(1)] ),
      refractometer_limit(Lim),
      format(atom(OtlHelp), 'Tick this if the refractometer shows no shadow edge: the RI is above its limit (about ~w), as with zircon and cubic zirconia.', [Lim]) },
    html(div(class(field),
             [ label(for(ri), 'Refractive index (RI)'),
               p(class(what), 'How strongly the stone bends light. Each gem has its own range.'),
               input([type(number), step(any), id(ri), name(ri), value(Num),
                      min('1.3'), max('3.0'), placeholder('e.g. 1.765')]),
               label([class(otl), title(OtlHelp)],
                     [ input(Box), span('Over the limit (no reading)') ]),
               p(class(where), [span(class(tag), 'How'), 'Read it from a gem refractometer (use the highest reading).']) ])).
field(sg, V) -->
    number_field(sg, 'Specific gravity (SG)', V, '1.0', '8.0', 'e.g. 4.00',
                 'How heavy the stone is compared with the same volume of water.',
                 'Weigh the stone in air and in water (hydrostatic balance).').
field(optic, V) -->
    { optic_options(Os) },
    select_field(optic, 'Optic character', V, Os,
                 'Whether light passes through as one ray or is split in two.',
                 'Turn the stone between crossed filters in a polariscope.').
field(colour, V) -->
    { findall(C-C, colour(_, C), Cs0), sort(Cs0, Cs) },
    select_field(colour, 'Colour', V, Cs,
                 'The main body colour of the stone.',
                 'Look at it in daylight against a white background.').
field(phenomenon, V) -->
    { phenomenon_options(Os) },
    select_field(phenomenon, 'Optical effect', V, Os,
                 'Special light effects such as a star or a cat''s-eye.',
                 'Look under a single light source and rotate the stone.').
field(inclusion, V) -->
    { findall(I-L, inclusion_type(I, L), Os) },
    select_field(inclusion, 'Inclusions', V, Os,
                 'Tiny features inside the stone that reveal how it formed.',
                 'Examine it with a 10x jeweller''s loupe.').

number_field(Name, Label, Value, Min, Max, Ph, What, Where) -->
    html(div(class(field),
             [ label(for(Name), Label),
               p(class(what), What),
               input([type(number), step(any), id(Name), name(Name), value(Value),
                      min(Min), max(Max), placeholder(Ph)]),
               p(class(where), [span(class(tag), 'How'), Where]) ])).

select_field(Name, Label, Value, Pairs, What, Where) -->
    { option_terms(Pairs, Value, Opts) },
    html(div(class(field),
             [ label(for(Name), Label),
               p(class(what), What),
               select([id(Name), name(Name)],
                      [ option(value(''), 'Unknown / not checked') | Opts ]),
               p(class(where), [span(class(tag), 'How'), Where]) ])).

option_terms(Pairs, Selected, Opts) :-
    findall(option(Attrs, Text),
            ( member(V-L, Pairs), label(L, Text),
              ( V == Selected -> Attrs = [value(V), selected(selected)] ; Attrs = [value(V)] ) ),
            Opts).

% target_select(+ParamName, +Selected, +ExtraOptions)
target_select(Name, Selected, Extra) -->
    { findall(V-V, rule(_, _, variety(V)), Vs0), sort(Vs0, Vs),
      findall(G-G, gem(G), Gs),
      findall(M-M, imitation_material(M), Ms),
      option_terms(Vs, Selected, VO),
      option_terms(Gs, Selected, GO),
      option_terms(Ms, Selected, MO),
      ( Extra == [] -> First = [option(value(''), 'Is it a ...?')] ; First = Extra ),
      % html_write needs a flat list of elements here
      append(First, [ optgroup(label('Varieties'), VO),
                      optgroup(label('Gem species'), GO),
                      optgroup(label('Imitations'), MO) ], Options) },
    html(select([name(Name), 'aria-label'('Gem to check')], Options)).

/* ---- Example gallery --------------------------------------------- */
examples_section -->
    html(section([class('section alt'), id(examples)],
      div(class(wrap),
        [ h2(class(center), 'Example stones to try'),
          p(class('center sub'),
            'Press "Try it" to load a stone''s readings into the form, then choose Identify or Verify.'),
          div(class(gallery), \example_cards)
        ]))).

example_cards -->
    { findall(example(K, T, S, E, V), example(K, T, S, E, V), Exs) },
    example_cards(Exs).

example_cards([]) --> [].
example_cards([example(Key, Title, Specs, Expected, Target)|T]) -->
    { picture_or_blank(Key, Pic),
      findall(li([span(class(k), KL), span(class(v), VL)]),
              ( member(F-V, Specs), spec_label(F, KL), spec_value(F, V, VL) ),
              Items),
      example_json(Title, Specs, Target, Json)
    },
    html(div(class(card),
             [ div(class(pic), Pic),
               div(class(body),
                   [ h3(Title),
                     ul(class(specs), Items),
                     p(class(expect), [span(class(tag), 'Expected'), Expected]),
                     button([type(button), class('btn btn-primary'), 'data-example'(Json)], 'Try it')
                   ])
             ])),
    example_cards(T).

spec_label(ri, 'RI').
spec_label(sg, 'SG').
spec_label(optic, 'Optic').
spec_label(colour, 'Colour').
spec_label(phenomenon, 'Effect').
spec_label(inclusion, 'Inclusion').

spec_value(inclusion, V, L) :- inclusion_type(V, L0), !, sub_atom_before_paren(L0, L).
spec_value(phenomenon, V, L) :- phenomenon_options(Os), memberchk(V-L, Os), !.
spec_value(ri, over_limit, 'Over the limit') :- !.
spec_value(ri, V, V) :- !.
spec_value(sg, V, V) :- !.
spec_value(_, V, L) :- label(V, L).

sub_atom_before_paren(A, B) :-
    (   sub_atom(A, Bf, _, _, ' (') -> sub_atom(A, 0, Bf, _, B) ; B = A ).

example_json(Title, Specs, Target, Json) :-
    findall(S, ( member(K-V, Specs), format(atom(S), '"~w":"~w"', [K, V]) ), Parts0),
    format(atom(TS), '"target":"~w"', [Target]),
    atomic_list_concat(Ws, '''', Title), atomic_list_concat(Ws, '\\u0027', TitleEsc),
    format(atom(NS), '"name":"~w"', [TitleEsc]),
    append(Parts0, [TS, NS], Parts),
    atomic_list_concat(Parts, ',', Body),
    format(atom(Json), '{~w}', [Body]).

/* ---- Glossary and scope ------------------------------------------ */
glossary -->
    html(section([class(section), id(glossary)],
      div(class(wrap),
        [ h2(class(center), 'Gem terms made simple'),
          p(class('center sub'), 'Click a term to read what it means.'),
          div(class(glossary),
            [ \term('Refractive index (RI)',
                    'How much a gem slows and bends light. Measured with a refractometer; corundum reads about 1.76-1.77, quartz about 1.54-1.55.'),
              \term('Specific gravity (SG)',
                    'The weight of a gem compared with an equal volume of water. Sapphire is heavy (about 4.0); quartz is light (about 2.65).'),
              \term('Optic character',
                    'Singly refractive (isotropic) gems like spinel and garnet let light through as one ray. Doubly refractive gems split it into two: uniaxial gems (sapphire, quartz) have one optic axis, biaxial gems (topaz, chrysoberyl) have two.'),
              \term('Birefringence',
                    'The difference between the two refractive index readings of a doubly refractive gem.'),
              \term('Optical effects',
                    'Star (asterism) and cat''s-eye (chatoyancy) come from needle-like inclusions; colour change is typical of alexandrite; adularescence is the floating glow of moonstone.'),
              \term('Inclusions',
                    'Small crystals, needles (silk), healed fractures or bubbles inside a stone. They are like fingerprints: natural stones and lab-grown stones show different kinds.'),
              \term('Synthetic vs imitation',
                    'A synthetic has the same chemistry as the natural gem but was grown in a laboratory. An imitation (glass, cubic zirconia) only looks similar.'),
              \term('Heat treatment',
                    'Heating is widely used to improve the colour of sapphire. It is acceptable if disclosed, but heated stones are worth less than unheated ones.')
            ])
        ]))).

term(Title, Text) -->
    html(details(class(term), [summary(Title), p(Text)])).

good_to_know -->
    { aggregate_all(count, gem(_), NG) },
    html(section(class('section alt'),
      div(class(wrap),
        div(class(notice),
          [ h3('Good to know'),
            ul([ li(['The knowledge base covers ', b(NG), ' common Sri Lankan gem species plus glass and cubic zirconia imitations.']),
                 li('Readings are allowed a small margin for measurement error (RI +/-0.005, SG +/-0.03).'),
                 li('Heat treatment can only be suggested, not proven. Many treatments need laboratory equipment.'),
                 li(['This assistant gives a first opinion. It does ', b(not), ' replace a certificate from the NGJA or another accredited gem laboratory.'])
               ])
          ])))).

/* ==================================================================
   IDENTIFY RESULT (forward chaining)
   ================================================================== */
identify_page(Request) :-
    read_inputs(Request, Inputs, _Target, Errors),
    (   Errors \== []
    ->  error_page(Errors)
    ;   show_identification(Inputs, '')
    ).

% show_identification(+Inputs, +Note): Note is extra html shown at the top
% (used by the plain-English question box)
show_identification(Inputs, Note) :-
        identify(Inputs),
        result_kind(Kind),
        headline(Kind, Kicker, Title, Sub, Level, PicKey),
        main_cf(Kind, MainCF),
        primary_origin(O, OTone, OText0),
        (   O \== none, fact_cf(origin(O), OCF), percent(OCF, OP)
        ->  format(atom(OText), '~w (~w%)', [OText0, OP]) ; OText = OText0 ),
        findall(A, (fired(_, _, advice(K)), advice_text(K, A)), Advice),
        friendly_steps(Steps),
        identify_explanation(Tech),
        forward_diagram(DSvg, DCaps),
        edit_link(Inputs, '', EditHref),
        page('Your result',
             [ \page_head('Identify mode', 'forward chaining',
                          'Your result', 'Here is what the expert system concluded from your data.'),
               div(class('wrap narrow'),
                 [ Note,
                   \result_hero(Kicker, Title, Sub, Level, MainCF, PicKey, OTone, OText),
                   \alternatives(Kind),
                   \advice_block(Advice),
                   \input_chips(Inputs),
                   \diagram_block(forward, DSvg, DCaps),
                   \steps_block('How the system reached this',
                                'Each step is one expert rule that applied to your stone, in the order it fired.',
                                Steps),
                   \profile_block(Kind),
                   \technical_block(Tech),
                   \result_actions(EditHref)
                 ]),
               \diagram_script
             ]).

result_hero(Kicker, Title, Sub, Level, CF, PicKey, OTone, OText) -->
    { picture_or_unknown(PicKey, Pic),
      level_text(Level, LT0), percent(CF, P),
      ( Level > 1 -> format(atom(LT), '~w - ~w% certain', [LT0, P]) ; LT = LT0 ),
      level_tone(Level, LTone),
      format(atom(OCls), 'badge ~w', [OTone]),
      format(atom(LCls), 'badge ~w', [LTone]),
      ( fact(treatment(likely_heated))
      -> Heat = [span(class('badge warn'), 'Probably heat-treated')] ; Heat = [] )
    },
    html(div(class('result-hero'),
             [ div(class(pic), Pic),
               div(class(info),
                   [ span(class(kicker), Kicker),
                     h2(Title),
                     p(class(sub), Sub),
                     div(class(badges), [ span(class(LCls), LT), span(class(OCls), OText) | Heat ]),
                     \meter(CF)
                   ])
             ])).

level_tone(3, good).
level_tone(2, warn).
level_tone(1, neutral).

% certainty meter: a bar filled to the certainty factor
meter(CF) -->
    { percent(CF, P), cf_word(P, Word),
      format(atom(W), 'width:~w%', [P]),
      format(atom(PT), '~w%', [P]) },
    html(div(class('meter-wrap'),
             [ div(class(meter),
                   [ span(class(mlabel), 'Certainty'),
                     span(class(cfbar), span([class(cffill), style(W)], '')),
                     b(PT),
                     span(class(cfword), ['(', Word, ')']) ]),
               \cf_help ])).

% "What does this mean?" - the certainty scale in plain words
cf_help -->
    { cf_scale(Scale),
      findall(li([b(R), ' ', T]), member(R-T, Scale), Items) },
    html(details(class(cfhelp),
                 [ summary('What does this percentage mean?'),
                   ul(Items),
                   p('It is a certainty factor: how strongly the expert rules believe the conclusion, based on the evidence you gave. It is not a statistical probability.') ])).

% Close calls and partial matches: a ranked list with certainty and evidence
alternatives(ambiguous(Gs)) --> !, alternatives_list(ambiguous(Gs), 'The species overlap here',
    'Your readings fit more than one species. They are ranked by certainty. Re-measure RI and SG carefully, or check the birefringence, to separate them.', Gs).
alternatives(candidates(Gs)) --> !, alternatives_list(candidates(Gs), 'Ranked possibilities',
    'Not enough data for a firm answer, so every gem consistent with what you entered is ranked by how much evidence supports it (certainty factors).', Gs).
alternatives(none) --> !,
    html(div(class(block),
      [ h3('What you can try'),
        ul(class(tips),
           [ li('Check the numbers: RI usually has three decimals (e.g. 1.765) and SG two (e.g. 4.00).'),
             li('Check the optic character again with a polariscope.'),
             li('The stone may be a material outside this system''s scope, or an imitation. A gem laboratory can test it.') ])
      ])).
alternatives(_) --> [].

alternatives_list(Kind, Title, Intro, Gs) -->
    { findall(div(class(rank),
                  [ span(class(rnum), N),
                    div(class(pic), P),
                    div(class(rbody),
                        [ div(class(rtop), [ h4(L), span(class(rpctw), [b(class(rpct), PT), span(class(rword), Word)]) ]),
                          span(class(cfbar), span([class(cffill), style(W)], '')),
                          p(class(ranges), R),
                          ul(class(evidence), EItems) ]) ]),
              ( nth1(N, Gs, G), label(G, L), picture_or_unknown(G, P), range_text(G, R),
                ( Kind = candidates(_) -> T = candidate(G) ; T = species(G) ),
                fact_cf(T, CF), percent(CF, Pc), cf_word(Pc, Word),
                format(atom(W), 'width:~w%', [Pc]), format(atom(PT), '~w%', [Pc]),
                evidence_for(Kind, G, Ev), findall(li(E), member(E, Ev), EItems) ),
              Cards) },
    html(div(class(block), [ h3(Title), p(class(muted), Intro), div(class('rank-list'), Cards) ])).

range_text(G, T) :-
    ri_range(G, R1, R2), sg_range(G, S1, S2), optic(G, O),
    format(atom(T), 'RI ~3f-~3f | SG ~2f-~2f | ~w', [R1, R2, S1, S2, O]).

advice_block([]) --> !.
advice_block(Advice) -->
    { findall(li([span(class(icon), \['&#10148;']), span(A)]), member(A, Advice), Items) },
    html(div(class('block advice'), [ h3('What you should do'), ul(Items) ])).

input_chips(Inputs) -->
    { findall(Chip,
              ( member(K, [ri, sg, optic, colour, phenomenon, inclusion]),
                chip_for(K, Inputs, Chip) ),
              Chips) },
    html(div(class(block), [ h3('What you told us'), div(class(chips), Chips) ])).

chip_for(K, Inputs, span(class(chip), [span(class(k), KL), ' ', b(VL)])) :-
    input_key(K, F), member(F, Inputs), !,
    chip_key(K, KL), arg(1, F, V), chip_value(K, V, VL).
chip_for(K, _, span(class('chip off'), [span(class(k), KL), ' not given'])) :-
    chip_key(K, KL).

chip_key(ri, 'RI').
chip_key(sg, 'SG').
chip_key(optic, 'Optic').
chip_key(colour, 'Colour').
chip_key(phenomenon, 'Effect').
chip_key(inclusion, 'Inclusions').

chip_value(ri, over_limit, 'over the limit') :- !.
chip_value(ri, V, V) :- !.
chip_value(sg, V, V) :- !.
chip_value(K, V, L) :- spec_value(K, V, L).

steps_block(Title, Intro, []) --> !,
    html(div(class(block), [ h3(Title), p(class(muted), Intro),
                             p('No rule could be applied to the data you gave.') ])).
steps_block(Title, Intro, Steps) -->
    { findall(N-S, nth1(N, Steps, S), NSteps) },
    html(div(class(block),
             [ h3(Title), p(class(muted), Intro),
               ol(class(timeline), \timeline(NSteps)) ])).

timeline([]) --> [].
timeline([N-step(Stage, Id, Head, Reasons, Why, Cite, CFText)|T]) -->
    { findall(li(R), member(R, Reasons), RItems),
      ( Why == "" -> WhyP = [] ; WhyP = [p(class(why), [b('Expert knowledge: '), Why])] ),
      ( Cite == "" -> SrcP = [] ; SrcP = [p(class(src), ['Source: ', Cite])] ),
      ( CFText == "" -> CFTag = [] ; CFTag = [span(class(cftag), CFText)] )
    },
    html(li(class(tstep),
            [ span(class(dot), N),
              div(class(tbody),
                  [ div(class(meta), [ span(class(stage), Stage), span(class(rule), ['Rule ', Id]) | CFTag ]),
                    h4(Head),
                    \because(RItems)
                  | WhyP ] ),
              div(class(tsrc), SrcP)
            ])),
    timeline(T).

because([]) --> !.
because(Items) --> html([p(class(bc), 'Because:'), ul(class(reasons), Items)]).

profile_block(strong(S)) --> !, profile(S).
profile_block(imitation([M|_])) --> !, profile(M).
profile_block(_) --> [].

profile(G) -->
    { label(G, L), gem_profile(G, Pairs),
      findall(div(class(prow), [span(class(k), K), span(class(v), V)]), member(K-V, Pairs), Rows),
      format(atom(T), 'About ~w', [L]) },
    html(div(class(block), [ h3(T), div(class(profile), Rows) ])).

technical_block(Sections) -->
    html(details(class('block tech'),
                 [ summary('Technical trace (facts and rules, for gemmologists and examiners)'),
                   \sections(Sections) ])).

sections([]) --> [].
sections([section(Title, Lines)|T]) -->
    html(div(class(section_t),
             [ h4(Title), div(class(trace), \trace_lines(Lines)) ])),
    sections(T).

trace_lines([]) --> [].
trace_lines([line(I, Text)|T]) -->
    { Pad is I * 1.4, format(atom(Style), 'padding-left:~wem', [Pad]) },
    html(div([class(line), style(Style)], Text)),
    trace_lines(T).

result_actions(EditHref) -->
    html(div(class('result-actions'),
             [ a([class('btn btn-primary'), href(EditHref)], 'Edit my inputs'),
               a([class('btn btn-secondary'), href('/#identify')], 'Start a new stone'),
               a([class('btn btn-ghost'), href('/#examples')], 'Try an example') ])).

/* ==================================================================
   VERIFY RESULT (backward chaining)
   ================================================================== */
verify_page(Request) :-
    read_inputs(Request, Inputs, Target, Errors0),
    (   Target == '' -> Errors = ['Please choose the gem you want to check (the "Is it a ...?" list).' | Errors0]
    ;   Errors = Errors0 ),
    (   Errors \== []
    ->  error_page(Errors)
    ;   show_verification(Inputs, Target, '')
    ).

show_verification(Inputs, Target, Note) :-
    verify(Inputs, Target, Result),              % backward chaining
    label(Target, TL),
    verify_explanation(Result, _, Tech),
    verify_view(Result, TL, Answer, Detail),
    backward_diagram(Result, DSvg, DCaps),       % needs the verify session facts
    identify(Inputs),                            % what the data points to instead
    result_kind(Kind),
    headline(Kind, _, BTitle, BSub, BLevel, BPic),
    edit_link(Inputs, Target, EditHref),
    identify_link(Inputs, IdHref),
    format(atom(Q), 'Is my stone a ~w?', [TL]),
    page('Verification result',
         [ \page_head('Verify mode', 'backward chaining', Q,
                      'The system worked backwards from your question and checked every condition.'),
           div(class('wrap narrow'),
             [ Note,
               Answer,
               \best_match(Result, BTitle, BSub, BLevel, BPic, IdHref),
               \input_chips(Inputs),
               \diagram_block(backward, DSvg, DCaps),
               Detail,
               \technical_block(Tech),
               \result_actions(EditHref)
             ]),
           \diagram_script
         ]).

/* ==================================================================
   REASONING DIAGRAM BLOCK (see diagrams.pl)
   ================================================================== */
diagram_block(Kind, SVG, Caps) -->
    { diagram_text(Kind, Title, Intro),
      diagram_legend(Kind, Legend),
      findall(li(C), member(C, Caps), CapItems),
      last(Caps, LastCap) },
    html(div(class('block diagram'),
       [ h3(Title),
         p(class(muted), Intro),
         div(class('d-controls'),
             [ button([type(button), class('btn btn-primary d-play')], 'Play step by step'),
               button([type(button), class('btn btn-secondary d-prev')], 'Back'),
               button([type(button), class('btn btn-secondary d-next')], 'Next'),
               button([type(button), class('btn btn-ghost d-all')], 'Show all'),
               span(class('d-count'), '') ]),
         p(class('d-caption'), LastCap),
         div(class('d-canvas'), \[SVG]),
         div(class(legend), Legend),
         ol([class(dcaps), hidden(hidden)], CapItems)
       ])).

diagram_text(forward, 'Reasoning diagram: forward chaining',
    'Data-driven. The system starts from your inputs (top row) and fires every rule whose conditions are all true. Each fired rule adds a new fact to working memory, which can let further rules fire, until nothing new can be derived. Gold numbers show the firing order. Hover over any box for details.').
diagram_text(backward, 'Reasoning diagram: backward chaining',
    'Goal-driven. The system starts from your question (top) and works downwards: it tries each rule that could prove the goal, turning the rule''s conditions into sub-goals and checking them from left to right. A rule is abandoned at its first failed condition. Hover over any box for details.').

diagram_legend(forward,
    [ \swatch('#e0e7ff', '#6366f1', 'Your input'),
      \swatch('#ede9fe', '#7c3aed', 'Species'),
      \swatch('#fae8ff', '#c026d3', 'Variety'),
      \swatch('#dcfce7', '#16a34a', 'Natural'),
      \swatch('#fef3c7', '#d97706', 'Synthetic / treated'),
      \swatch('#fee2e2', '#dc2626', 'Imitation'),
      \swatch('#fff7e6', '#f59e0b', 'Advice'),
      \swatch('#312e81', '#312e81', 'Rule (number = firing order)') ]).
diagram_legend(backward,
    [ \swatch('#dcfce7', '#16a34a', 'Proved'),
      \swatch('#fee2e2', '#dc2626', 'Failed'),
      \swatch('#f8fafc', '#b6bdcc', 'Never checked'),
      \swatch('#15803d', '#15803d', 'Rule that succeeded'),
      \swatch('#b91c1c', '#b91c1c', 'Rule that failed') ]).

swatch(Fill, Stroke, Text) -->
    { format(atom(Style), 'background:~w;border-color:~w', [Fill, Stroke]) },
    html(span(class(lg), [ span([class(sw), style(Style)], ''), Text ])).

diagram_script -->
    html(script(\[
'document.querySelectorAll(".diagram").forEach(function(d){',
'  var caps=[].map.call(d.querySelectorAll(".dcaps li"),function(li){return li.textContent;});',
'  var max=caps.length-1, cur=max, timer=null;',
'  var els=d.querySelectorAll("[data-step]");',
'  var cap=d.querySelector(".d-caption"), cnt=d.querySelector(".d-count");',
'  function render(){',
'    els.forEach(function(e){var s=+e.getAttribute("data-step");',
'      e.classList.toggle("dim", s>cur); e.classList.toggle("cur", s==cur && cur<max);});',
'    cap.textContent=caps[cur]; cnt.textContent="Step "+cur+" of "+max;',
'  }',
'  function stop(){ if(timer){clearInterval(timer); timer=null;} }',
'  d.querySelector(".d-next").onclick=function(){stop(); if(cur<max)cur++; render();};',
'  d.querySelector(".d-prev").onclick=function(){stop(); if(cur>0)cur--; render();};',
'  d.querySelector(".d-all").onclick=function(){stop(); cur=max; render();};',
'  d.querySelector(".d-play").onclick=function(){stop(); cur=0; render();',
'    timer=setInterval(function(){ if(cur>=max){stop(); return;} cur++; render(); },1800);};',
'  render();',
'});'
    ])).

verify_view(proved(_, Proof), TL, Answer, Detail) :-
    proof_steps(Proof, Steps),
    proof_cf(Proof, CF),
    format(atom(H), 'Yes - your stone is consistent with ~w', [TL]),
    format(atom(S), 'Every condition the expert rules require for ~w is met by what you entered.', [TL]),
    Answer = div(class('answer yes'),
                 [ span(class(mark), \['&#10003;']),
                   div([ h2(H), p(S), \meter(CF),
                         p(class(muted), 'A lab certificate is still recommended before buying.') ]) ]),
    Detail = \steps_block('How it was checked',
                          'The conditions were proved in this order, starting from your readings.', Steps).
verify_view(failed(_, Reasons), TL, Answer, Detail) :-
    friendly_why_not(Reasons, Items),
    format(atom(H), 'No - your stone does not match ~w', [TL]),
    (   main_reason(Items, MR) -> true
    ;   format(string(MR), "No rule in the knowledge base can conclude ~w.", [TL]) ),
    Answer = div(class('answer no'),
                 [ span(class(mark), \['&#10007;']),
                   div([ h2(H), p([b('Main reason: '), MR]) ]) ]),
    length(Items, N),
    (   N =:= 1 -> Routes = 'one way' ; format(atom(Routes), '~w ways', [N]) ),
    format(atom(Intro),
           'The knowledge base has ~w to prove a stone is ~w. Each was checked against your data:',
           [Routes, TL]),
    Detail = div(class(block),
                 [ h3('Why not?'), p(class(muted), Intro),
                   ul(class('why-tree'), \why_items(Items)) ]).

why_items([]) --> [].
why_items([item(Id, Text, Sub)|T]) -->
    { ( Sub == [] -> Icon = '&#10007;', Cls = 'wrow fail' ; Icon = '&#8627;', Cls = 'wrow' ),
      ( Id == '-' -> RuleTag = [] ; RuleTag = [span(class(rule), ['Rule ', Id])] ) },
    html(li([ div(class(Cls), [ span(class(x), \[Icon]), span(class(t), Text) | RuleTag ]),
              \why_sub(Sub) ])),
    why_items(T).

why_sub([]) --> !.
why_sub(Sub) --> html(ul(class('why-tree'), \why_items(Sub))).

best_match(proved(_, _), _, _, _, _, _) --> !.
best_match(failed(_, _), Title, Sub, Level, Pic, Href) -->
    { picture_or_unknown(Pic, P), level_text(Level, LT), level_tone(Level, Tone),
      format(atom(Cls), 'badge ~w', [Tone]) },
    html(div(class('block best'),
             [ h3('What your data points to instead'),
               div(class('best-row'),
                   [ div(class(pic), P),
                     div([ h4(Title), p(class(muted), Sub), span(class(Cls), LT) ]),
                     a([class('btn btn-primary'), href(Href)], 'See full identification') ])
             ])).

/* ==================================================================
   KNOWLEDGE BASE PAGE
   ================================================================== */
rules_page(_Request) :-
    aggregate_all(count, rule(_, _, _), NR),
    aggregate_all(count, gem(_), NG),
    format(atom(Intro),
           'The knowledge base holds property facts for ~w gem species and ~w production rules. Rules are written as IF conditions THEN conclusion, grouped in layers; each layer builds on the conclusions of the one before (rule chaining).',
           [NG, NR]),
    page('Knowledge base',
         [ \page_head('Knowledge base', 'facts and rules', 'Inside the expert system', Intro),
           div(class(wrap),
             [ \facts_table,
               \rule_layers
             ])
         ]).

facts_table -->
    { findall(tr([ td(b(L)), td(R), td(S), td(OP), td(H) ]),
              ( ( gem(G) ; imitation_material(G) ), label(G, L),
                ri_range(G, R1, R2), format(atom(R), '~3f - ~3f', [R1, R2]),
                sg_range(G, S1, S2), format(atom(S), '~2f - ~2f', [S1, S2]),
                optic(G, O), label(O, OP), hardness(G, H) ),
              Rows) },
    html(div(class(block),
             [ h3('Gem property facts'),
               div(class('table-wrap'),
                 table(class(kb),
                   [ tr([th('Material'), th('Refractive index'), th('Specific gravity'), th('Optic character'), th('Hardness')]) | Rows ]))
             ])).

rule_layers -->
    { findall(layer(T, D, Rows),
              ( layer_def(Functors, T, D),
                findall(tr([ td(span(class(rule), Id)), td(code(CT)), td(code(ConT)), td(W), td(class(src), Cite) ]),
                        ( rule(Id, Conds, Concl), functor(Concl, F, _), memberchk(F, Functors),
                          maplist(term_text, Conds, CTs), atomic_list_concat(CTs, '  AND  ', CT),
                          term_text(Concl, ConT), rule_why(Id, W, Cite) ),
                        Rows),
                Rows \== [] ),
              Layers) },
    layers(Layers).

layers([]) --> [].
layers([layer(T, D, Rows)|Ls]) -->
    html(div(class(block),
             [ h3(T), p(class(muted), D),
               div(class('table-wrap'),
                 table(class(kb),
                   [ tr([th('Rule'), th('IF'), th('THEN'), th('Why'), th('Source')]) | Rows ])) ])),
    layers(Ls).

layer_def([species],   'Layer 1 - Species identification', 'Match optic character, refractive index and specific gravity to a gem species.').
layer_def([imitation], 'Layer 1b - Imitation detection',   'Recognise glass and cubic zirconia.').
layer_def([candidate], 'Layer 1c - Partial matches',       'When data is missing, keep every gem consistent with what was supplied.').
layer_def([variety],   'Layer 2 - Variety',                'Name the variety from the species plus colour or optical effect.').
layer_def([origin, treatment], 'Layer 3 - Origin and treatment', 'Use inclusions to judge natural, synthetic, imitation or heat-treated.').
layer_def([advice],    'Layer 4 - Recommendations',        'Turn the conclusions into practical advice for the buyer.').

/* ==================================================================
   PLAIN-ENGLISH QUESTIONS (DCG parser in query_parser.pl)
   ================================================================== */
ask_page(Request) :-
    http_parameters(Request, [q(Q0, [default('')])]),
    normalize_space(atom(Q), Q0),
    (   Q == ''
    ->  ask_help_page('Please type a question about your stone.')
    ;   parse_query(Q, Mode, Facts0, Ignored),
        partition(valid_fact, Facts0, Facts, Rejected),
        (   Facts == [], Mode == identify
        ->  ask_help_page('I could not find any gem properties in that question.')
        ;   parsed_note(Q, Mode, Facts, Rejected, Ignored, Note),
            (   Mode = verify(T)
            ->  show_verification(Facts, T, Note)
            ;   show_identification(Facts, Note)
            )
        )
    ).

valid_fact(ri(over_limit)) :- !.
valid_fact(ri(V)) :- !, V >= 1.3, V =< 3.0.
valid_fact(sg(V)) :- !, V >= 1.0, V =< 8.0.
valid_fact(_).

parsed_note(Q, Mode, Facts, Rejected, Ignored, Note) :-
    findall(span(class(chip), [span(class(k), KL), ' ', b(VL)]),
            ( member(F, Facts), input_key(K, F), chip_key(K, KL), arg(1, F, V), chip_value(K, V, VL) ),
            Chips0),
    (   Mode = verify(T)
    ->  label(T, TL), Chips = [span(class('chip goal'), [span(class(k), 'Question'), ' ', b(['Is it ', TL, '?'])]) | Chips0]
    ;   Chips = [span(class('chip goal'), [span(class(k), 'Question'), ' ', b('What is it?')]) | Chips0]
    ),
    (   Rejected == [] -> RejP = []
    ;   maplist(term_text, Rejected, RTs), atomic_list_concat(RTs, ', ', RA),
        RejP = [p(class(warnline), ['Ignored values outside the possible range: ', RA])] ),
    (   Ignored == [] -> IgnP = []
    ;   atomic_list_concat(Ignored, ', ', IA),
        IgnP = [p(class(muted), ['Words not used: ', IA])] ),
    append([ [ h3('You asked'),
               p(class(quote), ['"', Q, '"']),
               p(class(muted), 'The grammar (a Prolog DCG) understood your question as:'),
               div(class(chips), Chips) ],
             RejP, IgnP ], Body),
    Note = div(class('block parsed'), Body).

ask_help_page(Message) :-
    page('Ask a question',
         [ \page_head('Plain-English question', 'DCG parser', 'Ask a question',
                      'Describe your stone in your own words. The system picks out the properties it knows about.'),
           div(class('wrap narrow'),
             [ div(class('block warnbox'), p(Message)),
               div(class(block),
                 [ h3('Try something like'),
                   ul(class(tips),
                      [ li(\ask_example('Is my stone a sapphire if the RI is 1.765 and it is blue?')),
                        li(\ask_example('What is a singly refractive red stone with SG 3.60?')),
                        li(\ask_example('RI 1.52, SG 2.57, biaxial, colourless, with adularescence')),
                        li(\ask_example('Is this a star sapphire? RI 1.765, SG 4.00, uniaxial, blue, star')) ]),
                   p(class(muted), 'Understood words: RI / refractive index, SG / specific gravity, singly or doubly refractive, uniaxial, biaxial, colour names, star, cat''s eye, colour change, adularescence, silk, crystals, fingerprints, gas bubbles, curved lines, swirl marks, discoid fractures, clean, and gem names.'),
                   form([class('ask-box light'), action('/ask'), method(get)],
                        [ input([type(text), name(q), required(required), placeholder('Type your question')]),
                          button([type(submit), class('btn btn-primary')], 'Ask') ])
                 ])
             ])
         ]).

/* ==================================================================
   CONSULTATION (interactive backward chaining with WHY)
   The state of the conversation travels in the URL: the answers so far,
   the properties the user does not know, and the goal.
   ================================================================== */
consult_page(Request) :-
    read_inputs(Request, Inputs0, _, Errors),
    http_parameters(Request,
        [ goal(Goal0,     [default('')]),
          unknown(Unk0,   [default('')]),
          skip(Skip,      [default('')]),
          asked(Asked,    [default('')]) ]),
    (   Errors \== []
    ->  error_page(Errors)
    ;   consult_goal_ok(Goal0, Goal)
    ->  parse_unknowns(Unk0, Unk1),
        (   input_key(Skip, _) -> Unk2 = [Skip|Unk1] ; Unk2 = Unk1 ),
        % "Answer" pressed with an empty field also means "don't know"
        (   input_key(Asked, AF), \+ memberchk(AF, Inputs0), \+ memberchk(Asked, Unk2)
        ->  Unk3 = [Asked|Unk2] ; Unk3 = Unk2 ),
        sort(Unk3, Unknowns),
        exclude(unknown_input(Unknowns), Inputs0, Inputs),
        consult(Goal, Inputs, Unknowns, Outcome),
        (   Outcome = ask(K, Stack)
        ->  question_page(Goal, Inputs, Unknowns, K, Stack)
        ;   Outcome = done(Result),
            consult_result_page(Goal, Inputs, Unknowns, Result)
        )
    ;   consult_start_page
    ).

consult_goal_ok(any_species, any_species) :- !.
consult_goal_ok(G, G) :- G \== '', verify_targets(Ts), memberchk(G, Ts).

parse_unknowns('', []) :- !.
parse_unknowns(A, Ks) :-
    atomic_list_concat(Parts, ',', A),
    include([K]>>input_key(K, _), Parts, Ks).

unknown_input(Unknowns, F) :- input_key(K, F), memberchk(K, Unknowns).

consult_goal_question(any_species, 'Which gem species is my stone?') :- !.
consult_goal_question(T, Q) :- label(T, L), format(atom(Q), 'Is my stone a ~w?', [L]).

question_text(ri,         'What is the refractive index (RI) of your stone?').
question_text(sg,         'What is the specific gravity (SG) of your stone?').
question_text(optic,      'What is the optic character of your stone?').
question_text(colour,     'What colour is your stone?').
question_text(phenomenon, 'Does your stone show a special optical effect?').
question_text(inclusion,  'What inclusions can you see with a 10x loupe?').

question_page(Goal, Inputs, Unknowns, K, Stack) :-
    consult_goal_question(Goal, GQ),
    question_text(K, QT),
    why_asking(K, Stack, WhyLines),
    findall(li(L), member(L, WhyLines), WhyItems),
    length(Inputs, NI), length(Unknowns, NU), N is NI + NU + 1,
    format(atom(QN), 'Question ~w', [N]),
    Stack = [frame(CurRule, _)|_],
    hidden_state(Goal, Inputs, Unknowns, Hidden),
    append(Hidden,
           [ input([type(hidden), name(asked), value(K)]),
             \field(K, ''),
             div(class(qbtns),
                 [ button([type(submit), class('btn btn-primary')], 'Answer'),
                   button([type(submit), class('btn btn-secondary'), name(skip), value(K)],
                          'I don''t know') ]) ],
           FormContent),
    consult_href(Goal, [], [], Restart),
    page('Consultation',
         [ \page_head('Consult mode', 'interactive backward chaining', GQ,
                      'The system tests one hypothesis at a time and asks only for the facts the current rule needs.'),
           div(class('wrap narrow'),
             [ div(class('block question'),
                 [ div(class(qmeta), [ span(class(stage), QN),
                                       span(class(rule), ['testing rule ', CurRule]) ]),
                   h2(QT),
                   form([action('/consult'), method(get)], FormContent),
                   details([class(whybox), open(open)],
                           [ summary('Why are you asking this?'),
                             ol(class(whylist), WhyItems) ])
                 ]),
               \answers_so_far(Inputs, Unknowns),
               p(class('form-foot'), a(href(Restart), 'Start the consultation again'))
             ])
         ]).

hidden_state(Goal, Inputs, Unknowns, Hidden) :-
    findall(input([type(hidden), name(Kp), value(V)]),
            ( member(F, Inputs), param_of(F, Kp, V) ),
            Hs),
    atomic_list_concat(Unknowns, ',', UA),
    Hidden = [ input([type(hidden), name(goal), value(Goal)]),
               input([type(hidden), name(unknown), value(UA)]) | Hs ].

consult_href(Goal, Inputs, Unknowns, Href) :-
    findall(K=V, ( member(F, Inputs), param_of(F, K, V) ), Ps0),
    atomic_list_concat(Unknowns, ',', UA),
    append([goal=Goal, unknown=UA], Ps0, Ps),
    uri_query_components(Q, Ps),
    format(atom(Href), '/consult?~w', [Q]).

answers_so_far([], []) --> !.
answers_so_far(Inputs, Unknowns) -->
    { findall(span(class(chip), [span(class(k), KL), ' ', b(VL)]),
              ( member(F, Inputs), input_key(K, F), chip_key(K, KL), arg(1, F, V), chip_value(K, V, VL) ),
              C1),
      findall(span(class('chip off'), [span(class(k), KL), ' don''t know']),
              ( member(K, Unknowns), chip_key(K, KL) ),
              C2),
      append(C1, C2, Chips) },
    html(div(class(block), [ h3('Your answers so far'), div(class(chips), Chips) ])).

consult_result_page(Goal, Inputs, Unknowns, Result) :-
    consult_goal_question(Goal, GQ),
    (   Result = proved(species(S), _), Goal == any_species -> label(S, TL)
    ;   label(Goal, TL) ),
    verify_explanation(Result, _, Tech),
    verify_view(Result, TL, Answer, Detail),
    backward_diagram(Result, DSvg, DCaps),
    length(Inputs, NI), length(Unknowns, NU), NQ is NI + NU,
    format(atom(Eff),
           'Backward chaining asked only ~w of the 6 possible questions: it requested a fact only when the rule it was testing needed it.',
           [NQ]),
    identify_link(Inputs, IdHref),
    consult_href(Goal, [], [], Restart),
    page('Consultation result',
         [ \page_head('Consult mode', 'interactive backward chaining', GQ,
                      'The consultation is finished. Here is the answer and how it was reached.'),
           div(class('wrap narrow'),
             [ Answer,
               div(class('block efficiency'), [ span(class(icon), \['&#9889;']), span(Eff) ]),
               \answers_so_far(Inputs, Unknowns),
               \diagram_block(backward, DSvg, DCaps),
               Detail,
               \technical_block(Tech),
               div(class('result-actions'),
                   [ a([class('btn btn-primary'), href(Restart)], 'Start again'),
                     a([class('btn btn-secondary'), href(IdHref)], 'Run full identification'),
                     a([class('btn btn-ghost'), href('/')], 'Home') ])
             ]),
           \diagram_script
         ]).

consult_start_page :-
    page('Consultation',
         [ \page_head('Consult mode', 'interactive backward chaining', 'Ask me step by step',
                      'Choose what you want to find out. The system will then ask you one question at a time.'),
           div(class('wrap narrow'),
             [ div(class(block),
                 [ h3('What do you want to find out?'),
                   p(class(muted), 'Choose "Find the species" to watch the system form a hypothesis (for example "is it corundum?"), test it, and move on to the next hypothesis if it fails - the way a gemmologist works.'),
                   form([action('/consult'), method(get), class('verify-row')],
                        [ \target_select(goal, any_species,
                              [option([value(any_species), selected(selected)],
                                      'Find the species (hypothesise and test)')]),
                          button([type(submit), class('btn btn-primary')], 'Start') ])
                 ])
             ])
         ]).

/* ==================================================================
   ERROR PAGE
   ================================================================== */
error_page(Errors) :-
    findall(li(E), member(E, Errors), Items),
    page('Please check your input',
         [ \page_head('Input check', 'nothing was lost', 'Please check your input',
                      'Some values could not be used. Go back, correct them and try again.'),
           div(class('wrap narrow'),
             [ div(class('block warnbox'), ul(Items)),
               div(class('result-actions'),
                   [ a([class('btn btn-primary'), href('javascript:history.back()')], 'Go back and fix it') ]) ])
         ]).

/* ==================================================================
   Reading and validating the form
   ================================================================== */
form_values(Request, Vals) :-
    catch(http_parameters(Request,
            [ ri(RI0, [default('')]), ri_otl(Otl, [default('')]), sg(SG, [default('')]),
              optic(O, [default('')]), colour(C, [default('')]), phenomenon(P, [default('')]),
              inclusion(I, [default('')]), target(T, [default('')]) ]),
          _, fail), !,
    ( Otl \== '' -> RI = over_limit ; RI = RI0 ),
    Vals = [ri=RI, sg=SG, optic=O, colour=C, phenomenon=P, inclusion=I, target=T].
form_values(_, []).

val(K, Vals, V) :- ( memberchk(K=V0, Vals) -> V = V0 ; V = '' ).

read_inputs(Request, Inputs, Target, Errors) :-
    http_parameters(Request,
        [ ri(RI0,         [default('')]),
          ri_otl(Otl,     [default('')]),   % "over the limit" checkbox
          sg(SG,          [default('')]),
          optic(Optic,    [default('')]),
          colour(Col,     [default('')]),
          phenomenon(Ph,  [default('')]),
          inclusion(Inc,  [default('')]),
          target(Target0, [default('')])
        ]),
    findall(C, colour(_, C), Cs),
    findall(P, phenomenon(_, P), Ps),
    findall(I, inclusion_type(I, _), Is),
    verify_targets(Ts),
    ( Otl \== '' -> RI = over_limit ; RI = RI0 ),
    Checks = [ num(ri, 'Refractive index (RI)', RI, 1.3, 3.0),
               num(sg, 'Specific gravity (SG)', SG, 1.0, 8.0),
               sel(optic, Optic, [isotropic, uniaxial, biaxial, doubly_refractive]),
               sel(observed_colour, Col, Cs),
               sel(phenomenon, Ph, [none|Ps]),
               sel(inclusion, Inc, Is) ],
    foldl(check_input, Checks, []-[], Inputs0-Errors0),
    reverse(Inputs0, Inputs),
    reverse(Errors0, Errors),
    (   Target0 == '' -> Target = ''
    ;   memberchk(Target0, Ts) -> Target = Target0
    ;   Target = ''
    ).

check_input(num(_, _, '', _, _), Acc, Acc) :- !.
check_input(num(ri, _, over_limit, _, _), Fs-Es, [ri(over_limit)|Fs]-Es) :- !.
check_input(num(Name, Label, A, Min, Max), Fs-Es, Fs1-Es1) :-
    (   catch(atom_number(A, N), _, fail), number(N), N >= Min, N =< Max
    ->  F =.. [Name, N], Fs1 = [F|Fs], Es1 = Es
    ;   format(atom(E), '~w should be a number between ~w and ~w, but "~w" was entered.', [Label, Min, Max, A]),
        Fs1 = Fs, Es1 = [E|Es]
    ).
check_input(sel(_, '', _), Acc, Acc) :- !.
check_input(sel(Name, V, Allowed), Fs-Es, Fs1-Es1) :-
    (   memberchk(V, Allowed)
    ->  F =.. [Name, V], Fs1 = [F|Fs], Es1 = Es
    ;   format(atom(E), 'The value "~w" is not a valid choice for ~w.', [V, Name]),
        Fs1 = Fs, Es1 = [E|Es]
    ).

% edit_link(+Inputs, +Target, -Href): home page with the form pre-filled
edit_link(Inputs, Target, Href) :-
    findall(K=V, ( member(F, Inputs), param_of(F, K, V) ), Ps0),
    (   Target == '' -> Ps = Ps0 ; append(Ps0, [target=Target], Ps) ),
    uri_query_components(Q, Ps),
    format(atom(Href), '/?~w#identify', [Q]).

% identify_link(+Inputs, -Href): the Identify result for the same inputs
identify_link(Inputs, Href) :-
    findall(K=V, ( member(F, Inputs), param_of(F, K, V) ), Ps),
    uri_query_components(Q, Ps),
    format(atom(Href), '/identify?~w', [Q]).

param_of(ri(V), ri, V).
param_of(sg(V), sg, V).
param_of(optic(V), optic, V).
param_of(observed_colour(V), colour, V).
param_of(phenomenon(V), phenomenon, V).
param_of(inclusion(V), inclusion, V).

/* ==================================================================
   Pictures
   ================================================================== */
picture_or_blank(Key, Pic) :-
    label(Key, L),
    ( gem_picture(Key, L, Pic) -> true ; Pic = '' ).

picture_or_unknown(Key, Pic) :-
    (   Key \== unknown, label(Key, L), gem_picture(Key, L, Pic) -> true
    ;   gem_svg(unknown, 'Unknown stone', faceted('#e3e7f0', '#7d8599'), SVG),
        Pic = \[SVG]
    ).

/* ==================================================================
   Page layout
   ================================================================== */
page(Title, Body) :-
    css(CSS),
    reply_html_page(
        [ title(Title),
          meta([name(viewport), content('width=device-width, initial-scale=1')]),
          link([rel(stylesheet),
                href('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Poppins:wght@600;700&display=swap')]),
          style(\[CSS]) ],
        [ \topbar,
          div(class(content), Body),
          \footer ]).

topbar -->
    { gem_svg(logo, 'Logo', faceted('#8fb0ff', '#3b2d9c'), Logo) },
    html(header(class(topbar),
      div(class('wrap bar'),
        [ a([class(brand), href('/')], [ span(class(logo), \[Logo]),
                                         span([b('GemID'), ' Assistant']) ]),
          % menu button: only visible on small screens (phones)
          button([type(button), id('menu-btn'), class('menu-btn'),
                  'aria-label'('Open menu'), 'aria-expanded'(false), 'aria-controls'('main-nav')],
                 [span(''), span(''), span('')]),
          nav(id('main-nav'),
              [ a(href('/#how'), 'How it works'),
                a(href('/#identify'), 'Identify'),
                a(href('/consult?goal=any_species'), 'Step by step'),
                a(href('/#examples'), 'Examples'),
                a(href('/#glossary'), 'Glossary'),
                a(href('/rules'), 'Knowledge base') ]),
          script(\[
'(function(){var b=document.getElementById("menu-btn"),n=document.getElementById("main-nav");',
'function set(o){n.classList.toggle("open",o);b.setAttribute("aria-expanded",o);',
'b.setAttribute("aria-label",o?"Close menu":"Open menu");}',
'b.addEventListener("click",function(){set(!n.classList.contains("open"));});',
'n.querySelectorAll("a").forEach(function(a){a.addEventListener("click",function(){set(false);});});',
'document.addEventListener("keydown",function(e){if(e.key==="Escape")set(false);});})();'
          ])
        ]))).

footer -->
    html(footer(class(footer),
      div(class(wrap),
        [ p([b('Gemstone Identification Assistant'),
             ' - a rule-based expert system built in SWI-Prolog.']),
          p('For guidance only. Always obtain a certificate from the NGJA or an accredited gem laboratory before a significant purchase.')
        ]))).

page_head(Mode, Technique, Title, Intro) -->
    html(section(class('page-head'),
      div(class('wrap narrow'),
        [ a([class(back), href('/')], ['<- ', 'Back to home']),
          span(class('mode-pill'), [b(Mode), ' - ', Technique]),
          h1(Title),
          p(Intro) ]))).

page_script -->
    html(script(\[
'document.querySelectorAll("[data-example]").forEach(function(b){',
'  b.addEventListener("click",function(){',
'    var d=JSON.parse(b.getAttribute("data-example"));',
'    var otl=document.getElementById("ri_otl");',
'    if(otl){otl.checked=(d.ri==="over_limit"); if(otl.checked){d.ri="";}}',
'    ["ri","sg","optic","colour","phenomenon","inclusion","target"].forEach(function(k){',
'      var el=document.querySelector("[name="+k+"]"); if(el){el.value=d[k]||"";}});',
'    var f=document.querySelector("#identify");',
'    f.scrollIntoView({behavior:"smooth"});',
'    var form=document.querySelector(".gem-form");',
'    form.classList.remove("flash"); void form.offsetWidth; form.classList.add("flash");',
'    var t=document.getElementById("toast");',
'    t.textContent=d.name+" readings loaded. Now press Identify stone or Verify.";',
'    t.classList.add("show"); clearTimeout(window._tt);',
'    window._tt=setTimeout(function(){t.classList.remove("show");},4000);',
'  });',
'});'
    ])).

css('
:root{--ink:#1b1f3a;--muted:#5d6480;--line:#e3e6ef;--bg:#f5f6fb;--card:#fff;
--primary:#4338ca;--primary-d:#312e81;--accent:#f5b83d;
--good:#15803d;--good-bg:#e7f6ec;--warn:#b45309;--warn-bg:#fdf1dc;--bad:#b91c1c;--bad-bg:#fde8e8;--neutral:#4b5563;--neutral-bg:#eef0f4}
*{box-sizing:border-box}
html{scroll-behavior:smooth}
body{margin:0;background:var(--bg);color:var(--ink);font-family:Inter,"Segoe UI",Arial,sans-serif;line-height:1.55}
h1,h2,h3,h4{font-family:Poppins,Inter,"Segoe UI",sans-serif;line-height:1.25;margin:0 0 .5em}
a{color:var(--primary)}
.wrap{max-width:1140px;margin:0 auto;padding:0 20px}
.wrap.narrow{max-width:900px}
.center{text-align:center}
.sub{color:var(--muted);max-width:640px;margin:0 auto 28px}
.muted{color:var(--muted)}
.tag{display:inline-block;font-size:.7rem;font-weight:700;text-transform:uppercase;letter-spacing:.06em;color:var(--primary);background:#eef0ff;border-radius:4px;padding:1px 6px;margin-right:6px}

/* top bar */
.topbar{position:sticky;top:0;z-index:20;background:rgba(18,20,48,.92);backdrop-filter:blur(8px)}
.bar{display:flex;align-items:center;justify-content:space-between;gap:16px;height:60px}
.brand{display:flex;align-items:center;gap:10px;color:#fff;text-decoration:none;font-size:1.05rem}
.brand .logo svg{width:30px;height:30px;display:block}
.topbar nav{display:flex;gap:4px;flex-wrap:wrap}
.topbar nav a{color:#cfd3ff;text-decoration:none;font-size:.9rem;padding:6px 10px;border-radius:6px}
.topbar nav a:hover{background:rgba(255,255,255,.1);color:#fff}
.menu-btn{display:none;flex-direction:column;justify-content:center;gap:5px;width:44px;height:44px;padding:10px;border:0;border-radius:8px;background:transparent;cursor:pointer}
.menu-btn span{display:block;height:2px;border-radius:2px;background:#fff}
.menu-btn:focus-visible{outline:2px solid #f5b83d}

/* buttons */
.btn{display:inline-block;border:0;border-radius:8px;padding:11px 20px;font:600 .95rem Inter,"Segoe UI",sans-serif;cursor:pointer;text-decoration:none;transition:transform .1s,box-shadow .2s,background .2s}
.btn:hover{transform:translateY(-1px)}
.btn-primary{background:var(--primary);color:#fff;box-shadow:0 4px 14px rgba(67,56,202,.3)}
.btn-primary:hover{background:var(--primary-d)}
.btn-secondary{background:#fff;color:var(--primary);border:2px solid var(--primary)}
.btn-ghost{background:transparent;color:var(--primary)}
.btn-light{background:var(--accent);color:#2a1a00;box-shadow:0 6px 18px rgba(245,184,61,.35)}
.btn-outline{background:transparent;color:#fff;border:2px solid rgba(255,255,255,.5)}

/* hero */
.hero{background:radial-gradient(1200px 500px at 80% 20%,#4b2d8f 0%,transparent 60%),linear-gradient(135deg,#12143a 0%,#1f1b54 55%,#2a1f63 100%);color:#fff;padding:64px 0 72px;overflow:hidden}
.hero-grid{display:grid;grid-template-columns:1.25fr 1fr;gap:40px;align-items:center}
.eyebrow{display:inline-block;background:rgba(255,255,255,.1);border:1px solid rgba(255,255,255,.2);border-radius:999px;padding:4px 14px;font-size:.82rem;color:#e4e6ff;margin-bottom:18px}
.hero h1{font-size:clamp(2rem,4.2vw,3.2rem);color:#fff}
.accent{color:var(--accent)}
.hero .lead{font-size:1.08rem;color:#d7d9f5;max-width:580px}
.hero-cta{display:flex;gap:12px;flex-wrap:wrap;margin:26px 0 30px}
.stats{list-style:none;padding:0;margin:0;display:flex;gap:28px;flex-wrap:wrap}
.stats li{display:flex;flex-direction:column}
.stats b{font:700 1.7rem Poppins,sans-serif;color:#fff}
.stats span{font-size:.82rem;color:#b9bce6}
.hero-art{position:relative;height:340px}
.hero-art .gem{position:absolute;filter:drop-shadow(0 18px 30px rgba(0,0,0,.45));animation:float 6s ease-in-out infinite}
.hero-art .gem svg{width:100%;height:100%;filter:none}
.hero-art .g1{width:190px;height:190px;left:18%;top:18%}
.hero-art .g2{width:120px;height:120px;left:66%;top:4%;animation-delay:-1.5s}
.hero-art .g3{width:130px;height:130px;left:62%;top:58%;animation-delay:-3s}
.hero-art .g4{width:95px;height:95px;left:2%;top:66%;animation-delay:-4.5s}
@keyframes float{0%,100%{transform:translateY(0)}50%{transform:translateY(-12px)}}

/* sections */
.section{padding:64px 0}
.section.alt{background:#eceefa}
.section h2{font-size:1.9rem}
.feature-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:18px;margin-top:28px}
.feature{background:var(--card);border-radius:14px;padding:22px;box-shadow:0 1px 3px rgba(20,20,60,.06);border:1px solid var(--line)}
.feature .icon{display:inline-flex;width:40px;height:40px;border-radius:10px;align-items:center;justify-content:center;background:#eef0ff;color:var(--primary);font-size:1.2rem;margin-bottom:10px}
.feature h3{font-size:1.05rem}
.feature p{margin:0;color:var(--muted);font-size:.93rem}
.steps3{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:18px}
.step3{background:#fff;border-radius:14px;padding:24px;border:1px solid var(--line)}
.step3 .num,legend .num{display:inline-flex;width:32px;height:32px;border-radius:50%;background:var(--primary);color:#fff;font-weight:700;align-items:center;justify-content:center;margin-bottom:10px}
.step3 p{color:var(--muted);margin:0;font-size:.94rem}
.modes-title{margin:40px 0 16px}
.modes{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:18px}
.mode-card{border-radius:14px;padding:24px;color:#fff}
.mode-card.identify{background:linear-gradient(135deg,#4338ca,#6d28d9)}
.mode-card.verify{background:linear-gradient(135deg,#0f766e,#0e7490)}
.mode-card h3{font-size:1.2rem;margin-top:12px}
.mode-card p{color:rgba(255,255,255,.88);margin:0 0 8px}
.mode-card .tech{font-size:.82rem;opacity:.8;margin-top:10px}
.pill{display:inline-block;background:rgba(255,255,255,.18);border-radius:999px;padding:3px 12px;font-size:.8rem;font-weight:600}

/* form */
.gem-form{background:#fff;border-radius:18px;padding:28px;box-shadow:0 10px 40px rgba(30,30,90,.08);border:1px solid var(--line)}
fieldset{border:0;padding:0;margin:0 0 26px}
legend{display:flex;align-items:center;gap:10px;font:600 1.1rem Poppins,sans-serif;margin-bottom:14px}
legend .num{margin:0;width:28px;height:28px;font-size:.9rem}
.field-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:20px}
.field{background:#fafbff;border:1px solid var(--line);border-radius:12px;padding:14px}
.field label{display:block;font-weight:700;margin-bottom:2px}
.field .what{margin:0 0 8px;font-size:.84rem;color:var(--muted)}
.field input,.field select,.verify-row select{width:100%;padding:10px 12px;border:1.5px solid #cfd4e2;border-radius:8px;font:1rem Inter,"Segoe UI",sans-serif;background:#fff}
.field input:focus,.field select:focus,.verify-row select:focus{outline:none;border-color:var(--primary);box-shadow:0 0 0 3px rgba(67,56,202,.15)}
.field .where{margin:8px 0 0;font-size:.8rem;color:var(--muted)}
.otl{display:flex;align-items:center;gap:8px;margin-top:8px;font-size:.88rem;cursor:pointer}
.field .otl input{width:18px;height:18px;padding:0;margin:0;accent-color:var(--primary);flex:none}
.actions{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:18px;border-top:1px solid var(--line);padding-top:24px}
.action-card{border-radius:12px;padding:18px;background:#f4f3ff}
.action-card:last-child{background:#effaf8}
.action-card h3{font-size:1.05rem;margin-bottom:2px}
.action-card p{margin:0 0 12px;font-size:.9rem;color:var(--muted)}
.action-card .btn-primary{width:100%}
.verify-row{display:flex;gap:10px}
.verify-row .btn-secondary{border-color:#0f766e;color:#0f766e}
.form-foot{text-align:right;margin:14px 0 0;font-size:.88rem}
@keyframes flash{0%{box-shadow:0 0 0 6px rgba(245,184,61,.9)}100%{box-shadow:0 10px 40px rgba(30,30,90,.08)}}
.gem-form.flash{animation:flash 1.4s ease-out}

/* gallery */
.gallery{display:grid;grid-template-columns:repeat(auto-fill,minmax(250px,1fr));gap:18px}
.card{background:#fff;border-radius:14px;overflow:hidden;display:flex;flex-direction:column;border:1px solid var(--line);transition:transform .15s,box-shadow .2s}
.card:hover{transform:translateY(-3px);box-shadow:0 12px 30px rgba(30,30,90,.12)}
.card .pic{background:radial-gradient(circle at 50% 40%,#3a3f66,#15172c);height:140px;display:flex;align-items:center;justify-content:center}
.gem-svg{width:100px;height:100px;filter:drop-shadow(0 6px 10px rgba(0,0,0,.5))}
.gem-photo{max-width:100%;max-height:140px;object-fit:contain}
.card .body{padding:14px 16px 16px;display:flex;flex-direction:column;flex:1}
.card h3{font-size:1.05rem}
.specs{list-style:none;margin:0 0 10px;padding:0;font-size:.86rem}
.specs li{display:flex;justify-content:space-between;gap:8px;border-bottom:1px dashed var(--line);padding:3px 0}
.specs .k{color:var(--muted)}.specs .v{font-weight:600;text-align:right}
.expect{font-size:.85rem;color:var(--ink);margin:4px 0 14px;flex:1}
.card .btn{width:100%}

/* glossary + notice */
.glossary{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:12px}
.term{background:#fff;border:1px solid var(--line);border-radius:10px;padding:14px 18px}
.term summary{cursor:pointer;font-weight:600}
.term p{margin:10px 0 0;color:var(--muted);font-size:.93rem}
.notice{background:#fff;border-left:5px solid var(--accent);border-radius:12px;padding:22px 26px}
.notice ul{margin:0;padding-left:20px;color:var(--muted)}

/* page head */
.page-head{background:linear-gradient(135deg,#12143a,#2a1f63);color:#fff;padding:26px 0 70px}
.page-head h1{font-size:clamp(1.6rem,3vw,2.3rem);color:#fff;margin-top:10px}
.page-head p{color:#cfd2f3;margin:0;max-width:680px}
.back{color:#cfd3ff;text-decoration:none;font-size:.9rem;display:block;margin-bottom:14px}
.mode-pill{display:inline-block;background:rgba(255,255,255,.12);border-radius:999px;padding:3px 12px;font-size:.82rem}
.content > .wrap.narrow{margin-top:-48px;padding-bottom:40px}

/* result */
.result-hero{display:flex;gap:26px;align-items:center;background:#fff;border-radius:18px;padding:24px;box-shadow:0 14px 40px rgba(30,30,90,.12);margin-bottom:18px}
.result-hero .pic{flex:none;width:160px;height:160px;border-radius:14px;background:radial-gradient(circle at 50% 40%,#3a3f66,#15172c);display:flex;align-items:center;justify-content:center}
.result-hero .pic .gem-svg{width:120px;height:120px}
.kicker{font-size:.8rem;text-transform:uppercase;letter-spacing:.08em;color:var(--primary);font-weight:700}
.result-hero h2{font-size:clamp(1.5rem,3vw,2.1rem);margin:4px 0}
.result-hero .sub{margin:0 0 12px;color:var(--muted);text-align:left}
.badges{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:12px}
.badge{display:inline-block;padding:4px 12px;border-radius:999px;font-size:.84rem;font-weight:600}
.badge.good{background:var(--good-bg);color:var(--good)}
.badge.warn{background:var(--warn-bg);color:var(--warn)}
.badge.bad{background:var(--bad-bg);color:var(--bad)}
.badge.neutral{background:var(--neutral-bg);color:var(--neutral)}
.meter{display:flex;align-items:center;gap:10px;font-size:.82rem;color:var(--muted)}
.bars{display:flex;gap:4px}
.mbar{width:34px;height:8px;border-radius:4px;background:#e2e5ee}
.mbar.on{background:linear-gradient(90deg,#4338ca,#7c3aed)}
.block{background:#fff;border-radius:14px;padding:22px 24px;margin-bottom:18px;border:1px solid var(--line)}
.block h3{font-size:1.15rem}
.block.advice{border-left:5px solid var(--good)}
.block.advice ul{list-style:none;padding:0;margin:0}
.block.advice li{display:flex;gap:10px;padding:6px 0}
.block.advice .icon{color:var(--good)}
.tips{margin:0;padding-left:20px;color:var(--muted)}
.chips{display:flex;flex-wrap:wrap;gap:8px}
.chip{background:#eef0ff;border-radius:999px;padding:5px 14px;font-size:.88rem}
.chip .k{color:var(--muted)}
.chip.off{background:#f3f4f7;color:#9aa0b3}
.alt-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:12px}
.altcard{display:flex;gap:12px;align-items:center;border:1px solid var(--line);border-radius:12px;padding:10px}
.altcard .pic{flex:none;width:64px;height:64px;border-radius:10px;background:radial-gradient(circle at 50% 40%,#3a3f66,#15172c);display:flex;align-items:center;justify-content:center}
.altcard .pic .gem-svg{width:48px;height:48px}
.altcard h4{margin:0}
.ranges{margin:2px 0 0;font-size:.8rem;color:var(--muted)}

/* timeline */
.timeline{list-style:none;margin:16px 0 0;padding:0;position:relative}
.timeline:before{content:"";position:absolute;left:15px;top:6px;bottom:6px;width:2px;background:#dcdff0}
.tstep{position:relative;padding:0 0 18px 48px}
.tstep .dot{position:absolute;left:0;top:0;width:32px;height:32px;border-radius:50%;background:var(--primary);color:#fff;font-weight:700;display:flex;align-items:center;justify-content:center;font-size:.9rem;box-shadow:0 0 0 4px #fff}
.tbody{background:#fafbff;border:1px solid var(--line);border-radius:12px;padding:12px 16px}
.meta{display:flex;gap:8px;align-items:center;margin-bottom:4px}
.stage{font-size:.74rem;font-weight:700;text-transform:uppercase;letter-spacing:.06em;color:var(--primary)}
.rule{font:600 .74rem Consolas,monospace;background:#eceefa;color:var(--muted);border-radius:4px;padding:1px 6px}
.tbody h4{margin:0 0 4px;font-size:1.02rem}
.bc{margin:4px 0 2px;font-size:.84rem;font-weight:600;color:var(--muted)}
.reasons{margin:0 0 6px;padding-left:20px;font-size:.92rem}
.why{margin:6px 0 0;font-size:.86rem;color:var(--ink);background:#fff;border-radius:8px;padding:6px 10px;border:1px dashed var(--line)}
.tsrc .src{margin:4px 0 0 2px;font-size:.76rem;color:#8a90a8}
.profile{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:0 24px}
.prow{display:flex;justify-content:space-between;gap:12px;border-bottom:1px dashed var(--line);padding:6px 0;font-size:.92rem}
.prow .k{color:var(--muted)}.prow .v{font-weight:600;text-align:right}
.tech summary{cursor:pointer;font-weight:600;color:var(--muted)}
.section_t{margin-top:16px}
.section_t h4{font-size:.8rem;text-transform:uppercase;letter-spacing:.06em;color:var(--primary)}
.trace{font:.84rem Consolas,monospace;background:#f7f8fc;border-radius:8px;padding:10px 12px}
.line{padding:1px 0;overflow-wrap:anywhere}
.result-actions{display:flex;gap:10px;flex-wrap:wrap;margin-top:6px}

/* verify */
.answer{display:flex;gap:20px;align-items:center;background:#fff;border-radius:18px;padding:24px;box-shadow:0 14px 40px rgba(30,30,90,.12);margin-bottom:18px;border-left:8px solid}
.answer.yes{border-color:var(--good)}
.answer.no{border-color:var(--bad)}
.answer h2{font-size:clamp(1.3rem,2.6vw,1.8rem);margin-bottom:6px}
.answer p{margin:0 0 4px}
.mark{flex:none;width:64px;height:64px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:2rem;font-weight:700;color:#fff}
.answer.yes .mark{background:var(--good)}
.answer.no .mark{background:var(--bad)}
.why-tree{list-style:none;margin:8px 0 0;padding-left:0}
.why-tree .why-tree{padding-left:28px;border-left:2px solid #eceefa;margin-left:10px}
.wrow{display:flex;gap:10px;align-items:baseline;padding:6px 0}
.wrow .x{color:var(--primary);font-weight:700}
.wrow.fail .x{color:var(--bad)}
.wrow .t{flex:1}
.best-row{display:flex;gap:16px;align-items:center;flex-wrap:wrap}
.best-row h4{margin:0 0 2px;font-size:1.1rem}
.best-row .pic{flex:none;width:80px;height:80px;border-radius:12px;background:radial-gradient(circle at 50% 40%,#3a3f66,#15172c);display:flex;align-items:center;justify-content:center}
.best-row .pic .gem-svg{width:60px;height:60px}
.best-row > div:nth-child(2){flex:1;min-width:200px}
.best-row p{margin:0 0 6px}
.warnbox{border-left:5px solid var(--bad)}

/* certainty, ranked candidates */
.meter b{color:var(--ink);font-size:.9rem}
.cfword{color:var(--muted);font-size:.85rem}
.cfhelp{margin-top:6px;font-size:.84rem;color:var(--muted)}
.cfhelp summary{cursor:pointer;color:var(--primary);font-weight:600;display:inline}
.cfhelp ul{margin:6px 0 4px;padding-left:18px}
.cfhelp p{margin:4px 0 0}
.rpctw{display:flex;flex-direction:column;align-items:flex-end;line-height:1.1}
.rword{font-size:.78rem;color:var(--muted)}
.cfbar{display:inline-block;position:relative;width:180px;height:9px;border-radius:5px;background:#e2e5ee;overflow:hidden;vertical-align:middle}
.cffill{position:absolute;left:0;top:0;bottom:0;border-radius:5px;background:linear-gradient(90deg,#4338ca,#7c3aed)}
.cftag{font-size:.74rem;font-weight:600;color:#15803d;background:#e7f6ec;border-radius:4px;padding:1px 6px}
.rank-list{display:flex;flex-direction:column;gap:12px}
.rank{display:flex;gap:14px;align-items:flex-start;border:1px solid var(--line);border-radius:12px;padding:12px}
.rnum{flex:none;width:28px;height:28px;border-radius:50%;background:#eef0ff;color:var(--primary);font-weight:700;display:flex;align-items:center;justify-content:center}
.rank .pic{flex:none;width:64px;height:64px;border-radius:10px;background:radial-gradient(circle at 50% 40%,#3a3f66,#15172c);display:flex;align-items:center;justify-content:center}
.rank .pic .gem-svg{width:48px;height:48px}
.rbody{flex:1;min-width:0}
.rtop{display:flex;justify-content:space-between;align-items:baseline;gap:10px}
.rtop h4{margin:0}
.rpct{font:700 1.2rem Poppins,sans-serif;color:var(--primary)}
.rank .cfbar{width:100%;margin:4px 0 6px}
.evidence{margin:6px 0 0;padding-left:18px;font-size:.85rem;color:var(--muted)}

/* question box, consultation */
.ask-box{display:flex;gap:10px;margin:0 0 10px;max-width:640px}
.ask-box input{flex:1;padding:12px 14px;border-radius:8px;border:0;font:1rem Inter,"Segoe UI",sans-serif;min-width:0}
.ask-box.light input{border:1.5px solid #cfd4e2}
.ask-examples{display:flex;flex-wrap:wrap;gap:6px;align-items:center;margin-bottom:26px;font-size:.82rem;color:#b9bce6}
.hero-grid > *{min-width:0}
.ask-chip{white-space:normal;overflow-wrap:anywhere;color:#e4e6ff;background:rgba(255,255,255,.1);border:1px solid rgba(255,255,255,.2);border-radius:999px;padding:3px 10px;text-decoration:none}
.ask-chip:hover{background:rgba(255,255,255,.2)}
.tips .ask-chip{color:var(--primary);background:#eef0ff;border-color:#dfe3ff}
.parsed{border-left:5px solid var(--accent)}
.parsed .quote{font-size:1.05rem;font-style:italic;margin:0 0 6px}
.chip.goal{background:#fdf1dc}
.warnline{color:var(--bad);font-size:.88rem}
.action-card.consult{background:#fdf6e9}
.question h2{font-size:1.35rem;margin:6px 0 14px}
.qmeta{display:flex;gap:8px;align-items:center}
.question .field{background:#fff;margin-bottom:14px}
.qbtns{display:flex;gap:10px;flex-wrap:wrap}
.whybox{margin-top:18px;background:#f4f3ff;border-radius:12px;padding:12px 16px}
.whybox summary{cursor:pointer;font-weight:700;color:var(--primary)}
.whylist{margin:10px 0 0;padding-left:20px}
.whylist li{margin:4px 0}
.efficiency{display:flex;gap:12px;align-items:center;border-left:5px solid var(--primary)}
.efficiency .icon{font-size:1.4rem;color:var(--accent)}

/* reasoning diagrams */
.d-controls{display:flex;gap:8px;flex-wrap:wrap;align-items:center;margin:12px 0}
.d-controls .btn{padding:7px 14px;font-size:.85rem}
.d-count{color:var(--muted);font-size:.85rem;margin-left:auto}
.d-caption{background:#1f1b54;color:#fff;border-radius:10px;padding:10px 14px;min-height:44px;margin:0 0 12px;font-size:.93rem}
.d-canvas{overflow-x:auto;background:#fafbff;border:1px solid var(--line);border-radius:12px;padding:8px;text-align:center}
.rsvg{width:100%;height:auto;display:block;margin:0 auto}
.rsvg .dstep{transition:opacity .35s}
.rsvg .dstep.dim{opacity:.07}
.rsvg g.dstep.cur rect{filter:drop-shadow(0 0 6px rgba(245,184,61,.95))}
.legend{display:flex;flex-wrap:wrap;gap:8px 16px;margin-top:12px;font-size:.82rem;color:var(--muted)}
.legend .sw{display:inline-block;width:16px;height:12px;border-radius:4px;border:2px solid;vertical-align:-2px;margin-right:6px}

/* knowledge base */
.table-wrap{overflow-x:auto}
table.kb{border-collapse:collapse;width:100%;font-size:.86rem}
table.kb th{background:#1f1b54;color:#fff;text-align:left;padding:8px}
table.kb td{border-bottom:1px solid var(--line);padding:8px;vertical-align:top}
table.kb code{font:.8rem Consolas,monospace;color:#3730a3;white-space:normal}
table.kb td.src{color:var(--muted);font-size:.78rem;min-width:160px}

/* footer, toast */
.footer{background:#12143a;color:#b9bce6;padding:28px 0;font-size:.88rem;margin-top:40px}
.footer p{margin:4px 0}
.footer b{color:#fff}
.toast{position:fixed;left:50%;bottom:24px;transform:translate(-50%,120px);background:#1b1f3a;color:#fff;padding:12px 20px;border-radius:10px;box-shadow:0 10px 30px rgba(0,0,0,.3);transition:transform .3s;z-index:50;max-width:90vw}
.toast.show{transform:translate(-50%,0)}

@media (max-width:820px){
 .hero-grid{grid-template-columns:1fr}
 .hero-art{height:220px}
 .hero-art .g1{width:130px;height:130px}
 .menu-btn{display:flex}
 .topbar nav{display:none;position:absolute;top:60px;left:0;right:0;flex-direction:column;gap:0;background:#12143a;padding:6px 12px 12px;box-shadow:0 12px 24px rgba(0,0,0,.35)}
 .topbar nav.open{display:flex}
 .topbar nav a{padding:12px 10px;font-size:1rem;border-bottom:1px solid rgba(255,255,255,.08)}
 .topbar nav a:last-child{border-bottom:0}
 .result-hero,.answer{flex-direction:column;text-align:center;align-items:center}
 .result-hero .sub{text-align:center}
 .badges{justify-content:center}
 .verify-row{flex-direction:column}
}
').
