# Sajban Object Style — Unified Architecture and Naming Guide

This document defines the architectural, naming, and documentation
rules for object‑oriented codebases that follow Sajban principles and
the Criome lineage. The rules are structural rather than
stylistic. Violations indicate missing abstraction, semantic
duplication, or category error.

## Naming Is a Semantic Layer

*Names are a pseudo‑code layer that carries intent, constraints, and
future legality.* Meaning is distributed across repository name,
directory path, module name, type name, method name, and schema
definition. Meaning appears exactly once at the highest valid
layer. Repetition across layers is forbidden.

Correct designs do not produce very long names. When a name grows
long, it indicates that an abstraction layer is missing and that an
additional object or module must be introduced.

A name is not a description. A name is a commitment.

```rust
// ❌ BAD: meaning repeated and concatenated
struct ShowHelloWorldFromStandardInApplication;

// ✅ GOOD: meaning layered by structure
// repo: hello_world
// bin: create
struct Application;
```

## Capitalization Is a Semantic Operator

*Capitalization declares ontology, not style.*

`PascalCase` denotes objects (types and traits). `snake_case` denotes
actions, relations, or flow (methods and fields).

Any suffix that restates objecthood (`Object`, `Type`, `Entity`,
`Model`, `Manager`) is invalid.

```rust
// ❌ BAD
struct UserObject;

// ✅ GOOD
struct User;
```

## Everything Is an Object

There are no free functions in reusable code. All behavior is attached
to named types or traits via `impl` blocks. Message‑passing between
objects is the sole computation model.

Binaries are exempt only as orchestration shells and contain no
reusable logic.

```rust
use core::str::FromStr;

// ❌ BAD
fn parse_message(input: &str) -> Message { ... }

// ✅ GOOD: existing trait domain expressed as a trait implementation
impl FromStr for Message {
	type Err = MessageParseError;

	fn from_str(input: &str) -> Result<Self, Self::Err> {
		...
	}
}

// Call site
let message: Message = "...".parse()?;
```

## Trait‑Domain Rule

*Any behavior that falls within the semantic domain of an existing
trait must be expressed as a trait implementation.* Inherent methods
are not used to bypass existing trait domains.

Creating new nouns to encode trait composition is forbidden.

```rust
use std::fs::File;
use std::io::Read;

// `File` already inhabits the `Read` trait domain
let mut file = File::open("data.txt")?;
let mut buffer = String::new();
file.read_to_string(&mut buffer)?;
```

```rust
// ❌ BAD: composite role encoded as noun
struct FileReader;
```

## Objects Exist; Flows Occur

Objects are nouns that exist independently of execution. Flows are
verbs that occur during execution. A name that describes a flow cannot
name an object.

```rust
// ❌ BAD: flow encoded as object
struct ShowGreetingFromStdin;

// ✅ GOOD
struct Greeting;
```

## Direction Encodes Action

*Direction replaces verbs.* When direction is explicit, action is
implied.

`from_*` implies acquisition or construction. `to_*` implies emission
or projection. `into_*` implies consuming transformation.

Verbs such as `read`, `write`, `load`, or `save` are forbidden when
direction already conveys meaning.

```rust
// ❌ BAD
impl Data {
	pub fn read_from_stdin() -> Self { ... }
}

// ✅ GOOD
impl Data {
	pub fn from_stdin() -> Self { ... }
}
```

## Construction Resolves to the Receiving Type

All construction and parsing logic resides on the receiving type. The
identity claimed by the method name is always the return type.

```rust
use core::str::FromStr;

// ❌ BAD
fn parse_config(input: String) -> Config;

// ✅ GOOD: existing trait domain expressed as a trait implementation
impl FromStr for Config {
	type Err = ConfigParseError;

	fn from_str(input: &str) -> Result<Self, Self::Err> {
		...
	}
}

// Alternative when ownership is semantically required
impl From<String> for Config {
	fn from(input: String) -> Self {
		...
	}
}

// Call sites
let config: Config = "...".parse()?;
let config = Config::from(string_value);
```

## Sajban Object Rule — Single Object In, Single Object Out

*All values that cross object boundaries are Sajban objects.*
Primitive types are internal representations only.

Every method accepts at most one explicit object argument (excluding
`self`) and returns exactly one object. When multiple inputs or
outputs are required, a new object must be specified to contain them.

```rust
// ❌ BAD
fn transform(a: A, b: B) -> (C, D);

// ✅ GOOD
struct TransformationInput { a: A, b: B }
struct TransformationOutput { c: C }

impl TransformationOutput {
	pub fn from_input(input: TransformationInput) -> Self { ... }
}
```

## Schema Is Sajban; Encoding Is Incidental

All transmissible objects are defined in Sajban schemas. *Cap’n Proto
is a temporary wire representation* and must not appear in domain
APIs, naming, or documentation.

