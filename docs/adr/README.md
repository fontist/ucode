# Architecture Decision Records

Each file in this directory records one architectural decision: the
context that drove it, the alternatives considered, and the
consequences. The aim is to preserve the *why* so that future
contributors don't re-litigate settled questions or — worse —
unknowingly reverse a decision whose reason is no longer obvious
from the code.

## Format

Michael Nygard's ADR template. Each file is named
`NNNN-kebab-case-title.md` (zero-padded sequence, monotonic). The
body has these sections:

- **Title** (H1, repeats the file slug)
- **Status** — Accepted, Superseded by ADR-NNNN, etc.
- **Context** — what's the situation, what forces are at play
- **Decision** — what we chose, in one or two sentences
- **Consequences** — positive, negative, and any follow-up created

ADRs are immutable once Accepted. Reversing a decision is a new ADR
that supersedes the prior one; both stay on disk so the history is
recoverable.

## Index

- [0001 — PDF library choice: mutool over hexapdf/origami](0001-pdf-library-choice.md)
