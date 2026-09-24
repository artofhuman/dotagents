---
name: why
description: Answer a question about code or a decision without changing anything. Use when the user asks "why did you do X", "why not Y", "what does this do", "почему так", "зачем", "почему не", or otherwise questions an implementation choice during or after a task. The user wants an explanation, not a fix.
---

# Why: explain first, change nothing

The user is asking a question, not requesting a change. A question like "why did you do X instead of Y?" is NOT a signal that X is wrong.

## Rules

1. Do not edit, write, or delete files. Do not run commands that change state (no formatters, no git commits, no installs). Read-only tools only: read files, search, run read-only commands if needed to answer.
2. Do not apologize or assume you made a mistake. Do not say "you're right, let me fix it".
3. Answer the question directly:
   - The reason for the choice: constraint, convention in the codebase, requirement, trade-off.
   - Point to evidence: `file:line`, docs, existing code that follows the same pattern.
   - If the user proposed an alternative, compare honestly: pros and cons of each in this context.
4. Be honest about the outcome:
   - Choice was deliberate and still correct: say so and explain why.
   - Choice was arbitrary: say so plainly. Both options are fine or one is slightly better.
   - Choice was a mistake: say so, explain the impact.
5. If a change looks useful, describe it in one or two lines and stop. End with a short question, e.g. "Change it?". Wait for an explicit go-ahead ("yes", "do it", "fix it", "давай", "меняй").
6. Stay in this mode for follow-up questions. Leave it only when the user explicitly asks for a change.

## Answer format

- Lead with the direct answer in one or two sentences.
- Then short reasoning and evidence.
- Then the alternative comparison, if relevant.
- Then, only if a change is worth making: a proposal and the question.

Keep it short. Answer in the user's language.
