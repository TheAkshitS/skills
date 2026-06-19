---
name: c4-views
description: Generate and review C4 model software-architecture diagrams (System Context, Container, Component) in Mermaid, Structurizr DSL, or C4-PlantUML. Use when the user wants to create, draw, author, diagram, or visualize software architecture or system structure, or to review, critique, or sanity-check an existing architecture or C4 diagram — including requests mentioning 'C4', a 'context/container/component diagram', an 'architecture diagram', or 'mermaid C4', even when they don't say 'C4' explicitly.
---

# C4 Architecture Diagrams

This skill drives two workflows over the C4 model (https://c4model.com): **generating**
a new architecture diagram and **reviewing** an existing one. The C4 model is
abstraction-first and notation-independent — you pick the abstractions first, then render
them in whatever notation fits. Get the model right and the picture follows.

Three reference files carry the depth. Read them on demand (see References at the end);
do not preload them.

---

## 1. The C4 mental model

C4 has one abstraction hierarchy. Each level is a strict zoom into the one above:

```
Person  ──uses──▶  Software System  ──contains──▶  Container  ──contains──▶  Component  ──implemented by──▶  Code
```

- **Person** — a human actor, role, or persona who uses the system.
- **Software System** — the highest level of value delivered; the thing in focus.
- **Container** — a separately deployable/runnable unit: an **application** or a **data
  store** that must be running for the system to work.
- **Component** — a grouping of related functionality behind an interface, living *inside*
  a container. Components are **not** separately deployable — the container is.
- **Code** — classes, functions, interfaces implementing a component.

> **Container ≠ Docker.** In C4 a "container" is an app or a data store (a web app, an SPA,
> a mobile app, a serverless function, a database schema, an S3 bucket) — **not** a Docker/OCI
> container. A Docker container is a *runtime host*; it belongs on a **Deployment** diagram as
> a deployment node, never as a C4 Container in a static diagram. Mislabeling these is the
> single most common C4 error.

### The diagram levels

**Core (static structure)** — each tells a different story to a different audience:

| Level | Name | Scope | Shows |
|-------|------|-------|-------|
| L1 | System Context | one software system | the system + the people and external systems it talks to |
| L2 | Container | one software system | the apps and data stores inside, their tech, how they communicate |
| L3 | Component | **one container** | the components inside that container |
| L4 | Code | one component | how the component is implemented (UML/ER) |

**Supplementary:** System Landscape (many systems, one org), Dynamic (runtime
collaboration with numbered steps), Deployment (instances mapped onto infrastructure —
*this* is where Docker containers, VMs, and cloud nodes appear).

### Normative default

**Produce L1 + L2 by default** — they are sufficient for most teams. Create **L3 only when
the user asks** (or when one container is genuinely complex). **L4 is rare** — most IDEs
generate it on demand; produce it only for the most critical component. Use only the levels
that add value; do not generate a level the user did not need.

See `references/c4-method.md` for full abstraction definitions, the non-obvious container
cases (managed cloud services, SPAs, message queues), and the supplementary diagrams.

---

## 2. Generating a C4 diagram

Work the steps in order. The model decisions (a–c) come before any notation.

**(a) Scope it.** Establish three things before drawing:
- the **single software system in focus** (C4 always zooms into exactly one);
- the **audience** (drives how much technical detail belongs in it);
- which **level(s)** are wanted. If unstated, apply the default below.

**(b) Default to L1 + L2.** Unless the user specified otherwise, produce a System Context
and a Container diagram. Add L3 only on request; L4 almost never.

**(c) Pick ONE abstraction level per diagram — never mix.** A Container diagram shows
containers only (plus the external people/systems they touch); it must not expose
components. A Component diagram decomposes exactly one container. Mixing levels in a single
diagram is a hard failure.

**(d) Choose a notation.** Use the compact matrix in §4. Default to **Mermaid native C4**
when the diagram lives in Markdown/GitHub and needs zero toolchain; reach for Structurizr or
C4-PlantUML when layout quality or a single source-of-truth model matters. Copy-pasteable
L1/L2/L3 templates for all four notations live in `references/notations.md` — author from
there, do not hand-write syntax from memory.

**(e) Author from the template.** Adapt the matching template for your chosen notation and
level. Keep element ids and naming consistent across the L1/L2/L3 set so the diagrams read
as one coherent collection.

**(f) Enforce the notation-independent rules.** These are non-negotiable regardless of which
notation you chose:
- **Every element** carries **name + type + technology + description.** Technology is
  required on every Container and Component; it is omitted on Person and Software System.
- **Every relationship** is **directed** (one unidirectional arrow — no bidirectional
  lines) and **specifically labeled.** Never ship a bare "Uses" / "Calls" / "Connects to" —
  say what flows and how, e.g. "Reads customer records from [JDBC]", "Sends password-reset
  email via [SMTP]". Any relationship that crosses a container boundary (inter-process
  communication) must name its **protocol/technology** (HTTPS/REST, gRPC, AMQP, …).
