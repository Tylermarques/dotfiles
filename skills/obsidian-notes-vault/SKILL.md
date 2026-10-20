---
name: obsidian-notes-vault
description: How to read from and write to Tyler's Obsidian vault at ~/Notes. Use whenever a task mentions "my notes", "the vault", "Obsidian", a note or meeting from the vault, or asks to save research, a summary, or a write-up as a note. Enforces the hard rule that agents only ever write inside "08 - AI/".
---

# Tyler's Obsidian Notes Vault

The vault lives at `~/Notes`. It is an Obsidian vault, a git repo with automatic
"vault backup" commits from the obsidian-git plugin, and it syncs across
machines. Treat it as a personal knowledge base you may **read anywhere** and
**write in exactly one place**.

## The one hard rule

**Only create, edit, or delete files inside `~/Notes/08 - AI/`.** Every other
path in the vault is read-only for agents, without exception:

- Do not edit, rename, move, or delete notes in any other folder, even to fix a
  typo, add a link, or update frontmatter.
- Do not touch `.obsidian/`, `99 - Meta/`, `*.sync-conflict-*` files, or
  `*.excalidraw.md` files (they hold compressed drawing data).
- Do not run `git` inside the vault. obsidian-git commits on its own schedule.
- If the user asks you to write somewhere else, stop and say the rule exists.
  Offer to put the content in `08 - AI/` instead, or wait for the user to
  explicitly confirm they want this rule overridden for that one file.

The directory name has spaces: `08 - AI`, not `08-AI`. Always quote paths.

## Vault layout

Numbered folders follow a PARA-style scheme.

| Folder | What lives there | Agent access |
|---|---|---|
| `000 Index.md` | Top-level index and open-task dashboard | read |
| `01 - Projects/` | Active projects, one subfolder or note per project (Good Start Labs, GoBolt, Finesse, ...) | read |
| `02 - Areas/` | Ongoing life areas (home, health, clubs, note organization) | read |
| `03 - Resources/` | Reference material by topic (Computer Vision, Data Infra, Engineering Practices, Python) | read |
| `04 - Permanent/` | Evergreen notes and `Clippings/` of saved articles | read |
| `05 - Fleeting/` | Quick captures, `Inbox/`, ideas not yet filed | read |
| `06 - Daily/` | Daily notes at `YYYY/MM-MMMM/YYYY-MM-DD-dddd.md` | read |
| `07 - Archives/` | Retired projects and notes | read |
| `08 - AI/` | **Agent output.** Research write-ups, plans, analyses, generated docs | **read + write** |
| `09 - Meetings/` | Auto-generated meeting notes, one file per call | read |
| `99 - Meta/` | Templates, Attachments, Excalidraw libs, citations.bib | read |
| vault root | ~100 loose notes, including many person notes (`Ian Barrett.md`) | read |

## Reading the vault

Use `grep`, `find`, `ls`, and `sed -n` directly. Quote every path.

```bash
ls ~/Notes/"09 - Meetings" | tail -20
grep -ril "terrain" ~/Notes/"01 - Projects" ~/Notes/"08 - AI"
grep -rl "\[\[Lauren Chin\]\]" ~/Notes/"09 - Meetings"
```

Wikilinks resolve by basename, so `[[Ian Barrett]]` points at
`~/Notes/Ian Barrett.md` wherever it sits. To find a link target, search by
filename: `find ~/Notes -name "Ian Barrett.md"`.

### Meeting notes (`09 - Meetings/`)

Files are named `YYYY-MM-DD <Title>.md`. Untitled calls carry a Google Meet
code as the title (`2026-09-02 eud-huyj-sea.md`). Duplicates get a numeric
suffix like `(239)`.

Each note has frontmatter (`created`, `tags: [meeting]`, `participants` as
wikilinks, `duration_minutes`, `meeting_id`, `source: meeting-notes`), then a
`## Summary` section with a two-paragraph recap plus Decision / Action Item /
Key Point bullets, then a full `## Transcript`.

Transcripts run 10 to 50 KB. Read the summary first and grep the transcript for
names or keywords rather than reading whole files:

```bash
sed -n '/^## Summary/,/^## Transcript/p' ~/Notes/"09 - Meetings/2026-09-09 Goodstart-xAI - Gaming Roadmap.md"
```

To find "the call with X from a couple of days ago", list by mtime and check
summaries and `participants`. Company names often appear only in a
participant's suffix, such as `[[Arvind Manivannan (xAI)]]`, or in the summary
text. If no matching note exists, say so rather than guessing.

## Writing to `08 - AI/`

Before creating a note, check whether one already covers the topic
(`ls ~/Notes/"08 - AI"`) and update it instead of creating a duplicate.

Conventions:

- **Filename**: Title Case with spaces, `.md`, no slashes or colons.
  `Measuring Stylistic Similarity Between Images.md`.
- **Frontmatter**: at minimum `created: YYYY-MM-DD` and a `tags:` list.
  Tags are lowercase kebab-case (`ai`, `computer-vision`, `research`, `xai`).
- **Links**: use wikilinks `[[Note Name]]` to other vault notes, especially the
  meeting notes and person notes that motivated the work. External references
  use plain markdown links. Prefer arXiv abstract URLs for papers.
- **Structure**: H1 title, a one-line goal or context paragraph, then sections.
  Tables and short bullets over long prose. A `## References` section at the end
  for research notes.
- **Tasks**: `- [ ] ...` is picked up by the Tasks plugin and surfaces in the
  index dashboard. Only add tasks the user asked for.
- **Do not** use Templater syntax (`<% ... %>`). It only runs inside Obsidian
  and will be left as literal text. Write real dates and values.
- **Attachments**: do not add images or binaries. Link to external URLs or
  describe the asset instead.

Skeleton:

```markdown
---
created: 2026-09-12
tags:
  - ai
  - research
---
# Note Title

One or two sentences on what this note is for and what prompted it.

Related: [[2026-09-09 Some Meeting]], [[Some Person]]

## Section

- ...

## References

- Author, *Title*, Venue Year — https://arxiv.org/abs/xxxx.xxxxx
```

## Summary for a hurried agent

1. Read anything under `~/Notes` with quoted paths.
2. Write only under `~/Notes/08 - AI/`. Nowhere else, no git.
3. Check for an existing note first, use frontmatter, wikilink the meetings and
   people that motivated the note.
4. If asked to write elsewhere, flag the rule and wait for explicit confirmation.
