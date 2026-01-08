def first_line(s):
  s | split("\n") | .[0];

.[0] | "# \(.commit.message | first_line(.)) \(.commit.committer.date)\nENV RUBY_REVISION=\(.sha)"
