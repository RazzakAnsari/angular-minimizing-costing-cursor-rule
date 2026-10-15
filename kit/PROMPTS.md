# Short prompts for Angular work

Paste one, fill in the `<...>`, and send. One task per chat keeps context
small. Add "diff only" when you just want the change.

## Understand
- `Where is <selector / method / route> defined and who calls it? Search only, no full-file reads.`
- `Explain what <method> in <file> does in 3 bullets.`
- `Which component renders the <page/section>? Give the file path only.`

## Fix
- `Bug: <what happens> instead of <what should happen> in <file>. Find the cause and show the smallest diff.`
- `This error appears in the console: <paste error>. Find the line responsible and propose a fix as a diff.`
- `<field> is undefined in <component>.html on first load. Fix it without changing the service.`

## Build a small piece
- `Add a standalone component <name> under src/app/features/<feature>/ with inputs <a, b>. OnPush. Show the files as diffs.`
- `Add a method <name>(<args>) to <service>.service.ts that calls <endpoint path>. Typed response, errors handled in the service.`
- `Add a lazy route '<path>' in <file>.routes.ts that loads <Component>.`
- `Add translation key <KEY> with text "<text>" to every file in src/assets/i18n/.`

## Change carefully
- `Refactor <method> in <file> to remove the nested subscribe. Keep the public signature.`
- `Convert <component> state to signals. List the changes first and wait for go.`
- `Rename <old> to <new> everywhere. List every file and usage first; do not edit yet.`

## Tests
- `Write a spec for <method> in <file>: happy path and one error path. Mock HTTP. Do not run it.`
- `This spec fails: <paste output>. Fix the test or tell me if the code is wrong. Do not skip it.`

## Review
- `Review the diff in <file> for bugs and missed unsubscribes. Max 5 findings, most important first.`

## Wrap up
- `Which command should I run to check this change? One line.`
