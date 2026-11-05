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

rails_details=$(curl -s https://api.github.com/repos/rails/rails/commits | jq -f new-details.jq -r)
if [ $? -ne 0 ] || [ -z "$rails_details" ]; then
  echo "Failed to fetch Rails commit details" >&2
  exit 1
fi

rails_comment=$(echo "$rails_details" | head -1 | sed 's|^# REV: |# RAILS REV: |')
rails_revision=$(echo "$rails_details" | tail -1 | sed 's|^ENV RUBY_REVISION=|ENV RAILS_REVISION=|')

if [[ "$OSTYPE" == "darwin"* ]]; then
  sed -i '' "s|^# RAILS REV: .*|$rails_comment|" Dockerfile
  sed -i '' "s|^ENV RAILS_REVISION=.*|$rails_revision|" Dockerfile
else
  sed -i "s|^# RAILS REV: .*|$rails_comment|" Dockerfile
  sed -i "s|^ENV RAILS_REVISION=.*|$rails_revision|" Dockerfile
fi

echo "$new_details"
echo "$rails_comment"
echo "$rails_revision"
