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
