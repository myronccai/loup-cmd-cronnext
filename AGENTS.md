# AGENTS.md

This repository is `cronnext`, a tool that prints the next run times of
cron schedules and crontab files, written in the Loup programming language,
part of the loup-cmd series of example applications. It is a
`host.scripted` project: the program is the `.lpscr` script
`bin/cronnext.lpscr`, which `loup run` executes from source, over
`host.scripted` modules in `lib/`. Nothing is compiled.

## Skills

| Skill | Location | Use it when |
|-------|----------|-------------|
| `loup-programmer` | [skills/loup-programmer/SKILL.md](skills/loup-programmer/SKILL.md) | Writing, reviewing, debugging or explaining Loup code: `.lpscr`, `.loup`, `.lphc`, `.lpweb` or `.lpfree` source files, `.lppkg` manifests, `@mode(...)` directives, or the `loup` / `loup-bootstrap` commands. |

Read `skills/loup-programmer/SKILL.md` before writing or changing any Loup code
in this repository. It links to detailed references under
`skills/loup-programmer/references/` for syntax, types and ownership, execution
modes and projects, errors and diagnostics, the standard library, and common
mistakes. Load those only as needed.

## Code layout

```text
.
├── package.lppkg                # manifest: name, version, toolchain, [build] entry (bin/cronnext.lpscr), [test] pattern
├── Makefile                     # run, check, test, e2e, ci, clean
├── LICENSE                      # MIT license (copyright Code Craft AI LLC)
├── bin/
│   └── cronnext.lpscr           # the program: arguments, inputs, modes, exit status (executable, shebang `loup run`)
├── lib/                         # the program's modules, all host.scripted
│   ├── appinfo.lpscr            # APP_NAME, APP_VERSION, APP_SUMMARY, exit statuses
│   ├── options.lpscr            # enum Mode, class Options, parse_args() (safe func), parse_count()
│   ├── usage.lpscr              # usage(), version_line()
│   ├── field.lpscr              # FieldKind, Part, Field, bounds(), value_of(), parse_part(), expand(), parse_field()
│   ├── schedule.lpscr           # Schedule, macro_fields(), parse_schedule(), day_matches(), runs_at(), next_run(), runs_of(), HORIZON
│   ├── clock.lpscr              # Civil, civil(), minute_at(), next hour/day/month, parse_time(), format_human/iso/wait()
│   ├── crontab.lpscr            # Origin, Entry, Line, Note, Crontab, classify(), read_crontab(), parse_operand()
│   ├── merge.lpscr              # merged_runs() with structures.priority_queue
│   └── explain.lpscr            # join_words(), ordinal(), time/day/month_words(), describe()
├── tests/
│   ├── *_test.lpscr             # unit tests: func test_*(): void
│   ├── e2e.sh                   # end-to-end tests: runs the script with loup run
│   └── fixtures/                # crontab (settings, @reboot, bad lines), system.crontab (user field)
├── specs/cronnext/              # requirements.md, design.md, tasks.md
├── skills/loup-programmer/      # the Loup skill and its references
└── .github/workflows/ci.yml     # installs Loup and runs `make ci`
```

## Check, run and test

Prerequisites: Loup 1.26.0 (`loup` and `loup-bootstrap` on `PATH`), `make`
and `bash`.

