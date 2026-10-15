# angular-minimizing-costing-cursor-rule

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
irm https://raw.githubusercontent.com/RazzakAnsari/angular-minimizing-costing-cursor-rule/main/install.ps1 | iex
```

**macOS / Linux / WSL**

```bash
curl -fsSL https://raw.githubusercontent.com/RazzakAnsari/angular-minimizing-costing-cursor-rule/main/install.sh | bash
```

Then fill in `.cursor/rules/project-context.mdc` and start a **new** Cursor chat.

The files are hidden from git automatically (see below), so nothing new shows
up in Source Control and nothing ends up in your commits.

---

## Install once for all your Angular projects

Open a terminal in the folder that holds your projects (for example `C:\code`)
and run one command. It finds every folder with an `angular.json` underneath
(git worktrees included, `node_modules`, `dist`, `bin`, `obj` and dot-folders
skipped, 6 levels deep) and installs into each one, then prints a table.

**Windows (PowerShell)**

```powershell
$env:MCCR_ALL = '1'; irm https://raw.githubusercontent.com/RazzakAnsari/angular-minimizing-costing-cursor-rule/main/install.ps1 | iex; Remove-Item Env:MCCR_ALL
```

Or name the folder yourself:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/RazzakAnsari/angular-minimizing-costing-cursor-rule/main/install.ps1))) -All -Root C:\code
```

**macOS / Linux / WSL**

```bash
curl -fsSL https://raw.githubusercontent.com/RazzakAnsari/angular-minimizing-costing-cursor-rule/main/install.sh | bash -s -- --all --root ~/code
```

Cursor has no global folder for project rule files, so "once" means one command
over the folder that holds your projects. Run the same command again after you
clone or create a new project; projects that already have the kit are left as
they are.

## Invisible to git

Inside a git repo the installer adds the exact files it wrote to that repo's
`.git/info/exclude`, between these two lines:

```
# >>> angular-minimizing-costing-cursor-rule / >>>
# <<< angular-minimizing-costing-cursor-rule / <<<
```

`info/exclude` works like `.gitignore` but lives only on your machine and is
never committed. So `git status`, `git add -A`, and Cursor's Source Control
panel do not see the kit, and your commits stay clean. Your `.gitignore` is never
touched, and other files in `.cursor/` that your team commits keep working.

- If git already tracks a file with the same name (say a team `PROMPTS.md`),
  the installer leaves it alone and prints `tracked ... skipped`.
- Want the team to commit the rules instead? Add `-Visible` (`MCCR_VISIBLE=1`,
  `--visible`); the files are then left visible to git.

## Is it installed?

```powershell
$env:MCCR_STATUS = '1'; irm https://raw.githubusercontent.com/RazzakAnsari/angular-minimizing-costing-cursor-rule/main/install.ps1 | iex; Remove-Item Env:MCCR_STATUS
```

```bash
curl -fsSL https://raw.githubusercontent.com/RazzakAnsari/angular-minimizing-costing-cursor-rule/main/install.sh | bash -s -- --status
```

You get one line per Angular project under the current folder: installed or
not, how many rules, whether git can see them (`hidden`, `VISIBLE`, `committed`
or `not git`), and the kit version. Each install also leaves a small marker,
`.cursor/rules/.mccr-installed`, listing what it added (also hidden from git).

### Preview first (nothing is written)

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/RazzakAnsari/angular-minimizing-costing-cursor-rule/main/install.ps1))) -DryRun
```

```powershell
$env:MCCR_DRYRUN = '1'; irm https://raw.githubusercontent.com/RazzakAnsari/angular-minimizing-costing-cursor-rule/main/install.ps1 | iex; Remove-Item Env:MCCR_DRYRUN
```

```bash
curl -fsSL https://raw.githubusercontent.com/RazzakAnsari/angular-minimizing-costing-cursor-rule/main/install.sh | bash -s -- --dry-run
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
| `-All`            | `--all`           | `MCCR_ALL=1`           | off      | Install into every Angular project under the root |
| `-Root <dir>`     | `--root <dir>`    | `MCCR_ROOT`            | current folder | Where `-All` and `-Status` look |
| `-Depth <n>`      | `--depth <n>`     | `MCCR_DEPTH`           | `6`      | How many folder levels `-All` and `-Status` search |
| `-Status`         | `--status`        | `MCCR_STATUS=1`        | off      | List the Angular projects under the root and whether the kit is in them |
| `-Uninstall`      | `--uninstall`     | `MCCR_UNINSTALL=1`     | off      | Remove only what the installer added (with `-All`: in every project) |
| `-Visible`        | `--visible`       | `MCCR_VISIBLE=1`       | off      | Do not hide the files from git |

Working from a clone instead of the web:

```powershell
git clone https://github.com/RazzakAnsari/angular-minimizing-costing-cursor-rule
& .\angular-minimizing-costing-cursor-rule\install.ps1 -Target C:\path\to\your-angular-app -DryRun
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
| `.cursor/rules/.mccr-installed` | never | Marker: kit version, date, and the files the installer added |

Pick one format per project. Loading `.cursor/rules` **and** `AGENTS.md` in
Cursor sends the same guidance twice and costs you more.

Repository layout:

```
install.ps1          Windows installer (local or irm | iex): install, -All, -Status, -Uninstall
install.sh           macOS / Linux installer (local or curl | bash): same options
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
- Never replaces a file that git already tracks.
- Writes only the files listed above plus its own block in `.git/info/exclude`.
  It runs only read-only git commands (`rev-parse`, `ls-files`, `status`,
  `worktree list`), never runs `npm` or `ng`, never edits `.gitignore`, and
  never edits your source code.
- Remote runs download one archive of this repo to a temp folder and delete
  it afterwards. Read [`install.ps1`](install.ps1) / [`install.sh`](install.sh)
  before piping anything from the internet into your shell.

---

## Removing it

The uninstaller deletes only the files listed in the marker, and only if you
have not changed them since (`-Force` removes changed ones too). It also removes
its block from `.git/info/exclude`.

```powershell
$env:MCCR_UNINSTALL = '1'; irm https://raw.githubusercontent.com/RazzakAnsari/angular-minimizing-costing-cursor-rule/main/install.ps1 | iex; Remove-Item Env:MCCR_UNINSTALL
```

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/RazzakAnsari/angular-minimizing-costing-cursor-rule/main/install.ps1))) -Uninstall -All
```

```bash
curl -fsSL https://raw.githubusercontent.com/RazzakAnsari/angular-minimizing-costing-cursor-rule/main/install.sh | bash -s -- --uninstall --all
```

---

## Questions

**Should the team commit these files?**
Your choice. By default they stay on your machine only, hidden from git. If you
want everyone on the team to get the same rules, install with `-Visible` and
commit `.cursor/rules/` and `PROMPTS.md`.

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
