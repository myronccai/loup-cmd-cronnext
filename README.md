# loup-cmd-cronnext

When will a cron job run? `cronnext` is a [Loup](https://code-craft.ai/references/loup)
script that prints the next run times of cron schedules and crontab files,
merged in time order with the line each comes from. It also lists each
schedule's runs, explains schedules in English and checks crontabs, with
the full cron syntax: lists, ranges, steps, month and weekday names,
`@daily` and friends, and the rule that joins the two day fields with "or".

Part of the **loup-cmd** series of example applications: classic Linux and
Windows commands, and projects for each Loup execution mode, each in its own
repository under [myronccai](https://github.com/myronccai?tab=repositories&q=loup-cmd).
This one is a `host.scripted` project: a thin `.lpscr` entry script in
`bin/` over `.lpscr` modules in `lib/`, run with `loup run`.

## Requirements

- [Loup Lite](https://github.com/code-craft-ai-company/loup-releases) 1.26.0
  or later (`loup` and `loup-bootstrap` on `PATH`); see [Installing Loup Lite](#installing-loup-lite).
- `make` and `bash` for the checks and tests. No C compiler: nothing is built.

## Installing Loup Lite

This example is built and tested with **Loup Lite**, the free public build of
the Loup toolchain from [Code Craft AI](https://code-craft.ai), meant for
education and training. Code Craft AI publishes the official builds,
installers and signed checksums at
**<https://github.com/code-craft-ai-company/loup-releases>**, for Linux
(x86-64, arm64), macOS (Apple silicon, Intel) and Windows (x86-64).

Linux and macOS:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
```

Windows (PowerShell):

```powershell
irm https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.ps1 | iex
```

The installer picks the archive for your machine, checks it against the
release's `SHA256SUMS`, unpacks it into `~/.loup`
(`%LOCALAPPDATA%\Programs\Loup` on Windows) and puts its `bin` directory on
your `PATH`; it needs no administrator rights. You get `loup`, the Stage0
compiler `loup-bootstrap` and the Wasm runtime `loup-launcher`. Open a new
shell and check:

```sh
loup --version             # loup 1.26.0 or later
```

CI installs the exact version it tests with, 1.26.0. To do the same:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/download/v1.26.0/loup-install.sh | sh -s -- --version 1.26.0
```

To install by hand, download your platform's archive from the
[releases page](https://github.com/code-craft-ai-company/loup-releases/releases),
check it against `SHA256SUMS`, unpack it anywhere and add its `bin` directory to
`PATH`. The [loup-releases README](https://github.com/code-craft-ai-company/loup-releases#verify-a-download)
explains how to verify the Sigstore signature on `SHA256SUMS`.

Loup Lite leaves out Loup's cryptography library and the full set of Loup
packages; this example needs neither. Commercial use of Loup needs a
license: <https://code-craft.ai/loup/license>.

## Usage

```sh
make run ARGS="-n 5 @hourly '*/20 9-17 * * mon-fri'"   # loup run bin/cronnext.lpscr -- ARGS
make ci                                               # check, unit tests, end-to-end tests
```

The script is executable (`#!/usr/bin/env -S loup run`). Each SCHEDULE
operand is one quoted schedule, optionally followed by a command; the runs
of all of them come out in one list, each with its source (`#2` is the
second operand) and its command, or its schedule when it has none:

```text
$ ./bin/cronnext.lpscr -n 7 -- --from '2026-10-23 16:50' '*/20 9-17 * * mon-fri' @hourly '0 18 * * fri  /usr/local/bin/weekly-report'
Fri 2026-10-23 17:00  #1  */20 9-17 * * mon-fri
Fri 2026-10-23 17:00  #2  @hourly
Fri 2026-10-23 17:20  #1  */20 9-17 * * mon-fri
Fri 2026-10-23 17:40  #1  */20 9-17 * * mon-fri
Fri 2026-10-23 18:00  #2  @hourly
Fri 2026-10-23 18:00  #3  /usr/local/bin/weekly-report
Fri 2026-10-23 19:00  #2  @hourly
```

`-e` says what a schedule means; note cron's rule for the third line: when
both day fields are restricted, either one is enough:

```text
$ ./bin/cronnext.lpscr -e -- --from '2026-10-20 14:37' '30 4 1,15 * 5' '0 */2 * * *' '0 0 1 */3 *'
#1  30 4 1,15 * 5
    at 04:30, on days 1 and 15 of the month or on Friday
    next: Fri 2026-10-23 04:30

#2  0 */2 * * *
    at minute 0 past every 2nd hour
    next: Tue 2026-10-20 16:00

#3  0 0 1 */3 *
    at 00:00, on day 1 of the month, in every 3rd month
    next: Fri 2027-01-01 00:00
```

Crontab files (`-f`, repeatable; `-` is standard input) are read the way
cron reads them: comments, `NAME=value` settings, `@reboot`. Bad lines are
reported with their line number and skipped, and the status becomes 1:

```text
$ ./bin/cronnext.lpscr -n 4 -f tests/fixtures/crontab -- --from 2026-10-20T02:30; echo "status $?"
cronnext: tests/fixtures/crontab:4: warning: CRON_TZ is ignored; times are UTC
cronnext: tests/fixtures/crontab:10: warning: @reboot runs only when cron starts
cronnext: tests/fixtures/crontab:12: bad hour field '25': 25 is out of range 0-23
cronnext: tests/fixtures/crontab:13: missing command
cronnext: tests/fixtures/crontab:11: warning: '0 0 30 2 *' never runs
Tue 2026-10-20 03:00  tests/fixtures/crontab:7  /opt/app/bin/backup >> /var/log/backup.log 2>&1
Tue 2026-10-20 03:00  tests/fixtures/crontab:9  /opt/app/bin/rotate-logs
Tue 2026-10-20 04:00  tests/fixtures/crontab:9  /opt/app/bin/rotate-logs
Tue 2026-10-20 05:00  tests/fixtures/crontab:9  /opt/app/bin/rotate-logs
status 1
```

`-c` prints only those messages, so `cronnext -c -f mycrontab` is a check
before `crontab mycrontab`. `-s` reads a system crontab with its user
field; `-l` lists each schedule's runs on its own and `-r` adds the wait:

```text
$ ./bin/cronnext.lpscr -s -f tests/fixtures/system.crontab -l -n 2 -r -- --from 2026-10-25
...
tests/fixtures/system.crontab:7  47 6 * * 7  (root) test -x /usr/sbin/anacron || run-parts --report /etc/cron.weekly
  Sun 2026-10-25 06:47  in 6h 47m
  Sun 2026-11-01 06:47  in 7d 6h 47m

tests/fixtures/system.crontab:8  52 6 1 * *  (root) test -x /usr/sbin/anacron || run-parts --report /etc/cron.monthly
  Sun 2026-11-01 06:52  in 7d 6h 52m
  Tue 2026-12-01 06:52  in 37d 6h 52m
$ ./bin/cronnext.lpscr -n 3 '0 9 * * mon' -- --from 2026-10-20 --iso
2026-10-26T09:00:00Z  #1  0 9 * * mon
2026-11-02T09:00:00Z  #1  0 9 * * mon
2026-11-09T09:00:00Z  #1  0 9 * * mon
```

### Options

| Option | Meaning |
|---|---|
| `-f`, `--file FILE` | read a crontab (repeatable; `-` is standard input) |
| `-s`, `--system` | crontab lines have a user field, as in `/etc/crontab` |
| `-n`, `--count N` | print N run times (default 10; with `--until` and no `-n`, all) |
| `--from TIME` / `--until TIME` | start at TIME (default now) / stop before TIME |
| `-l`, `--each` | list the runs of each schedule under its own heading |
| `-e`, `--explain` | describe each schedule in words, with its next run |
| `-c`, `--check` | print only the problems; exit 1 if a line is invalid |
| `--iso` | times as `2026-10-20T15:00:00Z` |
| `-r`, `--relative` | also print the wait from the start (`in 1d 2h 5m`) |
| `-h`, `--help` / `-V`, `--version` | help text / `cronnext (loup-cmd-cronnext) 0.1.0` |

TIME is `now`, `YYYY-MM-DD`, `YYYY-MM-DD HH:MM[:SS]` or
`YYYY-MM-DDTHH:MM[:SS]` with an optional `Z`, or `@SECONDS` since 1970.
Runs are counted from the first whole minute at or after `--from`. Short
options can be combined (`-lr`) and take attached values (`-n3`).

**Long options need `--` under `loup run`.** `loup run SCRIPT ARGS` treats
words starting with `--` as its own flags, and the self-hosted `loup run` on
Linux x86-64 drops unknown ones silently. Write
`loup run bin/cronnext.lpscr -- --from 2026-10-20 '0 9 * * *'` (or
`./bin/cronnext.lpscr -- --from ...`), or use the short options, which pass
through unchanged. `make run` adds the `--` for you.

**Schedules.** Five fields: minute (0-59), hour (0-23), day of month
(1-31), month (1-12 or `jan`-`dec`), day of week (0-7 or `sun`-`sat`; 0 and
7 are Sunday). Each is a comma-separated list of `*`, values, ranges `A-B`
and steps (`*/15`, `1-30/5`, `5/10`, which runs from 5 to the end of the
range). Macros: `@yearly`/`@annually`, `@monthly`, `@weekly`,
`@daily`/`@midnight`, `@hourly`; `@reboot` has no times. When both day
fields are restricted (neither starts with `*`), a day matches if either
matches; otherwise both must, so `*/2` counts as `*` there, as in Vixie
cron and cronie.

**Times are UTC.** Loup 1.26's date library has no local time zone, so
`TZ` and `CRON_TZ` settings bring a warning and are ignored.

Exit status: `0` success, `1` an input could not be read or a schedule is
invalid (the valid ones are still printed), `2` usage error.

## What this example shows

- **Enums with payloads** model the domain: a field's items are
  `Part.Every`, `Single(value)`, `Span(low, high)` and
  `Stepped(low, high, step)`; a crontab line is `Line.Blank`, `Comment`,
  `Setting(name, value)`, `Reboot(command)`, `Job(schedule, user, command)`
  or `Invalid(reason)`; an entry's `Origin` is `Operand(position)` or
  `FileLine(path, line)`; diagnostics are `Note.Warning` / `Note.Error`.
- **Rich `match`**: guards with bindings on tuples (`(start, _) if (start
  < least or start > most)` in `lib/field.lpscr`), cron's day rule as a
  match on a tuple of bools, literal tuples for English ordinals
  (`(_, teen) if (teen >= 11 and teen <= 13) => "th"`), guarded enum arms
  (`Some(h) if (h > c.hour)`), tuple destructuring from a match
  (`let (first, last, step) = match part { ... }`).
- **Sets of allowed values**: each field expands to a `set[int]`, tested
  with `contains` during the search; option tables use `set[string]`.
- **`structures.priority_queue`** merges the schedules: one pending run per
  schedule, ordered by minute and then input position.
- **`core.datetime`** (`civilFromDays`, `daysFromCivil`, `weekdayFromDays`,
  `Date`) for calendar arithmetic and **`core.time`** (`Instant.fromIso`,
  `toIso`, `fromMillis`, `now`, `Duration` between instants) for parsing,
  printing and waits.
- **`system.regex`** with named groups for list items, crontab lines,
  settings, user fields and times.
- A **class with `var` fields** filled by a `safe func` and an
  `edits` parameter (`lib/options.lpscr`), struct-valued fields, `const`
  values with digit separators, multiline strings, C-style `for` loops.

## Limitations

- UTC only (see above). Daylight-saving gaps and repeats, which shift real
  cron jobs, do not exist here.
- Speed is not a concern: 1,000 merged runs take 0.75 s under `loup run`,
  start-up included, because the search jumps over months, days and hours
  that cannot match. A schedule that never runs is recognised by finding no
  run in 28 years, the length of the calendar's weekday cycle.
- `@reboot` jobs and the `%` newline convention in commands are shown, not
  interpreted. No installed crontabs are read: give the files with `-f`.
- A file that exists but cannot be read (permissions) ends the run with
  `IoError` and status 1: the self-hosted `loup run` cannot catch `IoError`,
  so cronnext checks only that each file exists and is not a directory.

## Layout

```text
bin/cronnext.lpscr         # the program (host.scripted entry script)
lib/appinfo.lpscr          # name, version, exit statuses
lib/options.lpscr          # Mode, Options, parse_args
lib/usage.lpscr            # --help and --version text
lib/field.lpscr            # FieldKind, Part, Field: one cron field
lib/schedule.lpscr         # Schedule, macros, the day rule, next_run
lib/clock.lpscr            # minutes, calendar fields, parsing and printing times
lib/crontab.lpscr          # Origin, Entry, Line, Note: crontab lines and operands
lib/merge.lpscr            # merged_runs (priority queue)
lib/explain.lpscr          # schedules in English
tests/*_test.lpscr         # unit tests (make test)
tests/e2e.sh               # end-to-end tests with loup run (make e2e)
tests/fixtures/            # crontab (with bad lines), system.crontab
specs/cronnext/            # requirements, design, tasks
```

[AGENTS.md](AGENTS.md) has every check and test command and the conventions
for changing the code.

## License

[MIT](LICENSE), copyright 2026 Code Craft AI LLC. The Loup skill in
[`skills/loup-programmer/`](skills/loup-programmer/) is copied from the Loup
project and is not covered by this license; it keeps the Loup project's terms.
