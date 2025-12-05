FROM ubuntu:24.04 as builder
RUN apt -y update
RUN apt install -y \
    clang \
    git \
    autoconf \
    rustup \
    ruby \
    libatomic1 \
    make
RUN adduser --disabled-password user
USER user
RUN rustup default 1.85

FROM builder as build
WORKDIR /app
# ZJIT: Add tests for Kernel#kind_of? 2025-11-21T17:21:57Z
ENV RUBY_REVISION=1959fcacb357ec548ed8a000c6dc6e5f39a3fb55
RUN git init ruby
WORKDIR /app/ruby
RUN git remote add origin https://github.com/ruby/ruby.git
RUN git fetch --depth=1 origin "$RUBY_REVISION"
RUN git reset --hard FETCH_HEAD
RUN ./autogen.sh
RUN ./configure --enable-zjit=dev --disable-yjit --prefix=/usr/local --disable-install-doc
RUN make -sj $(nproc)

FROM ubuntu:24.04 as explorer
COPY --from=build /app/ruby/ruby /usr/local/bin/ruby
COPY static/ /app/static
COPY server.rb /app/server.rb
WORKDIR /app
EXPOSE 8081
ENTRYPOINT ["/usr/local/bin/ruby", "server.rb"]