- **Every diagram** has a **title** (type + scope, e.g. "Container diagram for Internet
  Banking System") **and a key/legend** explaining every shape, colour, border, and
  arrowhead. Legend handling differs by notation:
  - **Mermaid** (native C4 *and* flowchart-as-C4) has **no legend mechanism** — you must
    hand-author one (a dedicated note, or a small labeled node/subgraph) and keep it in sync
    with the shapes and colours you actually used.
  - **C4-PlantUML** auto-renders a legend — emit `LAYOUT_WITH_LEGEND()` or
    `SHOW_LEGEND()`, then confirm it covers any custom colours/shapes you introduced.
  - **Structurizr** generates the key from the `styles {}` block — still verify it explains
    every styled element.
- No generic terms ("business logic"); spell out or define every acronym.

**(g) Ship a prose element catalog alongside the diagram.** Follow the diagram with a short
written list naming each element, its type, its technology, and its responsibility — so the
diagram is usable in review and text-only contexts, and stands on its own without a verbal
walkthrough.

---

## 3. Reviewing a C4 diagram

A review judges the diagram on **two axes**:

1. **Ground truth — does it match reality?** When the actual source code or an authoritative
   spec is available, the diagram must reflect what the system *does*: element names,
   technologies, relationship directions, and protocols should match the running system.
   State the basis in the verdict ("Reviewed against source code at \<path\>" or
   "against spec \<name/version\>"). If neither is available, review **C4-method correctness
   only** and say so explicitly.
2. **C4-method correctness** — does it conform to the c4model.com checklist and avoid the
   known anti-patterns?

**Procedure:** apply every check in `references/review-rubric.md` (General G1–G6, Elements
E1–E9, Relationships R1–R6) as PASS / FAIL / N/A. For each FAIL, record the **specific**
element or relationship that triggered it and a **concrete** fix — not "add a label" but
"replace 'Uses' with 'Submits payment request [HTTPS/REST]'". Watch especially for: Docker
containers mislabeled as C4 Containers, components shown as separately deployable, missing
technology, bare relationship labels, and mixed abstraction levels.

**Output a structured verdict** — the exact format (verdict header with ground-truth basis +
diagram type + overall PASS / PASS_WITH_CONCERNS / FAIL, a per-check table, and a 2–4
sentence summary) is defined in `references/review-rubric.md`. Use it verbatim.

> **You cannot read binary/visual diagram files** (`.drawio`, `.vsdx`, and other proprietary
> binary formats). If handed one, ask the author for a **text notation** (Mermaid,
> Structurizr DSL, or C4-PlantUML) **or an exported SVG/PNG with readable labels** before
> proceeding — do not guess at contents.

---

## 4. Choosing a notation

Compact selector. (The frontmatter `description` mentions "Mermaid" as a single notation
for trigger brevity; this section splits the two Mermaid variants.) Full copy-pasteable
L1/L2/L3 templates and per-notation gotchas live in `references/notations.md`.

| Notation | Choose when… | Renderer | Maturity caveat |
|----------|--------------|----------|-----------------|
| **Mermaid native C4** (`C4Context`/`C4Container`/`C4Component`) | zero-toolchain diagram that renders inline in GitHub/GitLab/Markdown | Mermaid (built into GitHub & many tools) | **Experimental** — syntax may change; weak auto-layout; no legend. |
| **Mermaid flowchart-as-C4** (`flowchart` + `subgraph` + `classDef`) | you want full styling/layout control and Mermaid portability when native C4's layout falls short | same Mermaid engine — no binary | Mermaid core is stable, **but this is not real C4** — element type is hand-rolled via class + label text. |
| **Structurizr DSL** (`workspace { model {} views {} }`) | a large/evolving system where you want to **model once → render many consistent views** (single source of truth) | needs a Structurizr renderer (Lite via Docker, cloud, or on-prem) — **not** GitHub-native | mature; **auto-generated view keys are unstable** — set explicit keys. |
| **C4-PlantUML** (`!include C4_Container.puml`; `Person`/`Container`/`Rel`) | you already run a **PlantUML toolchain** (CI, IDE, Confluence) and want first-class C4 macros | PlantUML **+ Graphviz** (both required) | mature community standard; **v2.12.0 changed `Lay_*`/`LANDSCAPE` layout** — pin a version. |

See `references/notations.md` for the templates.

---

## 5. References

Read these on demand — pull the one that matches the task; do not load all three up front:

- **`references/c4-method.md`** — read when you need the authoritative C4 definitions:
  abstraction rules, the non-obvious container cases (managed cloud services, SPAs, message
  queues), the supplementary diagrams (System Landscape / Dynamic / Deployment), the
  notation principles, the anti-pattern list, and the tooling landscape.
- **`references/notations.md`** — read when **generating or fixing** a diagram and you need
  the copy-pasteable L1/L2/L3 templates, the element/relationship keyword tables, and the
  per-notation gotchas and version-pinning notes for all four notations.
- **`references/review-rubric.md`** — read when **reviewing** a diagram: the full G/E/R
  pass-fail checks, the anti-patterns to scan for, and the exact structured verdict format.
