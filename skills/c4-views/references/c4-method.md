# C4 Model — Method Reference

> Source of truth: **https://c4model.com/** (by Simon Brown). Claims are cited inline.

## Table of Contents

1. [Core abstractions](#1-core-abstractions)
2. [Diagram types](#2-diagram-types)
3. [Notation principles](#3-notation-principles)
4. [Best practices](#4-best-practices)
5. [Common mistakes / anti-patterns](#5-common-mistakes--anti-patterns)
6. [Tooling](#6-tooling)

---

## 1. Core abstractions

> "A software system is made up of one or more containers (applications and data stores), each of which contains one or more components, which in turn are implemented by one or more code elements (classes, interfaces, objects, functions, etc). And people (actors, roles, personas, named individuals, etc) use the software systems that we build."
> — https://c4model.com/abstractions

C4 is **abstraction-first**: its abstractions reflect how software architects and developers think about and build software — pick the model first, then choose any notation that renders it.

### Hierarchy

```
Person
  └─ uses ─► Software System
                └─ contains ─► Container(s)
                                  └─ contains ─► Component(s)
                                                    └─ implemented by ─► Code elements
```

### Abstraction definitions

| Abstraction | Definition | Key rules |
|-------------|-----------|-----------|
| **Person** | An actor, role, persona, or named individual who uses the software systems. | May be internal or external to the organisation. |
| **Software System** | The highest level of abstraction — delivers value to users (human or automated). Typically one team, one repo, deployed together. | NOT a product domain, bounded context, feature team, or squad. https://c4model.com/abstractions/software-system |
| **Container** | **An application or a data store** — a separately deployable/runnable unit with its own process space. | See "Container ≠ Docker" below. https://c4model.com/abstractions/container |
| **Component** | A grouping of related functionality behind a well-defined interface **inside** a container. | Components are **not** separately deployable — the container is the deployable unit. All components in a container share one process space. https://c4model.com/abstractions/component |
| **Code** | Classes, interfaces, enums, functions, objects — the programming-language building blocks that implement a component. | https://c4model.com/abstractions/code |

### Container ≠ Docker

> **"Not Docker! In the C4 model, a container represents an application or a data store. A container is something that needs to be running in order for the overall software system to work."**
> — https://c4model.com/abstractions/container

Examples of containers (each is a separately deployable unit):

- Server-side web application (Tomcat / IIS / Rails / Node)
- Client-side single-page application (SPA — Angular, React, etc.)
- Client-side desktop application
- Mobile app
- Server-side console application or batch process
- Serverless function (AWS Lambda, Azure Function)
- Database (schema in MySQL, SQL Server, MongoDB, Neo4j, etc.)
- Blob / content store (Amazon S3, Azure Blob Storage, CDN)

**Non-obvious cases** (https://c4model.com/abstractions/container):

| Scenario | Correct modelling |
|----------|-------------------|
| Managed cloud data service (Amazon S3, Amazon RDS, Azure SQL) | Treat as a **container** — you own the bucket/schema even though it is hosted externally. |
| Server-side web app that also ships a significant SPA | **Two containers** — two separate process spaces communicating (e.g. via JSON/HTTPS). |
| Message bus (SQS, Kafka, RabbitMQ) | The **queues/topics are containers** (they are data stores); the bus itself is not modelled as a container. This exposes real producer→consumer coupling. See https://c4model.com/abstractions/queues-and-topics |

> Note: "Docker container" legitimately reappears at the **Deployment diagram** level as a **deployment node** — that is the correct layer for infrastructure topology. See §2.

---

## 2. Diagram types

C4's core set covers **static structure** (https://c4model.com/diagrams). "The different levels of zoom allow you to tell different stories to different audiences."

> **"You don't need to use all 4 levels of diagram; only those that add value — the system context and container diagrams are sufficient for most software development teams."**
> — https://c4model.com/diagrams

### Core diagrams

| Level | Name | What it shows | Scope | Audience | Recommended for all teams? |
|-------|------|---------------|-------|----------|---------------------------|
| **L1** | System Context | The system in scope + the people and external software systems it interacts with. "Big picture." You don't own what sits outside the boundary. | One software system | "Everybody, both technical and non-technical people, inside and outside the software development team." | **Yes** |
| **L2** | Container | Zoom into the system boundary: the applications and data stores (containers), their technology, and how they communicate. | One software system | "Technical people inside and outside the software development team; including software architects, developers and operations/support staff." | **Yes** |
| **L3** | Component | Decompose **one container** into its components — responsibilities, technology, and implementation details. | One container | "Software architects and developers." | **No** — create only if it adds value; consider automating generation for long-lived docs. |
| **L4** | Code | How **one component** is implemented — UML class diagram, ER diagram, etc. | One component | "Software architects and developers." | **No** — "not recommended for anything but the most important or complex components"; most IDEs can generate this on demand. Ideally auto-generated. |

### Supplementary diagrams

| Diagram | What it shows | Scope | Audience |
|---------|---------------|-------|----------|
| **System Landscape** | Multiple software systems across an organisation — the view one step above L1. | An enterprise / organisation / department | Technical and non-technical; inside and outside the team. https://c4model.com/diagrams/system-landscape |
| **Dynamic** | How elements from the static model collaborate at runtime (user story, use case, feature). Based on a UML communication diagram; numbered interactions indicate ordering. | Any scope from the static model | Technical and non-technical. https://c4model.com/diagrams/dynamic |
| **Deployment** | How instances of systems/containers are deployed onto infrastructure within a specific environment (production, staging, development). Based on a UML deployment diagram. **Deployment node** = where an instance runs: a physical server, VM, PaaS, **a Docker container**, an app server, IIS. Nodes can be nested. Also infrastructure nodes (DNS, load balancers, firewalls). Cloud vendor icons are acceptable — include them in the diagram legend. | One deployment environment | "Technical people … including software architects, developers, infrastructure architects, and operations/support staff." https://c4model.com/diagrams/deployment |

> **Docker container at the Deployment level:** This is the canonical place where a Docker container appears — as a **deployment node**, not as a C4 abstraction. The abstraction level's "container" (app/data store) and the deployment level's "Docker container" (runtime host) are distinct concepts.

---

## 3. Notation principles

> "The C4 model is **notation independent**, and doesn't prescribe any particular notation. That said, you still need to ensure that your diagram notation makes sense, and that the diagrams are comprehensible. A good way to think about this is to ask yourself whether each diagram can stand alone, and be (mostly) understood without a narrative."
> — https://c4model.com/diagrams/notation

### Elements — required fields

Every element must carry (https://c4model.com/diagrams/notation):

| Field | Rule |
|-------|------|
| **Name** | Present on every element. |
| **Type** | Explicitly stated: Person, Software System, Container, or Component. |
| **Technology** | Required on every container and component. |
| **Description** | Short description giving an "at a glance" view of key responsibilities. |

### Relationships — required fields

| Field | Rule |
|-------|------|
| **Direction** | Every line represents a **unidirectional relationship** — no bidirectional arrows. |
| **Label** | Every line is labelled, consistent with the direction and intent of the relationship. "Try to be as specific as possible … ideally avoiding single words like, 'Uses'." |
| **Technology/protocol** | Required on relationships between containers (inter-process communication). |

### Diagrams — required metadata

| Requirement | Detail |
|-------------|--------|
| **Title** | Describes the diagram type and scope, e.g. "System Context diagram for Internet Banking System." |
| **Key/legend** | Explains all notation: shapes, colours, border styles, line types, arrowheads. |
| **Acronyms** | All acronyms and abbreviations are understandable by the intended audience, or explained in the legend. |

---

## 4. Best practices

| Practice | Rationale / Source |
|----------|-------------------|
| **Abstraction-first, not notation-first** | Pick the model's abstractions; then choose notation that renders them clearly. https://c4model.com/abstractions |
| **"Maps of your code" zoom metaphor** | Each level tells a different story to a different audience — like zooming in and out on a map. https://c4model.com/introduction |
| **Use only the levels that add value** | L1 + L2 are sufficient for most teams. L3 and L4 are opt-in. https://c4model.com/diagrams |
| **One abstraction level per diagram** | Never mix levels within a single diagram. Derived from per-diagram scope definitions and the "levels of abstraction are mixed" anti-pattern. |
| **Single-thing scope per static diagram** | System Context and Container diagrams focus on **one software system**; Component on **one container**; Code on **one component**. https://c4model.com/diagrams/* |
| **Self-explanatory test** | Ask: can this diagram stand alone and be mostly understood without a narrative? https://c4model.com/diagrams/notation |
| **Consistency across a diagram set** | Notation, naming, and reading order must be consistent between diagrams. https://c4model.com/introduction |
| **Modelling over diagramming for long-lived docs** | Build one model (directed graph of nodes and edges) and render multiple views; renaming and querying become easy. "A model is just data!" https://c4model.com/tooling |
| **Whiteboards for design sessions; tools for long-lived docs** | https://c4model.com/tooling |

---

## 5. Common mistakes / anti-patterns

### Official "Common diagramming problems" (https://c4model.com/introduction)

**Single-diagram problems:**

- Notation (colour coding, shapes, element sizes, line styles, etc.) is not explained or is inconsistent.
- The purpose and meaning of elements is ambiguous.
- Relationships between elements are missing.
- Relationships between elements are unlabelled.
- Generic terms such as "business logic" are used.
- Acronyms and abbreviations are not explained.
- Technology choices are missing.
- Levels of abstraction are mixed.

**Cross-diagram (collection) problems:**

- The notation is not consistent between diagrams.
- The naming of elements is not consistent between diagrams.
- The logical order in which to read the diagrams is not clear.
- There is no clear transition between one diagram and the next.

### C4-specific anti-patterns

| Anti-pattern | Why it's wrong | Correct approach |
|-------------|----------------|-----------------|
| Labelling a Docker/OS container as a C4 "Container" | In C4, a container = an app or data store. A Docker container is a deployment node. | Reserve "Container" for an app or data store; place Docker containers on the Deployment diagram. https://c4model.com/abstractions/container vs https://c4model.com/diagrams/deployment |
| Treating a component as separately deployable | Components are NOT deployable — only the container is. | Show a Component inside its parent Container; represent it as deployable only by promoting it to a Container. https://c4model.com/abstractions/component |
| Single-word relationship labels (e.g. "Uses") | Gives no information about intent or protocol. | Write specific labels: "Reads customer records from (JDBC)", "Sends password reset email via (SMTP)". https://c4model.com/diagrams/notation |
| Missing technology on a container/component | Technology is a required field. | Always add the technology stack/runtime to every container and component. |
| Missing protocol on an inter-container relationship | Inter-process technology is a required field. | Label every container-to-container arrow with the protocol/technology (e.g. HTTPS, gRPC, AMQP). |
| Modelling the message bus as a container | Obscures producer→consumer coupling; ties model to deployment topology. | Model the **queues/topics** as containers; omit the bus itself. https://c4model.com/abstractions/queues-and-topics |

### Review checklist (normative grading rubric — https://c4model.com/diagrams/checklist)

Use these as pass/fail checks when reviewing any C4 diagram:

**General**
- [ ] The diagram has a title.
- [ ] The meaning of the diagram (notation, etc.) is understandable.

**Elements**
- [ ] Every element has a name.
- [ ] You understand each element's type / level of abstraction.
- [ ] You understand what every element does.
- [ ] You understand the technology of each element where applicable.
- [ ] The meaning of all acronyms, colours, shapes, icons, border styles, and element sizes is understood.

**Relationships**
- [ ] Every arrow has a label describing intent.
- [ ] The description matches the relationship direction.
- [ ] You understand the technology of each relationship where applicable.
- [ ] The meaning of all acronyms, colours, arrowheads, and line styles is understood.

---

## 6. Tooling

C4 is **tooling independent** (https://c4model.com/tooling). The official page distinguishes two categories and argues modelling is preferable to diagramming for long-lived documentation.

| Category | Characteristic | Trade-off |
|----------|---------------|-----------|
| **Modelling (recommended)** | Builds one non-visual model; renders multiple views; understands semantics; assists with validation; easy renaming and querying; data friendly for diff/PR. | Usually requires learning a DSL or dedicated editor. |
| **Diagramming** | "Boxes and lines" editors. Quick to start. | "Can't provide any assistance or validation of your diagrams"; "can't query the diagrams"; rename-everywhere is manual; "data formats that are hard to diff." |

### Official tool list (https://c4model.com/tooling — verified 2026-06-15)
<!-- last-verified: 2026-06-15 — re-verify against c4model.com/tooling periodically -->

**Modelling tools (recommended tab):**

| Tool | Notes |
|------|-------|
| **Structurizr** | **"The original tool designed to support the C4 model — models as code, manual layout, AI friendly."** Simon Brown's own tool. Open-core DSL committed to source control; paid web platform. Treat as the canonical/reference modelling tool. |
| **IcePanel** | Commercial modelling tool (paid sponsor). "Create interactive diagrams. In minutes." |
| Archi | ArchiMate modelling toolkit with C4 support. |
| C4InterFlow | Architecture-as-Code approach. |
| Gaphor | Open-source modelling tool. |
| Model (Go) | Go-based modelling tool. |
| Overarch | Data-model driven; generates PlantUML, C4+UML. |
| pumla | PlantUML reuse and management. |
| PyStructurizr | Python DSL inspired by Structurizr. |
| RDB modeling | Simplified C4 in YAML. |

**Diagramming tools tab:**

| Tool | Notes |
|------|-------|
| **C4-PlantUML** | "Combines the benefits of PlantUML and the C4 model." Community PlantUML stdlib of C4 macros. Samples reproduce official C4 model examples by Simon Brown. |
| **Mermaid** | Built-in C4 syntax (`C4Context`, `Container`, `ContainerDb`, `System_Ext`, `Container_Boundary`, …). Free/OSS; renders in GitHub, GitLab, and many docs tools. **Flag: Mermaid's own C4 spec states verbatim: "C4 Diagram: This is an experimental diagram for now. The syntax and properties can change in future releases."** |
| **draw.io** | General client-side diagram editor. |
| Archinsight | Architecture-as-code language. |
| BAC4 Standalone | Browser-only React modeller. |
| C4 Modelizer | React-based modeller. |
| c4builder | Node CLI, text-based. |
| C4Sharp | .NET library. |
| CUE4Puml4C4 | CUE → PlantUML. |
| Diagrams | Cloud architecture in Python. |
| EasyC4 Diagram Creator | PlantUML/Mermaid C4 → .drawio. |
| Keadex Mina | Serverless C4 IDE. |

### Practical guidance for diagram generation

- **Structurizr DSL** is the recommended target for new long-lived documentation (modelling, canonical, Simon Brown's own).
- **C4-PlantUML** and **Mermaid** are practical targets for diagrams-as-code generation embedded in docs or pipelines. Mermaid has the lowest friction (renders natively in GitHub/GitLab) but flag its C4 mode as experimental.
- **Excalidraw is not on the c4model.com tool list.** Do not recommend it as a C4 tool.
- **draw.io** appears under its own name (not "diagrams.net") on the official list.
