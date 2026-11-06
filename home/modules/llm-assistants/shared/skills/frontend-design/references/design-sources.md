# Design Sources

This file holds the full rule set behind [SKILL.md](../SKILL.md), including rules SKILL.md does not condense, with each rule's source, strength, and any disagreement between sources. The project conventions and the user-stated rules without a public source live only in SKILL.md. A rule's strength is one of:

| Strength        | Meaning                                                                |
| --------------- | ---------------------------------------------------------------------- |
| WCAG A, AA, AAA | A normative success criterion.                                         |
| Multi-system    | At least two of Apple, Material, Carbon, and GOV.UK agree.             |
| Research        | An NN/g study or review.                                               |
| System          | One design system's rule.                                              |
| Platform        | A W3C Community Group report or a browser vendor's published guidance. |
| Practitioner    | A respected book or author, without the force of a standard.           |

A rule with several sources takes the strength of its strongest one.

## Contents

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [Foundations](#foundations)
  - [Design tokens](#design-tokens)
  - [Spacing scale](#spacing-scale)
  - [Type scale](#type-scale)
  - [Interaction states](#interaction-states)
- [Layout and spacing](#layout-and-spacing)
  - [Visual hierarchy](#visual-hierarchy)
  - [Grouping and separation](#grouping-and-separation)
  - [Key lines](#key-lines)
  - [Text alignment](#text-alignment)
  - [Small screens first](#small-screens-first)
  - [Reflow and zoom](#reflow-and-zoom)
  - [Images and loading](#images-and-loading)
- [Typography](#typography)
  - [Typefaces](#typefaces)
  - [Measure](#measure)
  - [Leading](#leading)
  - [Text spacing overrides](#text-spacing-overrides)
  - [Case](#case)
- [Color](#color)
  - [Color roles](#color-roles)
  - [Dark mode default](#dark-mode-default)
  - [Text contrast](#text-contrast)
  - [Non-text contrast](#non-text-contrast)
  - [Color is never the only cue](#color-is-never-the-only-cue)
  - [Text on colored backgrounds](#text-on-colored-backgrounds)
- [Data display](#data-display)
  - [Tables](#tables)
  - [Numeric columns](#numeric-columns)
  - [Chart type](#chart-type)
  - [Data-ink](#data-ink)
  - [Proportional encoding](#proportional-encoding)
  - [Direct labels](#direct-labels)
  - [Categorical colors](#categorical-colors)
- [Forms and feedback](#forms-and-feedback)
  - [Form layout](#form-layout)
  - [Labels](#labels)
  - [Validation](#validation)
  - [Error messages](#error-messages)
  - [Primary button](#primary-button)
  - [Action wording](#action-wording)
  - [Loading feedback](#loading-feedback)
  - [Empty states](#empty-states)
- [Accessibility](#accessibility)
  - [Keyboard operation](#keyboard-operation)
  - [Focus](#focus)
  - [Target size](#target-size)
  - [Dragging alternatives](#dragging-alternatives)
  - [Headings and widget patterns](#headings-and-widget-patterns)
  - [Text alternatives](#text-alternatives)
- [Motion](#motion)
  - [Durations](#durations)
  - [Purpose](#purpose)
  - [User control](#user-control)
- [Slides and diagrams](#slides-and-diagrams)
  - [One idea per slide](#one-idea-per-slide)
  - [Story structure](#story-structure)
  - [Diagram hierarchy and labels](#diagram-hierarchy-and-labels)
- [Choosing the sources](#choosing-the-sources)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Foundations

### Design tokens

- **Rule:** Define tokens for color, type, space, radius, and shadow, and reference tokens at call sites. Choose a small set of colors, two weights, and a few sizes before building.
- **Why:** tokens are the single source of truth across design tools and code, and they make theming possible. Fewer choices produce consistency without policing every screen.
- **Source:** [DTCG format 2025.10][dtcg-format], [Carbon color tokens][carbon-color], [Refactoring UI, limit your choices][refactoring-ui].
- **Strength:** Platform.

### Spacing scale

- **Rule:** Use one spacing scale. Carbon builds on multiples of 2, 4, and 8 from an 8px mini unit, GOV.UK uses a 5px-based scale from 0 to 60px, and Material uses 4dp and 8dp. Pick one and stay on it, and keep GOV.UK's 5px spacing and Carbon's 8px grid in separate artifacts.
- **Why:** arbitrary margins destroy rhythm and make small changes expensive, and the bases disagree, so the shared rule is consistency.
- **Source:** [Carbon spacing][carbon-spacing], [GOV.UK spacing][govuk-spacing].
- **Strength:** Multi-system.

### Type scale

- **Rule:** Use a small fixed type scale and map every size to a role. GOV.UK runs 16 to 80px in named steps, Carbon runs 12 to 92px from a single equation, and Material 3 has 15 baseline roles plus 15 emphasized roles. Set body text at the scale's body role. GOV.UK uses 19px with 25px leading, Carbon's dense product scale starts at 14px, and WCAG sets no minimum font size. Keep the type scale and body size from the same system as the spacing scale.
- **Why:** ad hoc sizes create inconsistent hierarchy. Small body text is the first thing to fail under zoom, low vision, and projection.
- **Source:** [GOV.UK type scale][govuk-type-scale], [Carbon typography][carbon-typography], [Material 3 type scale][material-type-scale].
- **Strength:** Multi-system.

### Interaction states

- **Rule:** Define every interaction state. Cover enabled, hover, focus, pressed, and disabled. Material's state layers use 8% hover, 10% focus, 10% pressed, and 16% drag opacity.
- **Why:** undefined states get invented per component.
- **Source:** [Material 3 states][material-states].
- **Strength:** System.

## Layout and spacing

### Visual hierarchy

- **Rule:** Give each view one dominant element. Rank everything else as secondary or tertiary, and make the focal point obvious at a glance. Build hierarchy with size, weight, and color together, and use two or three text colors and about two weights for UI hierarchy.
- **Why:** attention is scarce, and a flat field gives the eye no entry point. Size alone produces a flat, crowded hierarchy.
- **Source:** [Duarte, slide design][duarte-slide-design], [Refactoring UI][refactoring-ui], [Refactoring UI, 7 practical tips][refactoring-ui-tips].
- **Strength:** Practitioner.

### Grouping and separation

- **Rule:** Use proximity to encode grouping, and give important elements more surrounding space. Separate with space, background, or shadow before adding a border.
- **Why:** nearness reads as relationship, and extra space reads as importance.
- **Source:** [Carbon spacing][carbon-spacing], [Refactoring UI][refactoring-ui].
- **Strength:** System.

### Key lines

- **Rule:** Align to a grid and to shared key lines. Place type against the padding edge, and keep text out of the padding.
- **Why:** alignment removes visual noise and makes scanning easier.
- **Source:** [Carbon 2x grid][carbon-2x-grid].
- **Strength:** System.

### Text alignment

- **Rule:** Left-align body copy and center only short headings. Do not center whole text blocks, and do not justify body text in the browser without hyphenation.
- **Why:** centered and justified blocks have ragged or uneven edges that slow reading and break alignment with other elements.
- **Source:** [Butterick, centered text][butterick-centered-text], [Butterick, justified text][butterick-justified-text].
- **Strength:** Practitioner.

### Small screens first

- **Rule:** Design small-screen first, starting with a single column.
- **Why:** the constrained layout exposes the real content order, and enhancement is easier than reduction.
- **Source:** [GOV.UK layout][govuk-layout], [web.dev, responsive basics][webdev-responsive].
- **Strength:** System.

### Reflow and zoom

- **Rule:** Support 200% text resize, and reflow at 320 CSS px (400% zoom) without two-dimensional scrolling, except for parts that need two-dimensional layout such as data tables, maps, and diagrams. Set the viewport meta tag to `width=device-width, initial-scale=1`, and do not block zoom. Avoid `maximum-scale` and `user-scalable=no`.
- **Why:** zooming must not force horizontal back-and-forth reading. Without the viewport tag, mobile browsers render a desktop width and shrink it.
- **Source:** [WCAG 1.4.4][wcag-144], [1.4.10][wcag-1410], [web.dev, responsive basics][webdev-responsive].
- **Strength:** WCAG AA.

### Images and loading

- **Rule:** Give images `max-width: 100%` and explicit `width` and `height`. Meet Core Web Vitals at the 75th percentile: LCP at or under 2.5s, INP at or under 200ms, and CLS at or under 0.1.
- **Why:** oversized images cause horizontal scrolling, missing dimensions cause layout shift, and these metrics measure loading, interactivity, and visual stability as users experience them.
- **Source:** [web.dev, responsive basics][webdev-responsive], [web.dev, Web Vitals][webdev-vitals].
- **Strength:** Platform.

## Typography

### Typefaces

- **Rule:** Use at most two typefaces, each with a fixed role. Decorative faces go in headers or illustrations, and body copy stays in a text face.
- **Why:** more faces compete and muddy the hierarchy.
- **Source:** [Butterick, mixing fonts][butterick-mixing-fonts], [NN/g, pairing typefaces][nng-pairing-typefaces].
- **Strength:** Practitioner.
- **Disagreement:** Butterick says any two identifiably different fonts can mix, including two serifs, and that mixing is never required. Common web advice pairs serif with sans and avoids similar classifications. NN/g favors a single family with multiple weights.

### Measure

- **Rule:** Fill the available width up to 90 characters.
- **Why:** long lines make the eye travel far and lose its place, while a narrow column wastes the available width.
- **Source:** [Butterick, line length][butterick-line-length], [Every Layout, axioms][every-layout-axioms].
- **Strength:** Practitioner.
- **Disagreement:** 45 to 75 characters (Every Layout, citing _The Elements of Typographic Style_) versus 45 to 90 (Butterick). GOV.UK says no more than 75.

### Leading

- **Rule:** Set body leading around 1.3 to 1.5, and never below 1.2. Butterick gives 120 to 145% of point size, GOV.UK body is 19px with 25px leading at about 1.32, and WCAG's override test requires the layout to survive 1.5.
- **Why:** tight leading merges lines and makes tracking hard.
- **Source:** [Butterick, line spacing][butterick-line-spacing], [WCAG 1.4.12][wcag-1412].
- **Strength:** Practitioner.

### Text spacing overrides

- **Rule:** Do not break when users override text spacing. The layout must survive 1.5 line-height, 2em paragraph spacing, 0.12em letter spacing, and 0.16em word spacing.
- **Why:** users with dyslexia or low vision may apply these overrides.
- **Source:** [WCAG 1.4.12][wcag-1412].
- **Strength:** WCAG AA.

### Case

- **Rule:** Use sentence case for body text, headings, and most UI labels. All caps is acceptable for short labels, captions, and overlines, provided the text is tracked and kerned and the label is genuinely short. Do not use caps for paragraphs or multi-line headings, and avoid all-lowercase headings and titles, which are less scannable than mixed case. Apply caps with `text-transform: uppercase` so the underlying text keeps its case and screen readers announce the original word.
- **Why:** capitals homogenize word shapes and slow reading at body sizes, so they need extra tracking to stay legible.
- **Source:** [Butterick, all caps][butterick-all-caps], [NN/g, 113 guidelines][nng-113-guidelines], [NN/g, glanceable fonts][nng-glanceable-fonts], [Stanford UIT][stanford-uit-all-caps].
- **Strength:** Research.
- **Disagreement:** NN/g's general guidance says use sparingly or not at all, while its glanceable-reading study says uppercase can be faster for isolated short words.

## Color

### Color roles

- **Rule:** Use role-based color tokens, and build light and dark themes from the same role set. Map `primary`, `on-primary`, `surface`, `container`, and `outline` to components, and keep raw hex values at the token definition. In dark themes, each added layer gets lighter, as Carbon's near-black surfaces do with Gray 100 at `#161616`.
- **Why:** roles keep light and dark themes, and contrast pairs, coherent.
- **Source:** [Material 3 color roles][material-color-roles], [Carbon color][carbon-color].
- **Strength:** Multi-system.

### Dark mode default

- **Rule:** Offer dark mode, follow the OS setting, and keep light mode the default for a general audience. NN/g found light mode tends to produce better visual performance for normal-vision users, while some low-vision users benefit from dark.
- **Why:** the evidence favors light mode by default, and user choice covers the exceptions.
- **Source:** [NN/g, dark mode][nng-dark-mode].
- **Strength:** Research.

### Text contrast

- **Rule:** Set text contrast at least 4.5:1, and large text at least 3:1. Large means 18pt (about 24px) or 14pt bold (about 18.5px). Do not round a computed 4.499:1 up to a pass.
- **Why:** low-contrast text is unreadable for people with low vision or impaired contrast perception.
- **Source:** [WCAG 1.4.3][wcag-143].
- **Strength:** WCAG AA.
- **Disagreement:** Datawrapper gives minimum ratios of 2.5:1 for large text and 4:1 for small text, while WCAG 1.4.3 requires 4.5:1 for normal text and 3:1 for large text. Follow WCAG.

### Non-text contrast

- **Rule:** Keep UI component boundaries, states, meaningful graphics, and focus indicators at least 3:1 against adjacent colors.
- **Why:** otherwise the control or its state disappears for low-vision users.
- **Source:** [WCAG 1.4.11][wcag-1411].
- **Strength:** WCAG AA.

### Color is never the only cue

- **Rule:** Never use color as the only cue. Add text, an icon, a shape, or a pattern.
- **Why:** color blindness and monochrome displays remove the meaning.
- **Source:** [WCAG 1.4.1][wcag-141].
- **Strength:** WCAG A.

### Text on colored backgrounds

- **Rule:** Secondary text on a colored background uses white at reduced opacity, or a color of the background's hue, and stays within [Text contrast](#text-contrast).
- **Why:** grey on a colored background looks washed out, while a color of the background's hue lowers the text's emphasis and keeps it vivid.
- **Source:** [Refactoring UI][refactoring-ui-tips].
- **Strength:** Practitioner.

## Data display

### Tables

- **Rule:** Use a table when the task is comparing values across rows and columns. Put a human-readable identifier in the first column, so each row is recognizable. Never show an auto-generated ID there.
- **Why:** tables scale and support comparison better than cards.
- **Source:** [NN/g, data tables][nng-data-tables].
- **Strength:** Research.

### Numeric columns

- **Rule:** Right-align numeric columns, use tabular figures through `font-variant-numeric: tabular-nums lining-nums` so digits share a width, and put units in the header. Give the table a caption and use scoped headers.
- **Why:** aligned digits make columns comparable, and captions and scopes make tables navigable.
- **Source:** [Butterick, grids of numbers][butterick-grids-of-numbers], [Butterick, alternate figures][butterick-alternate-figures], [GOV.UK table][govuk-table], [Web Typography, numerals and tables][web-typography-numerals].
- **Strength:** System.

### Chart type

- **Rule:** Choose the chart from the message. Line for change over time, bar for comparison and shares, scatter for correlation, and histogram for distribution.
- **Why:** the statement the chart must make determines the form.
- **Source:** [Datawrapper, chart types][datawrapper-chart-types], [FT Visual Vocabulary][ft-visual-vocabulary].
- **Strength:** Practitioner.

### Data-ink

- **Rule:** Maximize data-ink. Remove gridlines, background fills, 3D effects, and decoration that do not carry data.
- **Why:** non-data ink competes with the data for attention.
- **Source:** [Tufte's data-ink, summarized by EU DataViz][eudataviz-chart-junk], [Nature][nature-illustration].
- **Strength:** Practitioner.

### Proportional encoding

- **Rule:** Keep the visual encoding proportional to the values. Do not truncate the axis on bar charts or use area and volume to exaggerate differences. Treat dual axes with care.
- **Why:** distorted encoding misleads readers about magnitude.
- **Source:** [Tufte's lie factor, summarized by EU DataViz][eudataviz-chart-junk], [Datawrapper, chart colors][datawrapper-colors], [FT Visual Vocabulary][ft-visual-vocabulary].
- **Strength:** Practitioner.

### Direct labels

- **Rule:** Label series directly and explain every encoding, then add a short description with the key takeaway.
- **Why:** readers should not hunt a legend.
- **Source:** [Datawrapper, chart colors][datawrapper-colors].
- **Strength:** Practitioner.

### Categorical colors

- **Rule:** Keep categorical chart colors to about seven, use grey for context, and test for color-vision deficiency.
- **Why:** more colors force legend-hunting and become indistinguishable.
- **Source:** [Datawrapper, chart colors][datawrapper-colors].
- **Strength:** Practitioner.

## Forms and feedback

### Form layout

- **Rule:** Use a single-column form with one question per row. Short related fields such as city, state, and postal code may share a row.
- **Why:** multiple columns interrupt the vertical reading flow.
- **Source:** [NN/g, web form design][nng-web-form-design].
- **Strength:** Research.

### Labels

- **Rule:** Give every input a persistent visible label, preferably above the field. Placeholders may add hints but must not replace labels.
- **Why:** disappearing hints strain memory and make error recovery harder.
- **Source:** [WCAG 3.3.2][wcag-332], [NN/g, placeholders][nng-placeholders], [NN/g, form white space][nng-form-white-space].
- **Strength:** WCAG A.

### Validation

- **Rule:** Validate only on submit, accept flexible formats, and turn off native HTML5 validation if it conflicts with your accessible error pattern.
- **Why:** early validation punishes slow typists, and native HTML5 bubbles cannot be made consistent or reliably accessible.
- **Source:** [GOV.UK validation][govuk-validation], [GOV.UK error message][govuk-error-message].
- **Strength:** System.

### Error messages

- **Rule:** Name the field in an error, say how to fix it, and preserve what the user entered. Add an error summary at the top, move focus to it, and link each summary item to its field.
- **Why:** users need to find and correct errors without re-entering data.
- **Source:** [WCAG 3.3.1][wcag-331], [3.3.3][wcag-333], [GOV.UK error message][govuk-error-message], [GOV.UK error summary][govuk-error-summary].
- **Strength:** WCAG AA.

### Primary button

- **Rule:** Use one primary button per page.
- **Why:** several primary buttons reduce the impact of each and obscure the next step.
- **Source:** [GOV.UK button][govuk-button].
- **Strength:** System.

### Action wording

- **Rule:** Use the same word for the same action across the flow. If the button says "Publish", the confirmation says "Published". Name the action, and avoid vague text such as "Submit" or "Click here".
- **Why:** inconsistent vocabulary forces users to re-learn each step, and vague button text hides what the action does.
- **Source:** [NN/g, heuristic 4][nng-heuristics], [GOV.UK button][govuk-button].
- **Strength:** Research.

### Loading feedback

- **Rule:** Match feedback to delay. Under 1s needs none, over 1s needs a busy indicator, and over 10s needs progress and an estimate. Use skeletons for container loads and inline spinners for actions.
- **Why:** users need to know whether the system is working.
- **Source:** [NN/g, response times][nng-response-times], [Carbon loading][carbon-loading].
- **Strength:** Research.

### Empty states

- **Rule:** Design the empty state. Explain what will appear here, why it is empty, and the next action.
- **Why:** first use and zero-result states are where users decide whether the product works.
- **Source:** [Carbon empty states][carbon-empty-states].
- **Strength:** System.

## Accessibility

### Keyboard operation

- **Rule:** Make all functionality keyboard-operable, with no per-keystroke timing requirement.
- **Why:** blind users, switch users, and voice-input users depend on the keyboard interface.
- **Source:** [WCAG 2.1.1][wcag-211].
- **Strength:** WCAG A.

### Focus

- **Rule:** Keep focus order meaningful, focus always visible, and the focused item at least partly unobscured. A strong indicator (WCAG AAA, 2.4.13) uses at least a 2px perimeter with 3:1 contrast, and the focus indicator is never removed without a visible replacement.
- **Why:** sighted keyboard users cannot operate what they cannot see.
- **Source:** [WCAG 2.4.3][wcag-243], [2.4.7][wcag-247], [2.4.11][wcag-2411], [2.4.13][wcag-2413].
- **Strength:** WCAG AA.

### Target size

- **Rule:** Set pointer targets at least 24 by 24 CSS pixels, or space them so a 24px circle centered on each does not intersect another. Prefer 44 by 44 for primary controls, which is WCAG AAA and the Apple default for iOS and iPadOS.
- **Why:** small, close targets cause mis-taps for people with tremor or limited dexterity.
- **Source:** [WCAG 2.5.8][wcag-258], [2.5.5][wcag-255], [Apple HIG accessibility][apple-hig-accessibility].
- **Strength:** WCAG AA.

### Dragging alternatives

- **Rule:** Give every dragging action a single-pointer alternative. Let a click on a slider track move the thumb, or provide a numeric input.
- **Why:** some users cannot press and drag accurately.
- **Source:** [WCAG 2.5.7][wcag-257].
- **Strength:** WCAG AA.

### Headings and widget patterns

- **Rule:** Write descriptive headings and labels, and use APG patterns for widgets. Menus, dialogs, tabs, and comboboxes need the documented roles, states, and keyboard behavior.
- **Why:** users navigate by headings and expect standard widget keys.
- **Source:** [WCAG 2.4.6][wcag-246], [WAI-ARIA Authoring Practices][wai-aria-apg].
- **Strength:** WCAG AA.

### Text alternatives

- **Rule:** Provide text alternatives for informative images. Complex images such as charts and diagrams need a short description plus a long description of the essential information. Use real text for text.
- **Why:** assistive technology cannot recover meaning from pixels, and users cannot restyle an image.
- **Source:** [WCAG 1.1.1][wcag-111], [WAI complex images][wai-complex-images], [WCAG 1.4.5][wcag-145].
- **Strength:** WCAG AA.

## Motion

### Durations

- **Rule:** Keep UI effects at 150, 200, or 300ms and larger spatial transitions at 350, 500, or 750ms, following Material's Standard motion scheme converted to web curves.
- **Why:** shorter feels instant, longer feels sluggish, and spatial moves need more time to read.
- **Source:** [Material 3 motion specs][material-motion-specs].
- **Strength:** System.

### Purpose

- **Rule:** Use motion to show what changed or to direct attention, and remove decorative motion. No autoplaying parallax or scattered entrance effects.
- **Why:** non-essential movement distracts.
- **Source:** [Reynolds, design tips][reynolds-tips].
- **Strength:** Practitioner.

### User control

- **Rule:** Give users control over motion. Moving, blinking, or scrolling content that starts automatically, lasts more than five seconds, and runs beside other content needs a way to pause, stop, or hide it, and auto-updating content that starts automatically beside other content needs the same or a way to control the update frequency, unless the motion is essential (2.2.2). Let users disable interaction-triggered motion unless it is essential, for example through `prefers-reduced-motion` (AAA, 2.3.3).
- **Why:** moving and auto-updating content distracts people with attention or reading difficulties, and interaction-triggered motion can cause nausea, migraine, and dizziness for people with vestibular disorders.
- **Source:** [WCAG 2.2.2][wcag-222], [2.3.3][wcag-233].
- **Strength:** WCAG A.

## Slides and diagrams

### One idea per slide

- **Rule:** One idea per slide, and pass the three-second glance test. A slide should read like a billboard. Use large type, whitespace, and images, since the best slides may have almost no text. Avoid bullet walls and slideuments.
- **Why:** audiences cannot read dense slides and listen at the same time. The spoken word carries the detail, and the slide carries the point.
- **Source:** [Duarte, slide design][duarte-slide-design], [Duarte, one idea per slide][duarte-one-idea], [Reynolds, design tips][reynolds-tips].
- **Strength:** Practitioner.

### Story structure

- **Rule:** Structure the talk as a story. Move from the status quo to what could be, alternate between the two, and end with a clear call to action.
- **Why:** story creates the tension that makes an audience pay attention.
- **Source:** [Duarte, HBR][duarte-hbr-story].
- **Strength:** Practitioner.

### Diagram hierarchy and labels

- **Rule:** Give diagrams a visual hierarchy and complete labels. Make the most important elements the most saturated and detailed, keep background elements neutral, label every element and the first instance of every object, and use figure parts and subheadings. Carry diagram meaning with consistent arrows.
- **Why:** a diagram is an argument about relationships, and unlabeled elements make it ambiguous.
- **Source:** [Nature, scientific illustration guide][nature-illustration].
- **Strength:** Practitioner.

## Choosing the sources

WCAG, GOV.UK, and Carbon form the smallest set that covers the skill's surfaces without asking an agent to internalize a branded visual language. WCAG supplies the only rules that are both normative and mechanically checkable. GOV.UK supplies the best public evidence on the highest-risk web surface, which is data entry and error recovery. Carbon supplies the patterns the other two lack for dense product screens and charts. Material 3 is the strongest alternative and the best source for color roles, state opacities, and motion tokens, but adopting it wholesale would impose an expressive identity and a large token vocabulary that the skill does not need.

- **[WCAG 2.2 AA plus WAI-ARIA APG][wcag-understanding]**

  - **Covers:** Testable criteria for contrast, focus, targets, reflow, text spacing, motion, errors, labels, and alt text, plus widget roles and keyboard behavior. Accessibility across web, slides, and diagrams. No visual language, layout, or content guidance.
  - **Conflicts and costs:** None with visual systems. It is a floor, so it constrains every other choice.

- **[GOV.UK Design System][govuk-design-system]**

  - **Covers:** Evidence-based patterns for forms, labels, validation, error summaries, buttons, tables, spacing, type scale, and service-page layout. Strongest on transactional web forms and public-service content. Weak on dashboards, charts, and expressive marketing surfaces.
  - **Conflicts and costs:** Austere visual language. Its 5px spacing scale, 19px body, and GDS Transport conflict with Carbon and Material values.

- **[IBM Carbon][carbon]**

  - **Covers:** Tokens, 2x grid, spacing and type scales, color themes, interaction states, empty and loading patterns, data tables, and Carbon Charts. Strongest on data-dense product UI, dashboards, and enterprise apps. Weaker on public-service form content and slides.
  - **Conflicts and costs:** IBM Plex and the 2x grid are branded. Its 8px base and dense 14px body conflict with GOV.UK.

- **[Material Design 3][material-3]**

  - **Covers:** The most complete visual system, with 26 color roles, 30 type styles, state layers, motion durations, elevation, and component states. Broad cross-platform app coverage. Strong for Android and token-driven theming. Heavy for a small skill.
  - **Conflicts and costs:** Its expressive visual language and dynamic color fight a brief that wants a distinct identity. Its token surface costs context and its values conflict with GOV.UK and Carbon.

- **[Apple Human Interface Guidelines][apple-hig-accessibility]**

  - **Covers:** Platform conventions, control sizing, accessibility expectations, and interaction feel for Apple platforms. Excellent for native Apple apps. Not a web, dashboard, or slide standard.
  - **Conflicts and costs:** Platform-bound. Its 44pt default overlaps WCAG AAA but does not replace web semantics.

- **Practitioner canon** (Butterick, Every Layout, Refactoring UI, Duarte, Reynolds, Tufte, Datawrapper, NN/g, and Nature)

  - **Covers:** Visual craft, including measure, leading, pairing, numerals, hierarchy, spacing, slide glance media, and data-ink. The aesthetic and editorial gaps the systems leave, especially slides and diagrams.
  - **Conflicts and costs:** Single-author advice can conflict, for example 45 to 75 versus 45 to 90 characters.

- **Platform guidance**

  - **Covers:** Viewport setup, responsive images, Core Web Vitals, and the design-token format, from W3C Community Groups and browser vendors.
  - **Conflicts and costs:** Vendor guidance reflects one browser's implementation, so check it against the others.

[apple-hig-accessibility]: https://developer.apple.com/design/human-interface-guidelines/accessibility
[butterick-all-caps]: https://practicaltypography.com/all-caps.html
[butterick-alternate-figures]: https://practicaltypography.com/alternate-figures.html
[butterick-centered-text]: https://practicaltypography.com/centered-text.html
[butterick-grids-of-numbers]: https://practicaltypography.com/grids-of-numbers.html
[butterick-justified-text]: https://practicaltypography.com/justified-text.html
[butterick-line-length]: https://practicaltypography.com/line-length.html
[butterick-line-spacing]: https://practicaltypography.com/line-spacing.html
[butterick-mixing-fonts]: https://practicaltypography.com/mixing-fonts.html
[carbon]: https://carbondesignsystem.com/
[carbon-2x-grid]: https://carbondesignsystem.com/elements/2x-grid/overview/
[carbon-color]: https://carbondesignsystem.com/elements/color/overview/
[carbon-empty-states]: https://carbondesignsystem.com/patterns/empty-states-pattern/
[carbon-loading]: https://carbondesignsystem.com/patterns/loading-pattern/
[carbon-spacing]: https://carbondesignsystem.com/elements/spacing/overview/
[carbon-typography]: https://carbondesignsystem.com/elements/typography/overview/
[datawrapper-chart-types]: https://www.datawrapper.de/blog/chart-types-guide
[datawrapper-colors]: https://academy.datawrapper.de/article/113-what-to-consider-when-choosing-colors-for-data-visualization
[dtcg-format]: https://www.designtokens.org/tr/2025.10/format/
[duarte-hbr-story]: https://hbr.org/2012/10/structure-your-presentation-li
[duarte-one-idea]: https://www.linkedin.com/posts/nancyduarte_this-mistake-is-costly-when-your-presentation-activity-7371184349502885888-n_yo
[duarte-slide-design]: https://www.duarte.com/blog/perfect-your-slide-design/
[eudataviz-chart-junk]: https://data.europa.eu/apps/data-visualisation-guide/chart-junk-and-data-ink-origins
[every-layout-axioms]: https://every-layout.dev/rudiments/axioms/
[ft-visual-vocabulary]: https://github.com/Financial-Times/chart-doctor/tree/main/visual-vocabulary
[govuk-button]: https://design-system.service.gov.uk/components/button/
[govuk-design-system]: https://design-system.service.gov.uk/
[govuk-error-message]: https://design-system.service.gov.uk/components/error-message/
[govuk-error-summary]: https://design-system.service.gov.uk/components/error-summary/
[govuk-layout]: https://design-system.service.gov.uk/styles/layout/
[govuk-spacing]: https://design-system.service.gov.uk/styles/spacing/
[govuk-table]: https://design-system.service.gov.uk/components/table/
[govuk-type-scale]: https://design-system.service.gov.uk/styles/type-scale/
[govuk-validation]: https://design-system.service.gov.uk/patterns/validation/
[material-3]: https://m3.material.io/
[material-color-roles]: https://m3.material.io/styles/color/roles
[material-motion-specs]: https://m3.material.io/styles/motion/overview/specs
[material-states]: https://m3.material.io/foundations/interaction/states/state-layers
[material-type-scale]: https://m3.material.io/styles/typography/type-scale-tokens
[nature-illustration]: https://www.nature.com/documents/Nature_scientific_illustration_author_guide.pdf
[nng-113-guidelines]: https://www.nngroup.com/articles/113-design-guidelines-homepage-usability/
[nng-dark-mode]: https://www.nngroup.com/articles/dark-mode/
[nng-data-tables]: https://www.nngroup.com/articles/data-tables/
[nng-form-white-space]: https://www.nngroup.com/articles/form-design-white-space/
[nng-glanceable-fonts]: https://www.nngroup.com/articles/glanceable-fonts/
[nng-heuristics]: https://www.nngroup.com/articles/ten-usability-heuristics/
[nng-pairing-typefaces]: https://www.nngroup.com/articles/pairing-typefaces/
[nng-placeholders]: https://www.nngroup.com/articles/form-design-placeholders/
[nng-response-times]: https://www.nngroup.com/articles/response-times-3-important-limits/
[nng-web-form-design]: https://www.nngroup.com/articles/web-form-design/
[refactoring-ui]: https://www.refactoringui.com/
[refactoring-ui-tips]: https://medium.com/refactoring-ui/7-practical-tips-for-cheating-at-design-40c736799886
[reynolds-tips]: https://www.garrreynolds.com/design-tips
[stanford-uit-all-caps]: https://uit.stanford.edu/accessibility/learn-about/typography/all-caps
[wai-aria-apg]: https://www.w3.org/WAI/ARIA/apg/
[wai-complex-images]: https://www.w3.org/WAI/tutorials/images/complex/
[wcag-111]: https://www.w3.org/WAI/WCAG22/Understanding/non-text-content.html
[wcag-141]: https://www.w3.org/WAI/WCAG22/Understanding/use-of-color.html
[wcag-1410]: https://www.w3.org/WAI/WCAG22/Understanding/reflow.html
[wcag-1411]: https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html
[wcag-1412]: https://www.w3.org/WAI/WCAG22/Understanding/text-spacing.html
[wcag-143]: https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html
[wcag-144]: https://www.w3.org/WAI/WCAG22/Understanding/resize-text.html
[wcag-145]: https://www.w3.org/WAI/WCAG22/Understanding/images-of-text.html
[wcag-211]: https://www.w3.org/WAI/WCAG22/Understanding/keyboard.html
[wcag-222]: https://www.w3.org/WAI/WCAG22/Understanding/pause-stop-hide.html
[wcag-233]: https://www.w3.org/WAI/WCAG22/Understanding/animation-from-interactions.html
[wcag-2411]: https://www.w3.org/WAI/WCAG22/Understanding/focus-not-obscured-minimum.html
[wcag-2413]: https://www.w3.org/WAI/WCAG22/Understanding/focus-appearance.html
[wcag-243]: https://www.w3.org/WAI/WCAG22/Understanding/focus-order.html
[wcag-246]: https://www.w3.org/WAI/WCAG22/Understanding/headings-and-labels.html
[wcag-247]: https://www.w3.org/WAI/WCAG22/Understanding/focus-visible.html
[wcag-255]: https://www.w3.org/WAI/WCAG22/Understanding/target-size-enhanced.html
[wcag-257]: https://www.w3.org/WAI/WCAG22/Understanding/dragging-movements.html
[wcag-258]: https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html
[wcag-331]: https://www.w3.org/WAI/WCAG22/Understanding/error-identification.html
[wcag-332]: https://www.w3.org/WAI/WCAG22/Understanding/labels-or-instructions.html
[wcag-333]: https://www.w3.org/WAI/WCAG22/Understanding/error-suggestion.html
[wcag-understanding]: https://www.w3.org/WAI/WCAG22/Understanding/
[web-typography-numerals]: https://book.webtypography.net/Web-Typography_Numerals-and-tables.pdf
[webdev-responsive]: https://web.dev/articles/responsive-web-design-basics
[webdev-vitals]: https://web.dev/articles/vitals
