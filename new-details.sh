#!/usr/bin/env bash
new_details=$(curl -s https://api.github.com/repos/ruby/ruby/commits | jq -f new-details.jq -r)
if [ $? -ne 0 ] || [ -z "$new_details" ]; then
  echo "Failed to fetch commit details" >&2
  exit 1
fi

comment=$(echo "$new_details" | head -1)
revision=$(echo "$new_details" | tail -1)

if [[ "$OSTYPE" == "darwin"* ]]; then
  sed -i '' "s|^# REV: .*|$comment|" Dockerfile
  sed -i '' "s|^ENV RUBY_REVISION=.*|$revision|" Dockerfile
else
  sed -i "s|^# REV: .*|$comment|" Dockerfile
  sed -i "s|^ENV RUBY_REVISION=.*|$revision|" Dockerfile
fi

echo "$new_details"
