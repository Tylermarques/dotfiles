# Shared instructions for every agent session

This file is the one copy. `~/dotfiles/claude/CLAUDE.md` is a symlink to it, and `~/.claude/CLAUDE.md` links there.

## Writing style

I generally prefer simplified technical English (ASD-STE100) for prose I read or act on: reports, summaries, PR descriptions, commit messages, and instructions to other agents. Use the `writing-simplified-technical-english` skill for the full rules.

Avoid these sentence features. They slow human readers down, and models overuse them:

- **Inanimate subjects with action verbs** ("the config wants…", "this function knows…"). Name the real actor.
- **Stacked nouns** ("task verifier container retry policy"). Spell out how the words relate.
- **Nouns used as verbs** ("calendar it", "PR this"). Use a real verb.
- **Long gaps between related words**, such as a subject far from its verb. Split the sentence.
- **Reduced relative clauses** ("the test the probe skipped"). Write "the test that the probe skipped".
- **Rare word combinations and jargon.** Prefer common phrasing.

## Engineering ethos

The `coding-ethos` skills, role agents and hooks come from `~/Projects/agents/coding-ethos`. That checkout is the canonical copy. Where a skill names `~/Documents/repos/personal/coding-ethos`, use `~/Projects/agents/coding-ethos` instead. Where a skill names another person as the user, the user is Tyler.

- **Before designing, writing or reviewing code, infra, tests or MRs, load the `coding-ethos` skill, then, for code, infra or tests, the references its read-table names.** It holds Tyler's cross-project engineering ethos. A repo's own base skill or CLAUDE.md overrides it on mechanics.
- **When Tyler gives feedback on how code should be designed or how work should be done, route it** using the skill's "Keeping this current" section. Code design rules go into the matching reference under the skill's `references/` and process that holds in every session into its **How we work** part. Large-build mechanics go into `build-manager`, ticket and tracker mechanics into `intent-ledger`, repo mechanics into the repo's base skill, and client or context facts into local memory. Writing to `~/Projects/agents/coding-ethos/` is allowed from every context, including contexts whose write scope is otherwise limited to their client directory.
- **Never put client, company, product, repo, person or ticket names in `coding-ethos`.** It loads into every client's sessions.
- **To check account usage, read `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/state/rate-limits.json`.** Usage is per account, so it's a symlink to `~/.local/state/claude-usage/<accountUuid>.json`, shared by every context on that account. The status line writes it on every refresh: `five_hour`/`seven_day` `used_percentage` and `resets_at` (epoch), plus `saved_at`. It is missing on accounts that don't report usage, and an old `saved_at` means the reading is stale.
- **The shell is zsh, not bash.** Quote any argument containing `?`, `*`, `[` or `]` (URLs with query strings, jq filters like `.sha[0:8]`, kubectl `custom-columns=...`), because zsh fails with "no matches found" instead of passing them through. Don't store a command in a variable and run `$cmd`: zsh doesn't word-split it and reports "command not found: <whole string>". Use an array (`cmd=(docker run …); "${cmd[@]}"`) or a function. Arrays are 1-indexed. For bash-only syntax, run it with `bash -c '…'`.
