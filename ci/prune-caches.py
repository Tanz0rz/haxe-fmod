#!/usr/bin/env python3
"""Prune the repo's GitHub Actions cache store.

The store is capped at 10GB and evicts least-recently-used entries once
full, so an unattended repo silently starts losing the caches it actually
needs. Two things fill it here:

  - Branch caches outlive their branch. Every branch that runs the full
    workflow copies the whole haxelib set (about 3.3GB), and deleting the
    branch does not delete its caches.
  - The hxcpp keys carry the commit sha so each run gets a fresh entry.
    That is what keeps them from going stale, and it leaves one set per
    commit behind at roughly 100MB a commit.

So this removes caches whose branch is gone and caches left by tag
runs. It removes caches on a side branch that has gone quiet, and
stable keys a pin rotation left behind. It also removes all but the
newest few entries of
each remaining key. Anything deleted is rebuilt by the next run that
wants it. The cost of being wrong here is one slow job, never a broken
one. The default branch is only ever pruned by the keep rule.

Usage:
  python3 ci/prune-caches.py --selftest
  python3 ci/prune-caches.py --dry-run
  python3 ci/prune-caches.py --keep 2 --max-age-days 14
  python3 ci/prune-caches.py --branch some-deleted-branch   (PR cleanup)
"""

import argparse
import os
import sys
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


def age_days(when):
    """Age of an ISO8601 timestamp in days, naive UTC."""
    stamp = when.replace("Z", "").split(".")[0]
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


FAMILY = re.compile(r"^(haxelib-.*?)-[0-9]+\.[0-9]+\.[0-9]+((?:-[a-z]+)*)-lime[0-9.]+-.*$")


def family(key):
    """A haxelib key without its Haxe version and pins. A pin rotation
    changes those and leaves the old key for nothing to restore. Every
    other key kind can hold two live versions at once, so none of them
    has a family."""
    m = FAMILY.match(key)
    return m.group(1) + m.group(2) if m else None


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

        # Tag runs leave caches nothing restores. A tag is built once,
        # and the doubled refs/heads/refs/tags/ prefix is how the runner
        # records them
        if "refs/tags/" in ref:
            condemn(entry, "tag run")
        elif name not in live_branches:
            condemn(entry, "branch {} no longer exists".format(name or ref))
        elif (max_age_days is not None and name != default_branch
              and age_days(entry["last_accessed_at"]) > max_age_days):
            # A side branch whose caches nothing has restored in weeks is
            # done with them, and one stale branch can hold gigabytes. The
            # stable keys of a busy branch are created once and restored
            # on every run, so the last restore is the idle measure. The
            # default branch is exempt: its caches stay hot by definition.
            condemn(entry, "{} idle {:.0f}d".format(name, age_days(entry["last_accessed_at"])))
        else:
            survivors.append(entry)

    if only_branch is not None:
        return doomed, reason

    # A stable key a pin rotation left behind has a newer key of its
    # family on the same ref. Nothing restored the old key since the
    # newer one was created. Two keys a workflow restores in turn both
    # stay, since each is touched after the other was created.
    families = {}
    for entry in survivors:
        fam = family(entry["key"])
        if fam is None:
            continue
        families.setdefault((entry["ref"], fam), []).append(entry)
    orphaned = set()
    for (ref, fam), entries in sorted(families.items()):
        newest = max(entries, key=lambda e: e["created_at"])
        for entry in entries:
            if entry is newest:
                continue
            if entry["last_accessed_at"] <= newest["created_at"]:
                condemn(entry, "superseded by {}".format(newest["key"]))
                orphaned.add(entry["id"])
    survivors = [entry for entry in survivors if entry["id"] not in orphaned]

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


