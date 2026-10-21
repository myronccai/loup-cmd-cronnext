# Requirements: cronnext

## Introduction

`cronnext` answers "when will this run?" for cron schedules. Given crontab
lines on the command line or crontab files, it prints the next run times of
all of them merged in time order, each with the line it came from; it can
also list each line's runs separately, explain a schedule in words, or only
check a crontab. It understands the full syntax of Vixie cron and cronie:
lists, ranges, steps, month and weekday names, the `@daily` style macros and
the rule that joins the day-of-month and day-of-week fields with "or".

It is a `host.scripted` program (`bin/cronnext.lpscr`, run with `loup run`)
for people who write and review crontabs. All times are UTC: the Loup 1.26
date library has no local time zone.

## Requirements

### Requirement 1: Schedule syntax

**User Story:** As a crontab author, I want every schedule cron accepts to
be understood so that the times shown are the times cron would use.

#### Acceptance Criteria

1. A schedule SHALL have five fields: minute (0-59), hour (0-23), day of month (1-31), month (1-12) and day of week (0-7, where 0 and 7 are Sunday).
2. A field SHALL be a comma-separated list of items; an item SHALL be `*`, a value, a range `A-B`, or one of those followed by a step `/N` (`*/15`, `1-30/5`); a value with a step (`5/10`) SHALL run from that value to the end of the field's range.
3. Months SHALL also be written `jan`-`dec` and days of the week `sun`-`sat`, in any case, alone or in ranges.
4. THE macros `@yearly`, `@annually`, `@monthly`, `@weekly`, `@daily`, `@midnight` and `@hourly` SHALL stand for `0 0 1 1 *`, `0 0 1 1 *`, `0 0 1 * *`, `0 0 * * 0`, `0 0 * * *`, `0 0 * * *` and `0 * * * *`.
5. WHEN both the day-of-month and day-of-week fields are restricted (neither starts with `*`), a day SHALL match when either field matches; otherwise it SHALL match when both do.
6. WHEN a field is malformed, THE program SHALL name the field, the text and the reason: `bad hour field '25': 25 is out of range 0-23`.
7. `@reboot` SHALL be reported as running only at startup and given no times.

### Requirement 2: Inputs

**User Story:** As a user, I want to check schedules typed on the command
line as well as whole crontab files.

#### Acceptance Criteria

1. Each SCHEDULE operand SHALL be one schedule, optionally followed by a command (`'0 3 * * * backup.sh'`).
2. WHEN `-f FILE` is given (repeatable; `-` is standard input), THE program SHALL read a crontab: blank lines and `#` comments are skipped, `NAME=value` lines are settings, other lines are jobs with a schedule and a command.
3. WHEN `-s` is given, crontab jobs SHALL have a user field after the schedule, as in `/etc/crontab`.
4. A setting of `TZ` or `CRON_TZ` SHALL bring a warning that times are UTC; other settings SHALL be ignored.
5. WHEN a line or operand is invalid, THE program SHALL print `cronnext: SOURCE: MESSAGE` to stderr, skip it, carry on with the others and exit 1.
6. WHEN a FILE is missing or a directory, THE program SHALL say so (`No such file or directory`, `Is a directory`) and exit 1.

### Requirement 3: Next run times

**User Story:** As a user, I want the coming run times of all my jobs in one
list so that I can see what happens when.

#### Acceptance Criteria

1. THE program SHALL print the first N run times at or after the start (default: now) over all schedules, in time order; runs at the same minute SHALL appear in input order.
2. Each line SHALL show the time (`Tue 2026-10-20 15:00`), the source (`#2` for the second operand, `FILE:LINE` for a crontab line) and the command, or the schedule when there is none.
3. `-n N` SHALL set N (default 10); `--from TIME` SHALL set the start and `--until TIME` SHALL stop before TIME; with `--until` and no `-n`, all runs before TIME SHALL be printed.
4. TIME SHALL be `now`, `YYYY-MM-DD`, `YYYY-MM-DD HH:MM[:SS]` or `YYYY-MM-DDTHH:MM[:SS]` with an optional `Z`, or `@SECONDS` since 1970; a time with seconds SHALL be rounded up to the next minute.
5. WHEN `--iso` is given, times SHALL be printed as `2026-10-20T15:00:00Z`; WHEN `-r` is given, each line SHALL also show the time left from the start (`in 1d 2h 5m`).
6. WHEN `-l` is given, THE program SHALL print each schedule's first N runs under a heading per schedule instead of one merged list.
7. WHEN a schedule can never run (`0 0 30 2 *`), THE program SHALL warn `SOURCE: never runs` and leave it out.

### Requirement 4: Explaining and checking

**User Story:** As a crontab author, I want to read a schedule in words and to
check a crontab before installing it.

#### Acceptance Criteria

1. WHEN `-e` is given, THE program SHALL print for each schedule its source and text, a description in English (`every 15 minutes between 09:00 and 17:59, on Monday through Friday`) and its next run.
2. WHEN `-c` is given, THE program SHALL print nothing for valid input and report every invalid line, exiting 1 when there is one.

### Requirement 5: Command line

**User Story:** As a user and script author, I want conventional options,
messages and exit statuses.

#### Acceptance Criteria

1. THE parser SHALL accept short options alone, combined (`-lr`) or with attached values (`-n3`), long options as `--name VALUE` or `--name=VALUE`, options after operands, and `--` to end the options.
2. WHEN an option is unknown, lacks its value or gets a bad value, when no schedule and no file is given, or when `-e`, `-l` and `-c` are combined, THE program SHALL print `cronnext: MESSAGE` and `Try 'cronnext --help' for more information.` and exit 2.
3. WHEN `-h` or `--help` is given, THE program SHALL print the usage text; WHEN `-V` or `--version` is given, `cronnext (loup-cmd-cronnext) 0.1.0`; both exit 0.
4. THE program SHALL exit 0 on success, 1 when an input could not be read or a schedule was invalid, and 2 on a usage error.
