Using the JSON input at the end of this message, write a one-day activity log for the user in Markdown with exactly two sections, `## Timeline` and then `## Draft`, starting directly with `## Timeline` without preamble or closing remarks. Keep both headings on a day without work, when the Draft holds only the Unattributed line. The input provides `metrics` (measured intervals, totals, and point events like commits and GitLab or GitHub actions), `excerpts` (user prompts and agents' final replies per session), `projects` (a map from repository names to the project names the user reports under), and `examples` (task lines previously written by the user).

Treat measured minutes as facts, and never invent a time span, duration, meeting, person, merge request, or outcome unsupported by the input. When evidence for what a session achieved is thin, state what was attempted and omit the outcome. Excerpts often show a decision being revised, so report only the final choice.

## Timeline

Write one `###` entry per coherent piece of work in start-time order. While an entry usually spans one interval, combine intervals from the same session and task, and split an interval when its excerpts show clearly distinct tasks. Format each heading as `### HH:MM-HH:MM · Project · Task`, taking interval times from `metrics` and mapping repositories to project names in `projects` when available. A combined entry lists each of its ranges, as in `### 10:00-10:50, 11:05-11:30 · Project · Task`, and a split entry keeps the whole interval's range and states its share of the minutes in `Labels`. Below the heading, include these bullets:

- `Labels:` the context, mode, and minutes split into in-hours, lunch, and after-hours (omitting zero values), plus `concurrent with a meeting` when indicated by the interval.
- `Sources:` the agent and the first 8 characters of its session id, or `calendar` for a meeting, followed by related merge requests, issues, and commit counts drawn from point events for the same project and time.
- `Summary:` two to four sentences for the user's manager detailing what the user and agents did, what changed, and current status.

Include entries for meetings as well, strictly reflecting what the title states. While personal-context entries appear with their label in the timeline, omit them entirely from the Draft section.

## Draft

Format work-context tasks as `- <minutes>m <Project> - <Task> | <status>` with whole minutes, optionally inserting a sub-project as `<Project> - <Sub-project> - <Task>`, with the status remaining optional. Account for all work-context minutes across the Draft lines by dividing each interval's minutes proportionally among its tasks based on the evidence, ensuring total Draft minutes equal `work_in_hours`, `work_lunch`, and `work_after_hours` combined and rounded to whole minutes. Place tasks worked at lunch or after hours on separate lines ending in `| lunch` or `| after hours`, after any status, so the user can decide whether to count them.

Phrase each task in idiomatic, professional English as a single clause starting with an imperative verb and specifying a concrete artifact or outcome, such as a version, merge request, or document. Attribute collaborators with "with" and requesters with "for". Keep status values brief, such as `Done`, `Ongoing`, or `Pending review`. When `examples` are provided, match their vocabulary and level of detail. Typical lines read like these:

- 45m Billing Service - Release 1.4.0 and fix the deployment issues it exposed | Done
- 30m Search API - Review Alice's merge requests on query caching and request changes
- 60m Interview - Interview the candidate and write the report

Conclude the section with `- Unattributed: <minutes>m` displaying the measured unattributed minutes rounded to whole minutes so the user can fill that time from memory.
