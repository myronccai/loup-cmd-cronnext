#!/usr/bin/env bash
# End-to-end tests: run bin/cronnext.lpscr with `loup run` and compare its
# standard output (byte for byte), standard error where it matters, and exit
# status with the expected ones. Every case gives --from, so the output does
# not depend on the clock; one case checks `now` by counting lines.
#
# usage: tests/e2e.sh [LOUP]     (run from the repository root)

set -u
LOUP=${1:-loup}
SCRIPT=bin/cronnext.lpscr
CRONTAB=tests/fixtures/crontab
SYSTEM=tests/fixtures/system.crontab
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0

# run ARGS...: the script under test, with ARGS after `--` so that long
# options reach it, standard input from the file named by $IN (default
# /dev/null), output to $TMP/out and $TMP/err. Returns its exit status.
run() {
    "$LOUP" run "$SCRIPT" -- "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
}

report() {
    local name=$1 status=$2 want_status=$3 want_file=$4 got_file=$5
    if [ "$status" -eq "$want_status" ] && cmp -s "$want_file" "$got_file"; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff "$want_file" "$got_file" | sed 's/^/    /' | head -20
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

# check NAME STATUS EXPECTED_STDOUT [ARGS...]: compare standard output.
check() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    shift 3
    run "$@"
    report "$name" $? "$want_status" "$TMP/want" "$TMP/out"
}

# check_err NAME STATUS EXPECTED_STDERR [ARGS...]: compare standard error.
check_err() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    shift 3
    run "$@"
    report "$name" $? "$want_status" "$TMP/want" "$TMP/err"
}

# --- merged run times ----------------------------------------------------------

check "operands merged" 0 'Tue 2026-10-20 14:40  #1  */20 9-17 * * mon-fri
Tue 2026-10-20 15:00  #1  */20 9-17 * * mon-fri
Tue 2026-10-20 15:00  #2  @hourly
Tue 2026-10-20 15:20  #1  */20 9-17 * * mon-fri
Tue 2026-10-20 15:40  #1  */20 9-17 * * mon-fri
' --from 2026-10-20T14:37 -n 5 '*/20 9-17 * * mon-fri' @hourly '0 9 * * *'

check "crontab, bad lines skipped" 1 'Tue 2026-10-20 14:40  tests/fixtures/crontab:6  /opt/app/bin/sync --quiet
Tue 2026-10-20 15:00  tests/fixtures/crontab:6  /opt/app/bin/sync --quiet
Tue 2026-10-20 15:00  tests/fixtures/crontab:9  /opt/app/bin/rotate-logs
Tue 2026-10-20 15:20  tests/fixtures/crontab:6  /opt/app/bin/sync --quiet
' --from 2026-10-20T14:37 -n 4 -f "$CRONTAB"

check_err "crontab notes" 1 "cronnext: $CRONTAB:4: warning: CRON_TZ is ignored; times are UTC
cronnext: $CRONTAB:10: warning: @reboot runs only when cron starts
cronnext: $CRONTAB:12: bad hour field '25': 25 is out of range 0-23
cronnext: $CRONTAB:13: missing command
cronnext: $CRONTAB:11: warning: '0 0 30 2 *' never runs
" --from 2026-10-20T14:37 -n 4 -f "$CRONTAB"

check "a weekend away" 0 'Sat 2026-10-24 12:00  #1  lunch
Sun 2026-10-25 12:00  #1  lunch
Mon 2026-10-26 09:00  #2  0 9 * * mon-fri
' --from 2026-10-24 -n 3 '0 12 * * sat,sun lunch' '0 9 * * mon-fri'

check "the day rule: 13th or Friday" 0 'Fri 2026-11-06 00:00  #1  0 0 13 * fri
Fri 2026-11-13 00:00  #1  0 0 13 * fri
Fri 2026-11-20 00:00  #1  0 0 13 * fri
Fri 2026-11-27 00:00  #1  0 0 13 * fri
Fri 2026-12-04 00:00  #1  0 0 13 * fri
Fri 2026-12-11 00:00  #1  0 0 13 * fri
Sun 2026-12-13 00:00  #1  0 0 13 * fri
' --from 2026-11-01 -n 7 '0 0 13 * fri'

check "leap day" 0 $'Tue 2028-02-29 03:15  #1  15 3 29 2 *\nSun 2032-02-29 03:15  #1  15 3 29 2 *\n' --from 2026-10-20 -n 2 '15 3 29 2 *'

