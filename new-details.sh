#!/usr/bin/env bash
curl -s https://api.github.com/repos/ruby/ruby/commits | jq -f new-details.jq -r
