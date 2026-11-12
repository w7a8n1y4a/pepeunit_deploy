#!/bin/bash
set -eu

cache="${PU_SAVE_REPO_PATH:-repo_cache}"
if [ -L "$cache" ]; then
  echo "Repository cache must be a directory, not a symlink: $cache" >&2
  exit 1
fi
mkdir -p -- "$cache"
chown -R -P --no-dereference 10001:10001 -- "$cache"
