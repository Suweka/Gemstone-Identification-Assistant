/*  query_parser.pl
    Gemstone Identification Assistant - NATURAL-LANGUAGE QUERIES (DCG)

    Parses plain-English questions with a Definite Clause Grammar, e.g.

        "Is my stone a sapphire if the RI is 1.765 and it is blue?"
        "What is a singly refractive red stone with SG 3.60?"
        "RI 1.52, SG 2.57, biaxial, colourless, with adularescence"
        "Could it be glass? isotropic, RI 1.52, gas bubbles"

    parse_query(+Text, -Mode, -Facts, -Ignored)
        Mode    = identify | verify(Target)
        Facts   = input facts, e.g. [ri(1.765), observed_colour(blue)]
        Ignored = words that were not understood (stop words removed)

    The grammar recognises phrases anywhere in the sentence and skips
    words it does not know, so word order is flexible.
*/

:- encoding(utf8).

parse_query(Text, Mode, Facts, Ignored) :-
    tokenize_query(Text, Tokens),
    phrase(items(Items), Tokens), !,
    findall(T, member(goal(T), Items), Goals),
    ( last(Goals, G) -> Mode = verify(G) ; Mode = identify ),
    findall(F, member(fact(F), Items), Fs0),
    keep_last_per_key(Fs0, Facts),
    findall(W, ( member(skip(W), Items), \+ stop_word(W) ), Ignored).

/* ---- Tokenizer: lower case, drop apostrophes, split on punctuation - */
tokenize_query(Text, Tokens) :-
    string_lower(Text, Lower),
    string_codes(Lower, Cs0),
    exclude(apostrophe, Cs0, Cs1),
    maplist(normalise_code, Cs1, Cs),
    string_codes(S, Cs),
    split_string(S, " ", " ", Parts),
    exclude(==(""), Parts, Parts1),
    maplist(clean_token, Parts1, Tokens0),
    exclude(==(''), Tokens0, Tokens).

