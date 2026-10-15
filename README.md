# minimize-cursor-cost-rule

**Angular-focused AI rules by Abdul Razzak** that keep Cursor (and other AI
coding tools) cheap, focused, and safe on real Angular codebases.

The assistant searches before it reads, edits only the lines that need to
change, answers without padding, and will not build, commit, delete, or touch
secrets unless you explicitly ask.

License: MIT.

---

## Install in one line

Open a terminal **in your Angular project root** (the folder with `angular.json`).

**Windows (PowerShell)**

```powershell
irm https://raw.githubusercontent.com/RazzakAnsari/minimize-cursor-cost-rule/main/install.ps1 | iex
```

**macOS / Linux / WSL**

```bash
curl -fsSL https://raw.githubusercontent.com/RazzakAnsari/minimize-cursor-cost-rule/main/install.sh | bash
```

Then fill in `.cursor/rules/project-context.mdc` and start a **new** Cursor chat.

### Preview first (nothing is written)

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/RazzakAnsari/minimize-cursor-cost-rule/main/install.ps1))) -DryRun
```

```powershell
$env:MCCR_DRYRUN = '1'; irm https://raw.githubusercontent.com/RazzakAnsari/minimize-cursor-cost-rule/main/install.ps1 | iex; Remove-Item Env:MCCR_DRYRUN
```

```bash
curl -fsSL https://raw.githubusercontent.com/RazzakAnsari/minimize-cursor-cost-rule/main/install.sh | bash -s -- --dry-run
```

`irm ... | iex` cannot take switches, so use the `[scriptblock]::Create` form or
the environment variables below when you need options.

---

## Installer settings

| PowerShell        | Bash              | Environment variable   | Default  | Meaning |
|-------------------|-------------------|------------------------|----------|---------|
| `-Target <dir>`   | `--target <dir>`  | `MCCR_TARGET`          | current folder | Angular project to install into |
| `-Rules <list>`   | `--rules <list>`  | `MCCR_RULES`           | `all`    | `all`, or a comma list such as `ng-components,ng-templates`. The four always-on rules are always included. |
| `-Tool <name>`    | `--tool <name>`   | `MCCR_TOOL`            | `cursor` | `cursor` (`.cursor/rules`), `agents` (`AGENTS.md`), `claude` (`CLAUDE.md`), or `all` |
| `-IndexIgnore`    | `--index-ignore`  | `MCCR_INDEXIGNORE=1`   | off      | Also add a `.cursorindexingignore` |
| `-DryRun`         | `--dry-run`       | `MCCR_DRYRUN=1`        | off      | Print what would happen; write nothing |
| `-Force`          | `--force`         | `MCCR_FORCE=1`         | off      | Replace existing files and allow a folder without `angular.json` |

Working from a clone instead of the web:

```powershell
git clone https://github.com/RazzakAnsari/minimize-cursor-cost-rule
& .\minimize-cursor-cost-rule\install.ps1 -Target C:\path\to\your-angular-app -DryRun
```

---

## What lands in your project

| File | Loaded | Purpose |
|------|--------|---------|
| `.cursor/rules/guardrails.mdc` | always | Things the assistant must never do on its own (wins over everything) |
| `.cursor/rules/response-style.mdc` | always | Short answers, diffs instead of whole files |
| `.cursor/rules/tool-budget.mdc` | always | Search before reading, no repeat reads, no auto-builds |
| `.cursor/rules/project-context.mdc` | always | Your stack, folders, and shortcuts - **fill this in** |
| `.cursor/rules/ng-components.mdc` | `*.component.ts` | Standalone vs NgModule, OnPush, inputs/outputs, teardown |
| `.cursor/rules/ng-templates.mdc` | `*.component.html` | Control flow, `track`, bindings, translations, a11y |
| `.cursor/rules/ng-styles.mdc` | `*.scss`, `*.css` | Tokens, no `::ng-deep`, RTL-friendly properties |
| `.cursor/rules/ng-services.mdc` | services, interceptors, guards | DI, typed HTTP, big-file handling |
| `.cursor/rules/ng-app-structure.mdc` | modules, routes, `app.config.ts` | Lazy routes, root providers |
| `.cursor/rules/ng-signals.mdc` | `*.ts` (on demand) | `signal`, `computed`, `effect`, interop |
| `.cursor/rules/ng-rxjs.mdc` | `*.ts` (on demand) | Flattening operators, teardown, errors |
| `.cursor/rules/ng-specs.mdc` | `*.spec.ts` | TestBed, HTTP mocks, no skipping tests |
| `.cursor/rules/ng-i18n.mdc` | `assets/i18n/**`, `*.xlf` | Grep keys, keep every language in sync |
| `.cursor/rules/ts-style.mdc` | `*.ts` (on demand) | No `any`, types, aliases |
| `PROMPTS.md` | you read it | Short, copy-paste prompts for common Angular tasks |
| `AGENTS.md` / `CLAUDE.md` | with `-Tool agents/claude/all` | The same guidance as one file for other tools |

Pick one format per project. Loading `.cursor/rules` **and** `AGENTS.md` in
Cursor sends the same guidance twice and costs you more.

Repository layout:

```
install.ps1          Windows installer (local or irm | iex)
install.sh           macOS / Linux installer (local or curl | bash)
kit/
  .cursor/rules/     the 14 rule files
  AGENTS.md
  CLAUDE.md
  PROMPTS.md
  cursorindexingignore.txt
```

---

## What the assistant will and won't do

Unless you ask for that exact action in your latest message, it will not:

- run `ng` commands, `npm` / `npx` / `yarn` / `pnpm`, or state-changing `git`
- delete, move, or rename files
- open or edit `src/environments/**`, `.env*`, keys, tokens, or credential files
- edit `angular.json`, `package.json`, lock files, `tsconfig*.json`, or CI files
- add or upgrade dependencies
- change more than 3 files or ~150 lines without showing a plan first
- rewrite a whole existing file
- make network calls

It marks risky replies with `CAUTION: PRODUCTION CONFIG` or
`CAUTION: SENSITIVE CODE`.

These are instructions to a model, not a sandbox. Keep Cursor's command
approval on and review diffs.

## What the installer will and won't do

- Stops if the folder has no `angular.json` (unless forced).
- Keeps any file that already exists (unless forced) and prints every file it
  adds or keeps. Running it twice is harmless.
- Writes only the files listed above. It never runs `npm`, `ng`, or `git`
  and never edits your source code.
- Remote runs download one archive of this repo to a temp folder and delete
  it afterwards. Read [`install.ps1`](install.ps1) / [`install.sh`](install.sh)
  before piping anything from the internet into your shell.

---

## Removing it

Delete what the installer added:

```powershell
Remove-Item .cursor\rules\guardrails.mdc, .cursor\rules\response-style.mdc, .cursor\rules\tool-budget.mdc, .cursor\rules\project-context.mdc, .cursor\rules\ng-*.mdc, .cursor\rules\ts-style.mdc, PROMPTS.md
```

```bash
rm -f .cursor/rules/{guardrails,response-style,tool-budget,project-context,ts-style}.mdc .cursor/rules/ng-*.mdc PROMPTS.md
```

Also remove `AGENTS.md`, `CLAUDE.md`, or `.cursorindexingignore` if you installed them.

---

## Questions

**Should the team commit these files?**
Yes. Commit `.cursor/rules/` and `PROMPTS.md` to your Angular repo so everyone
gets the same behaviour. Fill in `project-context.mdc` once.

**The assistant stopped running builds. How do I check my change?**
It ends each change with the command to run. Run it yourself, or tell it
"run the type check" in that message.

**It used to load a whole service. Now it doesn't. Is something missing?**
No - that is the point. If it needs more context, it searches and reads the
relevant range.

**Will this work with NgModules and older Angular?**
Yes. The rules tell the assistant to follow the style already in each file
rather than migrate it.

**Any model tips?**
Lower the reasoning effort setting before switching to a weaker model, keep one
task per chat, and judge cost by changes you actually accept.

---

## License

MIT (c) 2026 Abdul Razzak. See [LICENSE](LICENSE).
