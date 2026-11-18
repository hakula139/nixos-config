# Verification and Tests

Rules for debugging, verification, and test suites across repositories.

## Debugging and Verification

- Keep task-specific validation in scratch commands.
- When tests fail, coverage drops, or behavior breaks, investigate the root cause before patching symptoms. Skipping tests, adding ignores or retries, or special-casing specific commits or data to get checks passing also patches symptoms, so fix the cause or make the test hermetic.
- Verify the result before declaring the task done, directly or through a delegate's verification evidence. Confirm that asynchronous or external operations have landed, including API responses, advanced git refs, and multi-repo build passes. Name any UI change you could not test in a browser.
- Show that a refactor or port preserves behavior by diffing the old and new code's output on the same inputs and environment.

## Tests

### Scope and Coverage

- Add a permanent test only for a concrete regression risk or non-obvious contract that existing coverage does not protect. Before keeping it, break the behavior it guards and confirm that it fails. Avoid structural-only assertions (`assert_eq!(items.len(), 3)`) that pass even when the behavior is wrong.
- Keep the suite lean and aimed at the project's core behavior. Test wrapper code only with the one or two cases that pin a non-obvious contract.
- Drop or merge tests whose coverage is subsumed by others.
- For a script whose behavior depends on large external state, test its pure functions with tables and validate the rest with a real run.

### Inputs

- Write test data with neutral, invented names (`/home/u/src/app`, `example.com`), never paths, repositories, hosts, or accounts from the user's own environment. When a case depends on a real value's shape, such as an underscore that `LIKE` would treat as a wildcard, keep the shape under a generic name.
- Keep each test directory's fixtures self-contained, extracting fixtures shared across test directories into a dedicated shared directory so each test suite stays independent. Never reference another test's fixtures with `../`.

### Structure and Execution

- Merge tests that differ only in their inputs and expected outputs into one table-driven test when the table makes the group's shared intent clearer, and keep tests separate when their setup or the behavior they check differs. Use the framework's parametrization where it exists, and otherwise loop over case records, naming the case in each assertion message so a failure shows which input broke.
- Structure each test as arrange, act, and assert, with blank lines between the steps. Keep any check that the act succeeded beside the act.
