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
# [ruby/prism] Fix wrong error message for lower percent i arrays
ENV RUBY_REVISION=d5c7cf0a1a1d2a72421b9a166e19442f89b99868
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

FROM server_builder as explorer
COPY --from=build /app/ruby/ruby /usr/local/bin/ruby
COPY static/ /app/static
WORKDIR /app
ENTRYPOINT ruby server.ruby
