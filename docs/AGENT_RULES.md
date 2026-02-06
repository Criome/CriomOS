## Capitalization-Based Durability Ruleset for LLM Agents

This section defines a *separate* meaning of capitalization that applies **only
to filesystem paths and filenames**, not to code. It does not overlap with,
extend, or modify the capitalization rules used inside code. The two systems are
orthogonal.

Capitalization in paths encodes *durability*: the resistance of instructions to
modification by an agent. Durability is structural, not rhetorical, and is
resolved purely from path and filename.

**Durability tiers** are inferred from capitalization alone:

ALL CAPS denotes immutable law. Such files and directories define non-negotiable
constraints. They are never edited, never contradicted, loaded first, and always
win conflicts.

PascalCase denotes stable contract. Such files define durable structure and
intent. They are not edited by default; changes require explicit mandate.
Extension is permitted only when meaning is preserved, and they may not conflict
with ALL CAPS.

lowercase denotes mutable implementation. Such files contain operational detail
and may be freely edited to satisfy higher-tier constraints.

Durability composes from the *maximum tier present in the path*. A single ALL
CAPS segment makes the entire path immutable; a PascalCase filename elevates an
otherwise mutable directory. When tiers conflict, ALL CAPS prevail over
PascalCase, which prevail over lowercase. If tiers match, the nearest ancestor
in the path hierarchy prevails.

Agents must treat capitalization as authority metadata. Law is never edited.
Constraints are never weakened. Tasks requiring violation of higher-durability
paths are refused.

This mechanism provides a zero-syntax, backward-compatible authority system in
which filesystem capitalization alone determines what may bend and what must
not.

## Capitalization-Based Durability Ruleset for LLM Agents

*This section applies only to filesystem paths and filenames.* It is
**orthogonal** to capitalization rules inside code, which encode ontology.

### Core Principle

**Capitalization in paths encodes durability**: the resistance of instructions
to modification by an agent. Durability is structural, not rhetorical, and is
resolved solely from path and filename.

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

If tiers conflict, the highest tier prevails. If tiers match, the nearest
ancestor prevails.

### Conflict Resolution Order

1. **ALL CAPS**
1. **PascalCase**
1. **lowercase**

Lower tiers may not contradict higher tiers.

### Agent Guarantees

- Law is never edited.
- Constraints are never weakened.
- Capitalization is treated as *authority metadata*, not style.
- Tasks requiring violation of higher-durability paths are refused.

### Result

*A zero-syntax, backward-compatible authority system* where filesystem
capitalization alone determines what may bend and what must not.
