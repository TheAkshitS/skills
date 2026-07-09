# C4 Diagram Review Rubric

Reference used when reviewing an existing C4 diagram against the official
c4model.com checklist and anti-pattern list.

**Source of truth:** https://c4model.com/diagrams/checklist (normative grading rubric)
and https://c4model.com/introduction (common diagramming problems).
There is no `/diagrams/dos-and-donts` page — this rubric IS the canonical
review artifact.

---

## Contents

1. [How to use this rubric](#1-how-to-use-this-rubric)
2. [General checks](#2-general-checks)
3. [Element checks](#3-element-checks)
4. [Relationship checks](#4-relationship-checks)
5. [Anti-patterns to look for](#5-anti-patterns-to-look-for)
6. [Ground truth and verdict format](#6-ground-truth-and-verdict-format)

---

## 1. How to use this rubric

Apply every applicable check below as a **PASS** or **FAIL**.

- A check is **not applicable (N/A)** only when the diagram type genuinely
  cannot trigger it (e.g. "technology on containers" is N/A for a System
  Context diagram, which has no containers).
- When a check fails, record: the specific element or relationship that
  triggered the failure, and a concrete suggested fix.
- Produce one structured verdict per diagram (see §6).

**Binary files.** This rubric cannot be applied to proprietary binary formats
(e.g. `.drawio`, `.vsdx`) that cannot be read as text. For those, ask the
author to provide the diagram as a text notation (Structurizr DSL,
C4-PlantUML, Mermaid C4) or an exported SVG/PNG with readable labels before
proceeding.

Also read:

- `c4-method.md` — abstraction definitions and diagram-type scope
- `notations.md` — element and relationship notation requirements

---

## 2. General checks

Source: https://c4model.com/diagrams/checklist (general section) and
https://c4model.com/diagrams/notation (diagram-level requirements).

| ID | Check | PASS condition |
|----|-------|----------------|
| G1 | **Title present** | The diagram carries a title that names both the diagram type and its scope (e.g. "System Context diagram for Payments Service"). | 
| G2 | **Key / legend present** | A key or legend exists that explains every shape, colour, border style, line type, arrowhead, and icon used in the diagram. |
| G3 | **Acronyms and abbreviations explained** | Every acronym or abbreviation — whether business-domain or technology — is either spelled out in the diagram itself or defined in the key/legend. |
| G4 | **Self-explanatory** | A reader with appropriate technical background can understand the diagram without a separate verbal walkthrough. Evaluate by asking: "Can this diagram stand alone?" (https://c4model.com/diagrams/notation). |
| G5 | **Correct diagram type declared** | The diagram is explicitly labelled as one of the recognised C4 types: System Context, Container, Component, Code, System Landscape, Dynamic, or Deployment. Unlabelled or mislabelled types FAIL. |
| G6 | **Scope matches the declared type** | System Context and Container diagrams scope to a single software system; Component diagrams scope to a single container; Code diagrams scope to a single component. A diagram that includes elements outside its declared scope FAILS. |

---

## 3. Element checks

Source: https://c4model.com/diagrams/checklist (elements section) and
https://c4model.com/diagrams/notation (element requirements).

| ID | Check | PASS condition |
|----|-------|----------------|
| E1 | **Every element has a name** | No element is anonymous or labelled only with a placeholder. |
| E2 | **Every element has an explicit type** | The type (Person, Software System, Container, Component, Deployment Node, Infrastructure Node) is shown on or beside every element. Implicit typing by shape/colour alone FAILS unless the key makes the mapping unambiguous. |
| E3 | **Every element has a short description** | Each element carries a description sufficient to convey its key responsibilities at a glance (https://c4model.com/diagrams/notation). |
| E4 | **Technology is shown on containers and components** | Every Container and Component element names its technology (e.g. "Java 21 / Spring Boot", "PostgreSQL 16"). Missing technology on a Container or Component FAILS. Technology is optional — and should not be shown — on Person and Software System elements. |
| E5 | **Abstraction level is consistent — no level-mixing** | All elements belong to the same abstraction level appropriate for the diagram type. A Container diagram must not contain Component-level elements; a System Context diagram must not expose container internals. Mixed abstraction levels FAIL (https://c4model.com/introduction common diagramming problems: "Levels of abstraction are mixed"). |
| E6 | **Container ≠ Docker container (abstraction misuse flagged)** | In any static structure diagram (System Context, Container, Component), "Container" means a separately deployable or runnable application or data store — **not** a Docker/OCI container image or runtime (https://c4model.com/abstractions/container: "Not Docker!"). If an element labelled or described as a "container" refers to a Docker/OS container rather than an app/data-store unit, this FAILS. Note: a Docker container legitimately appears on a **Deployment** diagram as a Deployment Node, not as a C4 Container. |
| E7 | **Components are not shown as separately deployable** | A Component element must execute within its parent Container's process space. Any element described as independently deployable or hosted separately from its container FAILS (https://c4model.com/abstractions/component). |
| E8 | **Managed cloud data services treated as containers when owned** | Services such as Amazon S3 buckets, RDS databases, or Azure SQL instances that the team owns and configures should appear as Container elements (not as external Software Systems), because the team owns the schema or bucket even if the host infrastructure is managed elsewhere (https://c4model.com/abstractions/container). Flag if they are incorrectly externalised. |
| E9 | **Notation is explained or consistent** | Every colour, shape, border style, icon, and element-size variation carries a documented meaning in the key/legend. Unexplained visual variation FAILS (https://c4model.com/introduction: "Notation … is not explained or is inconsistent"). |

---

## 4. Relationship checks

Source: https://c4model.com/diagrams/checklist (relationships section) and
https://c4model.com/diagrams/notation (relationship requirements).

| ID | Check | PASS condition |
|----|-------|----------------|
| R1 | **Every relationship is directed** | All lines carry a directional arrowhead. Bidirectional or undirected lines FAIL unless the diagram type explicitly permits them (e.g. a Dynamic diagram may use numbered sequence arrows) (https://c4model.com/diagrams/notation: "Every line should represent a unidirectional relationship"). |
| R2 | **Every relationship has a specific label** | Every arrow carries a label describing the intent or data flow. Generic one-word labels such as "Uses", "Calls", or "Connects to" FAIL — the label must convey what is being communicated or requested (https://c4model.com/diagrams/notation: "Try to be as specific as possible with the label, ideally avoiding single words like, 'Uses'"). |
| R3 | **Label direction matches arrow direction** | The label text reads in the same direction as the arrow (dependency or data flows in the direction the arrow points). A label inconsistent with its arrowhead FAILS. |
| R4 | **Cross-container relationships carry a technology / protocol** | Any relationship that crosses a Container boundary (representing inter-process communication) must be labelled with the technology or protocol used (e.g. "HTTPS/REST", "gRPC", "AMQP 0-9-1"). Missing protocol on an inter-container line FAILS (https://c4model.com/diagrams/notation). |
| R5 | **No unlabelled relationships** | Relationships with no label at all FAIL. Refer also to R2 — both absence and excessive vagueness are failures. |
| R6 | **Relationship notation is explained** | Every arrowhead style, line style, and colour variation on relationships is documented in the key/legend. Undocumented visual distinction FAILS. |

---

## 5. Anti-patterns to look for

The following are the official "Common diagramming problems" from
https://c4model.com/introduction, plus abstraction-derived anti-patterns.
Check each one explicitly during review.

### Single-diagram problems (https://c4model.com/introduction)

- Notation (colour, shapes, element sizes, line styles, etc.) is not explained
  or is inconsistent.
- The purpose and meaning of elements is ambiguous.
- Relationships between elements are missing.
- Relationships between elements are unlabelled.
- Generic terms such as "business logic" are used.
- Acronyms and abbreviations are not explained.
- Technology choices are missing.
- Levels of abstraction are mixed.

### Cross-diagram / collection problems (https://c4model.com/introduction)

- Notation is not consistent between diagrams in the same set.
- Naming of elements is not consistent between diagrams in the same set.
- The logical reading order of diagrams in the set is not clear.
- There is no clear transition between one diagram and the next.

### Abstraction-misuse anti-patterns

- **Docker container labelled as C4 Container** — a Docker/OCI container
  belongs on a Deployment diagram as a Deployment Node, not as a Container
  in a static structure diagram (https://c4model.com/abstractions/container,
  https://c4model.com/diagrams/deployment).
- **Component treated as separately deployable** — components are not
  deployable units; only the container that hosts them is
  (https://c4model.com/abstractions/component).
- **Single-word relationship label** — "Uses" is the canonical example of a
  label too vague to be useful (https://c4model.com/diagrams/notation).
- **Technology omitted on a container or inter-container line** — this is one
  of the most common failures on Container and Component diagrams
  (https://c4model.com/diagrams/notation).
- **Managed cloud data service externalised incorrectly** — S3 buckets, RDS
  instances, Azure SQL databases owned by the team are containers, not
  external systems (https://c4model.com/abstractions/container).
- **Message bus shown as a container instead of its queues/topics** — model
  the individual queues and topics as containers (data stores); the bus itself
  is infrastructure, not a C4 Container
  (https://c4model.com/abstractions/queues-and-topics).

---

## 6. Ground truth and verdict format

### Ground truth

The strongest review compares the diagram against the actual source code or
authoritative specification when they are available. In that mode, the diagram
must accurately reflect what the code does: element names, technology choices,
relationship directions, and protocols should match the running system.
State explicitly in the verdict: "Reviewed against source code at \<path\>"
or "Reviewed against specification \<name, version\>".

When source code or a specification is not available, the review evaluates
C4-method correctness only — i.e. whether the diagram conforms to the official
c4model.com definitions, notation requirements, and checklist. State this
limitation explicitly: "No source code or spec provided; review covers
C4-method correctness only."

### Verdict format

Produce one structured verdict per diagram reviewed. Use this structure:

```
## Verdict: <diagram title or file name>

**Ground truth basis:** [source code at <path> | spec <name/version> | C4-method correctness only]
**Diagram type:** [declared type, or "not declared"]
**Overall:** PASS | PASS_WITH_CONCERNS | FAIL

### Checks

| ID | Result | Finding | Suggested fix |
|----|--------|---------|---------------|
| G1 | PASS   | Title reads "Container diagram for Order Service" | — |
| E6 | FAIL   | Element "api-container" labelled as "Docker container running the API" — this is a Deployment Node, not a C4 Container | Rename to "Order API" (Container: Node.js 20 / Express); move the Docker runtime detail to a Deployment diagram |
| R2 | FAIL   | Arrow from "Web App" to "Order Service" labelled "Uses" | Replace with a specific label, e.g. "Submits order request [HTTPS/REST]" |
...

### Summary

<2–4 sentences: number of checks evaluated, failures, highest-priority fixes>
```

Rules for the verdict table:

- List every check that was evaluated. Do not silently skip N/A checks — mark
  them N/A with a one-line rationale.
- For every FAIL, the "Suggested fix" must be concrete and specific — not
  "add a label" but "replace 'Uses' with 'Submits payment request
  [HTTPS/REST]'".
- Include the location of each finding (element name, relationship endpoints,
  or diagram region) so the author can find it without a verbal walkthrough.
- A PASS_WITH_CONCERNS verdict means all hard checks pass but one or more
  advisory issues (e.g. a label that is specific but could be more precise,
  or a technology shown at the wrong granularity) were found.
