/*  knowledge_base.pl
    Gemstone Identification Assistant - KNOWLEDGE BASE

    This file holds ONLY domain knowledge (facts + production rules).
    It contains no inference code: the inference engine lives in engine.pl.
    Keeping the two apart is the classic expert-system architecture
    (knowledge base + inference engine + user interface).

    Representation
      * Facts   : gem/1, ri_range/3, sg_range/3, optic/2, hardness/2,
                  birefringence/2, colour/2, phenomenon/2, ...
      * Rules   : rule(Id, Conditions, Conclusion)
                  stored as DATA so the same rule base can be run by the
                  forward chainer AND the backward chainer, and every rule
                  has an Id that can be shown in explanations.
      * rule_info(Id, WhyText, SourceId) gives the justification and the
                  literature source of each rule (knowledge acquisition).

    Measurement ranges are refractometer / hydrostatic READING ranges taken
    from the sources below. engine.pl adds a small tolerance
    (RI +/-0.005, SG +/-0.03) to allow for measurement error.
*/

:- encoding(utf8).
:- discontiguous rule/3, rule_info/3.

/* ------------------------------------------------------------------
   Sources (reference list for the knowledge acquisition table)
   ------------------------------------------------------------------ */
source(gia,     'GIA Gem Encyclopedia, Gemological Institute of America (www.gia.edu)').
source(gemdat,  'Gemdat.org - gemstone property database').
source(webster, 'Webster, R. - Gems: Their Sources, Descriptions and Identification (Butterworth-Heinemann)').
source(read,    'Read, P. G. - Gemmology (Butterworth-Heinemann)').
source(matlins, 'Matlins, A. & Bonanno, A. C. - Gem Identification Made Easy (GemStone Press)').
source(igs,     'International Gem Society (www.gemsociety.org)').
source(ngja,    'National Gem and Jewellery Authority of Sri Lanka (www.ngja.gov.lk)').
source(design,  'Knowledge engineer design decision (derived from the above)').

/* ------------------------------------------------------------------
   FACTS - gem species known to the system
   ------------------------------------------------------------------ */
gem(corundum).
gem(spinel).
gem(garnet).
gem(chrysoberyl).
gem(zircon).
gem(topaz).
gem(tourmaline).
gem(quartz).
gem(feldspar).          % orthoclase feldspar (moonstone)
gem(beryl).

% Common imitation materials (not natural gems)
imitation_material(glass).
imitation_material(cubic_zirconia).

/* Refractive index reading range: ri_range(Gem, Min, Max) */
ri_range(corundum,       1.757, 1.780).
ri_range(spinel,         1.712, 1.736).
ri_range(garnet,         1.730, 1.890).
ri_range(chrysoberyl,    1.740, 1.760).
ri_range(zircon,         1.810, 1.990).
ri_range(topaz,          1.606, 1.644).
ri_range(tourmaline,     1.614, 1.666).
ri_range(quartz,         1.540, 1.558).
ri_range(feldspar,       1.515, 1.530).
ri_range(beryl,          1.564, 1.602).
ri_range(glass,          1.440, 1.770).
ri_range(cubic_zirconia, 2.150, 2.180).

/* Specific gravity range: sg_range(Gem, Min, Max) */
sg_range(corundum,       3.95, 4.10).
sg_range(spinel,         3.55, 3.70).
sg_range(garnet,         3.57, 4.30).
sg_range(chrysoberyl,    3.70, 3.78).
sg_range(zircon,         4.60, 4.80).
sg_range(topaz,          3.49, 3.57).
sg_range(tourmaline,     3.00, 3.26).
sg_range(quartz,         2.60, 2.70).
sg_range(feldspar,       2.55, 2.63).
sg_range(beryl,          2.63, 2.92).
sg_range(glass,          2.20, 4.50).
sg_range(cubic_zirconia, 5.60, 6.00).

