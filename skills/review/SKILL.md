---
name: review
description: "Full review of the changes since a fixed point (commit, branch, tag, or merge-base) in one merged report: Spec (does the code solve the originating task?), Correctness (bugs, via the built-in /code-review), and Standards (does the code follow this repo's documented coding standards?). Use when the user wants to review a branch, a PR, work-in-progress changes, or asks to \"review since X\"."
---

One review, one report, three axes:

- **Spec**: does the diff solve the originating task, fully and without extra scope?
- **Correctness**: bugs, found by the built-in `/code-review` skill.
- **Standards**: does the code conform to this repo's documented coding standards?

All three run in parallel in the background: Spec and Standards as sub-agents, `/code-review` as its own fork. Then they are merged into one report.

Arguments: `/review [fixed-point] [level]`. `level` (`low`…`max`) is passed through to `/code-review`.

## Process

### 1. Pin the fixed point

Use the fixed point the user gave (SHA, branch, tag, `HEAD~5`, ...). If none, use the integration branch the repo docs name (CLAUDE.md, AGENTS.md, CLAUDE.local.md), as `origin/<branch>`; if the docs name none, ask.

Capture `git diff <fixed-point>...HEAD` (three-dot, against the merge-base) and `git log <fixed-point>..HEAD --oneline`. Confirm the ref resolves (`git rev-parse`) and the diff is non-empty; fail here, not inside sub-agents. If the working tree has uncommitted changes, say so: they are not part of the reviewed range.

### 2. Fetch the task

Find the task key in the branch name and commit messages (`NDS-1234`, `PROJ-56`, `#123`, `!67`). Then, in order:

1. If `docs/agents/issue-tracker.md` exists, follow it.
2. Tracker keys like `ABC-123` with a YouTrack MCP available: `get_issue`, `get_issue_comments`, and `get_issue_links` when the issue refers to linked issues for the actual requirements. Comments often change the requirements; read them all.
3. GitHub / GitLab refs: `gh issue view` / `glab issue view`.
4. A path the user passed, or a spec file under `docs/`, `specs/`, `.scratch/` matching the branch name.
5. Nothing found: ask the user. If there is no task, skip the Spec sub-agent and say so in the report.

Fetch the task here, in the main thread, and paste its text into the Spec prompt: sub-agents may lack the tracker tools.

### 3. Collect the standards

- Repo docs on how to write code: `CLAUDE.md`, `AGENTS.md`, `CLAUDE.local.md` (and files they `@`-include), `CODING_STANDARDS.md`, `CONTRIBUTING.md`.
- The `feedback` memories from this session's auto-memory directory (see `MEMORY.md`). Sub-agents do not see memory, so pass their paths or contents explicitly.
- The **smell baseline** below.

Two rules bind the baseline:

- **The repo overrides.** A documented repo standard always wins; where it endorses something the baseline would flag, suppress the smell.
- **Always a judgement call.** Each smell is a labelled heuristic ("possible Feature Envy"), never a hard violation. Skip anything tooling already enforces.

Each smell reads *what it is* → *how to fix*:

- **Mysterious Name**: a name that doesn't reveal what it does or holds. → rename it; if no honest name comes, the design's murky.
- **Duplicated Code**: the same logic shape in more than one hunk or file. → extract the shared shape, call it from both.
- **Feature Envy**: a method that reaches into another object's data more than its own. → move it onto the data it envies.
- **Data Clumps**: the same few fields or params travelling together. → bundle them into one type.
- **Primitive Obsession**: a primitive standing in for a domain concept. → give the concept its own small type.
- **Repeated Switches**: the same `if`-cascade on the same type recurs. → polymorphism, or one shared map.
- **Shotgun Surgery**: one logical change forces scattered edits. → gather what changes together.
- **Divergent Change**: one module edited for several unrelated reasons. → split by reason to change.
- **Speculative Generality**: abstraction or hooks for needs the task doesn't have. → delete it.
- **Message Chains**: long `a.b().c().d()` navigation. → hide the walk behind one method.
- **Middle Man**: a function that mostly delegates onward. → call the real target directly.
- **Refused Bequest**: a subclass ignoring most of what it inherits. → composition instead.

### 4. Start Spec and Standards in the background

Spawn both with the Agent tool in one message, so they run in parallel.

**Spec prompt**: the diff command, commit list, the full task text with comments, and the brief: "Report: (a) requirements the task asked for that are missing or partial; (b) behaviour in the diff that wasn't asked for (scope creep); (c) requirements that look implemented but where the implementation looks wrong. Quote the task line for each finding and give `file:line`. Add a one-line fix to each finding. End with a verdict: solves the task — yes / partially / no. Under 400 words."

**Standards prompt**: the diff command, commit list, the standards files and memory paths from step 3, the smell baseline pasted in full, and the brief: "Report (a) every place the diff violates a documented standard: cite the file and the rule; (b) any baseline smell: name it and quote the hunk. Give `file:line`. Add a one-line fix to each finding. Mark documented-standard breaches as hard, smells as judgement calls. Skip anything tooling enforces. Under 400 words."

### 5. Start /code-review

In the same message as the sub-agents, invoke the `code-review` skill via the Skill tool. Args: the current branch name as the target, plus `level` if the user gave one. Never pass `--fix` or `--comment`: the user decides on fixes after reading the merged report.

It runs as a background fork and returns its findings as text in a task notification. Without `level` it reuses the last one the user typed; mention the level in the report.

### 6. Merge

Wait for all three notifications (Spec, Standards, `/code-review`); do not poll. Then write one report in the user's language, sections in this order:

1. **Task**: the task key and title, the Spec verdict, then missing / partial, scope creep, wrong implementation.
2. **Bugs**: the `/code-review` findings, most severe first, with `file:line`, the failure scenario in one line, and the verdict (CONFIRMED / PLAUSIBLE) when present.
3. **Standards**: hard violations first, then smells.

Rules:

- Keep findings inside their section; do not rerank across sections. A change can pass one axis and fail another, and mixing them lets one mask the other.
- Deduplicate: when two sections report the same root issue at the same place, keep it once in the most fitting section and add "(also: Standards)" or similar.
- Every finding ends with a short **Fix:** line: one concrete action, what to change and where. `/code-review` findings come without one; write it yourself from the code. If no fix is clear, name the decision that is needed instead.
- Finding plus fix, two lines where possible; drop sub-agent preambles.
- An axis that was skipped or failed (no task, sub-agent error) gets one line saying so, not silence.

End with a summary line: findings per section, the worst issue within each section, and whether the code solves the task.
