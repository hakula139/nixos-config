---
name: frontend-design
description: >-
  Design and build accessible web UI, dashboards, slides, and diagrams that fit their content
  and audience. Use when building or changing any interface, when choosing layout, type, color,
  spacing, motion, or copy, and when reviewing a rendered result, even when the request does not
  mention design.
---

# Frontend Design

Project conventions govern the stack and tooling. WCAG bounds every surface, and the public baseline supplies the patterns. Each design rule states the goal it serves, so it generalizes to the interface in front of you.

## Project conventions

- Work inside the project's existing stack and idioms, so one screen never mixes styling systems.
- For new UI, use the latest Tailwind CSS.
- Use `@apply` to share a class set wherever several elements repeat it, keeping classes concise, shared, and consistent.
- Reuse the established UI framework and its components before building your own.
- Use open-source libraries for icons, fonts, and rendering such as markdown, and write your own only when no library fits.
- Keep the design simple, elegant, and consistent with the user's related projects.

## Design baseline

Use each public standard for the areas where it is authoritative.

- **WCAG 2.2 AA and the WAI-ARIA Authoring Practices** set contrast, focus, target size, reflow, and error identification for every surface.
- **GOV.UK Design System** provides the patterns for forms, validation, errors, content, and service pages.
- **IBM Carbon** provides the patterns for data-dense product UI, dashboards, tables, and charts.
- **Material 3** supplies color roles, state-layer opacities, and motion durations.
- **The practitioner canon** (Butterick, Every Layout, Refactoring UI, Duarte, Reynolds, Tufte, Datawrapper, NN/g, and Nature) covers typography, hierarchy, slides, and diagrams.
- **Platform guidance** from W3C Community Groups and browser vendors covers viewport setup, responsive images, Core Web Vitals, and the design-token format.

Precedence:

- WCAG is a floor. A visual direction may change the look but cannot remove contrast, focus, target size, reflow, or error identification.
- Pick one system's spacing scale, type scale, and body size per artifact and apply them throughout, since GOV.UK's 5px scale and 19px body conflict with Carbon's 8px grid and 14px body.
- Use GOV.UK for form structure and errors, Carbon for the data surfaces named above, Material 3 for the cross-cutting values above, and the canon and Platform guidance inside the WCAG floor.

[references/design-sources.md](references/design-sources.md) holds the full rule set, including rules SKILL.md does not condense, with each rule's source, strength, and any disagreement between sources, plus how the sources were chosen.

## Rules

### Foundations

- Draw every margin and gap from a single spacing scale, so the rhythm holds and small changes stay cheap.
- Map a small fixed type scale to roles and set body text to the body role, so the hierarchy stays consistent and text survives zoom.

### Layout and spacing

- Give each view one dominant element and build hierarchy through size, weight, and color together, using about two weights and two or three text colors, so the eye finds an entry point and sees what matters.
- Group related items by proximity, and give important elements more surrounding space, so nearness reads as relationship and extra space reads as importance.
- Align related edges to shared key lines, keep body copy left-aligned, and center only short headings, because centered and justified blocks break alignment and slow reading. Do not justify browser body text without hyphenation.
- Design from a single small-screen column first, with no page-level horizontal overflow or obscured focus, so content and controls stay reachable.
- Support 200% text resize and reflow at 320 CSS px (400% zoom) without two-dimensional scrolling, except for elements that require a two-dimensional layout such as data tables, maps, and diagrams.
- Show less text, and use more icons or images where they make the content more readable, but do not blindly switch text to images, so attention stays on the idea.
- Put detail in tooltips or popovers when needed, so the screen does not fill with text.
- Place controls in a row's free space before overlapping or stacking them, so no control is covered while part of the row sits empty.
- Design for growth, with many tabs, columns, or aspects, so added tabs or columns do not overflow.
- Style each element type the same way on every screen, so a reader never has to relearn it.

### Typography

- Set body leading at 1.3 to 1.5 and never below 1.2, and build the layout to survive user overrides of 1.5 line-height, 2em paragraph spacing, 0.12em letter spacing, and 0.16em word spacing.
- Fill the available width up to 90 characters, so the eye travels a comfortable distance without losing its place.
- Use at most two typefaces with fixed roles and keep decorative faces out of body copy, so the typefaces reinforce the hierarchy.
- Leave no short word alone on the last line of a paragraph or heading, since a lone word reads as a mistake and weakens the line.
- Use sentence case for body text, headings, and most labels. All caps is acceptable for short labels and captions when the text is tracked and the label is genuinely short. Never set a paragraph or a multi-line heading in caps, since caps remove the word shapes that aid recognition. Apply caps with `text-transform: uppercase` so the underlying text keeps its case.

