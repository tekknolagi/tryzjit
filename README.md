# tryzjit

## Running locally

Running tryzjit requires having a version of Ruby with ZJIT support as well as
the `--zjit-dump-hir-iongraph` flag available. Ensure that your executable
`ruby` points to one.

```bash
ruby website/server.rb
```

## Running with Docker

```bash
docker build -t tryzjit .
```

```bash
docker run -i -t -p 8081:8081 tryzjit
```

## Rails page

`/rails` is the same explorer, but the server boots a minimal single-file Rails
app (in-memory SQLite, `eager_load = true`) before the snippet runs, and only
then enables ZJIT. Rails is pinned by `RAILS_REVISION` in the Dockerfile and
bumped by `new-details.sh` alongside Ruby. To set it up locally, run this once
(and again after a bump) with the same ZJIT `ruby` on your PATH:

```bash
rails/setup.sh
```

It checks out that revision into `rails/src` and bundles `rails/Gemfile` into
`rails/vendor/bundle`. The Docker image runs the same script at build time.