/* Optic character: isotropic (singly refractive), uniaxial or biaxial */
optic(corundum,       uniaxial).
optic(spinel,         isotropic).
optic(garnet,         isotropic).
optic(chrysoberyl,    biaxial).
optic(zircon,         uniaxial).
optic(topaz,          biaxial).
optic(tourmaline,     uniaxial).
optic(quartz,         uniaxial).
optic(feldspar,       biaxial).
optic(beryl,          uniaxial).
optic(glass,          isotropic).
optic(cubic_zirconia, isotropic).

/* Mohs hardness (information only - hardness testing damages stones) */
hardness(corundum,       9).
hardness(spinel,         8).
hardness(garnet,         7).
hardness(chrysoberyl,    8.5).
hardness(zircon,         7.5).
hardness(topaz,          8).
hardness(tourmaline,     7.5).
hardness(quartz,         7).
hardness(feldspar,       6).
hardness(beryl,          7.5).
hardness(glass,          5.5).
hardness(cubic_zirconia, 8.5).

/* Birefringence (information only; 0.0 = singly refractive) */
birefringence(corundum,    0.008).
birefringence(spinel,      0.0).
birefringence(garnet,      0.0).
birefringence(chrysoberyl, 0.009).
birefringence(zircon,      0.059).
birefringence(topaz,       0.009).
birefringence(tourmaline,  0.018).
birefringence(quartz,      0.009).
birefringence(feldspar,    0.006).
birefringence(beryl,       0.006).

/* Possible body colours: colour(Gem, Colour) */
colour(corundum, red).        colour(corundum, pink).
colour(corundum, orange).     colour(corundum, yellow).
colour(corundum, green).      colour(corundum, blue).
colour(corundum, purple).     colour(corundum, colourless).
colour(spinel, red).          colour(spinel, pink).
colour(spinel, orange).       colour(spinel, purple).
colour(spinel, blue).
colour(garnet, red).          colour(garnet, orange).
colour(garnet, brown).        colour(garnet, green).
colour(garnet, purple).
colour(chrysoberyl, yellow).  colour(chrysoberyl, green).
colour(chrysoberyl, brown).
colour(zircon, colourless).   colour(zircon, blue).
colour(zircon, yellow).       colour(zircon, brown).
colour(zircon, green).        colour(zircon, red).
colour(zircon, orange).
colour(topaz, colourless).    colour(topaz, blue).
colour(topaz, yellow).        colour(topaz, orange).
colour(topaz, pink).          colour(topaz, brown).
colour(tourmaline, pink).     colour(tourmaline, red).
colour(tourmaline, green).    colour(tourmaline, blue).
colour(tourmaline, yellow).   colour(tourmaline, brown).
colour(tourmaline, black).
colour(quartz, colourless).   colour(quartz, purple).
colour(quartz, yellow).       colour(quartz, brown).
colour(quartz, pink).
colour(feldspar, colourless). colour(feldspar, white).
colour(beryl, blue).          colour(beryl, green).
colour(beryl, yellow).        colour(beryl, pink).
colour(beryl, colourless).

/* Optical phenomena a species can show: phenomenon(Gem, P) */
phenomenon(corundum,    star).
phenomenon(corundum,    colour_change).
phenomenon(spinel,      star).
phenomenon(garnet,      star).
phenomenon(garnet,      colour_change).
phenomenon(chrysoberyl, cats_eye).
phenomenon(chrysoberyl, colour_change).
phenomenon(tourmaline,  cats_eye).
phenomenon(quartz,      cats_eye).
phenomenon(quartz,      star).
phenomenon(beryl,       cats_eye).
phenomenon(feldspar,    adularescence).