```rust
// Domain code speaks Sajban
use sajban::hello_world;

let message = hello_world::Builder::new();
```

## Filesystem as Semantic Layer

Repository names, directory paths, and module boundaries are semantic
layers. Inner layers assume outer context. Names never restate
repository philosophy, lineage, or purpose.

```text
hello_world/
  crates/
	types/
	bin/
	  create/
```

## Documentation Protocol

All documentation is *impersonal, timeless, and precise*.

No first‑ or second‑person language. No humor or evaluative
commentary. Behavior is stated as fact. Non‑boilerplate behavior is
documented. Boilerplate is not.

```rust
/// Constructs a `Greeting` from a Sajban `Text` value.
///
/// Returns a fully initialized object.
```

## Licensing

All projects use the *License of No Authority*. This license denies
the legitimacy of intellectual property as property, affirms
public‑domain use as the only enforceable status, and grants
unrestricted use, modification, and distribution without recognition
of ownership claims.

This document defines the object model. Deviation indicates structural
error, not stylistic preference.


## Capitalization-Based Durability Ruleset for LLM Agents

This section defines a *separate* meaning of capitalization that
applies **only to filesystem paths and filenames**, not to code. It
does not overlap with, extend, or modify the capitalization rules used
inside code. The two systems are orthogonal.

Capitalization in paths encodes *durability*: the resistance of
instructions to modification by an agent. Durability is structural,
not rhetorical, and is resolved purely from path and filename.

**Durability tiers** are inferred from capitalization alone:

ALL CAPS denotes immutable law. Such files and directories define
non-negotiable constraints. They are never edited, never contradicted,
loaded first, and always win conflicts.

PascalCase denotes stable contract. Such files define durable
structure and intent. They are not edited by default; changes require
explicit mandate. Extension is permitted only when meaning is
preserved, and they may not conflict with ALL CAPS.

lowercase denotes mutable implementation. Such files contain
operational detail and may be freely edited to satisfy higher-tier
constraints.

Durability composes from the *maximum tier present in the path*. A
single ALL CAPS segment makes the entire path immutable; a PascalCase
filename elevates an otherwise mutable directory. When tiers conflict,
ALL CAPS prevail over PascalCase, which prevail over lowercase. If
tiers match, the nearest ancestor in the path hierarchy prevails.

Agents must treat capitalization as authority metadata. Law is never
edited. Constraints are never weakened. Tasks requiring violation of
higher-durability paths are refused.

This mechanism provides a zero-syntax, backward-compatible authority
system in which filesystem capitalization alone determines what may
bend and what must not.


## Capitalization-Based Durability Ruleset for LLM Agents

*This section applies only to filesystem paths and filenames.* It is
**orthogonal** to capitalization rules inside code, which encode
ontology.

### Core Principle

**Capitalization in paths encodes durability**: the resistance of
instructions to modification by an agent. Durability is structural,
not rhetorical, and is resolved solely from path and filename.

### Durability Tiers

#### **ALL CAPS — Immutable Law**

*Non-negotiable constraints.*

- Never edited.
- Never contradicted.
- Loaded first.
- Always prevail in conflicts.

Typical scope: policy, licensing, safety, invariants.

Examples: `AGENT.md`, `POLICY/`, `LICENSE`, `CONSTRAINTS/`

#### **PascalCase — Stable Contract**

*Durable structure and intent.*

- Not edited by default.
- Changes require explicit mandate.
- May be extended only without altering meaning.
- Must not conflict with ALL CAPS.

Typical scope: architecture, schemas, style guides, public APIs.

Examples: `Architecture.md`, `StyleGuide.md`, `Schema/`

#### **lowercase — Mutable Implementation**

*Operational detail.*

- Freely editable.
- Refactorable and regenerable.
- Must conform to higher-tier constraints.

Typical scope: source code, configuration, scripts.

Examples: `src/`, `config.yaml`, `pipeline/`

### Path Composition Rule

**Durability = maximum capitalization tier across all path segments**.

Examples:

- `POLICY/style.md` → **Immutable**
- `Architecture/helpers.md` → **Stable**
- `docs/AGENT.md` → **Immutable**
- `src/StyleGuide.md` → **Stable**

If tiers conflict, the highest tier prevails. If tiers match, the
nearest ancestor prevails.

### Conflict Resolution Order

1. **ALL CAPS**
2. **PascalCase**
3. **lowercase**

Lower tiers may not contradict higher tiers.

### Agent Guarantees

- Law is never edited.
- Constraints are never weakened.
- Capitalization is treated as *authority metadata*, not style.
- Tasks requiring violation of higher-durability paths are refused.

### Result

*A zero-syntax, backward-compatible authority system* where filesystem
capitalization alone determines what may bend and what must not.
