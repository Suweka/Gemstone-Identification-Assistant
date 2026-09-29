/*  examples.pl
    Gemstone Identification Assistant - EXAMPLE STONES + GEM PICTURES

    Example stones shown as cards on the home page. "Try it" copies the
    specs into the form so the user can run Identify or Verify.

    Pictures are drawn as inline SVG (works offline). To use a real photo
    instead, save it as  images/<key>.jpg  (or .png / .webp), e.g.
    images/blue_sapphire.jpg  - it will be used automatically.
*/

:- encoding(utf8).

/* example(Key, Title, Specs, ExpectedResult, VerifyTarget)
   Specs use the form field names: ri, sg, optic, colour, phenomenon, inclusion */
example(blue_sapphire, 'Blue sapphire',
        [ri-'1.765', sg-'4.00', optic-uniaxial, colour-blue, inclusion-silk],
        'Blue sapphire, likely natural', blue_sapphire).
example(synthetic_ruby, 'Synthetic ruby',
        [ri-'1.764', sg-'3.99', optic-uniaxial, colour-red, inclusion-curved_lines],
        'Ruby, synthetic (flame fusion)', ruby).
example(star_sapphire, 'Star sapphire',
        [ri-'1.765', sg-'4.00', optic-uniaxial, colour-blue, phenomenon-star, inclusion-silk],
        'Star sapphire, likely natural', star_sapphire).
example(padparadscha, 'Padparadscha',
        [ri-'1.766', sg-'4.00', optic-uniaxial, colour-orange, inclusion-fingerprints],
        'Padparadscha, likely natural', padparadscha).
example(red_spinel, 'Red spinel',
        [ri-'1.718', sg-'3.60', optic-isotropic, colour-red, inclusion-crystals],
        'Red spinel, likely natural', red_spinel).
example(hessonite, 'Hessonite garnet',
        [ri-'1.745', sg-'3.65', optic-isotropic, colour-orange, inclusion-crystals],
        'Hessonite (garnet), likely natural', hessonite).
example(alexandrite, 'Alexandrite',
        [ri-'1.748', sg-'3.73', optic-biaxial, colour-green, phenomenon-colour_change, inclusion-fingerprints],
        'Alexandrite, likely natural', alexandrite).
example(cats_eye, 'Cat''s-eye chrysoberyl',
        [ri-'1.747', sg-'3.72', optic-biaxial, colour-yellow, phenomenon-cats_eye, inclusion-crystals],
        'Cat''s-eye chrysoberyl, likely natural', cats_eye_chrysoberyl).
example(moonstone, 'Moonstone',
        [ri-'1.520', sg-'2.57', optic-biaxial, colour-colourless, phenomenon-adularescence, inclusion-crystals],
        'Moonstone (feldspar), likely natural', moonstone).
example(amethyst, 'Amethyst',
        [ri-'1.544', sg-'2.65', optic-uniaxial, colour-purple, inclusion-fingerprints],
        'Amethyst (quartz), likely natural', amethyst).
example(aquamarine, 'Aquamarine',
        [ri-'1.577', sg-'2.70', optic-uniaxial, colour-blue, inclusion-crystals],
        'Aquamarine (beryl), likely natural', aquamarine).
example(blue_zircon_otl, 'Blue zircon',
        [ri-over_limit, sg-'4.70', optic-uniaxial, colour-blue, inclusion-crystals],
        'Blue zircon, likely natural (RI over the refractometer limit)', blue_zircon).
example(glass_imitation, 'Blue glass imitation',
        [ri-'1.520', optic-isotropic, colour-blue, inclusion-gas_bubbles],
        'Imitation: glass', glass).
example(cubic_zirconia, 'Cubic zirconia',
        [sg-'5.80', optic-isotropic, colour-colourless, inclusion-none],
        'Imitation: cubic zirconia', cubic_zirconia).
example(unknown_red, 'Red stone, no instruments',
        [optic-isotropic, colour-red],
        'Possible: spinel or garnet (data missing)', red_spinel).

/* gem_visual(Key, Shape)
     faceted(Light, Dark)        round brilliant seen from above
     split(Colour1, Colour2)     colour-change stone (half and half)
     cabochon(Light, Dark, Fx)   domed stone; Fx = none | star | cats_eye | glow
     bubbles(Light, Dark)        faceted glass with gas bubbles
   Keys cover the examples, the varieties and the species, so the result
   page can show a picture of whatever was identified. */
