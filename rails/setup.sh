#!/usr/bin/env bash
# Check out rails/rails at RAILS_REVISION (read from the Dockerfile unless set
# in the environment) into rails/src, and bundle it into rails/vendor/bundle.
# Run with the same ZJIT ruby that serves the site.
set -euo pipefail
cd "$(dirname "$0")"

rev="${RAILS_REVISION:-$(sed -n 's/^ENV RAILS_REVISION=//p' ../Dockerfile)}"
if [ "$(cat src/.revision 2>/dev/null)" != "$rev" ]; then
  rm -rf src
  git init -q src
  git -C src fetch -q --depth=1 https://github.com/rails/rails.git "$rev"
  git -C src checkout -q FETCH_HEAD
  rm -rf src/.git
  echo "$rev" > src/.revision
fi

bundle config set --local path vendor/bundle
bundle install
