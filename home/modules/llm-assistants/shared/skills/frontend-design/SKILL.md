---
name: frontend-design
description: >-
  Design and build UI that fits its content and audience, covering applications, sites, decks, and
  diagrams. Use when building or changing any interface, when choosing layout, type, spacing,
  motion, or copy, and when reviewing a rendered result, even when the request does not mention
  design.
---

# Frontend Design

These rules cover what a capable model tends to get wrong in UI work when left to its own habits. Each names the goal it serves, so apply it to the interface in front of you.

## Stack

- Work inside the project's existing stack and its idioms, such as Tailwind classes where the repository styles that way, so one page does not follow two sets of styling rules.
- For a new application UI, use Tailwind CSS with each token defined once, plus the ecosystem's established component library, and hand-build a component only when neither the library nor the framework has a fit, as the global instructions' Design rules require.
- Bespoke presentational work, such as a deck or a landing page, may hand-build its components on those same tokens, so the bespoke page still shares the product's system.
- Use an established icon library, and keep every icon in use in one local module so the set stays coherent. A hand-drawn path breaks the library's stroke weight and grid, so glyphs and arrows come from the library.

## Direction

- Aim for a result that looks designed for this content and audience, and match the project's design system when it has one, so the work reads as part of the product.
- Define color, type, and spacing as tokens, add a token only when a need appears, and keep the set small so the system stays learnable.
- Plan a new direction before coding, since a layout chosen while typing tends to fall back on the familiar.

## Consistency

- Give every element type, such as a footnote, table, caption, or transition, one style across every screen, and give a different kind a visibly different treatment, so a reader carries what they learn from one page to the next and never relearns an element.
- Let structure follow meaning, so a sub-case nests inside its parent and a reader sees the relationship without reading a label.

## Density

- Show the least text that carries the message, and replace text with a glyph, arrow, or diagram when the visual already says it, so attention goes to the idea.
- Cut content before cramming it into the layout, and avoid both a page filled edge to edge and one so thin it wastes the space. Every element should have room to be read.
- Shape each screen around its content, so screens that say different things do not all reduce to one table plus a note.

## Type

- Reserve monospace for literals a reader could type or search for, such as commands, paths, identifiers, and keys, and match its weight to the surrounding text, so the face marks a literal and sits calmly in the line.
- Set no text in all caps, because it slows reading and removes case information.
- Break headings and card text at phrase boundaries, leave no short word alone on a last line, and keep body lines under about 80 characters so the eye can find the next line.

## Layout

- Measure positions and gaps in the rendered page before changing geometry, because guessed padding and alignment fail repeatedly.
- Take spacing from the scale and give equal relationships equal gaps, so a reader can tell which items belong together.
- Align related edges so items that belong together read as one group, and match the heights of side-by-side panels so the row reads as one band.
- Allow no overflow or occlusion at every viewport the project supports, so nothing is cut off or hidden.

## Motion

- Use motion where it explains a change, and design its order and timing, so the reader sees what moved and why.
- Prefer calm transitions, and honor reduced motion so the page stays usable for people who ask for less movement.

## Copy

- The global instructions' Writing rules apply to every string in the interface, so an interface reads as one voice from labels to errors.
- Where a page argues or explains, as a deck or landing page does, headings are short claims. On any page, a subtitle adds information the heading does not carry, so a reader can scan the structure from headings alone.
- Parallel notes on sibling cards or diagram nodes answer the same question, so a reader can compare them across the row.
- Labels may drop articles, while full sentences keep them, so a reader can tell a label from a sentence at a glance.
- Keep copy concrete and relevant to the actual audience. Take claims, figures, and examples only from a source the user agreed to, and mark any placeholder as one, so nothing without a source ships as fact.

## Defaults to question

Before keeping a structure, check whether the content asked for it. An interchangeable card grid, a stat hero built from a gradient and a large number, decorative labels, and arrows or separators that carry no meaning fit any topic. A layout chosen because it is familiar leaves the page without a point of view, so replace it when the content suggests something else.

## Verify

- Look at the rendered result through the `browser-debugging` skill at the project's viewports, checking overflow, alignment, console errors, keyboard navigation, and reduced motion, because a page is judged on what renders.
- When the repository deploys previews, open the change as a PR / MR so the user can review the preview.
- Read a video by extracting frames before describing it, so the description rests on what the footage shows.