/* Colours most commonly seen in the trade for each species (evidence rule r19) */
typical_colour(corundum,    blue).       typical_colour(corundum,    red).
typical_colour(corundum,    pink).       typical_colour(corundum,    yellow).
typical_colour(spinel,      red).        typical_colour(spinel,      pink).
typical_colour(garnet,      red).        typical_colour(garnet,      orange).
typical_colour(chrysoberyl, yellow).     typical_colour(chrysoberyl, green).
typical_colour(zircon,      colourless). typical_colour(zircon,      blue).
typical_colour(topaz,       blue).       typical_colour(topaz,       yellow).
typical_colour(tourmaline,  pink).       typical_colour(tourmaline,  green).
typical_colour(quartz,      purple).     typical_colour(quartz,      colourless).
typical_colour(feldspar,    colourless). typical_colour(feldspar,    white).
typical_colour(beryl,       blue).       typical_colour(beryl,       green).

/* Inclusion types the user can report (value, description) */
inclusion_type(none,              'None visible (clean under 10x loupe)').
inclusion_type(silk,              'Silk (fine needle-like rutile)').
inclusion_type(crystals,          'Mineral crystals').
inclusion_type(fingerprints,      'Fingerprints / healed fractures').
inclusion_type(gas_bubbles,       'Round gas bubbles').
inclusion_type(curved_lines,      'Curved growth lines (striae)').
inclusion_type(swirl_marks,       'Swirl marks (flow lines)').
inclusion_type(discoid_fractures, 'Discoid fractures (halo around crystal)').

/* Human-readable texts for advice conclusions */
advice_text(get_certificate,
    'Features are consistent with a natural stone. Obtain an NGJA (National Gem and Jewellery Authority) or other accredited laboratory certificate before purchase.').
advice_text(synthetic_price,
    'The stone shows features of a laboratory-grown (synthetic) gem. It is real gem material, but its price should be a small fraction of a natural stone.').
advice_text(imitation_value,
    'This is an imitation, not a natural gemstone. It has little gem value - do not pay gemstone prices.').
advice_text(lab_test_bubbles,
    'Gas bubbles point to glass or a synthetic. Do not buy it as natural; have it tested at a gem laboratory.').
advice_text(lab_test_clean,
    'A completely clean corundum is unusual and synthetics are often clean. Ask for a laboratory test before paying natural prices.').
advice_text(check_inclusions,
    'Examine the stone with a 10x loupe for inclusions to help decide natural versus synthetic.').
advice_text(disclose_heat,
    'Discoid fractures suggest heat treatment. Heated stones are common and acceptable but must be disclosed and are valued lower than unheated stones.').
advice_text(check_colour_change,
    'Confirm the colour change under daylight and incandescent light. Alexandrite is high value, so certification is strongly advised.').
advice_text(padparadscha_cert,
    'Padparadscha is a trade name for a narrow pinkish-orange colour range; only a gem laboratory can certify the name.').
advice_text(measure_more,
    'Measurements are incomplete. Measure the missing properties (RI with a refractometer, SG by hydrostatic weighing, optic character with a polariscope) to confirm.').
advice_text(re_measure,
    'The measurements fit more than one species. Re-measure RI and SG carefully, or check birefringence and absorption spectrum.').
advice_text(no_match,
    'No gem in the knowledge base matches. Re-check the measurements; the stone may be outside the scope of this system or an imitation. Seek a laboratory test.').

/* ==================================================================
   PRODUCTION RULES   rule(Id, [Condition, ...], Conclusion)
   All conditions must hold (logical AND). not(C) = negation as failure.
   Conditions evaluated by the engine (tests):
     optic(T), ri_in(G), sg_in(G), missing(Property), partial_data,
     gem_type(G), optic_ok(G), ri_ok(G), sg_ok(G), colour_ok(G),
     phenomenon_ok(G), ambiguous_species, not(C)
   User-input facts: observed_colour(C), phenomenon(P), inclusion(I)
   Rules are listed in layers; each layer builds on the conclusions of
   the one before it (rule chaining).
   ================================================================== */

