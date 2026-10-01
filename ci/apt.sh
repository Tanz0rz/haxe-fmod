#!/usr/bin/env bash
# apt-get with every download bounded by the clock. A stalled mirror
# otherwise holds one install until the job limit cancels the job.
#
# bash ci/apt.sh update
# bash ci/apt.sh install -y <packages...>
#
# update and the download half of install each get three attempts, and
# an attempt that runs past its limit is killed. Packages already
# fetched stay in the cache, so the next attempt resumes. One retry and
# a short timeout per package send a stalled fetch on to the next
# mirror. The unpack half runs once with no limit, since killing dpkg
# leaves the package database broken.
set -u
[ "$#" -gt 0 ] || { echo "apt: no command given" >&2; exit 2; }
OPTS="-o Acquire::Retries=1 -o Acquire::http::Timeout=10 -o Acquire::https::Timeout=10"
UPDATE_LIMIT="${APT_UPDATE_LIMIT:-120}"
DOWNLOAD_LIMIT="${APT_DOWNLOAD_LIMIT:-240}"
PAUSE="${APT_PAUSE:-10}"

bounded() {
  limit="$1"
  shift
  for attempt in 1 2 3; do
    # timeout runs under sudo, so its signal reaches apt-get
    sudo timeout -k 10 "$limit" apt-get $OPTS "$@" && return 0
    status=$?
    echo "apt: '$1' failed or ran past ${limit}s (status $status), attempt $attempt of 3" >&2
    [ "$attempt" = 3 ] && return "$status"
    sleep "$PAUSE"
  done
}

command="$1"
shift
case "$command" in
  update)
    bounded "$UPDATE_LIMIT" update "$@"
    ;;
  install)
    bounded "$DOWNLOAD_LIMIT" install --download-only "$@" || exit $?
    sudo apt-get install --no-download "$@"
    ;;
  *)
    echo "apt: unknown command '$command'" >&2
    exit 2
    ;;
esac
