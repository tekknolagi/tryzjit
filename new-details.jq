def first_line(s):
  s | split("\n") | .[0];

def get_latest_commit(o):
  if (o | type) != "array" then
    # Probably rate limited
    error(o)
  else
    o | .[0]
  end;

get_latest_commit(.) | "# \(.commit.message | first_line(.)) \(.commit.committer.date)\nENV RUBY_REVISION=\(.sha)"