/* ---- Layer 1: species identification (full data) ---------------- */
rule(r1,  [optic(uniaxial),  ri_in(corundum),    sg_in(corundum)],    species(corundum)).
rule(r2,  [optic(isotropic), ri_in(spinel),      sg_in(spinel)],      species(spinel)).
rule(r3,  [optic(isotropic), ri_in(garnet),      sg_in(garnet)],      species(garnet)).
rule(r4,  [optic(biaxial),   ri_in(chrysoberyl), sg_in(chrysoberyl)], species(chrysoberyl)).
rule(r5,  [optic(uniaxial),  ri_in(zircon),      sg_in(zircon)],      species(zircon)).
rule(r6,  [optic(biaxial),   ri_in(topaz),       sg_in(topaz)],       species(topaz)).
rule(r7,  [optic(uniaxial),  ri_in(tourmaline),  sg_in(tourmaline)],  species(tourmaline)).
rule(r8,  [optic(uniaxial),  ri_in(quartz),      sg_in(quartz)],      species(quartz)).
rule(r9,  [optic(biaxial),   ri_in(feldspar),    sg_in(feldspar)],    species(feldspar)).
rule(r10, [optic(uniaxial),  ri_in(beryl),       sg_in(beryl)],       species(beryl)).

rule_info(r1,  'Corundum is doubly refractive (uniaxial) with RI about 1.762-1.770 and SG about 4.00.', gia).
rule_info(r2,  'Spinel is singly refractive (isotropic) with RI about 1.718 and SG about 3.60.', webster).
rule_info(r3,  'Garnets are singly refractive with RI 1.73-1.89 and SG 3.6-4.3 depending on the type.', webster).
rule_info(r4,  'Chrysoberyl is biaxial with RI about 1.746-1.755 and SG about 3.73.', gia).
rule_info(r5,  'High zircon is uniaxial with very high RI (often over the refractometer limit) and SG about 4.7.', gemdat).
rule_info(r6,  'Topaz is biaxial with RI about 1.61-1.64 and SG about 3.53.', gia).
rule_info(r7,  'Tourmaline is uniaxial with RI about 1.62-1.64 and SG about 3.06.', gia).
rule_info(r8,  'Quartz is uniaxial with RI 1.544-1.553 and SG 2.65.', read).
rule_info(r9,  'Orthoclase feldspar (moonstone) is biaxial with RI about 1.52 and SG about 2.57.', read).
rule_info(r10, 'Beryl is uniaxial with RI about 1.57-1.60 and SG about 2.7.', gemdat).

/* ---- Layer 1b: imitations ---------------------------------------- */
rule(r11, [optic(isotropic), ri_in(glass), inclusion(gas_bubbles), not(species(_))], imitation(glass)).
rule(r12, [inclusion(swirl_marks), not(species(_))],                                 imitation(glass)).
rule(r13, [optic(isotropic), sg_in(cubic_zirconia)],                                 imitation(cubic_zirconia)).

rule_info(r11, 'A singly refractive stone with a glass RI and round gas bubbles, matching no gem species, is glass.', igs).
rule_info(r12, 'Swirl marks (flow lines) are typical of moulded glass.', matlins).
rule_info(r13, 'Cubic zirconia is isotropic with an SG of 5.6-6.0, far heavier than any natural gem in scope.', gia).

/* ---- Layer 1c: partial match when data is missing ---------------- */
rule(r14, [partial_data, not(species(_)), not(imitation(_)), gem_type(G),
           optic_ok(G), ri_ok(G), sg_ok(G), colour_ok(G), phenomenon_ok(G)],
          candidate(G)).

rule_info(r14, 'When RI, SG or optic character is missing, every gem consistent with ALL the supplied properties remains a candidate.', design).

/* Evidence rules: each supplied property that positively matches a
   candidate adds certainty to it (combined MYCIN-style), so incomplete
   data produces a RANKED list of candidates instead of a flat list. */
