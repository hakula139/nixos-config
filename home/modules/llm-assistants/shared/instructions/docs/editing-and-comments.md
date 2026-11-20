# Editing and Comments

Rules for source edits, layout, and comments across repositories.

## Editing

- Before editing, read the surrounding code and comparable files, using the closest counterpart for any new file. Match their structure, naming, comments, docstrings, and section banners where applicable, and treat a gap from those conventions or from sibling code as a defect to fix even when the code works.
- For CI changes, match action references, shells, and command layout in comparable workflows, checking maintained sibling repositories when local precedent is absent. Introduce commit SHA or digest pinning or repository security enforcement only when the task calls for that policy change.
- In a standalone Bash script with more than one command, start with `set -euo pipefail`, and quote every expansion, even inside `[[ ]]`, unless it should split into words or match as a pattern.
- Establish the general case before adding exceptions or qualifications. Respect API contracts and local ordering conventions.
- Write changes to a repository's source and documentation files, including new ones, with your file-edit tool, while shell writes stay fine for generated files, scratch and build files, and files outside a repository.
- When review feedback questions a file's grouping or ordering, reorganize the whole file from first principles in the same change, preserving its behavior.
- Before finishing, compare the complete edited construct and its callers with the surrounding code and comparable files, including unchanged entries in the same group.

## Comments

@comments@