apostrophe(0'\').
apostrophe(0x2019).          % typographic apostrophe

normalise_code(C, C) :- code_type(C, alnum), !.
normalise_code(0'., 0'.) :- !.
normalise_code(_, 0' ).

% keep "1.765" but strip sentence full stops ("4.00." -> 4.00, "blue." -> blue)
clean_token(S0, A) :-
    split_string(S0, "", ".", [S]),
    (   S == "" -> A = ''
    ;   number_string(_, S) -> atom_string(A, S)
    ;   split_string(S, ".", "", [W|_]), atom_string(A, W) ).

/* ---- Grammar ---------------------------------------------------- */
items([I|Is]) --> item(I), !, items(Is).
items([skip(W)|Is]) --> [W], !, items(Is).
items([]) --> [].

item(goal(T))  --> goal_phrase(T).
item(fact(F))  --> fact_phrase(F).

% "is my stone a ruby", "could it be glass", "check whether it is a spinel"
goal_phrase(T) --> [is], stone_ref, article, target(T).
goal_phrase(T) --> [could], stone_ref, [be], article, target(T).
goal_phrase(T) --> [might], stone_ref, [be], article, target(T).
goal_phrase(T) --> verify_word, article, target(T).

verify_word --> [verify].
verify_word --> [confirm].
verify_word --> [check, for].
verify_word --> [is, this].

stone_ref --> [my, stone].
stone_ref --> [my, gem].
stone_ref --> [the, stone].
stone_ref --> [this, stone].
stone_ref --> [this, gem].
stone_ref --> [it].
stone_ref --> [this].
stone_ref --> [].

article --> [a].
article --> [an].
article --> [the].
article --> [].

% gem names: the longest name is tried first ("star sapphire" before "sapphire")
target(T, S0, S) :-
    target_names(Names),
    member(Words-T, Names),
    append(Words, S, S0), !.

target_names(Sorted) :-
    findall(N-(Ws-T),
            ( target_words(Ws, T), length(Ws, L), N is -L ),
            Ps),
    keysort(Ps, SortedPs), pairs_values(SortedPs, Sorted).

target_words(Ws, T) :-
    verify_targets(Ts), member(T, Ts),
    atomic_list_concat(Ws, '_', T).
target_words([sapphire], blue_sapphire).
target_words([cats, eye], cats_eye_chrysoberyl).
target_words([cat, eye], cats_eye_chrysoberyl).
target_words([cz], cubic_zirconia).
target_words([zirconia], cubic_zirconia).
target_words([garnet], garnet).
target_words([red, garnet], pyrope_almandine).
target_words([almandine], pyrope_almandine).
target_words([pyrope], pyrope_almandine).
target_words([cymophane], cats_eye_chrysoberyl).
target_words([padparadscha, sapphire], padparadscha).

% ---- property phrases ----
fact_phrase(ri(over_limit)) --> ri_word, link, over_limit_words.
fact_phrase(ri(over_limit)) --> over_limit_words, [on, the, refractometer].
fact_phrase(ri(N)) --> ri_word, link, number(N).
fact_phrase(sg(N)) --> sg_word, link, number(N).
fact_phrase(optic(O)) --> optic_words(O).
fact_phrase(phenomenon(P)) --> phenomenon_words(P).
fact_phrase(inclusion(I)) --> inclusion_words(I).
fact_phrase(observed_colour(C)) --> [W], { colour_word(W, C) }.

ri_word --> [refractive, index, ri].
ri_word --> [refractive, index].
ri_word --> [ri].
ri_word --> [r, i].
ri_word --> [refraction].

ri_word --> [refractometer, reading].
ri_word --> [refractometer].

% the refractometer shows no reading: RI above the instrument's limit
over_limit_words --> [over, the, limit].
over_limit_words --> [above, the, limit].
over_limit_words --> [over, limit].
over_limit_words --> [otl].
over_limit_words --> [no, reading].

sg_word --> [specific, gravity, sg].
sg_word --> [specific, gravity].
sg_word --> [sg].
sg_word --> [s, g].
sg_word --> [density].

link --> [W], { link_word(W) }, !, link.
link --> [].

link_word(is).     link_word(of).       link_word(about).  link_word(around).
link_word(reads).  link_word(reading).  link_word(value).  link_word(was).
link_word(approx). link_word(approximately). link_word(at). link_word(roughly).

number(N) --> [A], { atom_number(A, N) }.

optic_words(isotropic)         --> [singly, refractive].
optic_words(isotropic)         --> [single, refraction].
optic_words(isotropic)         --> [single, refractive].
optic_words(isotropic)         --> [isotropic].
optic_words(isotropic)         --> [sr].
optic_words(uniaxial)          --> [uniaxial].
optic_words(biaxial)           --> [biaxial].
optic_words(doubly_refractive) --> [doubly, refractive].
optic_words(doubly_refractive) --> [double, refraction].
optic_words(doubly_refractive) --> [double, refractive].
optic_words(doubly_refractive) --> [anisotropic].
optic_words(doubly_refractive) --> [dr].

phenomenon_words(none)          --> [no, effect].
phenomenon_words(none)          --> [no, phenomenon].
phenomenon_words(cats_eye)      --> [cats, eye].
phenomenon_words(cats_eye)      --> [cat, eye].
phenomenon_words(cats_eye)      --> [catseye].
phenomenon_words(cats_eye)      --> [chatoyancy].
phenomenon_words(cats_eye)      --> [chatoyant].
phenomenon_words(colour_change) --> [colour, change].
phenomenon_words(colour_change) --> [color, change].
phenomenon_words(colour_change) --> [changes, colour].
phenomenon_words(colour_change) --> [changes, color].
phenomenon_words(adularescence) --> [adularescence].
phenomenon_words(adularescence) --> [adularescent].
phenomenon_words(adularescence) --> [glow].
phenomenon_words(star)          --> [star].
phenomenon_words(star)          --> [asterism].

inclusion_words(none)              --> [no, inclusions].
inclusion_words(none)              --> [eye, clean].
inclusion_words(none)              --> [clean].
inclusion_words(none)              --> [flawless].
inclusion_words(gas_bubbles)       --> [gas, bubbles].
inclusion_words(gas_bubbles)       --> [bubbles].
inclusion_words(gas_bubbles)       --> [bubble].
inclusion_words(curved_lines)      --> [curved, growth, lines].
inclusion_words(curved_lines)      --> [curved, lines].
inclusion_words(curved_lines)      --> [curved, striae].
inclusion_words(curved_lines)      --> [curved].
inclusion_words(swirl_marks)       --> [swirl, marks].
inclusion_words(swirl_marks)       --> [swirls].
inclusion_words(swirl_marks)       --> [swirl].
inclusion_words(discoid_fractures) --> [discoid, fractures].
inclusion_words(discoid_fractures) --> [discoid].
inclusion_words(silk)              --> [silk].
inclusion_words(silk)              --> [rutile, needles].
inclusion_words(silk)              --> [needles].
inclusion_words(crystals)          --> [crystal, inclusions].
inclusion_words(crystals)          --> [crystals].
inclusion_words(crystals)          --> [crystal].
inclusion_words(fingerprints)      --> [fingerprints].
inclusion_words(fingerprints)      --> [fingerprint].
inclusion_words(fingerprints)      --> [feathers].
inclusion_words(fingerprints)      --> [healed, fractures].

colour_word(W, C) :- colour(_, W), !, C = W.
colour_word(colorless, colourless).
colour_word(clear, colourless).
colour_word(violet, purple).
colour_word(lilac, purple).
colour_word(golden, yellow).

% only the last value given for each property is kept
keep_last_per_key(Fs, Kept) :-
    reverse(Fs, Rev),
    keep_first(Rev, [], Kept0),
    reverse(Kept0, Kept).

keep_first([], _, []).
keep_first([F|Fs], Seen, Out) :-
    functor(F, Name, _),
    (   memberchk(Name, Seen) -> Out = Rest
    ;   Out = [F|Rest] ),
    keep_first(Fs, [Name|Seen], Rest).

stop_word(W) :- memberchk(W, [a, an, the, is, it, its, my, this, that, stone, gem, gemstone,
    and, with, if, of, what, which, has, have, shows, show, showing, under, loupe, i, see,
    saw, there, are, some, in, to, be, could, can, you, tell, me, please, whether, check,
    looks, look, like, colour, color, inclusions, inclusion, effect, optic, character,
    reading, measured, measure, value, about, on, for, identify, stones, do, does, am, was,
    very, quite, slightly, light, dark, deep, but, or, not, no, any, how, when, where]).
