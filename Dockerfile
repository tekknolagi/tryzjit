FROM ubuntu:24.04 AS builder
RUN apt-get update && apt-get install -y \
  clang \
  git \
  autoconf \
  rustup \
  ruby \
  make \
  jq \
  && rm -rf /var/lib/apt/lists/* \
  && adduser --disabled-password user
USER user
RUN rustup default stable

# Build Ruby executable
FROM builder AS ruby-builder
ARG RUBY_REVISION=master
WORKDIR /app/ruby
RUN git clone --depth=1 --branch "$RUBY_REVISION" https://github.com/ruby/ruby.git . \
  && ./autogen.sh \
  && ./configure --enable-zjit=dev --disable-yjit \
  && make -sj "$(nproc)"

# Build Rust server
FROM builder AS rust-builder
WORKDIR /app
COPY --chown=user:user Cargo.toml Cargo.lock ./
COPY --chown=user:user src ./src
RUN cargo build --release

# Final image
FROM ubuntu:24.04
RUN apt-get update && apt-get install -y ca-certificates \
  && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=ruby-builder /app/ruby/miniruby /app/ruby
COPY --from=rust-builder /app/target/release/tryzjit-v2 /app/tryzjit-v2
COPY static ./static
EXPOSE 3000
CMD ["/app/tryzjit-v2"]
