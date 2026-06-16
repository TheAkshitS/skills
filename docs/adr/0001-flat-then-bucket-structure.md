# ADR-0001: Flat-then-bucket skill organization

## Status

Accepted.

## Context

The repository needs a directory structure for organizing skills that scales
from one skill to dozens. Two approaches were considered:

1. **Always-bucketed**: every skill lives under a category folder from day one
   (`skills/engineering/c4-views/`).
2. **Flat-then-bucket**: skills start flat (`skills/c4-views/`), migrating to
   category buckets only when 3+ skills exist and grouping becomes meaningful.

## Decision

Adopt **flat-then-bucket**. Skills live directly under `skills/` until the
count and variety justify bucket folders.

Planned buckets when the time comes:

- `engineering/` — daily code work (diagrams, TDD, debugging, architecture)
- `productivity/` — general workflow tools (grilling, handoff, teaching)
- `misc/` — kept around but rarely used

Buckets that stay excluded from `plugin.json` and README:

- `personal/` — tied to individual setup
- `in-progress/` — drafts not yet ready to ship
- `deprecated/` — no longer maintained

## Consequences

- Simpler paths for early adopters and single-skill users.
- Scripts (`validate-skills.sh`, `link-skills.sh`) must support both flat and
  nested paths from the start.
- Migration to buckets is a one-time rename + path update when the threshold is
  reached.
- `plugin.json` and README must be updated when skills move into buckets.
