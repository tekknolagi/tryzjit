FROM ubuntu:24.04 as builder
RUN apt -y update
RUN apt install -y \
    clang \
    git \
    autoconf \
    rustup \
    ruby \
    make
RUN adduser --disabled-password user
USER user
RUN rustup default 1.85

FROM builder as build
WORKDIR /app
# Compatibility with test-unit-ruby-core 2025-10-17
ENV RUBY_REVISION=837947ac7fb52c0492eb148e3cb17946aefaadc4
RUN git init ruby
WORKDIR /app/ruby
RUN git remote add origin https://github.com/ruby/ruby.git
RUN git fetch --depth=1 origin "$RUBY_REVISION"
RUN git reset --hard FETCH_HEAD
RUN ./autogen.sh
RUN ./configure --enable-zjit=dev --disable-yjit
RUN make -sj $(nproc)

FROM ubuntu:24.04 as server_builder
RUN apt -y update
RUN apt install -y python3

FROM server_builder as explorer
COPY --from=build /app/ruby/ruby /usr/local/bin/ruby
COPY website/ /app/website
WORKDIR /app/website
ENTRYPOINT python3 gen.py explorer --runtime /usr/local/bin/ruby --ipv6
