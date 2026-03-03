# Phase 2: Context & Memory preparation

Turn interview answers into actual files the agent will read. This is the tangible output of Phase 1 -- don't skip it. Each file should be drafted, presented to the user for review, and only saved after approval.

## 2a. Write context files

Draft the following files from interview answers. Present each to the user before saving. All paths are relative to `.datagen/agent/<agent-name>/`.

| File | Source | Content |
|------|--------|---------|
| `context/output-template.md` | 1a (ideal output) | Example or template of what good output looks like |
| `context/criteria.md` | 1a (rules, judgment) | Decision rules, scoring rubrics, filtering logic |
| `context/domain-context.md` | 1c (domain knowledge) | Background knowledge, glossaries, edge cases, industry terms |

For each file:
1. Draft the content based on what the user said in the interview
2. Present it to the user: "Here's what I drafted for `context/criteria.md` -- does this capture your rules correctly?"
3. Iterate until approved, then save to `.datagen/agent/<agent-name>/context/`

If the user provided reference lists or lookup tables (from 1c), save each as its own file in `.datagen/agent/<agent-name>/context/` (e.g., `context/target-accounts.md`, `context/icp-definition.md`).

## 2b. Write memory files

Create memory files from interview answers about preferences and feedback.

**`.datagen/agent/<agent-name>/memory/preferences.md`** -- from 1c answers (user rules, filters, scoring weights, output format preferences):

```markdown
# Preferences

## Filters
- <filter rules from interview>

## Scoring weights
- <weights from interview>

## Output format
- <format preferences from interview>
```

**`.datagen/agent/<agent-name>/memory/feedback_learnings.md`** -- from 1d answers (feedback loop design). Create the template structure:

```markdown
# Feedback Learnings

## Skip patterns
<!-- Patterns learned from user feedback. The agent reads this before filtering steps. -->

## Quality signals
<!-- Positive patterns that indicate good results -->
```

If the user said they want auto-learn (from 1d), note that in the file header. If review-first, add a comment reminding the agent to propose changes before writing.

## 2c. Checkpoint -- confirm all files

List every file created in Phase 2. Use `AskUserQuestion`:

```
AskUserQuestion:
  question: "Here are the context and memory files I've created. Review the list -- anything missing or wrong?"
  options:
    - "Looks good, continue" -- proceed to Phase 3
    - "Need to add more files" -- user has additional context to capture
    - "Need to revise a file" -- user wants to edit something
```

Only proceed to Phase 3 after explicit approval.
