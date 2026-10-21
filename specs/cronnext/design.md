# Design: cronnext

## Overview

`bin/cronnext.lpscr` is a `host.scripted` script. Its top-level statements
parse `args()` into an `Options` object, handle `--help` and `--version`,
parse `--from`/`--until` into minutes, turn the operands and crontab files
into `Entry` values (reporting bad lines), drop schedules that never run and
print what the mode asks for. Everything else is in `lib/`, in
`host.scripted` modules that the unit tests import directly.

```text
args() ─ parse_args ─► Options
operands ─ parse_operand ─┐
files ─ read_crontab ─────┴► list[Entry] (Origin, Schedule, command, user)
Schedule ─ next_run ─► minute ... ─ merged_runs (PriorityQueue) ─► (minute, entry) ─► stdout
Schedule ─ describe ─► English (-e)
```

## Modules

| Module | Contents |
|---|---|
| `bin/cronnext.lpscr` | top level: options, times, inputs, modes, exit status |
| `lib/appinfo.lpscr` | name, version, exit statuses |
| `lib/options.lpscr` | `Mode`, class `Options`, `parse_args` (a `safe func`), `parse_count` |
| `lib/usage.lpscr` | `usage()`, `version_line()` |
| `lib/field.lpscr` | `FieldKind`, `Part`, `Field`, `bounds`, `value_of`, `parse_part`, `expand`, `parse_field` |
| `lib/schedule.lpscr` | `Schedule`, macros, `parse_schedule`, `day_matches`, `runs_at`, `next_run`, `runs_of`, `HORIZON` |
| `lib/clock.lpscr` | minutes since 1970, `Civil`, `civil`, `minute_at`, next hour/day/month, `parse_time`, `format_human/iso/wait` |
| `lib/crontab.lpscr` | `Origin`, `Entry`, `Line`, `Note`, `Crontab`, `classify`, `read_crontab`, `parse_operand` |
| `lib/merge.lpscr` | `merged_runs` with `structures.priority_queue` |
| `lib/explain.lpscr` | `Shape`, `join_words`, `ordinal`, `time_words`, `day_words`, `month_words`, `describe` |

### Fields

```loup
pub enum Part { Every, Single(value: int), Span(low: int, high: int), Stepped(low: int, high: int, step: int) }
pub struct Field { kind: FieldKind; text: string; parts: list[Part]; allowed: set[int]; values: list[int]; restricted: bool; }
```

A `system.regex` pattern with named groups splits a list item into `star`,
`low`, `high` and `step`; `value_of` reads numbers and the month and weekday
names; a `match` on the `(low, high)` tuple with guards rejects values out
of range and backward ranges. `expand` turns the parts into a `set[int]`
(Sunday as 7 becomes 0), and `values` keeps the same numbers in order for
the search. `restricted` is false when the text starts with `*`.

### Schedules and the search

`parse_schedule` replaces a macro by its five fields (`@reboot` is an
error the callers report as a warning) and parses each field. Cron's day
rule is a `match` on `(day.restricted, weekday.restricted)`: both
restricted means either day field may match, otherwise both must.

Times are minutes since 1970 (UTC). `next_run(s, start, limit)` does not
test every minute: from the current minute it jumps to the next month when
the month is not allowed, to the next day when the day does not match, to
the next allowed hour (or the next day), and to the next allowed minute (or
the next hour). A search therefore costs about one step per day passed.
`civil` gives the calendar fields of a minute through `core.datetime`
(`civilFromDays`, `weekdayFromDays`), and `minute_at` goes back
(`daysFromCivil`). A schedule with no run within `HORIZON` (28 years of 366
days, longer than the calendar's weekday cycle) never runs.

### Merging

`merged_runs` keeps a `PriorityQueue[(int, int)]` of (next minute, entry
index) pairs ordered by minute and then index: it pops the earliest run,
records it, and pushes that entry's following run, until the count or the
limit is reached. Equal minutes come out in input order.

### Inputs

`classify` sorts a crontab line into `Line.Blank`, `Comment`,
`Setting(name, value)`, `Reboot(command)`, `Job(schedule, user, command)`
or `Invalid(reason)`, using two regular expressions (`NAME=value`; a macro
or five fields and the rest) and a third for the user field of a system
crontab. `read_crontab` collects the jobs as entries with an
`Origin.FileLine(path, line)` and the problems as `Note.Warning` /
`Note.Error`, in line order. Operands are parsed with the same job pattern,
the command being optional; their origin is `Origin.Operand(n)`.

### Times

`parse_time` accepts `now`, `@SECONDS` and ISO-like dates and times (one
regular expression with named groups), builds a full
`YYYY-MM-DDTHH:MM:SSZ` string and lets `core.time`'s `Instant.fromIso`
validate the calendar; the result is rounded up to a whole minute. Times
print as `Tue 2026-10-20 15:00` (`core.datetime.Date` for the date) or,
with `--iso`, through `Instant.toIso`; `-r` adds the wait, the `Duration`
between two instants.

### Explaining

`shape_of` reduces a field to the forms that read differently: `Any`,
`At(values)` (only single values), `Every(step)` (one step over the whole
range) and `Mixed`. `time_words` matches on the minute's shape and then the
hour's, `day_words` combines the two day fields with cron's rule ("or" when
both are restricted), and `month_words` names the months; `describe` joins
the non-empty phrases with commas.

### Options

`Options` is a class with `var` fields and defaults; `parse_args` is a
`safe func` that creates one and fills it while reading the words, with
`apply_option(edits o: Options, ...)` handling each option. Short options
map to long ones through a dict; which options take a value is a
`set[string]`. The modes (`--each`, `--explain`, `--check`) exclude each
other.

## Error handling

| Situation | Message | Status |
|---|---|---|
| usage error, bad `--from`/`--until` | `cronnext: MESSAGE` + `Try 'cronnext --help' ...` | 2 |
| bad operand | `cronnext: #N: REASON` | 1 (others still run) |
| bad crontab line | `cronnext: FILE:LINE: REASON` | 1 (others still run) |
| missing file, directory | `cronnext: FILE: No such file or directory` / `Is a directory` | 1 |
| `TZ`/`CRON_TZ`, `@reboot`, a schedule that never runs | `cronnext: SOURCE: warning: ...` | (continues) |

The self-hosted `loup run` cannot catch `IoError`, so the script checks
`exists` and `isDir` before `readText`.

## Testing

- Unit tests (`tests/*_test.lpscr`, `make test`): fields, schedules and the
  search (checked against a brute-force reference that tests every minute
  with the same rules), the clock, crontab lines, the merge, explanations
  and options.
- `tests/e2e.sh` (`make e2e`) runs the script with `loup run` on operands
  and on `tests/fixtures/crontab` and `system.crontab`, always with
  `--from`, and compares stdout, stderr and the exit status.

## Compared with cronie's cronnext

cronie ships a `cronnext` that reads the installed crontabs and prints the
next run as seconds since 1970. This one takes schedules and crontab files,
prints readable times, merges any number of runs, explains schedules and
checks crontabs. It reads no installed crontabs, has no `-i`/`-e` user
filters, and works in UTC only.