### Color

- Set text contrast to at least 4.5:1 and large text to at least 3:1, where large means 18pt (about 24px) or 14pt bold (about 18.5px), and never round a computed 4.499:1 up to a pass, because low-contrast text disappears for low-vision users.
- Keep component boundaries, states, meaningful graphics, and focus indicators at 3:1 contrast or better against adjacent colors, so the control and its state remain visible.
- Never use color as the only cue. Pair it with text, an icon, a shape, or a pattern, so the meaning survives color blindness.
- Define color as role tokens such as `primary`, `on-primary`, `surface`, `container`, and `outline`, build light and dark themes from the same roles, follow the OS setting for dark mode, and keep light mode the default for a general audience, so contrast pairs stay coherent and dark mode remains a choice.

### Data display

- Use a table when the task compares values across rows and columns, so the table supports comparison. Put a human-friendly name in the first column. Never show an internal ID there.
- Right-align numeric columns, use tabular figures, put units in the header, and give the table a caption and scoped headers, so values line up and the table is navigable.
- Choose the chart from the message: a line for change over time, a bar for comparison and share, a scatter for correlation, and a histogram for distribution, so the form makes the statement the chart must make.
- Maximize data-ink by removing gridlines, background fills, 3D effects, and decoration, so nothing competes with the data.
- Keep the visual encoding proportional to the values, and label encodings directly with a short description of the key takeaway, so the chart does not mislead about magnitude or send readers hunting a legend. Do not truncate the value axis on a bar chart or use area and volume to exaggerate differences.

### Forms and feedback

- Use a single-column form with one question per row, letting only short related fields such as city, state, and postal code share a row, so the vertical reading flow holds.
- Give every input a persistent visible label above the field, reserve placeholders for hints, validate on submit, accept flexible formats, and preserve the user's input, so the field stays identifiable and slow typists are not penalized.
- Name the field in each error message, explain how to fix it, and place an error summary at the top that links to each offending field, so users can find and fix errors without re-entering data.
- Match feedback to the delay, so users know the system is working: use no special feedback under 1s, a busy indicator over 1s, and a progress indicator with a time estimate over 10s, using skeletons for container loads and inline spinners for actions.
- Design the empty state with what will appear, why it is empty, and the next action, so first use and the zero-result state are clear.
- Use one primary button per page that names the action, and use the same word for the same action across the flow, so the next step is clear.

### Accessibility

- Make all functionality keyboard-operable, with no per-keystroke timing requirement, and keep focus order meaningful and focus always visible. A strong indicator uses at least a 2px perimeter at 3:1 contrast, and the focus indicator is never removed without a visible replacement.
- Make pointer targets at least 24 by 24 CSS pixels, or preferably 44 by 44 for primary controls, and give every dragging action a single-pointer alternative, such as clicking a slider track or typing into a numeric input, so people with limited dexterity can operate it.
- Provide text alternatives for informative images, with a short description and a long description for complex charts and diagrams, and render text as real text, so assistive technology and restyling both work.
- Write descriptive headings and labels, and follow the APG roles, states, and keyboard behaviors for menus, dialogs, tabs, and comboboxes, because users navigate by headings and expect standard widget keys.

### Motion

- Set UI effects to 150, 200, or 300ms and larger spatial transitions to 350, 500, or 750ms, so small changes feel instant and spatial moves stay readable.
- Use motion to show what changed or to direct attention, and remove decorative autoplay and parallax. Give automatic motion that runs beside other content for more than five seconds a pause, stop, or hide control, give auto-updating content the same or a frequency control, and let users disable interaction-triggered motion through `prefers-reduced-motion`, so moving content neither distracts nor sickens anyone.

### Slides and diagrams

- Give each slide one idea that passes a three-second glance, with large type, whitespace, and images, so the audience can listen while they glance.
- Structure the talk as a story from the status quo to what could be and end with a clear call to action, so the audience follows the problem through to the outcome.
- Give a diagram a visual hierarchy, make the most important elements the most saturated and detailed, keep the background neutral, and label every element and the first instance of every object, so the argument about relationships is unambiguous.
- Carry diagram meaning with labels and consistent arrows, and give every diagram short and long text alternatives, so color-blind and blind readers get the argument.

## Verify

- Check the rendered result with the `browser-debugging` skill across the project's viewports for overflow, alignment, padding, contrast, keyboard focus, and reduced motion, measuring positions and gaps in the screenshot before changing any geometry.
- Deploy to the project's test or preview environment so the user can review it.
