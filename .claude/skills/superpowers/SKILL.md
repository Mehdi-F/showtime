# superpowers

Structured development methodology for AI agents: Brainstorm → Plan → Execute → Test → Review.

## Trigger

`/superpowers` — Use for complex features, refactors, or multi-file changes. Can also invoke sub-skills like `/superpowers:plan`, `/superpowers:tdd`, `/superpowers:review`.

## Workflow phases

### 1. **Brainstorm** 🧠
Ask clarifying questions before coding:
- What's the goal and why?
- What are edge cases or constraints?
- Any existing patterns to follow?
- Who's affected by this change?

### 2. **Plan** 📋
Create a task breakdown:
- List sub-tasks (5–15 minute chunks each)
- Identify critical files / dependencies
- Spot architectural decisions needed
- Estimate complexity

### 3. **Execute** 🚀
Develop with structured steps:
- Follow the plan (loop on each task)
- Check in after each task completes
- Adjust plan if needed (don't surprise)
- Use sub-agents for parallelizable work

### 4. **TDD (RED-GREEN-REFACTOR)** ✅
For significant logic:
- **RED**: Write test showing failure
- **GREEN**: Minimal code to pass test
- **REFACTOR**: Clean up, extract, optimize
- Run full test suite after each phase

### 5. **Review & Ship** 🎯
Before merging:
- Code review (style, patterns, security)
- Manual testing of golden path + edge cases
- Commit with clear message
- Push to designated branch

## Example invocation

```
/superpowers:plan
Goal: Add friend activity feed to profile
Constraints: Must load in <500ms, support offline cache
```

Then follow the plan breakdown, executing each task methodically.

## Best practices

- **State assumptions** before digging in
- **One task = one commit** (small, reviewable changes)
- **Test as you go** (don't defer testing)
- **Pair with /caveman** for concise updates between tasks
- **Escalate blockers early** (don't spin on unknowns)

## Sub-commands

- `/superpowers:plan` — Just the planning phase
- `/superpowers:tdd` — Activate TDD cycle for this change
- `/superpowers:review` — Code review checklist
- `/superpowers:ship` — Pre-merge validation

## Token efficiency

Superpowers + Caveman = structured work + terse output = efficient long sessions.