gem_visual(blue_sapphire,        faceted('#6f9bff', '#0f2a8a')).
gem_visual(synthetic_ruby,       faceted('#ff6b81', '#8a0018')).
gem_visual(ruby,                 faceted('#ff6b81', '#8a0018')).
gem_visual(star_ruby,            cabochon('#ff6b81', '#7a0016', star)).
gem_visual(star_sapphire,        cabochon('#7fa4ff', '#0f2a7a', star)).
gem_visual(pink_sapphire,        faceted('#ffb3d1', '#c2356f')).
gem_visual(padparadscha,         faceted('#ffc2a8', '#e0613f')).
gem_visual(yellow_sapphire,      faceted('#fff08a', '#c99a00')).
gem_visual(white_sapphire,       faceted('#ffffff', '#a9b4c6')).
gem_visual(red_spinel,           faceted('#ff7a8a', '#a3122d')).
gem_visual(hessonite,            faceted('#ffb562', '#9c4a06')).
gem_visual(pyrope_almandine,     faceted('#d94a5a', '#4d0510')).
gem_visual(alexandrite,          split('#2f9e6e', '#b0305f')).
gem_visual(cats_eye,             cabochon('#f2d46b', '#8a6a07', cats_eye)).
gem_visual(cats_eye_chrysoberyl, cabochon('#f2d46b', '#8a6a07', cats_eye)).
gem_visual(moonstone,            cabochon('#ffffff', '#b9c4d6', glow)).
gem_visual(amethyst,             faceted('#c79cff', '#51208f')).
gem_visual(citrine,              faceted('#ffd76a', '#c26f00')).
gem_visual(aquamarine,           faceted('#c8f1ff', '#4a9fc2')).
gem_visual(blue_zircon,          faceted('#b5fbff', '#1b9fb0')).
gem_visual(blue_zircon_otl,      faceted('#b5fbff', '#1b9fb0')).
gem_visual(glass_imitation,      bubbles('#8fb0ff', '#1d3c9c')).
gem_visual(glass,                bubbles('#8fb0ff', '#1d3c9c')).
gem_visual(cubic_zirconia,       faceted('#ffffff', '#9aa7bd')).
gem_visual(unknown_red,          faceted('#e8707e', '#7e1426')).
% species defaults (used when no variety is identified)
gem_visual(corundum,             faceted('#6f9bff', '#0f2a8a')).
gem_visual(spinel,               faceted('#ff7a8a', '#a3122d')).
gem_visual(garnet,               faceted('#d94a5a', '#4d0510')).
gem_visual(chrysoberyl,          faceted('#e9e07a', '#7f7a10')).
gem_visual(zircon,               faceted('#f3f6ff', '#a4adc2')).
gem_visual(topaz,                faceted('#ffd199', '#c0701e')).
gem_visual(tourmaline,           faceted('#8ee0a4', '#1c6b3a')).
gem_visual(quartz,               faceted('#f5f7fb', '#b3bccd')).
gem_visual(feldspar,             cabochon('#ffffff', '#b9c4d6', glow)).
gem_visual(beryl,                faceted('#c8f1ff', '#4a9fc2')).

/* ------------------------------------------------------------------
   Picture for a key: real photo if one exists, otherwise SVG.
   gem_picture(+Key, +Label, -Html)   Html is an html_write term
   ------------------------------------------------------------------ */
:- prolog_load_context(directory, Dir),
   atom_concat(Dir, '/images', ImgDir),
   asserta(gem_image_dir(ImgDir)).

gem_picture(Key, Label, img([src(Src), alt(Label), class('gem-photo')])) :-
    gem_image_dir(Dir),
    member(Ext, [jpg, jpeg, png, webp]),
    format(atom(File), '~w/~w.~w', [Dir, Key, Ext]),
    exists_file(File), !,
    format(atom(Src), '/images/~w.~w', [Key, Ext]).
gem_picture(Key, Label, \[SVG]) :-
    gem_visual(Key, Shape), !,
    gem_svg(Key, Label, Shape, SVG).

% Picture for an identification result: first variety, species or imitation
result_picture(Html) :-
    (   fact(variety(K)) ; fact(imitation(K)) ; fact(species(K)) ),
    label(K, L),
    gem_picture(K, L, Html), !.

/* ------------------------------------------------------------------
   SVG drawing
   ------------------------------------------------------------------ */
outer_pts('30,8 70,8 92,30 92,70 70,92 30,92 8,70 8,30').
table_pts('38,24 62,24 76,38 76,62 62,76 38,76 24,62 24,38').

