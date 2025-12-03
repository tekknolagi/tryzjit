FROM ubuntu:24.04 AS builder
RUN apt-get update && apt-get install -y \
  clang \
  git \
  autoconf \
  make \
  libatomic1 \
  && rm -rf /var/lib/apt/lists/* \
  && adduser --disabled-password user
USER user

# Build Ruby executable
FROM builder AS ruby-builder
ARG RUBY_REVISION=master
WORKDIR /app/ruby
RUN git clone --depth=1 --branch "$RUBY_REVISION" https://github.com/ruby/ruby.git . \
  && ./autogen.sh \
  && ./configure --enable-zjit=dev --disable-yjit \
  && make -sj "$(nproc)"

# Final image
FROM ubuntu:24.04
RUN apt-get update && apt-get install -y ca-certificates libatomic1 \
  && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=ruby-builder /app/ruby/miniruby /app/ruby
COPY server.rb /app/server.rb
COPY static ./static
EXPOSE 3000
CMD ["/app/ruby", "/app/server.rb"]
