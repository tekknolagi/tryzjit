#!/usr/bin/env bash
curl -s https://api.github.com/repos/ruby/ruby/commits | jq -r '.[0] | "# \(.commit.message) \(.commit.committer.date)\nENV RUBY_REVISION=\(.sha)"'
