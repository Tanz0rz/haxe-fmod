#!/usr/bin/env python3
"""Prune the repo's GitHub Actions cache store.

The store is capped at 10GB and evicts least-recently-used entries once
full, so an unattended repo silently starts losing the caches it actually
needs. Two things fill it here:

  - Branch caches outlive their branch. Every branch that runs the full
    workflow copies the whole haxelib set (about 3.3GB), and deleting the
    branch does not delete its caches.
  - The hxcpp keys carry the commit sha so each run gets a fresh entry
    (that is what keeps them from going stale), which leaves one set per
    commit behind at roughly 100MB a commit.

So this removes caches whose branch is gone, caches left by tag runs,
caches on a side branch that has gone quiet, and all but the newest few
entries of each remaining key. Anything deleted is rebuilt by the next run
that wants it: the cost of being wrong here is one slow job, never a
broken one. The default branch is only ever pruned by the keep rule.

Usage:
  python3 ci/prune-caches.py --dry-run
  python3 ci/prune-caches.py --keep 2 --max-age-days 14
  python3 ci/prune-caches.py --branch some-deleted-branch   (PR cleanup)
"""

import argparse
import datetime
import json
import re
import subprocess
import sys

SHA_SUFFIX = re.compile(r"-[0-9a-f]{40}$")


def gh(*args):
    result = subprocess.run(["gh", *args], stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE)
    if result.returncode != 0:
        sys.stderr.write(result.stderr.decode("utf-8", "replace"))
        sys.exit(1)
    return result.stdout.decode("utf-8", "replace")


def mb(size):
    return size / 1048576.0


def fetch_caches(repo):
    raw = gh("api", "--paginate",
             "repos/{}/actions/caches?per_page=100".format(repo),
             "-q", ".actions_caches[] | @json")
    return [json.loads(line) for line in raw.splitlines() if line.strip()]


def fetch_default_branch(repo):
    return gh("api", "repos/{}".format(repo), "-q", ".default_branch").strip()


def age_days(created_at):
    """Age of an ISO8601 timestamp in days, naive UTC."""
    stamp = created_at.replace("Z", "").split(".")[0]
    then = datetime.datetime.strptime(stamp, "%Y-%m-%dT%H:%M:%S")
    return (datetime.datetime.utcnow() - then).total_seconds() / 86400.0


def fetch_live_branches(repo):
    raw = gh("api", "--paginate", "repos/{}/branches?per_page=100".format(repo),
             "-q", ".[].name")
    return {name for name in raw.splitlines() if name.strip()}


def base_key(key):
    """The key with its per-commit sha suffix removed, so every run of the
    same cache groups together."""
    return SHA_SUFFIX.sub("", key)


def plan(caches, live_branches, keep, only_branch, default_branch="master",
         max_age_days=None):
    """Returns (doomed, reason_by_id). Kept deliberately conservative: a
    cache is only dropped for a reason that can be named."""
    doomed, reason = [], {}

    def condemn(entry, why):
        doomed.append(entry)
        reason[entry["id"]] = why

    survivors = []
    for entry in caches:
        ref = entry.get("ref", "")
        name = ref[len("refs/heads/"):] if ref.startswith("refs/heads/") else ref

        if only_branch is not None:
            if name == only_branch:
                condemn(entry, "branch {} closed".format(only_branch))
            continue

        # Tag runs leave caches nothing will ever restore: a tag is built
        # once, and the doubled refs/heads/refs/tags/ prefix is how they
        # are recorded
        if "refs/tags/" in ref:
            condemn(entry, "tag run")
        elif name not in live_branches:
            condemn(entry, "branch {} no longer exists".format(name or ref))
        elif (max_age_days is not None and name != default_branch
              and age_days(entry["created_at"]) > max_age_days):
            # A side branch that has not built in weeks is done with its
            # caches, and one stale branch can hold gigabytes. The default
            # branch is exempt: its caches stay hot by definition.
            condemn(entry, "{} idle {:.0f}d".format(name, age_days(entry["created_at"])))
        else:
            survivors.append(entry)

    if only_branch is not None:
        return doomed, reason

    # Of what is left, keep the newest few of each key. Stable keys (no sha
    # suffix) have one entry each and fall under the limit untouched.
    groups = {}
    for entry in survivors:
        groups.setdefault((entry["ref"], base_key(entry["key"])), []).append(entry)
    for (ref, key), entries in sorted(groups.items()):
        if len(entries) <= keep:
            continue
        entries.sort(key=lambda e: e["created_at"], reverse=True)
        for entry in entries[keep:]:
            condemn(entry, "superseded ({} newer)".format(keep))

    return doomed, reason


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", default="Tanz0rz/haxe-fmod")
    parser.add_argument("--keep", type=int, default=2,
                        help="entries to keep per key (default 2)")
    parser.add_argument("--max-age-days", type=int, default=14,
                        help="drop non-default-branch caches older than this"
                             " (default 14, 0 disables)")
    parser.add_argument("--branch", default=None,
                        help="delete only this branch's caches (PR cleanup)")
    parser.add_argument("--dry-run", action="store_true")
    options = parser.parse_args()

    caches = fetch_caches(options.repo)
    live = fetch_live_branches(options.repo) if options.branch is None else set()
    default_branch = fetch_default_branch(options.repo) if options.branch is None else ""
    total = sum(entry["size_in_bytes"] for entry in caches)
    print("store: {:.0f} MB across {} caches".format(mb(total), len(caches)))

    doomed, reason = plan(caches, live, options.keep, options.branch,
                          default_branch, options.max_age_days or None)
    if not doomed:
        print("nothing to prune")
        return

    freed = sum(entry["size_in_bytes"] for entry in doomed)
    for entry in sorted(doomed, key=lambda e: -e["size_in_bytes"]):
        print("  {} {:>7.0f} MB  {}  [{}]".format(
            "would delete" if options.dry_run else "deleting",
            mb(entry["size_in_bytes"]), entry["key"], reason[entry["id"]]))

    if options.dry_run:
        print("would free {:.0f} MB, leaving {:.0f} MB".format(
            mb(freed), mb(total - freed)))
        return

    failed = 0
    for entry in doomed:
        result = subprocess.run(
            ["gh", "api", "-X", "DELETE",
             "repos/{}/actions/caches/{}".format(options.repo, entry["id"])],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if result.returncode != 0:
            failed += 1
            print("  failed to delete {}".format(entry["key"]))
    print("freed {:.0f} MB, leaving {:.0f} MB ({} failed)".format(
        mb(freed), mb(total - freed), failed))


if __name__ == "__main__":
    main()
