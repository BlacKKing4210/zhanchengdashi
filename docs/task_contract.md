# Execution Task Contract

## Identity

- Feature ID:
- Task title:
- Version:
- Accountable role owner:
- Execution task ID:
- Model/reasoning profile:
- Project adapter Skill:
- RAG Skill: `game-project-rag`
- Primary domain Skill:

## Goal

Describe one player-visible or production-visible outcome.

## Scope

- Included:
- Excluded:
- Non-goals:

## Sources And Baselines

| Source or file | Version/hash | Access |
|---|---|---|
| RAG gate receipt | | Read-only |
| RAG task receipt and context pack | | Read-only |
| Functional source | | Read-only |
| Numeric/config source | | Read-only |
| Allowed runtime file | | Write after authorization |

## Dependencies And Locks

- Dependencies:
- Shared files:
- Unique writer:
- Task-local temporary root:

## Acceptance

1. Real behavior or asset requirement.
2. Regression requirement.
3. Boundary and cleanup requirement.

## First Read-Only Receipt

Before writes, report the RAG index signature, task query, citations, loaded Skills, sources, baselines, write scope, conflicts, process state, and READY/CONCERNS/NOT READY.

## Evidence

Map each acceptance item to normal behavior, deterministic asset evidence, screenshots, manifests, or scoped static checks.

## Close Conditions

Acceptance complete, final baselines reported, temporary outputs removed, processes stopped, locks released, owner review complete, task archived, feature progress updated, and RAG refreshed if any active source changed.