rule(r15, [candidate(G), not(missing(optic)), optic_ok(G)],                  candidate(G)).
rule(r16, [candidate(G), not(missing(ri)), ri_ok(G)],                        candidate(G)).
rule(r17, [candidate(G), not(missing(sg)), sg_ok(G)],                        candidate(G)).
rule(r18, [candidate(G), not(missing(phenomenon)), not(phenomenon(none)), phenomenon_ok(G)], candidate(G)).
rule(r19, [candidate(G), typical_colour_ok(G)],                              candidate(G)).

rule_info(r15, 'A matching optic character is moderate evidence for a candidate.', design).
rule_info(r16, 'A matching refractive index is the strongest single test in gemmology.', read).
rule_info(r17, 'A matching specific gravity is good supporting evidence.', read).
rule_info(r18, 'An optical effect the species is known for is good evidence.', gia).
rule_info(r19, 'A colour that is typical for the species is weak supporting evidence.', matlins).

/* ---- Layer 2: variety -------------------------------------------- */
rule(r21, [species(corundum), observed_colour(red), not(phenomenon(star))],      variety(ruby)).
rule(r22, [species(corundum), observed_colour(red), phenomenon(star)],           variety(star_ruby)).
rule(r23, [species(corundum), phenomenon(star), not(observed_colour(red))],      variety(star_sapphire)).
rule(r24, [species(corundum), observed_colour(blue),   not(phenomenon(star))],   variety(blue_sapphire)).
rule(r25, [species(corundum), observed_colour(pink),   not(phenomenon(star))],   variety(pink_sapphire)).
rule(r26, [species(corundum), observed_colour(orange), not(phenomenon(star))],   variety(padparadscha)).
rule(r27, [species(corundum), observed_colour(yellow), not(phenomenon(star))],   variety(yellow_sapphire)).
rule(r28, [species(corundum), observed_colour(colourless), not(phenomenon(star))], variety(white_sapphire)).
rule(r29, [species(chrysoberyl), phenomenon(colour_change)],                     variety(alexandrite)).
rule(r30, [species(chrysoberyl), phenomenon(cats_eye)],                          variety(cats_eye_chrysoberyl)).
rule(r31, [species(feldspar), phenomenon(adularescence)],                        variety(moonstone)).
rule(r32, [species(quartz), observed_colour(purple)],                            variety(amethyst)).
rule(r33, [species(quartz), observed_colour(yellow)],                            variety(citrine)).
rule(r34, [species(garnet), observed_colour(orange)],                            variety(hessonite)).
rule(r35, [species(garnet), observed_colour(red)],                               variety(pyrope_almandine)).
rule(r36, [species(beryl), observed_colour(blue)],                               variety(aquamarine)).
rule(r37, [species(spinel), observed_colour(red)],                               variety(red_spinel)).
rule(r38, [species(zircon), observed_colour(blue)],                              variety(blue_zircon)).

rule_info(r21, 'Red corundum is called ruby.', gia).
rule_info(r22, 'Red corundum showing asterism (a star) is star ruby.', gia).
rule_info(r23, 'Non-red corundum showing asterism is star sapphire.', gia).
rule_info(r24, 'Blue corundum is blue sapphire.', gia).
rule_info(r25, 'Pink corundum (lighter than ruby) is sold as pink sapphire.', gia).
rule_info(r26, 'Pinkish-orange to orange corundum from Sri Lanka is traded as padparadscha.', gia).
rule_info(r27, 'Yellow corundum is yellow sapphire.', gia).
rule_info(r28, 'Colourless corundum is white sapphire.', gia).
rule_info(r29, 'Chrysoberyl that changes colour between daylight and incandescent light is alexandrite.', gia).
rule_info(r30, 'Chrysoberyl showing chatoyancy is cat''s-eye chrysoberyl (cymophane).', gia).
rule_info(r31, 'Orthoclase feldspar showing adularescence is moonstone.', gia).
rule_info(r32, 'Purple quartz is amethyst.', gia).
rule_info(r33, 'Yellow quartz is citrine.', gia).
rule_info(r34, 'Orange to brownish-orange garnet is hessonite (grossular).', gia).
rule_info(r35, 'Red garnet is usually of the pyrope-almandine series.', webster).
rule_info(r36, 'Blue beryl is aquamarine.', gia).
rule_info(r37, 'Red spinel is a valued variety often confused with ruby.', gia).
rule_info(r38, 'Blue zircon is almost always produced by heating brown zircon.', gia).