def selftest():
    """The rules against fixtures shaped like the live store."""
    def stamp(days_ago):
        when = datetime.datetime.utcnow() - datetime.timedelta(days=days_ago)
        return when.strftime("%Y-%m-%dT%H:%M:%SZ")

    def entry(id, key, created, accessed, ref="refs/heads/dev"):
        return {"id": id, "ref": ref, "key": key, "created_at": stamp(created),
                "last_accessed_at": stamp(accessed), "size_in_bytes": 1}

    pins_old = "haxelib-hl-Linux-4.3.6-lime8.3.0-openfl9.5.0"
    pins_new = "haxelib-hl-Linux-4.3.6-lime8.3.0-openfl9.5.0-dox1.6.0"
    docs_a = "haxelib-docs-Linux-4.3.6-lime8.3.0-openfl9.5.0-dox1.6.0"
    docs_b = "haxelib-docs-Linux-4.3.6-flixel-heaps-lime8.3.0-openfl9.5.0-dox1.6.0"
    sha_a = "hxcpp-Linux-app-" + "a" * 40
    sha_b = "hxcpp-Linux-app-" + "b" * 40
    sha_c = "hxcpp-Linux-app-" + "c" * 40
    caches = [
        entry(1, pins_old, 3, 2),             # rotated away, unused since
        entry(2, pins_new, 1, 0),             # the live key
        entry(3, "fmod-sdk-Linux-2.02.33", 5, 2),   # two SDK versions, both live
        entry(4, "fmod-sdk-Linux-2.03.12", 1, 0),   # newer, and the old one idle since
        entry(5, sha_a, 3, 3), entry(6, sha_b, 2, 2), entry(7, sha_c, 1, 1),
        entry(8, "kha-macOS-" + "d" * 40, 30, 0),   # restored today, stays
        entry(9, "kha-macOS-" + "e" * 40, 30, 30),  # idle a month
        entry(10, pins_new, 1, 0, ref="refs/heads/gone"),
        entry(11, pins_new, 1, 0, ref="refs/heads/refs/tags/v1"),
        entry(12, docs_a, 1, 0),              # two docs keys, distinct families
        entry(13, docs_b, 2, 1),
    ]
    doomed, reason = plan(caches, {"master", "dev"}, 2, None, "master", 14)
    got = {e["id"]: reason[e["id"]] for e in doomed}
    expect = {
        1: "superseded by " + pins_new,
        5: "superseded (2 newer)",
        9: "dev idle 30d",
        10: "branch gone no longer exists",
        11: "tag run",
    }
    if got != expect:
        print("selftest FAIL: got {} expected {}".format(got, expect))
        sys.exit(1)
    doomed, reason = plan(caches, {"master", "dev"}, 2, "dev", "master", 14)
    if sorted(e["id"] for e in doomed) != [1, 2, 3, 4, 5, 6, 7, 8, 9, 12, 13]:
        print("selftest FAIL: branch close kept {}".format(sorted(e["id"] for e in doomed)))
        sys.exit(1)
    # The family regex against the keys the workflow makes today, so a
    # reordered pins string cannot switch the rule off unnoticed
    workflow = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".github", "workflows", "audio-test.yml")
    with open(workflow) as fh:
        text = fh.read()
    pins = re.search(r"HAXELIB_PINS: (\S+)", text).group(1)
    haxe = re.search(r"HAXE_VERSION: (\S+)", text).group(1)
    live_keys = ["haxelib-{}-Linux-{}-{}".format(label, haxe, pins)
                 for label in ("hl", "cpp", "docs", "doctor", "html5", "package")]
    live_keys.append("haxelib-docs-Linux-{}-flixel-heaps-{}".format(haxe, pins))
    families = [family(key) for key in live_keys]
    if any(f is None for f in families) or len(set(families)) != len(families):
        print("selftest FAIL: the family regex does not fit the workflow's keys: {}".format(families))
        sys.exit(1)
    print("prune-caches selftest: all rules hold")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--selftest", action="store_true",
                        help="run the rules against fixtures and exit")
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
    if options.selftest:
        selftest()
        return

    caches = fetch_caches(options.repo)
    live = fetch_live_branches(options.repo) if options.branch is None else set()
    default_branch = fetch_default_branch(options.repo) if options.branch is None else ""
    # An empty branch listing reads as every branch gone, which condemns
    # the whole store. A listing that empty is an API failure, so stop.
    if options.branch is None and (not live or not default_branch):
        print("refusing to prune: the branch listing came back empty")
        sys.exit(1)
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
    # A refused delete fails the step, so a token without the right
    # scope is noticed instead of the store filling up
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
