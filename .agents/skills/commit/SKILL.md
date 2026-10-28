---
name: commit
description: Smart commit workflow — analyze staged/unstaged git changes, auto-detect type and scope, and generate a Conventional Commits message with a bulleted body, then commit after user confirmation. Use whenever the user asks to commit changes, says /commit, 提交代码, 生成提交信息, or wants a conventional commit message written for them.
---

# Smart Commit Workflow

Work through these steps in order. The user may pass an explicit type as an argument (e.g. `/commit feat`); otherwise detect it from the changes.

## Step 1: Analyze Changes

1. Run `git status` to see all changed files.
2. Run `git diff` (and `git diff --cached`) to see specific changes.
3. Distinguish staged from unstaged changes.

## Step 2: Determine Commit Type

If the user did not specify a type, auto-detect from the changes:

- `test` — test file changes
- `docs` — documentation changes
- `chore` — build, config, dependency related
- `feat` — new feature (default)
- `fix` — bug fix
- `refactor` — code refactoring
- `style` — code style adjustments
- `perf` — performance optimization

## Step 3: Determine Scope

Infer the scope from file paths: `auth`, `podcast`, `chat`, `settings`, `user`, `api`, `models`, `services`, `core`, `ui`. Omit the scope when no clear domain matches.

## Step 4: Generate the Commit Message

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>[optional scope]: <summary>

- <Bullet point 1>

- <Bullet point 2>
```

Rules for the body bullets:

- One significant change per bullet, separated by a blank line
- Imperative mood ("Add", "Fix", "Move" — not "Adds", "Fixed", "Moving")
- Specific and concise, no trailing period, max 80 characters per line

Example:

```
refactor(podcast): restructure simplified episode card layout and add widget tests

- Move play/add to queue buttons to bottom row with metadata

- Reorganize card to show title, description, then actions

- Add proper test keys for widget testing

- Add new widget test for simplified episode card layout
```

**Never** include `Co-Authored-By:` lines.

The type prefix determines the CHANGELOG group produced by git-cliff (see root `cliff.toml`):

| Pattern | Group |
|---------|-------|
| `^feat` | 🚀 Features |
| `^fix` | 🐛 Bug Fixes |
| `^doc` | 📚 Documentation |
| `^perf` | ⚡ Performance |
| `^refactor` | 🚜 Refactor |
| `^style` | 🎨 Styling |
| `^test` | 🧪 Testing |
| `^chore` | ⚙️ Miscellaneous Tasks |

## Step 5: Wait for Confirmation

Show the generated message to the user and ask for confirmation. Cancel if not accepted — do not commit unreviewed messages.

## Step 6: Execute the Commit

1. If unstaged changes belong in the commit, `git add` the relevant files first (only the files analyzed above — never `git add -A` when unrelated changes exist).
2. Run `git commit` with the confirmed message.
3. Show the commit result (hash + summary).
