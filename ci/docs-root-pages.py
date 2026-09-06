"""MkDocs hook that serves the repo-root docs from inside the site.

LIMITATIONS.md, MIGRATION.md, and CHANGELOG.md ship in the haxelib
package and are linked from the README, so they stay at the repo root.
This hook adds them to the site build as limitations.md, migration.md,
and changelog.md without keeping a second copy under docs/.

Relative links inside those files point at repo-root files (LICENSE,
fmod-scripts/...). They are rewritten to GitHub URLs so they keep working
from the rendered site.
"""

import os
import re

from mkdocs.structure.files import File

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

ROOT_PAGES = {
    "LIMITATIONS.md": "limitations.md",
    "MIGRATION.md": "migration.md",
    "CHANGELOG.md": "changelog.md",
}

GITHUB_BLOB = "https://github.com/Tanz0rz/haxe-fmod/blob/master/"

# Links that already resolve to another root page keep pointing inside
# the site. Everything else that looks like a repo path goes to GitHub.
_LINK = re.compile(r"\]\((?!https?://|#|mailto:)([^)\s]+)\)")


def _rewrite(match):
    target = match.group(1)
    for source, page in ROOT_PAGES.items():
        if target == source or target.startswith(source + "#"):
            return "](" + target.replace(source, page) + ")"
    return "](" + GITHUB_BLOB + target + ")"


def on_files(files, config):
    for source, page in ROOT_PAGES.items():
        with open(os.path.join(ROOT, source), encoding="utf-8") as fh:
            content = _LINK.sub(_rewrite, fh.read())
        files.append(File.generated(config, page, content=content))
    return files
