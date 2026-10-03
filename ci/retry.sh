#!/usr/bin/env bash
# Runs a command up to three times with a pause between attempts. A
# transient failure of a network fetch otherwise costs a whole job.
# --clean <dir> removes a directory before each attempt after the first,
# for a clone whose target a failed attempt left behind.
#
# bash ci/retry.sh [--clean <dir>] <command...>
set -u
[ "$#" -gt 0 ] || { echo "retry: no command given" >&2; exit 2; }
attempts=3
pause=15
clean=""
if [ "${1:-}" = "--clean" ]; then
  clean="$2"
  shift 2
fi
for attempt in $(seq "$attempts"); do
  if [ "$attempt" != 1 ] && [ -n "$clean" ]; then rm -rf "$clean"; fi
  "$@" && exit 0
  status=$?
  if [ "$attempt" = "$attempts" ]; then
    echo "retry: '$1' failed $attempts times" >&2
    exit $status
  fi
  echo "retry: '$1' failed with status $status, attempt $attempt of $attempts" >&2
  sleep $pause
done
exit "${status:-1}"