/* ---- Layer 3: origin (natural / synthetic / imitation) ----------- */
rule(r41, [species(corundum), inclusion(curved_lines)],              origin(synthetic)).
rule(r42, [species(corundum), inclusion(gas_bubbles)],               origin(synthetic)).
rule(r43, [species(spinel), inclusion(gas_bubbles)],                 origin(synthetic)).
rule(r44, [inclusion(gas_bubbles), not(species(_)), not(imitation(_))], origin(glass_or_synthetic)).
rule(r45, [imitation(_)],                                            origin(imitation)).
rule(r46, [species(corundum), inclusion(silk)],                      origin(likely_natural)).
rule(r47, [species(_), inclusion(crystals)],                         origin(likely_natural)).
rule(r48, [species(_), inclusion(fingerprints)],                     origin(likely_natural)).
rule(r49, [species(corundum), inclusion(discoid_fractures)],         treatment(likely_heated)).
rule(r50, [treatment(likely_heated)],                                origin(likely_natural)).
rule(r51, [species(corundum), inclusion(none)],                      origin(needs_lab_test)).
rule(r52, [species(_), missing(inclusion)],                          origin(undetermined)).
rule(r53, [species(_), inclusion(none), not(species(corundum))],     origin(undetermined)).

rule_info(r41, 'Curved growth lines (striae) are diagnostic of flame-fusion (Verneuil) synthetic corundum; natural corundum grows in straight lines.', gia).
rule_info(r42, 'Round gas bubbles in corundum indicate a flame-fusion synthetic.', gia).
rule_info(r43, 'Gas bubbles in spinel indicate flame-fusion synthetic spinel.', webster).
rule_info(r44, 'Round gas bubbles in an unidentified stone indicate glass or a synthetic.', igs).
rule_info(r45, 'An identified imitation material is not a natural gemstone.', design).
rule_info(r46, 'Rutile silk is a natural inclusion in corundum.', gia).
rule_info(r47, 'Included mineral crystals are a typical sign of natural growth.', matlins).
rule_info(r48, 'Fingerprints (healed fractures) are usually natural, although flux synthetics can show similar features.', matlins).
rule_info(r49, 'Discoid fractures around crystals form when corundum is heated.', gia).
rule_info(r50, 'Heat treatment is applied to natural stones, so a heated stone is natural (but treated).', gia).
rule_info(r51, 'Natural corundum is rarely inclusion-free; a clean stone needs a lab test to rule out a synthetic.', igs).
rule_info(r52, 'Without inclusion evidence the origin cannot be decided.', design).
rule_info(r53, 'A clean stone of this species gives no origin evidence at loupe level.', design).

/* ---- Layer 4: recommendations ------------------------------------ */
rule(r61, [origin(likely_natural)],     advice(get_certificate)).
rule(r62, [origin(synthetic)],          advice(synthetic_price)).
rule(r63, [origin(imitation)],          advice(imitation_value)).
rule(r64, [origin(glass_or_synthetic)], advice(lab_test_bubbles)).
rule(r65, [origin(needs_lab_test)],     advice(lab_test_clean)).
rule(r66, [origin(undetermined)],       advice(check_inclusions)).
rule(r67, [treatment(likely_heated)],   advice(disclose_heat)).
rule(r68, [variety(alexandrite)],       advice(check_colour_change)).
rule(r69, [variety(padparadscha)],      advice(padparadscha_cert)).
rule(r70, [candidate(_)],               advice(measure_more)).
rule(r71, [ambiguous_species],          advice(re_measure)).
rule(r72, [not(species(_)), not(candidate(_)), not(imitation(_))], advice(no_match)).