facet_lines('<g stroke="#fff" stroke-opacity=".35" stroke-width="1"><line x1="30" y1="8" x2="38" y2="24"/><line x1="70" y1="8" x2="62" y2="24"/><line x1="92" y1="30" x2="76" y2="38"/><line x1="92" y1="70" x2="76" y2="62"/><line x1="70" y1="92" x2="62" y2="76"/><line x1="30" y1="92" x2="38" y2="76"/><line x1="8" y1="70" x2="24" y2="62"/><line x1="8" y1="30" x2="24" y2="38"/><line x1="50" y1="8" x2="38" y2="24"/><line x1="50" y1="8" x2="62" y2="24"/><line x1="92" y1="50" x2="76" y2="38"/><line x1="92" y1="50" x2="76" y2="62"/><line x1="50" y1="92" x2="62" y2="76"/><line x1="50" y1="92" x2="38" y2="76"/><line x1="8" y1="50" x2="24" y2="62"/><line x1="8" y1="50" x2="24" y2="38"/></g>').

gem_svg(Key, Label, faceted(Light, Dark), SVG) :-
    radial_grad(Key, Light, Dark, Defs),
    faceted_body(Key, Dark, '', Body),
    svg_wrap(Label, Defs, Body, SVG).
gem_svg(Key, Label, bubbles(Light, Dark), SVG) :-
    radial_grad(Key, Light, Dark, Defs),
    Bubbles = '<g fill="#fff" fill-opacity=".18" stroke="#fff" stroke-opacity=".8" stroke-width="1"><circle cx="40" cy="58" r="4"/><circle cx="60" cy="44" r="2.5"/><circle cx="54" cy="66" r="2"/><circle cx="66" cy="60" r="3.2"/><circle cx="44" cy="40" r="1.8"/></g>',
    faceted_body(Key, Dark, Bubbles, Body),
    svg_wrap(Label, Defs, Body, SVG).
gem_svg(Key, Label, split(C1, C2), SVG) :-
    format(atom(Defs),
      '<linearGradient id="g_~w" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="~w"/><stop offset=".47" stop-color="~w"/><stop offset=".53" stop-color="~w"/><stop offset="1" stop-color="~w"/></linearGradient>',
      [Key, C1, C1, C2, C2]),
    faceted_body(Key, '#222', '', Body),
    svg_wrap(Label, Defs, Body, SVG).
gem_svg(Key, Label, cabochon(Light, Dark, Fx), SVG) :-
    radial_grad(Key, Light, Dark, Grad),
    cab_effect(Key, Fx, FxDefs, FxBody),
    atom_concat(Grad, FxDefs, Defs),
    format(atom(Body),
      '<ellipse cx="50" cy="52" rx="42" ry="36" fill="url(#g_~w)" stroke="~w" stroke-width="1.5"/>~w<ellipse cx="36" cy="36" rx="13" ry="7" fill="#fff" fill-opacity=".45" transform="rotate(-20 36 36)"/>',
      [Key, Dark, FxBody]),
    svg_wrap(Label, Defs, Body, SVG).

radial_grad(Key, Light, Dark, Defs) :-
    format(atom(Defs),
      '<radialGradient id="g_~w" cx="40%" cy="35%" r="75%"><stop offset="0" stop-color="~w"/><stop offset="1" stop-color="~w"/></radialGradient>',
      [Key, Light, Dark]).

faceted_body(Key, Stroke, Extra, Body) :-
    outer_pts(O), table_pts(T), facet_lines(F),
    format(atom(Body),
      '<polygon points="~w" fill="url(#g_~w)" stroke="~w" stroke-width="1.5"/><polygon points="~w" fill="#fff" fill-opacity=".12" stroke="#fff" stroke-opacity=".5"/>~w~w<polygon points="30,8 50,8 38,24 24,38 8,30" fill="#fff" fill-opacity=".28"/>',
      [O, Key, Stroke, T, F, Extra]).

cab_effect(_, none, '', '').
cab_effect(_, star, '',
    '<g stroke="#fff" stroke-opacity=".85" stroke-width="1.8" stroke-linecap="round"><line x1="50" y1="20" x2="50" y2="84"/><line x1="23" y1="36" x2="77" y2="68"/><line x1="23" y1="68" x2="77" y2="36"/></g>').
cab_effect(_, cats_eye, '',
    '<ellipse cx="50" cy="52" rx="3" ry="31" fill="#fff" fill-opacity=".85"/>').
cab_effect(Key, glow, Defs, Body) :-
    format(atom(Defs), '<filter id="f_~w"><feGaussianBlur stdDeviation="5"/></filter>', [Key]),
    format(atom(Body), '<ellipse cx="56" cy="46" rx="24" ry="15" fill="#8fbaff" fill-opacity=".75" filter="url(#f_~w)"/>', [Key]).

svg_wrap(Label, Defs, Body, SVG) :-
    format(atom(SVG),
      '<svg class="gem-svg" viewBox="0 0 100 100" role="img" aria-label="~w"><defs>~w</defs>~w</svg>',
      [Label, Defs, Body]).