# --until with no -n: every run before the end (the hourly lines are
# counted, the others compared).
run --from 2026-10-19 --until 2026-10-26 -s -f "$SYSTEM"
status=$?
grep -c 'cron.hourly' "$TMP/out" > "$TMP/got"
printf '168\n' > "$TMP/want"
report "until: every hourly run" $status 0 "$TMP/want" "$TMP/got"
grep -v 'cron.hourly' "$TMP/out" > "$TMP/got"
printf '%s\n' 'Mon 2026-10-19 06:25  tests/fixtures/system.crontab:6  (root) test -x /usr/sbin/anacron || run-parts --report /etc/cron.daily' \
    'Tue 2026-10-20 06:25  tests/fixtures/system.crontab:6  (root) test -x /usr/sbin/anacron || run-parts --report /etc/cron.daily' \
    'Wed 2026-10-21 06:25  tests/fixtures/system.crontab:6  (root) test -x /usr/sbin/anacron || run-parts --report /etc/cron.daily' \
    'Thu 2026-10-22 06:25  tests/fixtures/system.crontab:6  (root) test -x /usr/sbin/anacron || run-parts --report /etc/cron.daily' \
    'Fri 2026-10-23 06:25  tests/fixtures/system.crontab:6  (root) test -x /usr/sbin/anacron || run-parts --report /etc/cron.daily' \
    'Sat 2026-10-24 06:25  tests/fixtures/system.crontab:6  (root) test -x /usr/sbin/anacron || run-parts --report /etc/cron.daily' \
    'Sun 2026-10-25 06:25  tests/fixtures/system.crontab:6  (root) test -x /usr/sbin/anacron || run-parts --report /etc/cron.daily' \
    'Sun 2026-10-25 06:47  tests/fixtures/system.crontab:7  (root) test -x /usr/sbin/anacron || run-parts --report /etc/cron.weekly' > "$TMP/want"
report "until: the daily and weekly runs" $status 0 "$TMP/want" "$TMP/got"

check "iso and relative" 0 '2027-01-15T09:00:00Z  in 1h       #1  0 9 15 1 *
2027-01-18T09:00:00Z  in 3d 1h    #2  0 9 * * mon
2027-01-25T09:00:00Z  in 10d 1h   #2  0 9 * * mon
2027-02-01T00:00:00Z  in 16d 16h  #3  @monthly
' --from @1800000000 -n 4 --iso -r '0 9 15 1 *' '0 9 * * mon' '@monthly'

check "seconds round up" 0 $'Tue 2026-10-20 14:31  #1  * * * * *\n' --from '2026-10-20 14:30:01' -n 1 '* * * * *'
check "count 0" 0 '' --from 2026-10-20 -n 0 '* * * * *'

run -n 3 '* * * * *'
status=$?
wc -l < "$TMP/out" | tr -d ' ' > "$TMP/got"
printf '3\n' > "$TMP/want"
report "from now" $status 0 "$TMP/want" "$TMP/got"

IN=$CRONTAB check "crontab on standard input" 1 $'Tue 2026-10-20 03:00  stdin:7  /opt/app/bin/backup >> /var/log/backup.log 2>&1\n' --from 2026-10-20T02:30 -n 1 -f -

# --- each schedule on its own --------------------------------------------------------

check "each, relative" 0 '#1  0 6 * * *  wake up
  Sun 2026-10-25 06:00  in 6h
  Mon 2026-10-26 06:00  in 1d 6h
' --from 2026-10-25 -l -r -n 2 '0 6 * * * wake up'

check "each" 0 '#1  @daily (0 0 * * *)
  Tue 2026-10-20 00:00
  Wed 2026-10-21 00:00
  Thu 2026-10-22 00:00

#2  0 12 * * sat,sun  lunch
  Sat 2026-10-24 12:00
  Sun 2026-10-25 12:00
  Sat 2026-10-31 12:00
' --from 2026-10-20 -l -n 3 @daily '0 12 * * sat,sun lunch'

# --- explain ------------------------------------------------------------------------------

check "explain" 0 '#1  */15 9-17 * * mon-fri
    every 15 minutes between 09:00 and 17:59, on Monday through Friday
    next: Tue 2026-10-20 14:45

#2  0 0 1 */3 *
    at 00:00, on day 1 of the month, in every 3rd month
    next: none before Wed 2026-10-21 00:00