rule_info(r61, 'Natural stones should be certified before purchase; NGJA offers testing in Sri Lanka.', ngja).
rule_info(r62, 'Synthetic gems are far cheaper than natural ones and must be sold as synthetic.', igs).
rule_info(r63, 'Imitations have little gem value.', igs).
rule_info(r64, 'Stones showing gas bubbles need laboratory confirmation.', igs).
rule_info(r65, 'Clean corundum requires advanced laboratory tests to prove natural origin.', gia).
rule_info(r66, 'Inclusions seen with a 10x loupe are the main field test for origin.', matlins).
rule_info(r67, 'Treatments must be disclosed to the buyer.', ngja).
rule_info(r68, 'Alexandrite is identified by its daylight/incandescent colour change.', gia).
rule_info(r69, 'The padparadscha name is reserved for a specific colour range.', gia).
rule_info(r70, 'Additional measurements are needed to narrow down the candidates.', design).
rule_info(r71, 'Overlapping readings must be resolved by more precise measurement.', design).
rule_info(r72, 'When no rule identifies the stone, the system must not guess.', design).

/* ==================================================================
   CERTAINTY FACTORS   rule_cf(RuleId, CF)   0.0 (no belief) - 1.0 (certain)
   How strongly the expert believes a rule's conclusion when all its
   conditions hold (MYCIN-style). Rules not listed have CF 1.0.
   Justification: species ranges overlap slightly between gems, colour
   names are subjective, and several inclusion types can occur in both
   natural and synthetic stones, so those rules are given lower CFs.
   ================================================================== */
% Species: three independent measurements agree, but ranges can overlap
rule_cf(r1, 0.95).  rule_cf(r2, 0.90).  rule_cf(r3, 0.90).  rule_cf(r4, 0.95).
rule_cf(r5, 0.90).  rule_cf(r6, 0.95).  rule_cf(r7, 0.90).  rule_cf(r8, 0.90).
rule_cf(r9, 0.90).  rule_cf(r10, 0.90).
% Imitations
rule_cf(r11, 0.85). rule_cf(r12, 0.80). rule_cf(r13, 0.95).
% Partial matches: a base belief plus weighted evidence
rule_cf(r14, 0.20). rule_cf(r15, 0.30). rule_cf(r16, 0.50). rule_cf(r17, 0.40).
rule_cf(r18, 0.40). rule_cf(r19, 0.15).
% Varieties: colour names are judged by eye
rule_cf(r21, 0.95). rule_cf(r22, 0.95). rule_cf(r23, 0.95). rule_cf(r24, 0.95).
rule_cf(r25, 0.85). rule_cf(r26, 0.70). rule_cf(r27, 0.90). rule_cf(r28, 0.90).
rule_cf(r29, 0.90). rule_cf(r30, 0.95). rule_cf(r31, 0.95). rule_cf(r32, 0.95).
rule_cf(r33, 0.90). rule_cf(r34, 0.85). rule_cf(r35, 0.80). rule_cf(r36, 0.90).
rule_cf(r37, 0.90). rule_cf(r38, 0.85).
% Origin: some inclusions occur in both natural and synthetic stones
rule_cf(r41, 0.95). rule_cf(r42, 0.90). rule_cf(r43, 0.85). rule_cf(r44, 0.70).
rule_cf(r45, 1.00). rule_cf(r46, 0.80). rule_cf(r47, 0.70). rule_cf(r48, 0.60).
rule_cf(r49, 0.80). rule_cf(r50, 0.90). rule_cf(r51, 0.60). rule_cf(r52, 1.00).
rule_cf(r53, 1.00).
