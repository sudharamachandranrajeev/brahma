#!/usr/bin/env bash
# Brings each app's latest main into apps/<name>.
#
# The apps are developed in their own repositories; apps/ holds them as git
# subtrees (with full history) so the suite app can build them together.
# Never edit apps/<name> here: change the app's repository, push, then run
# this. Usage: scripts/pull-apps.sh [name...]   (default: every app)
set -euo pipefail
cd "$(dirname "$0")/.."
owner=https://github.com/sudharamachandranrajeev

# apps/<name> comes from the repository of the same name, except these.
declare -A repo=([anveshana]=graha-anveshana [vahana]=vahana-anveshana)

if [ -n "$(git status --porcelain)" ]; then
  echo "Commit or stash your changes first." >&2
  exit 1
fi

names=("$@")
if [ ${#names[@]} -eq 0 ]; then
  for d in apps/*/; do names+=("$(basename "$d")"); done
fi

for name in "${names[@]}"; do
  echo "== $name"
  from=${repo[$name]:-$name}
  git subtree pull --prefix "apps/$name" "$owner/$from.git" main \
    -m "Update apps/$name from $from main

Co-Authored-By: Claude Code <noreply@anthropic.com>"
done