#3  @weekly (0 0 * * 0)  cleanup
    at 00:00, on Sunday
    next: none before Wed 2026-10-21 00:00

#4  5 4 * * *
    at 04:05
    next: none before Wed 2026-10-21 00:00
' --from 2026-10-20T14:37 --until 2026-10-21 -e '*/15 9-17 * * mon-fri' '0 0 1 */3 *' '@weekly cleanup' '5 4 * * *'

run --from 2026-10-20 -e -f "$CRONTAB"
status=$?
sed -n '9,11p' "$TMP/out" > "$TMP/got"
printf '%s\n' "$CRONTAB:8  30 4 1,15 * 5  /opt/app/bin/report --monthly" \
    '    at 04:30, on days 1 and 15 of the month or on Friday' \
    '    next: Fri 2026-10-23 04:30' > "$TMP/want"
report "explain a crontab line" $status 1 "$TMP/want" "$TMP/got"

# --- check -----------------------------------------------------------------------------------

check "check, clean" 0 '' -c -s -f "$SYSTEM"
check_err "check, problems" 1 "cronnext: $CRONTAB:4: warning: CRON_TZ is ignored; times are UTC
cronnext: $CRONTAB:10: warning: @reboot runs only when cron starts
cronnext: $CRONTAB:12: bad hour field '25': 25 is out of range 0-23
cronnext: $CRONTAB:13: missing command
cronnext: $CRONTAB:11: warning: '0 0 30 2 *' never runs
" -c -f "$CRONTAB"
check "check prints no times" 1 '' -c -f "$CRONTAB"
check "a system crontab without -s: the user is part of the command" 0 $'Tue 2026-10-20 06:25  tests/fixtures/system.crontab:6  root    test -x /usr/sbin/anacron || run-parts --report /etc/cron.daily\n' --from 2026-10-20T06:20 -n 1 -f "$SYSTEM"

# --- errors and exit statuses -------------------------------------------------------------------

check_err "bad operand, others still run" 1 $'cronnext: #1: bad minute field \'61\': 61 is out of range 0-59\ncronnext: #3: warning: \'0 0 30 2 *\' never runs\n' --from 2026-10-20 -n 2 '61 * * * *' '0 12 * * *' '0 0 30 2 *'
check "bad operand, the good one" 1 $'Tue 2026-10-20 12:00  #2  0 12 * * *\nWed 2026-10-21 12:00  #2  0 12 * * *\n' --from 2026-10-20 -n 2 '61 * * * *' '0 12 * * *'
check_err "reboot operand" 1 $'cronnext: #1: @reboot runs only when cron starts\n' --from 2026-10-20 @reboot
check_err "missing file" 1 $'cronnext: nope.cron: No such file or directory\n' -f nope.cron
check_err "directory" 1 $'cronnext: tests: Is a directory\n' -f tests

USAGE_HINT="Try 'cronnext --help' for more information."
check_err "no schedule" 2 "cronnext: no schedule given (give SCHEDULE operands or -f FILE)
$USAGE_HINT
"
check_err "bad --from" 2 "cronnext: invalid time 'yesterday' (use YYYY-MM-DD[THH:MM[:SS]], @SECONDS or now)
$USAGE_HINT
" --from yesterday @daily
check_err "bad --until" 2 "cronnext: invalid time '2026-02-30': invalid day: 30 for 2026-02
$USAGE_HINT
" --until 2026-02-30 @daily
check_err "time zone" 2 "cronnext: invalid time '2026-10-20T10:00+02:00': only UTC times are supported
$USAGE_HINT
" --from 2026-10-20T10:00+02:00 @daily
check_err "unknown option" 2 "cronnext: unrecognized option '--next'
$USAGE_HINT
" --next @daily
check_err "two modes" 2 "cronnext: --each and --check cannot be combined
$USAGE_HINT
" -lc @daily
check_err "bad count" 2 "cronnext: invalid count '-1'
$USAGE_HINT
" -n -1 @daily
check "usage error, no output" 2 '' -n x @daily

check "version" 0 $'cronnext (loup-cmd-cronnext) 0.1.0\n' --version
run -h
status=$?
head -1 "$TMP/out" > "$TMP/got"
printf 'usage: cronnext [OPTION]... [SCHEDULE]...\n' > "$TMP/want"
report "help" $status 0 "$TMP/want" "$TMP/got"

echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
