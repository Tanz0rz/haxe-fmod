#!/usr/bin/env python3
"""Prints the source hash the HashLink shim carries as its
hlaxe_fmod_src marker. build-hdll computes the same hash
(BuildHdll.sourceHash) and passes it to the compiler, and the package
check compares the two on a release tag. That proves the shipped hdlls
were built from the tagged shim sources.

The hash is SHA-1 over the shim source, every shared header, and the
manifest, in sorted path order, each as its path, a newline, its bytes,
and a newline.

Run: python3 ci/hlaxe-src-hash.py [repo-root]
"""
import hashlib
import os
import sys


def source_files(root):
    shared = sorted(f for f in os.listdir(os.path.join(root, "native", "shared")) if f.endswith(".h"))
    return (["native/hlaxe/hlaxe_fmod.c"]
            + ["native/shared/" + f for f in shared]
            + ["native/manifest/studio_api.txt"])


def source_hash(root):
    digest = hashlib.sha1()
    for rel in source_files(root):
        with open(os.path.join(root, rel), "rb") as fh:
            digest.update(rel.encode("utf-8") + b"\n" + fh.read() + b"\n")
    return digest.hexdigest()


if __name__ == "__main__":
    print(source_hash(sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")))
