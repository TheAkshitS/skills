# Test fixtures

This directory is intentionally empty.

The test suite in `../test-validate-skills.sh` generates fixtures inline via
heredocs into a `mktemp -d` scratch dir at runtime. The intent:

- **No stale state.** Each test run starts from a clean filesystem.
- **No coupling.** Tests don't depend on a hand-maintained fixture tree.
- **Read the test file to see exactly what is exercised.** Fixtures live next
  to the assertions that use them.

If a future test needs reusable fixtures (multi-file skill structures, sample
diagrams, etc.), add them here and link them from the test file.