Loup Lite comes from <https://github.com/code-craft-ai-company/loup-releases>;
[README.md](README.md#installing-loup-lite) has the install commands.

| Task | Command | Notes |
|------|---------|-------|
| Run from source | `make run ARGS="-n 5 @hourly '*/20 9-17 * * mon-fri'"` | `loup run bin/cronnext.lpscr -- ARGS` |
| Run directly | `./bin/cronnext.lpscr -e '0 9 * * mon'` | long options only after `--` (see below) |
| Type-check | `make check` | `loup-bootstrap check bin/cronnext.lpscr` and the modules it imports |
| Unit tests | `make test` | each `tests/*_test.lpscr` in turn |
| One test file | `make test TESTS=tests/schedule_test.lpscr` | |
| Matching tests | `make test TEST_ARGS="--filter leap"` | tests whose name contains `leap` |
| End-to-end tests | `make e2e` | `tests/e2e.sh`: output and exit status of `loup run` |
| Everything CI runs | `make ci` | check, test, e2e, then `--version` |
| Clean | `make clean` | removes `.temp/` |

Run `make ci` before reporting a change as done. Unit tests run under Stage0
(`loup-bootstrap`); the script runs under the self-hosted `loup run`, which
behaves differently in places (below), so only `make e2e` shows what users get.
Every e2e case passes `--from`, so results do not depend on the clock.

Toolchain facts this project depends on (Loup 1.26.0, Linux x86-64):

- A script entry cannot be built (`E-BUILD-COMPILED`), so there is no build
  target. `loup-bootstrap check FILE` does type-check a script and its
  imports; `[build] entry` points at `bin/cronnext.lpscr`.
- `loup run SCRIPT --long` treats `--long` as its own flag; the self-hosted
  driver drops it silently. Script options go after `--`:
  `loup run bin/cronnext.lpscr -- --from 2026-10-20 '0 9 * * *'`. Short
  options pass through.
- In both interpreters, when several arms of a `match` on a tuple bind the
  same name, only the last of those arms gets a value: give each arm its own
  names (`(start, _)`, `(_, stop)`, `(lo, hi)` in `lib/field.lpscr`).
  Enum arms (`Some(h) if (...)`, `Some(_)`) are not affected.
- Inside a comprehension, a local named `min` or `max` is not seen (both
  interpreters; Stage0 reads `max` as the string "max"): use other names
  (`least`, `most`).
- Stage0 tuple patterns may hold only literals, bindings, `_` and tuples, not
  `Some(x)` or enum variants.
- A `const` cannot be computed from an imported `const`
  (`E_CONST_NOT_EVALUABLE`): `HORIZON` is a literal.
- Constructing an enum payload or struct with named arguments inside a lambda
  or comprehension fails in both interpreters once any function declares a
  `var` of the same name; this code constructs outside lambdas.
- `core.datetime` has no local time zone in 1.26 (`Date.today()` is UTC);
  `Instant.fromIso` needs a full `YYYY-MM-DDTHH:MM:SSZ` string, which
  `lib/clock.lpscr` builds.
- `where` and `from` are reserved words; `system` is a standard-library
  namespace (the option field is `system_crontab`).
- The self-hosted `loup run` cannot catch `IoError`; check `exists`/`isDir`
  before `readText`.
- `loup-bootstrap test` with all files at once fails random tests with an
  empty `RuntimeError` on a busy machine; the Makefile runs one file at a time
  with `--no-parallel`.

## Making a change

1. Update the spec in `specs/cronnext/` (see [specs/README.md](specs/README.md)).
2. Change the code: behaviour in `lib/`, top-level flow in `bin/`.
3. Add or update unit tests in `tests/` and cases in `tests/e2e.sh`. Check
   new expected run times against an independent source (a brute-force
   minute-by-minute search with the same rules, or a cron library).
4. Run `make ci`.
5. Tick the finished tasks in `specs/cronnext/tasks.md`.

Keep behaviour in functions that return values, so unit tests can check it;
only `bin/cronnext.lpscr` prints, reads files and calls `exit`.

## Conventions

- Every source file is `@mode(host.scripted)` (`.lpscr`); the entry script
  has a `#!/usr/bin/env -S loup run` line and the executable bit. Keep it
  thin: arguments, I/O, exit status.
- Imports are relative: `from ..lib.schedule import (...)` in `bin/` and
  `tests/`, `from .field import (...)` inside `lib/`. A script's package
  root is its own directory, so `from lib.schedule` would not resolve.
- Times are ints: minutes since 1970-01-01T00:00Z. Convert at the edges
  (`parse_time`, `format_*`).
- Keep `APP_VERSION` in `lib/appinfo.lpscr` equal to `version` in
  `package.lppkg`.
- The skill documents toolchain 1.25.1; this project targets 1.26.0. When
  they disagree, trust the toolchain's behaviour.
